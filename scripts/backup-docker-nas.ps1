<#
.SYNOPSIS
    Nightly size-tiered backup of Docker data + WSL config layer to the OMV NAS.
.DESCRIPTION
    Registered as \DevOptimizer\Nas-Backup (daily 05:30, user-level). Two tiers:
      NIGHTLY (every run):  pg_dumpall of the running Postgres container, tar of
        every named Docker volume under 2 GB, tar of the WSL config layer
        (cu130-slim compose file, cloudless.gr, existing backups dir).
      WEEKLY (Sundays):     remaining large volumes + broad WSL home tar excluding
        regenerable dirs (node_modules, caches, toolchains, vscode-server).
    Transfers via scp to omv:devoptimizer-backups/{nightly,weekly}, writes a
    sha256 manifest per run, prunes remote beyond KeepNightly/KeepWeekly and
    local staging beyond 2 runs. Gates: never wakes WSL, skips when the engine
    or the NAS is unreachable (Docker Desktop autostart owns engine startup).
    Failures write DevOptimizer event-log 1005.
#>
#requires -Version 5.1
# CATEGORY: docker
param(
    [string]$StagingRoot = 'D:\DevOptimizer\backups\nas-staging',
    [string]$NasDir = '/srv/dev-disk-by-uuid-fa6231ab-eae7-40ea-a4b6-400f767a89d7/devoptimizer-backups',
    [int]$KeepNightly = 7,
    [int]$KeepWeekly = 4,
    [int]$KeepMonthly = 3,
    [int]$MaxNightlyVolumeGB = 2,
    [switch]$VerifyOnly,
    [switch]$ForceWeekly,
    [switch]$ForceMonthly
)
$ErrorActionPreference = 'SilentlyContinue'
$logFile = 'D:\DevOptimizer\logs\nas-backup.log'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$dateTag = Get-Date -Format 'yyyyMMdd-HHmm'
$isSunday = (Get-Date).DayOfWeek -eq 'Sunday'
$isFirstOfMonth = (Get-Date).Day -eq 1
$weekly = $isSunday -or $ForceWeekly
$monthly = $isFirstOfMonth -or $ForceMonthly

