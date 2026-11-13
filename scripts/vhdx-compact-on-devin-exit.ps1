# vhdx-compact-on-devin-exit.ps1 - fires the elevated Nightly-Vhdx-Compact
# task once per day, but only when Devin is fully closed (no Devin.exe and
# no devin-server inside Ubuntu-24.04). Runs every 5 min via scheduled task
# \Vhdx-Compact-DevinExit (limited rights - it only launches the elevated
# task, never compacts itself).
# CATEGORY: maintenance
$ErrorActionPreference = 'Continue'
$log   = 'D:\DevOptimizer\logs\vhdx-compact-on-exit.log'
$stamp = 'D:\DevOptimizer\logs\.vhdx-compact-fired'

function Log([string]$m) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') $m" }

# Once per calendar day max
$today = Get-Date -Format 'yyyy-MM-dd'
$compactedToday = (Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $today)

# Gate 1: Devin Desktop app
if (Get-Process -Name 'Devin' -ErrorAction SilentlyContinue) { exit 0 }

# Gate 2: devin-server still alive in Ubuntu-24.04 (wsl calls flake - retry)
$alive = $false
foreach ($i in 1..3) {
    $out = & wsl.exe -d Ubuntu-24.04 -e bash -lc "pgrep -f 'devin acp|server-mai[n]' | head -3" 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) { $alive = $true; break }
    Start-Sleep -Seconds 5
}
if ($alive) { exit 0 }

if ($compactedToday) {
    # Compaction already ran - but a wsl --shutdown is also the only
    # documented cure for the vsock-wedge class (WSL#41901/14005: hvs
    # ring-buffer alloc fails under memory fragmentation, vsock relay never
    # recovers, every wsl.exe call WSAETIMEDOUTs). If the repair log shows
    # wedge evidence in the last 2h, recycle WSL now that Devin is out.
    $repairLog = 'D:\DevOptimizer\logs\wsl-repair.log'
    $wedgeFlag = 'D:\DevOptimizer\logs\.vsock-wedge-healed'
    $wedged = $false
    if (Test-Path $repairLog) {
        $recent = Get-Content $repairLog -Tail 80 -ErrorAction SilentlyContinue
        $wedged = [bool]($recent | Select-String 'unreachable|WSAETIMEDOUT|Wsl/Service|BROKEN' | Select-Object -First 1)
    }
    $healedToday = (Test-Path $wedgeFlag) -and ((Get-Content $wedgeFlag -Raw).Trim() -eq $today)
    if ($wedged -and -not $healedToday) {
        Log 'vsock wedge evidence in wsl-repair.log - recycling WSL to heal it'
        & wsl.exe --shutdown 2>&1 | Out-Null
        & wsl.exe -d Ubuntu-24.04 -e true 2>&1 | Out-Null   # warm the distro back up
        $ddExe = "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
        if (Test-Path $ddExe) { Start-Process $ddExe }
        Set-Content -Path $wedgeFlag -Value $today
        Log 'wsl recycled + Docker Desktop relaunched'
    }
    exit 0
}

# Both clear - fire the elevated compaction task and stamp today.
# Stamp only after schtasks succeeds - a failed fire must retry next pass.
Log 'Devin closed - launching Nightly-Vhdx-Compact'
$out = & schtasks.exe /run /tn '\DevOptimizer\Nightly-Vhdx-Compact' 2>&1
$out | ForEach-Object { Log "schtasks: $_" }
if ($LASTEXITCODE -eq 0) { Set-Content -Path $stamp -Value $today } else { Log "schtasks failed rc=$LASTEXITCODE - will retry" }
