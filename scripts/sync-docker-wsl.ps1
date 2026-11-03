<#
.SYNOPSIS
    Docker Desktop <-> WSL Ubuntu sync & heal (scheduled): recovers containers, WSL
    integration, and published-port proxies after either side restarts.
.DESCRIPTION
    Brings the combined Docker Desktop + Ubuntu-24.04 system back to a consistent state:
      [1] Guards: skip without waking when the WSL VM is down; skip when the engine is
          unreachable (Docker Desktop autostart owns bringing it up).
      [2] WSL integration check: docker CLI inside the distro must reach the engine.
      [3] Exited-container recovery: starts Exited containers whose restart policy is
          always/unless-stopped, retrying through the docker-desktop bind-mount-bridge
          window (they exit 127 with "error mounting .../docker-desktop-bind-mounts/..."
          when started too soon after a WSL VM boot). Deliberately-stopped containers
          (restart=no) are never resurrected.
      [4] Port-proxy healing: probes published ports from WINDOWS (the proxy layer that
          dies on WSL VM restarts - container healthy but HTTP resets). On failure:
          re-probe once (registration lag), then restart the publishing container and
          re-probe. This is the documented remedy for the 9390 social-metrics proxy.
      [5] Health snapshot logged after every run.
    Cheap when healthy (~3 docker calls + N curl probes). Registered as
    \DevOptimizer\Docker-WSL-Sync (every 30 min + at logon). Log:
    logs\docker-wsl-sync.log; repairs also write DevOptimizer event 1004.
#>
#requires -Version 5.1
# CATEGORY: docker
param(
    [string]$ProbePorts = '9390|/metrics',   # comma-separated port|path pairs
    [int]$BridgeWaitSeconds = 150,           # max time spent retrying exit-127 starts
    [int]$ProbeTimeoutSec = 8,
    [string]$Distro = 'Ubuntu-24.04'
)

$ErrorActionPreference = 'SilentlyContinue'
$logFile = 'D:\DevOptimizer\logs\docker-wsl-sync.log'
$actions = 0

function Log { param($msg)
    Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
}
function Note-Event { param($msg)
    Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1004 `
        -EntryType Warning -Message "Docker-WSL sync: $msg" -ErrorAction SilentlyContinue
}

# --- [1] Guards ---------------------------------------------------------------
Log '--- sync run started ---'
if (-not (Get-Process vmmemWSL -ErrorAction SilentlyContinue)) {
    Log 'WSL VM not running (skipped - no wake)'
    exit 0
}
docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    $backend = Get-Process com.docker.backend -ErrorAction SilentlyContinue
    if (-not $backend) {
        # Docker Desktop is not running at all (e.g. killed by a WSL update).
        # Relaunch it; containers with restart policies come back on their own.
        Log 'docker engine unreachable AND com.docker.backend absent - relaunching Docker Desktop'
        Note-Event 'Docker Desktop was not running; relaunched by Docker-WSL-Sync'
        Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
        exit 0
    }
    # Backend alive but engine unreachable: count consecutive strikes and do a
    # full stop+start on the 3rd consecutive failure (Wedged daemon recovery).
    $stateFile = 'D:\DevOptimizer\logs\docker-down-strikes.txt'
    $strikes = 0
    if (Test-Path $stateFile) { $strikes = [int](Get-Content $stateFile -ErrorAction SilentlyContinue | Select-Object -First 1) }
    $strikes++
    Set-Content -Path $stateFile -Value $strikes -ErrorAction SilentlyContinue
    if ($strikes -ge 3) {
        Log "docker engine unreachable $strikes runs in a row with backend alive - restarting Docker Desktop"
        Note-Event "Docker Desktop backend wedged ($strikes strikes); force-restarted by Docker-WSL-Sync"
        Stop-Process -Name 'com.docker.backend','Docker Desktop' -Force -ErrorAction SilentlyContinue
        Start-Sleep 5
        Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
        Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
        exit 0
    }
    Log "docker engine not reachable (Docker Desktop still starting - strike $strikes/3, skipped)"
    exit 0
}
Remove-Item 'D:\DevOptimizer\logs\docker-down-strikes.txt' -Force -ErrorAction SilentlyContinue

# --- [2] WSL integration check ------------------------------------------------
$serverVer = (wsl.exe -d $Distro -e docker version --format '{{.Server.Version}}') -replace "`r", ""
if ($serverVer) {
    Log "integration OK: $Distro docker CLI reaches engine $serverVer"
} else {
    Log "WARN: docker CLI inside $Distro cannot reach engine - WSL integration broken (remedy: restart Docker Desktop)"
    Note-Event "WSL integration broken for $Distro (docker CLI cannot reach engine)"
}

# --- [3] Exited-container recovery (restart policies only) --------------------
# stack-ops idle-sleep integration: containers fronted by the stack-ops wake
# proxy are Exited *by design* when idle and wake on first request — never
# resurrect them here. Fail-open: if stack-ops is unreachable its sleeper is
# down too, so no managed container is legitimately asleep and the normal
# resurrection path applies.
$stackOpsManaged = @{}
try {
    $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:8787/status' -TimeoutSec 5
    foreach ($p in $resp.PSObject.Properties) {
        $stackOpsManaged[$p.Name] = $true
        if ($p.Value.container) { $stackOpsManaged[$p.Value.container] = $true }
    }
    if ($stackOpsManaged.Count -gt 0) {
        Log ("stack-ops managing {0} container name(s) - excluded from exited recovery" -f $stackOpsManaged.Count)
    }
} catch { }
$exited = (docker ps -a --filter status=exited --format '{{.Names}}') -replace "`r", "" | Where-Object { $_ }
$candidates = @()
foreach ($name in $exited) {
    if ($stackOpsManaged.ContainsKey($name)) { continue }
    $policy = (docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' $name) -replace "`r", ""
    if ($policy -eq 'always' -or $policy -eq 'unless-stopped') { $candidates += $name }
}

if ($candidates.Count -eq 0) {
    Log 'containers in sync (0 exited with restart policy)'
} else {
    Log ("recovery: starting {0} exited container(s): {1}" -f $candidates.Count, ($candidates -join ', '))
    Note-Event "starting exited containers: $($candidates -join ', ')"
    $deadline = (Get-Date).AddSeconds($BridgeWaitSeconds)
    $pending = $candidates
    while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline) {
        $stillPending = @()
        foreach ($name in $pending) {
            docker start $name 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $actions++
                Log "  started: $name"
            } else {
                $err = (docker inspect -f '{{.State.Error}}' $name) -replace "`r", ""
                if ($err -match 'bind-mounts') {
                    Log "  bridge not ready for $name (exit-127 window) - will retry"
                    $stillPending += $name
                } else {
                    Log "  FAILED to start $name : $err"
                    Note-Event "container $name failed to start: $err"
                }
            }
        }
        if ($stillPending.Count -gt 0) { Start-Sleep -Seconds 15 }
        $pending = $stillPending
    }
    if ($pending.Count -gt 0) { Log ("  gave up on (bridge wait expired): {0}" -f ($pending -join ', ')) }
}

