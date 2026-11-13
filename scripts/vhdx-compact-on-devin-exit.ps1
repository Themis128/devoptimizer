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
if ((Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $today)) { exit 0 }

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

# Both clear - fire the elevated compaction task and stamp today
Set-Content -Path $stamp -Value $today
Log 'Devin closed - launching Nightly-Vhdx-Compact'
& schtasks.exe /run /tn 'Nightly-Vhdx-Compact' 2>&1 | ForEach-Object { Log "schtasks: $_" }
