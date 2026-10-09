<#
.SYNOPSIS
    Host memory/VRAM guard - tiered self-healing to keep the workstation freeze-free.
.DESCRIPTION
    Registered as \DevOptimizer\Host-Guard (every 5 min, user-level). Fast path is
    host-side only (no wsl.exe calls unless acting). Tiers:
      T2  Available < 2500 MB            -> guest drop_caches (rate-limited 30 min)
      T3  VRAM > 85% AND Available<2500  -> docker model unload of loaded models
      T4  Available < 1200 MB (critical) -> T2+T3, then:
             Devin.exe closed  -> auto-bounce WSL/Docker (2-min self-heal)
             Devin.exe open    -> critical event only, NEVER bounce a session
    Root-cause basis (2026-10-07): freezes were host memory starvation - WDDM
    spills GPU pages into system RAM when VRAM is 96% full (DMR models resident),
    plus vmmemWSL structural commit. Judge the host by Available MBytes, not Free.
    Log: logs\host-guard.log; events 1006 (warning) / 1007 (critical+healed).
#>
#requires -Version 5.1
# CATEGORY: monitoring
param(
    [int]$SoftThresholdMB = 2500,
    [int]$CriticalThresholdMB = 1200,
    [int]$VramPercentThreshold = 85,
    [int]$RateLimitMinutes = 30,
    [int]$BounceRateLimitMinutes = 60,
    [switch]$OnceVerbose
)
$ErrorActionPreference = 'SilentlyContinue'
$logFile = 'D:\DevOptimizer\logs\host-guard.log'
$stateFile = 'D:\DevOptimizer\logs\host-guard-state.json'

function Log { param($m) Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }
function Note { param($id, $msg)
    Log ("event{0}: {1}" -f $id, $msg)
    Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId $id -EntryType $(if ($id -ge 1007) { 'Error' } else { 'Warning' }) -Message "Host guard: $msg" -ErrorAction SilentlyContinue
}

# --- metrics (host-side, fast) --------------------------------------------------
$availMB = 0
try { $availMB = [int](Get-Counter '\Memory\Available MBytes' -ErrorAction Stop).CounterSamples[0].CookedValue } catch {}
$vramUsed = 0; $vramTotal = 0
$nsmi = nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>$null
if ($nsmi -match '(\d+)\s*,\s*(\d+)') { $vramUsed = [int]$Matches[1]; $vramTotal = [int]$Matches[2] }
$vramPct = if ($vramTotal -gt 0) { [int](100 * $vramUsed / $vramTotal) } else { 0 }
$vmmem = (Get-Process vmmemWSL -ErrorAction SilentlyContinue).WorkingSet64/1GB
$os = Get-CimInstance Win32_OperatingSystem
$commitPct = if ($os.TotalVirtualMemorySize -gt 0) { [int](100 * ($os.TotalVirtualMemorySize - $os.FreeVirtualMemory) / $os.TotalVirtualMemorySize) } else { 0 }

Log ("metrics: avail={0}MB vram={1}/{2}MB ({3}%) vmmemWSL={4:N1}GB commit={5}%" -f $availMB, $vramUsed, $vramTotal, $vramPct, $vmmem, $commitPct)

# --- state (rate limits) ----------------------------------------------------------
$state = $null
try { $state = Get-Content $stateFile -Raw -ErrorAction Stop | ConvertFrom-Json } catch {}
$now = Get-Date
function LastAction { param($key)
    if ($state -and $state.$key) { return [datetime]$state.$key }
    return [datetime]::MinValue
}
function SaveState { param($updates)
    if (-not $state) { $state = [pscustomobject]@{} }
    foreach ($k in $updates.Keys) { $state | Add-Member -NotePropertyName $k -NotePropertyValue $updates[$k].ToString('o') -Force }
    $state | ConvertTo-Json -Depth 3 | Set-Content $stateFile -Encoding ASCII
}
$devinOpen = [bool](Get-Process Devin -ErrorAction SilentlyContinue)
$wslUp = [bool](Get-Process vmmemWSL -ErrorAction SilentlyContinue)
$engineUp = $false
docker info 2>$null | Out-Null
$engineUp = ($LASTEXITCODE -eq 0)