function Log { param($msg) Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) }
function NoteFail { param($msg)
    Log ("FAIL: " + $msg)
    Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1005 -EntryType Warning `
        -Message "NAS backup: $msg" -ErrorAction SilentlyContinue
}

Log '--- nas-backup run started ---'

# --- [1] Gates ----------------------------------------------------------------
if (-not (Get-Process vmmemWSL -ErrorAction SilentlyContinue)) { Log 'WSL VM not running (skipped - no wake)'; exit 0 }
docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Log 'docker engine not reachable (skipped)'; exit 0 }
ssh -o BatchMode=yes -o ConnectTimeout=10 omv 'echo nas-ok' 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { NoteFail 'NAS ssh unreachable (skipped run)'; exit 0 }
$nasFree = ssh -o BatchMode=yes omv 'df -h / | tail -1' 2>$null
Log ("nas reachable, root: {0}" -f ($nasFree -join '').Trim())

if ($VerifyOnly) {
    Log ("VERIFY-ONLY: weekly={0}; volumes: {1}; postgres container: {2}" -f $weekly,
        ((docker volume ls -q 2>$null | Measure-Object).Count),
        ((docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -match 'postgres|db' } | Select-Object -First 1)))
    exit 0
}

# --- [2] Staging ---------------------------------------------------------------
$nightlyDir = Join-Path $StagingRoot $dateTag
New-Item -Path $nightlyDir -ItemType Directory -Force | Out-Null
$files = @()

# --- [3] Postgres dump (nightly) ------------------------------------------------
# Target social-postgres explicitly (port 5433) as it holds the actual data;
# the generic 'postgres' container (port 5432) is often empty/template.
$gzipExe = 'C:\Program Files\Git\usr\bin\gzip.exe'
$pgContainer = 'social-postgres'
if (docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $pgContainer }) {
    $pgUser = (docker inspect $pgContainer --format '{{range .Config.Env}}{{println .}}{{end}}' 2>$null |
        Where-Object { $_ -match '^POSTGRES_USER=' }) -replace '^POSTGRES_USER=', ''
    if (-not $pgUser) { $pgUser = 'postgres' }
    $dumpFile = Join-Path $nightlyDir ("pgdumpall-{0}.sql.gz" -f $dateTag)
    # cmd /c pipeline: PowerShell `>` redirection re-encodes native stdout as
    # UTF-16 text and corrupts gzip binary output (all dumps 2026-11-12..14
    # were garbage). cmd redirection is byte-transparent.
    $gzipExe = 'C:\Program Files\Git\usr\bin\gzip.exe'
    cmd /c "docker exec $pgContainer pg_dumpall -U $pgUser 2>nul | `"$gzipExe`" > `"$dumpFile`""
    if ((Test-Path $dumpFile) -and ((Get-Item $dumpFile).Length -gt 1KB) -and
        ((Format-Hex -Path $dumpFile -Count 2 | Out-String) -match '1F8B')) {
        $files += $dumpFile; Log ("pg_dumpall OK: {0} ({1:N1} MB)" -f $pgContainer, ((Get-Item $dumpFile).Length/1MB))
    } else { NoteFail ("pg_dumpall produced no data from {0}" -f $pgContainer) }
} else {
    # Fallback: try any postgres container
    $fallback = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -match 'postgres' } | Select-Object -First 1
    if ($fallback) {
        Log ("social-postgres not running, trying fallback: {0}" -f $fallback)
        $pgUser = (docker inspect $fallback --format '{{range .Config.Env}}{{println .}}{{end}}' 2>$null |
            Where-Object { $_ -match '^POSTGRES_USER=' }) -replace '^POSTGRES_USER=', ''
        if (-not $pgUser) { $pgUser = 'postgres' }
        $dumpFile = Join-Path $nightlyDir ("pgdumpall-{0}.sql.gz" -f $dateTag)
        cmd /c "docker exec $fallback pg_dumpall -U $pgUser 2>nul | `"$gzipExe`" > `"$dumpFile`""
        if ((Test-Path $dumpFile) -and ((Get-Item $dumpFile).Length -gt 1KB) -and
            ((Format-Hex -Path $dumpFile -Count 2 | Out-String) -match '1F8B')) {
            $files += $dumpFile; Log ("pg_dumpall OK: {0} ({1:N1} MB)" -f $fallback, ((Get-Item $dumpFile).Length/1MB))
        } else { NoteFail ("pg_dumpall produced no data from {0}" -f $fallback) }
    } else { Log 'no postgres container found (pg dump skipped)' }
}

# Post-section assert: every run must produce a pgdumpall — 2026-11-15 the
# section emitted zero log lines and the dump silently never landed. If the
# set lacks one, the whole Postgres backup is absent and that must be loud.
if (-not ($files | Where-Object { $_ -match 'pgdumpall-.*\.sql\.gz$' })) {
    NoteFail 'pgdumpall missing from backup set — Postgres NOT backed up this run'
}