# --- [4] Port-proxy healing ---------------------------------------------------
foreach ($pair in ($ProbePorts -split ',')) {
    $parts = $pair.Trim() -split '\|', 2
    if ($parts.Count -lt 2) { continue }
    $port = $parts[0].Trim()
    $path = $parts[1].Trim()
    if (-not $path.StartsWith('/')) { $path = "/$path" }

    $code = curl.exe -s -o NUL -w '%{http_code}' -m $ProbeTimeoutSec ("http://localhost:{0}{1}" -f $port, $path)
    if ("$code" -match '^2|^3') { Log "port-proxy OK: $port$path -> $code"; continue }

    Start-Sleep -Seconds 20   # registration lag right after a VM/desktop restart
    $code = curl.exe -s -o NUL -w '%{http_code}' -m $ProbeTimeoutSec ("http://localhost:{0}{1}" -f $port, $path)
    if ("$code" -match '^2|^3') { Log "port-proxy OK after grace: $port$path -> $code"; continue }

    $publisher = $null
    foreach ($line in ((docker ps --format '{{.Names}}|{{.Ports}}') -replace "`r", "")) {
        if ($line -match ":$port->") { $publisher = ($line -split '\|')[0]; break }
    }
    if (-not $publisher) {
        Log "port-proxy DEAD: $port$path -> $code, no running container publishes $port"
        Note-Event "port $port dead (code $code) and no running publisher found"
        continue
    }
    Log "port-proxy DEAD for $port (code $code) - restarting publisher $publisher"
    docker restart $publisher 2>$null | Out-Null
    $actions++
    Start-Sleep -Seconds 30
    $code = curl.exe -s -o NUL -w '%{http_code}' -m ($ProbeTimeoutSec * 2) ("http://localhost:{0}{1}" -f $port, $path)
    if ("$code" -match '^2|^3') {
        Log "  recovered: $port$path -> $code after restarting $publisher"
        continue
    }
    # docker restart cannot heal a stale Docker Desktop bind/port registration.
    # Proven remedy (2026-11-02): force-recreate the compose service via the
    # in-distro CLI so DD builds a fresh bridge entry. Labels carry project,
    # service, and working dir, so no paths are hardcoded here.
    $labelsJson = docker inspect --format '{{json .Config.Labels}}' $publisher 2>$null
    $labels = $null
    try { $labels = $labelsJson | ConvertFrom-Json } catch { }
    $proj = $labels.'com.docker.compose.project'
    $svc = $labels.'com.docker.compose.service'
    $wdir = $labels.'com.docker.compose.project.working_dir'
    if ($proj -and $svc -and $wdir) {
        Log "  restart insufficient - force-recreating compose service $proj/$svc (workdir $wdir)"
        wsl -d Ubuntu-24.04 -- docker compose --project-directory $wdir -p $proj up -d --no-deps --force-recreate $svc 2>$null | Out-Null
        $actions++
        Start-Sleep -Seconds 45
        $code = curl.exe -s -o NUL -w '%{http_code}' -m ($ProbeTimeoutSec * 2) ("http://localhost:{0}{1}" -f $port, $path)
        if ("$code" -match '^2|^3') {
            Log "  recovered: $port$path -> $code after force-recreate"
        } else {
            Log "  STILL BROKEN: $port$path -> $code after restart + force-recreate of $publisher - needs manual check"
            Note-Event "port $port still broken after restart and force-recreate of $publisher"
        }
    } else {
        Log "  STILL BROKEN: $port$path -> $code after restarting $publisher (no compose labels - cannot force-recreate) - needs manual check"
        Note-Event "port $port still broken after restarting $publisher (no compose labels)"
    }
}

# --- [5] Snapshot -------------------------------------------------------------
$up = ((docker ps -q) -replace "`r", "" | Where-Object { $_ }).Count
Log ("sync complete: {0} container(s) up, {1} repair action(s) taken" -f $up, $actions)
exit 0