# --- T2: soft pressure -> guest drop_caches ---------------------------------------
if ($wslUp -and $availMB -lt $SoftThresholdMB -and ((LastAction 'lastDropCaches') -lt $now.AddMinutes(-$RateLimitMinutes))) {
    wsl.exe -d Ubuntu-26.04 -u root -- sh -c "sync; echo 3 > /proc/sys/vm/drop_caches" 2>$null | Out-Null
    Note 1006 ("Available {0} MB < {1} - guest drop_caches applied" -f $availMB, $SoftThresholdMB)
    SaveState @{ lastDropCaches = $now }
    Start-Sleep -Seconds 10
    $availMB = [int](Get-Counter '\Memory\Available MBytes' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
    Log ("post-dropcache available: {0} MB" -f $availMB)
}

# --- T3: VRAM squeeze + host pressure -> unload models -----------------------------
# GOTCHA: docker model ps/unload CLI re-attempts a broken standalone-runner install
# and exits 127 on this machine - NEVER use docker model * commands here. The models
# are served by the INTEGRATED docker-model-runner container; restarting it evicts
# all models from VRAM (proven 2026-10-07: 7844 -> 686 MiB).
if ($engineUp -and $vramPct -gt $VramPercentThreshold -and $availMB -lt $SoftThresholdMB -and ((LastAction 'lastUnload') -lt $now.AddMinutes(-$RateLimitMinutes))) {
    docker restart docker-model-runner 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Note 1006 ("VRAM {0}% + Available {1} MB - docker-model-runner restarted (models evicted)" -f $vramPct, $availMB)
        SaveState @{ lastUnload = $now }
        Start-Sleep -Seconds 10
        $vramUsed = 0
        $nsmi = nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>$null
        if ("$nsmi" -match '(\d+)') { $vramUsed = [int]$Matches[1] }
        Log ("VRAM after runner restart: {0} MiB" -f $vramUsed)
    } else { Log 'T3 skipped: docker-model-runner restart failed' }
}

# --- T4: critical -> everything + auto-bounce when Devin closed ---------------------
if ($availMB -lt $CriticalThresholdMB) {
    if ($devinOpen) {
        Note 1007 ("CRITICAL Available {0} MB with Devin OPEN - alerting only, no bounce. Close Devin or free memory manually." -f $availMB)
        exit 0
    }
    if ((LastAction 'lastBounce') -ge $now.AddMinutes(-$BounceRateLimitMinutes)) { Log 'T4: bounce rate-limited (recent bounce)'; exit 0 }
    SaveState @{ lastBounce = $now }
    Log 'T4: critical memory with Devin closed - AUTO-BOUNCE starting'
    & 'C:\Program Files\Docker\Docker\DockerCli.exe' -Shutdown 2>$null
    Get-Process 'Docker Desktop','com.docker.backend' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    wsl.exe --shutdown 2>$null | Out-Null
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) { if (-not (Get-Process vmmemWSL -ErrorAction SilentlyContinue)) { break }; Start-Sleep -Seconds 2 }
    Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    $deadline = (Get-Date).AddSeconds(180)
    while ((Get-Date) -lt $deadline) { docker info 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { break }; Start-Sleep -Seconds 5 }
    Log 'engine restarted - bridge grace 120s'
    Start-Sleep -Seconds 120
    foreach ($c in (docker ps -a --filter 'status=exited' --format '{{.Names}}' 2>$null)) {
        $pol = (docker inspect $c --format '{{.HostConfig.RestartPolicy.Name}}' 2>$null) -replace "`r", ''
        if ($pol -match 'always|unless-stopped') { docker start $c 2>$null | Out-Null; Log ("  recovered: {0}" -f $c) }
    }
    Start-Sleep -Seconds 15
    $probe = curl.exe -s -o NUL -w '%{http_code}' -m 10 'http://localhost:9390/metrics' 2>$null
    $after = [int](Get-Counter '\Memory\Available MBytes' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
    Note 1007 ("CRITICAL {0} MB -> auto-bounce done. Available now {1} MB, 9390={2}" -f $availMB, $after, $probe)
    exit 0
}

if ($OnceVerbose) { Write-Output ("metrics: avail={0}MB vram={1}% commit={2}%" -f $availMB, $vramPct, $commitPct) }
exit 0