# --- [4] Docker volumes, size-tiered --------------------------------------------
$gzip = 'C:\Program Files\Git\usr\bin\gzip.exe'
$volSizes = @{}
$dfOut = docker system df -v --format '{{json .Volumes}}' 2>$null
try {
    $vjson = $dfOut | ConvertFrom-Json
    foreach ($v in $vjson) { $volSizes[$v.Name] = $v.Size }
} catch {
    # fallback: parse human table (sizes like "1.5GB")
    $inV = $false
    foreach ($line in (docker system df -v 2>$null)) {
        if ($line -match '^Local Volumes') { $inV = $true; continue }
        if ($inV -and $line -match '^(.+?)\s{2,}') {
            $parts = ($line -replace '`r','') -split '\s+'
            if ($parts.Count -ge 4 -and $parts[0] -ne 'VOLUME NAME') { $volSizes[$parts[0]] = $parts[-2] + $parts[-1] }
            if ($line -match '^Build Cache') { break }
        }
    }
}
function SizeGB { param($s)
    if ($s -match '([\d.]+)\s*([kKmMgGtT]?B?)') {
        $n = [double]$matches[1]
        switch -Regex ($matches[2]) { 'T' { return $n*1024 } 'G' { return $n } 'M' { return $n/1024 } 'k' { return $n/1048576 } default { return $n/1073741824 } }
    }
    return 999
}
$tinyImage = docker images --format '{{.Repository}}:{{.Tag}}' 2>$null | Where-Object { $_ -match '^(alpine|busybox)' } | Select-Object -First 1
if (-not $tinyImage) { docker pull alpine:3 2>$null | Out-Null; $tinyImage = 'alpine:3' }
$tarred = 0
foreach ($vol in (docker volume ls -q 2>$null)) {
    $gb = SizeGB $volSizes[$vol]
    if ($gb -lt $MaxNightlyVolumeGB) { $tier = 'nightly' }
    elseif ($monthly) { $tier = 'monthly' }
    else { $tier = 'weekly' }
    if ($tier -eq 'weekly' -and -not $weekly) { Log ("volume {0} ({1:N2} GB) deferred to weekly tier" -f $vol, $gb); continue }
    if ($tier -eq 'monthly' -and -not $monthly) { Log ("volume {0} ({1:N2} GB) deferred to monthly tier" -f $vol, $gb); continue }
    $out = Join-Path $nightlyDir ("vol-{0}-{1}.tar.gz" -f ($vol -replace '[^a-zA-Z0-9_-]', '_'), $dateTag)
    docker run --rm -v ("{0}:/data:ro" -f $vol) -v ("{0}:/backup" -f $nightlyDir) $tinyImage tar czf ("/backup/{0}" -f (Split-Path $out -Leaf)) -C /data . 2>$null | Out-Null
    if ((Test-Path $out) -and ((Get-Item $out).Length -gt 100)) { $files += $out; $tarred++ }
    elseif (Test-Path $out) { Log ("volume {0}: empty (ok)" -f $vol) }
    else { NoteFail ("volume tar failed: {0}" -f $vol) }
}
Log ("volumes tarred: {0} of {1}" -f $tarred, (docker volume ls -q 2>$null | Measure-Object).Count)

# --- [5] WSL layer (nightly: config; weekly: broad home; monthly: full system) --------------------------
$wslType = if ($monthly) { 'monthly' } elseif ($weekly) { 'home' } else { 'config' }
$wslOut = Join-Path $nightlyDir ("wsl-{0}-{1}.tar.gz" -f $wslType, $dateTag)
if ($monthly) {
    # Monthly: full WSL home + docker data roots (excluding regenerable)
    $cmd = "tar czf - -C / --exclude='home/tbaltzakis/node_modules' --exclude='home/tbaltzakis/.cache' --exclude='home/tbaltzakis/.local' --exclude='home/tbaltzakis/.cargo' --exclude='home/tbaltzakis/.rustup' --exclude='home/tbaltzakis/.npm' --exclude='home/tbaltzakis/.vscode-server' --exclude='home/tbaltzakis/.next' --exclude='home/tbaltzakis/__pycache__' --exclude='home/tbaltzakis/target' --exclude='var/lib/docker/overlay2' --exclude='var/lib/docker/volumes/*/_data/node_modules' --exclude='var/lib/docker/volumes/*/_data/.cache' --exclude='var/lib/docker/volumes/*/_data/target' --exclude='var/lib/docker/volumes/*/_data/__pycache__' --exclude='proc' --exclude='sys' --exclude='dev' --exclude='run' --exclude='mnt' --exclude='media' --exclude='tmp' --exclude='home/tbaltzakis/.wine' home var/lib/docker 2>/dev/null"
} elseif ($weekly) {
    $cmd = "tar czf - -C /home/tbaltzakis --exclude='node_modules' --exclude='.cache' --exclude='.local' --exclude='.cargo' --exclude='.rustup' --exclude='.npm' --exclude='.vscode-server' --exclude='.next' --exclude='__pycache__' --exclude='target' ."
} else {
    $cmd = "tar czf - -C /home/tbaltzakis cu130-slim/docker-compose.yml cu130-slim/.env cloudless.gr 2>/dev/null"
}
# WSL writes the archive itself via /mnt/<drive> — PowerShell `>` re-encodes
# native stdout as UTF-16 and corrupted every wsl-*.tar.gz (verified 2026-11-14).
$wslStaging = $nightlyDir
if ($wslStaging -match '^([A-Za-z]):\\(.*)$') { $wslStaging = '/mnt/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/') }
$wslOutName = Split-Path $wslOut -Leaf
& wsl.exe -d Ubuntu-24.04 -e sh -lc "$cmd > '$wslStaging/$wslOutName'"
if ((Test-Path $wslOut) -and ((Get-Item $wslOut).Length -gt 1KB)) { $files += $wslOut; Log ("wsl layer OK: {0:N1} MB" -f ((Get-Item $wslOut).Length/1MB)) }
else { NoteFail 'wsl layer tar empty' }

