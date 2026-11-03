# Maintain-SocialAuto.ps1 - zero-downtime maintenance for the socialauto stack
# (cu130-slim compose + Docker Model Runner inside WSL Ubuntu-24.04)
# CATEGORY: maintenance
<#
.SYNOPSIS
    Zero-downtime maintenance for the socialauto (cu130-slim) infrastructure.

.DESCRIPTION
    Performs only non-disruptive actions and reports on everything else:

    SAFE (default ON):
      - Prunes exited containers, dangling (untagged) images, and build cache
        older than 7 days. Never touches running containers, tagged images
        (rollback snapshots), volumes, or networks.
      - Drops WSL page caches when host free memory is below -MinHostFreeGB
        (proven safe; caches rebuild on demand).
    REPORT-ONLY (no action without -Remediate):
      - Unhealthy containers are listed; -Remediate restarts them (they are
        already failing, so this cannot take the platform down).
    INFORMATIONAL:
      - DMR health + loaded models, watchdog status, docker system df, and a
        reminder that all containers use unbounded json-file logs (fixing that
        requires container recreation - downtime - so it stays manual).

    Deliberately NOT automated (downtime-bearing): image updates, container
    recreates, vhdx compaction, wsl --shutdown, volume prune.

.PARAMETER Remediate
    Restart unhealthy containers (they are already failing). Default: report only.

.PARAMETER ReportOnly
    Skip all mutating actions (prunes, cache drop); print what would happen.

.PARAMETER MinHostFreeGB
    Drop WSL page caches when host free memory falls below this. Default 2.

.PARAMETER LogDir
    Directory for the run log. Default D:\DevOptimizer\logs. Set to 'none' to
    disable file logging.

.EXAMPLE
    .\Maintain-SocialAuto.ps1
    Standard maintenance pass (safe actions on, unhealthy report-only).

.EXAMPLE
    .\Maintain-SocialAuto.ps1 -ReportOnly

.EXAMPLE
    .\Maintain-SocialAuto.ps1 -Remediate
    Also restarts containers that are currently unhealthy.

.NOTES
    Exit codes: 0 = clean pass; 1 = WSL/engine unreachable; 2 = unhealthy
    containers found (remediated or not). Zero downtime by design.
#>
param(
    [switch]$Remediate,
    [switch]$ReportOnly,
    [int]$MinHostFreeGB = 2,
    [string]$LogDir = 'D:\DevOptimizer\logs'
)

$distro = 'Ubuntu-24.04'
$ErrorActionPreference = 'Continue'

function Invoke-Wsl([string]$cmd, [switch]$AsRoot) {
    if ($AsRoot) {
        $out = & wsl.exe -d $distro -u root -- bash -c $cmd 2>$null
    } else {
        $out = & wsl.exe -d $distro -- bash -c $cmd 2>$null
    }
    $joined = (@($out) -join "`n") -replace "`0", ''
    # wsl.exe can deliver multi-line output as ONE element with embedded
    # newlines; split so callers always get real lines.
    return ($joined -split "`r?`n") | Where-Object { $_ -ne '' }
}

