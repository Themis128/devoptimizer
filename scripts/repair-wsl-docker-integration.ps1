<#
.SYNOPSIS
    WSL2/Docker-Desktop integration watchdog - detects and repairs the failure
    modes that trigger Docker Desktop's "WSL integration unexpectedly stopped"
    popup, so the popup never needs answering.
.DESCRIPTION
    Runs every 30 min via the DevOptimizer-WSL-Repair scheduled task. Checks,
    in order, and only acts when something is actually broken (idempotent):

      1. Ubuntu-24.04 distro is reachable (wsl -d starts it on demand)
      2. ~/.docker/run is creatable as the login user and no top-level ~ entry
         is root-owned
         (root-owned home was the 2026-11-10 incident: Docker's
         'mkdir -p ~/.docker/run' failed -> integration stopped -> popup)
         -> repairs with 'wsl -u root chown -R <user>:<user> ~'
      3. /var/run/docker.sock exists in Ubuntu-24.04 and the docker CLI can
         reach the engine -> if missing while Docker Desktop is running,
         restarts Docker Desktop (quit + relaunch) and re-verifies

    All commands run as direct argv (no bash -c) to avoid PS->wsl quoting
    issues. All actions logged to logs\wsl-repair.log. -DryRun reports only.
    Never touches docker-desktop distro data or containers beyond the
    Docker Desktop restart (containers have their own restart policies).
#>
#requires -Version 5.1
# CATEGORY: maintenance

[CmdletBinding()]
param(
    [string]$Distro = 'Ubuntu-24.04',
    [string]$Root   = 'D:\DevOptimizer',
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$logFile = Join-Path $Root 'logs\wsl-repair.log'

function Log([string]$msg) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    try {
        # rotate at ~1 MB: keep the tail so the 1-min schedule can't grow it forever
        if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 1MB) {
            $tail = Get-Content $logFile -Tail 2000 -ErrorAction SilentlyContinue
            Set-Content -Path $logFile -Value $tail -Encoding UTF8
        }
        Add-Content -Path $logFile -Value $line -ErrorAction Stop
    } catch { }
    Write-Host $line
}

function WslArgs {
    # Direct argv into the distro - no shell, no quoting pitfalls.
    # Usage: WslArgs @('mkdir','-p','/home/x/.docker/run')  [as root: -Root]
    param([string[]]$A, [switch]$Root)
    $exeArgs = @('-d', $Distro)
    if ($Root) { $exeArgs += @('-u', 'root') }
    $exeArgs += '--'
    $exeArgs += $A
    $out = & wsl.exe @exeArgs 2>&1 | Out-String
    return @{ Code = $LASTEXITCODE; Out = $out.Trim() }
}

Log "=== WSL repair check (dryRun=$DryRun) ==="

# --- 1. Distro reachable? ---
$probe = WslArgs @('echo', '__WSL_OK__')
if ($probe.Out -notmatch '__WSL_OK__') {
    Log "[$Distro] not installed/unreachable - skipping"
    return
}

# --- 2. Home ownership + ~/.docker/run ---
$userR = WslArgs @('whoami')
$user  = $userR.Out.Trim()
$hd      = "/home/$user"

$mkdirTest = WslArgs @('mkdir', '-p', "$hd/.docker/run")
$foreign   = WslArgs @('find', $hd, '-maxdepth', '1', '!', '-user', $user)
$foreignN  = @($foreign.Out -split "`n" | Where-Object { $_.Trim() }).Count

if ($mkdirTest.Code -ne 0 -or $foreignN -gt 0) {
    Log ("[home] BROKEN user={0} mkdirExit={1} foreignTopLevel={2}" -f $user, $mkdirTest.Code, $foreignN)
    if (-not $DryRun) {
        Log "[home] repairing: chown -R $user`:$user $hd"
        $fix = WslArgs @('chown', '-R', "$user`:$user", $hd) -Root
        $fix2 = WslArgs @('mkdir', '-p', "$hd/.docker/run")
        $fix2b = WslArgs @('chown', "$user`:$user", "$hd/.docker", "$hd/.docker/run") -Root
        Log ("[home] repair chownExit={0} mkdirExit={1} chownDockerExit={2}" -f $fix.Code, $fix2.Code, $fix2b.Code)
    }
} else {
    Log "[home] OK ($user)"
}

# --- 3. docker.sock + engine reachability ---
$sock = WslArgs @('test', '-S', '/var/run/docker.sock')
$engineOk = $false
$engVer = ''
if ($sock.Code -eq 0) {
    $eng = WslArgs @('timeout', '8', 'docker', 'info', '--format', '{{.ServerVersion}}')
    $engineOk = ($eng.Code -eq 0 -and $eng.Out -match '^\d+\.\d+')
    $engVer = $eng.Out
}
$ddRunning = [bool](Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue)

if ($sock.Code -ne 0 -or -not $engineOk) {
    Log ("[docker] BROKEN sock={0} engine={1}({2}) dockerDesktopRunning={3}" -f ($sock.Code -eq 0), $engineOk, $engVer, $ddRunning)
    if (-not $DryRun) {
        if ($ddRunning) {
            Log '[docker] restarting Docker Desktop'
            Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue | Stop-Process -Force
            Start-Sleep -Seconds 5
            Start-Process "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
            $deadline = (Get-Date).AddMinutes(3)
            do {
                Start-Sleep -Seconds 10
                $eng = WslArgs @('timeout', '8', 'docker', 'info', '--format', '{{.ServerVersion}}')
            } while (-not ($eng.Code -eq 0 -and $eng.Out -match '^\d+\.\d+') -and (Get-Date) -lt $deadline)
            Log ("[docker] post-restart engineOk={0} ver={1}" -f ($eng.Code -eq 0 -and $eng.Out -match '^\d+\.\d+'), $eng.Out)
        } else {
            Log '[docker] Docker Desktop not running - leaving stopped (socket absence is expected)'
        }
    }
} else {
    Log "[docker] OK (engine $engVer reachable)"
}

Log '=== WSL repair check done ==='