# --- [6] Manifest + transfer ------------------------------------------------------
$manifest = Join-Path $nightlyDir ("manifest-{0}.csv" -f $dateTag)
"file,bytes,sha256" | Set-Content $manifest -Encoding ASCII
foreach ($f in $files) {
    $h = (Get-FileHash $f -Algorithm SHA256).Hash
    Add-Content $manifest ("{0},{1},{2}" -f (Split-Path $f -Leaf), (Get-Item $f).Length, $h) -Encoding ASCII
}
$tier = if ($monthly) { 'monthly' } elseif ($weekly) { 'weekly' } else { 'nightly' }
ssh -o BatchMode=yes omv ("mkdir -p {0}/{1}" -f $NasDir, $tier) 2>$null | Out-Null
$okCount = 0
$scpFails = 0
foreach ($f in ($files + $manifest)) {
    $sent = $false
    foreach ($attempt in 1..3) {
        scp -o BatchMode=yes -o ConnectTimeout=15 -q $f ("omv:{0}/{1}/" -f $NasDir, $tier) 2>$null
        if ($LASTEXITCODE -eq 0) { $sent = $true; break }
        # if the NAS link died mid-run, don't burn retries on every file
        ssh -o BatchMode=yes -o ConnectTimeout=8 omv 'echo nas-ok' 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { break }
        Start-Sleep -Seconds (5 * $attempt)
    }
    if ($sent) { $okCount++ } else { $scpFails++; NoteFail ("scp failed: {0}" -f (Split-Path $f -Leaf)) }
}
if ($scpFails -gt 0 -and $okCount -eq 0) { NoteFail 'NAS transfer: all files failed (link down mid-run?)' }
Log ("transferred {0}/{1} file(s) to omv:{2}/{3}" -f $okCount, ($files.Count + 1), $NasDir, $tier)

# --- [7] Retention -----------------------------------------------------------------
# Retention is date-based (mtime), not file-count: a single run ships ~35
# files, so the old `tail -n +N` count math silently kept ~1 run instead of
# KeepNightly nights (observed 2026-11-12: only the newest nightly survived).
ssh -o BatchMode=yes omv ("find {0}/nightly -type f -mtime +{1} -delete" -f $NasDir, $KeepNightly) 2>$null
ssh -o BatchMode=yes omv ("find {0}/weekly -type f -mtime +{1} -delete" -f $NasDir, ($KeepWeekly * 7)) 2>$null
ssh -o BatchMode=yes omv ("find {0}/monthly -type f -mtime +{1} -delete" -f $NasDir, ($KeepMonthly * 30)) 2>$null
# Local staging: on a fully successful transfer delete the current run's
# staging too (the files live on the NAS + manifest); keep partial runs for
# retry, and never retain more than 2 older runs regardless. Two weekly
# stagings can hold 45+ GB (DMR models volume + WSL monthly layer), which
# filled D: to 0 bytes free on 2026-11-01.
if ($okCount -eq ($files.Count + 1)) {
    Remove-Item -LiteralPath $nightlyDir -Recurse -Force -ErrorAction SilentlyContinue
    Log ("staging purged after full transfer: {0}" -f (Split-Path $nightlyDir -Leaf))
}
Get-ChildItem $StagingRoot -Directory | Sort-Object Name -Descending | Select-Object -Skip 2 | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Log ("--- nas-backup run complete: tier={0}, files={1} ---" -f $tier, $okCount)
exit 0