# --- File logging ---
$logFile = $null
if ($LogDir -and $LogDir -ne 'none') {
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    $logFile = Join-Path $LogDir ("socialauto-maintenance-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))
}
function Write-Log([string]$line) {
    Write-Host $line
    if ($logFile) { Add-Content -Path $logFile -Value "[$(Get-Date -Format 'HH:mm:ss')] $line" -Encoding UTF8 }
}

# --- Transcript pattern: route output through Write-Log -----------------------
# (console + optional file in one call; sections below use Write-Log only)

Write-Log "=== SocialAuto Maintenance - zero-downtime pass - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
if ($ReportOnly) { Write-Log "[MODE] report-only: no prunes, no cache drop" }

# --- 0. Preflight (tolerates the engine still booting when this pass fires as
#        a logon catch-up: wait up to ~8 minutes for docker to answer) ---
$ping = @(Invoke-Wsl 'echo ok') | Where-Object { $_ -match '^ok$' }
if (-not $ping) {
    Write-Log "[FAIL] WSL distro '$distro' unreachable - maintenance aborted (platform itself is untouched)."
    exit 1
}
# Accept ONLY a clean version line. When the distro's docker shim is missing
# (WSL-integration cold-start race, hit 2026-10-06 04:00), wsl.exe relays the
# "docker could not be found" text on STDOUT - and -notmatch applied to an
# array FILTERS elements instead of testing, so the error text used to pass
# this check and every later count parsed the error lines as data.
$engineOk = $false
$serverVersion = ''
for ($i = 0; $i -lt 48; $i++) {
    $serverVersion = Invoke-Wsl 'docker version --format {{.Server.Version}} 2>/dev/null || echo DOWN'
    $verLine = @($serverVersion) | Where-Object { $_ -match '^\s*\d+(\.\d+){1,3}\s*$' } | Select-Object -First 1
    if ($verLine) { $engineOk = $true; $serverVersion = $verLine.Trim(); break }
    if ($i -eq 0) { Write-Log "[WAIT] docker engine/CLI not answering yet - waiting up to 8 minutes ..." }
    Start-Sleep -Seconds 10
}
if (-not $engineOk) {
    Write-Log "[FAIL] Docker engine/CLI not responsive inside WSL after 8 minutes - maintenance aborted."
    exit 1
}
Write-Log "[ OK ] WSL + docker engine responsive (server $serverVersion)"

# --- 1. Stack snapshot (before) ---
# Only a pure-digit line is a count; anything else on stdout is error text,
# never data. -1 = unreadable, which aborts the pass below.
function Get-StackCount([string]$wslCmd) {
    $digits = @(Invoke-Wsl $wslCmd) | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1
    if ($null -ne $digits) { return [int]($digits.Trim()) }
    return -1
}
$before = [ordered]@{
    running   = Get-StackCount 'docker ps -q | wc -l'
    unhealthy = Get-StackCount 'docker ps --filter health=unhealthy -q | wc -l'
    exited    = Get-StackCount 'docker ps -a --filter status=exited -q | wc -l'
}
if (($before.running -lt 0) -or ($before.unhealthy -lt 0) -or ($before.exited -lt 0)) {
    Write-Log "[FAIL] could not read stack counts (docker CLI missing inside distro?) - aborting."
    exit 1
}
Write-Log "[ OK ] stack before: $($before.running) running / $($before.unhealthy) unhealthy / $($before.exited) exited"

# --- 2. Safe housekeeping: prunes ---
if ($ReportOnly) {
    $dangling = [int](Invoke-Wsl 'docker images -f dangling=true -q | wc -l').Trim()
    Write-Log "[ DRY ] would prune: $dangling dangling image(s), exited containers, build cache older than 7 days"
} else {
    # Exited containers that must never be pruned: the cu130-slim compose
    # project (stack-ops idle-sleep keeps most of it stopped on purpose -
    # pruning them once deleted 16 sleeping containers incl. ComfyUI and all
    # browser sidecars) and the Desktop model-runner container (outside
    # compose, deleted by a prune once already). container prune honors
    # label!= filters; docker ps does not, so counts are computed by
    # subtracting protected IDs from the exited list.
    $pruneFilters = '--filter "label!=com.docker.compose.project=cu130-slim" --filter "label!=com.docker.desktop.service=model-runner"'
    $exitedIds = @(Invoke-Wsl 'docker ps -a --filter status=exited -q' | Where-Object { $_ -match '^[0-9a-f]+$' })
    $protectedIds = @(
        @(Invoke-Wsl 'docker ps -a --filter status=exited --filter "label=com.docker.compose.project=cu130-slim" -q') +
        @(Invoke-Wsl 'docker ps -a --filter status=exited --filter "label=com.docker.desktop.service=model-runner" -q')
    ) | Select-Object -Unique
    $prunable = @($exitedIds | Where-Object { $protectedIds -notcontains $_ }).Count
    if ($prunable -gt 0) {
        [void](Invoke-Wsl "docker container prune -f $pruneFilters")
        Write-Log "[ OK ] pruned exited containers: $prunable removed ($($protectedIds.Count) protected - stack-ops sleeping/compose + DMR runner)"
    } else {
        Write-Log "[ OK ] no exited containers to prune"
    }

    $dangling = [int](Invoke-Wsl 'docker images -f dangling=true -q | wc -l').Trim()
    if ($dangling -gt 0) {
        [void](Invoke-Wsl 'docker image prune -f')
        $danglingAfter = [int](Invoke-Wsl 'docker images -f dangling=true -q | wc -l').Trim()
        Write-Log "[ OK ] pruned dangling images: $($dangling - $danglingAfter) removed"
    } else {
        Write-Log "[ OK ] no dangling images"
    }

    $bcRaw = Invoke-Wsl 'docker builder prune -f --filter until=168h'
    $bcLine = @($bcRaw) | Where-Object { $_ -match 'reclaimed' } | Select-Object -First 1
    if ($bcLine) {
        Write-Log "[ OK ] build cache pruned (kept last 7 days): $($bcLine.Trim())"
    } else {
        Write-Log "[ OK ] build cache prune: nothing reclaimed"
    }
}

# --- 3. Unhealthy containers (report / opt-in remediate) ---
# Keep only real "name|status" lines: if docker is missing mid-run, WSL's
# error text must not be reported as a (phantom) unhealthy container.
$unhealthy = @(Invoke-Wsl "docker ps --filter health=unhealthy --format '{{.Names}}|{{.Status}}'") |
    Where-Object { $_ -match '^[A-Za-z0-9][A-Za-z0-9_.\-]+\|' }
if ($unhealthy.Count -gt 0) {
    foreach ($u in $unhealthy) {
        $name = ($u -split '\|')[0]
        if ($Remediate -and -not $ReportOnly) {
            Write-Log "[FIX ] unhealthy: $name - restarting (it is already failing) ..."
            [void](Invoke-Wsl "docker restart $name")
            Start-Sleep -Seconds 5
            $st = Invoke-Wsl "docker inspect $name --format '{{.State.Health.Status}}' 2>/dev/null || echo restarted"
            Write-Log "[FIX ] $name now: $($st.Trim())"
        } else {
            Write-Log "[WARN] unhealthy container: $u - rerun with -Remediate to restart it"
        }
    }
} else {
    Write-Log "[ OK ] no unhealthy containers"
}

# --- 4. DMR (Docker Model Runner) health ---
$dmr = Invoke-Wsl "curl -s -m 5 -o /dev/null -w '%{http_code}' http://localhost:12435/engines/v1/models 2>/dev/null || echo 000"
if ($dmr.Trim() -eq '200') {
    $loaded = Invoke-Wsl "curl -s -m 5 http://localhost:12435/api/ps 2>/dev/null" | ForEach-Object {
        try { (@(($_ | ConvertFrom-Json).models) | Measure-Object).Count } catch { '?' }
    }
    Write-Log "[ OK ] DMR API healthy; loaded model entries: $($loaded)"
} else {
    Write-Log "[WARN] DMR API not reachable (HTTP $dmr) - dmr-watchdog owns recovery; check docker logs dmr-watchdog"
}
$wd = Invoke-Wsl "docker ps --filter name=dmr-watchdog --format '{{.Status}}'"
Write-Log "[ OK ] dmr-watchdog: $($wd.Trim())"

# --- 5. Host memory: drop WSL page caches when tight (safe) ---
$os = Get-CimInstance Win32_OperatingSystem
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
Write-Log "[ OK ] host free memory: $freeGB GB"
if ($freeGB -lt $MinHostFreeGB) {
    if ($ReportOnly) {
        Write-Log "[ DRY ] would drop WSL page caches (host below ${MinHostFreeGB} GB)"
    } else {
        $before2 = [double]$os.FreePhysicalMemory
        [void](Invoke-Wsl 'sync; echo 3 > /proc/sys/vm/drop_caches' -AsRoot)
        Start-Sleep -Seconds 3
        $os2 = Get-CimInstance Win32_OperatingSystem
        $free2 = [math]::Round($os2.FreePhysicalMemory / 1MB, 1)
        Write-Log "[ OK ] dropped WSL page caches: host free $freeGB -> $free2 GB"
    }
} else {
    Write-Log "[ OK ] host memory above threshold - no cache drop needed"
}

# --- 6. Disk + log-driver debt note ---
$dfLine = @(Invoke-Wsl 'df -h /') | Where-Object { $_ -match '^/dev' } | Select-Object -First 1
$dfFields = ($dfLine -replace '\s+', ' ').Trim() -split ' '
if ($dfFields.Count -ge 5) {
    Write-Log "[ OK ] WSL root disk: $($dfFields[2]) used / $($dfFields[1]) ($($dfFields[4]))"
} else {
    Write-Log "[WARN] could not read WSL disk usage"
}
$sysdf = Invoke-Wsl 'docker system df --format "{{.Type}}: {{.Size}} (reclaimable {{.Reclaimable}})"'
foreach ($line in @($sysdf)) { if ($line) { Write-Log "[ OK ] docker $($line.Trim())" } }
Write-Log "[NOTE] all containers use unbounded json-file logs; bound them with per-service"
Write-Log "       logging: options (max-size/max-file) at the next planned recreate - downtime-bearing, so manual."

# --- 7. Stack snapshot (after) + verdict ---
$after = [ordered]@{
    running   = Get-StackCount 'docker ps -q | wc -l'
    unhealthy = Get-StackCount 'docker ps --filter health=unhealthy -q | wc -l'
    exited    = Get-StackCount 'docker ps -a --filter status=exited -q | wc -l'
}
if (($after.running -lt 0) -or ($after.unhealthy -lt 0) -or ($after.exited -lt 0)) {
    Write-Log "[FAIL] could not read post-pass stack counts - investigate (platform state unknown)."
    exit 1
}
Write-Log "[ OK ] stack after: $($after.running) running / $($after.unhealthy) unhealthy / $($after.exited) exited"
if ($after.running -lt $before.running) {
    Write-Log "[FAIL] running count DROPPED ($($before.running) -> $($after.running)) - investigate immediately!"
    exit 2
}
if ($after.unhealthy -gt 0) {
    Write-Log "[WARN] MAINTENANCE DONE - unhealthy containers remain"
    exit 2
}
Write-Log "=== MAINTENANCE DONE - ZERO DOWNTIME ($($after.running) running throughout) ==="
exit 0
