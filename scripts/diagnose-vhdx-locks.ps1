# diagnose-vhdx-locks.ps1 - read-only WSL/Docker VHDX lock diagnostic.
# Reports per-vhdx: allocated size, NTFS sparse flag, exclusive-lock status,
# handle.exe holder enumeration (needs elevation for cross-process results),
# and the last compaction run's outcome.
# Usage: pwsh -File scripts\diagnose-vhdx-locks.ps1
# 2026-11-20 - see skill: devoptimizer-vhdx-compaction
$ErrorActionPreference = 'Continue'
$targets = @(
    "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx",
    'C:\WSL\Ubuntu-24.04\ext4.vhdx',
    "$env:LOCALAPPDATA\Docker\wsl\main\ext4.vhdx"
)
$handle = 'D:\DevOptimizer\tools\handle.exe'
$log    = 'D:\DevOptimizer\logs\nightly-vhdx-compact.log'

Write-Host "=== VHDX lock diagnostic $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host ("Elevated: {0} (handle.exe holder names need elevation)" -f $elevated)

foreach ($v in $targets) {
    if (-not (Test-Path $v)) { Write-Host "MISSING: $v"; continue }
    $name = Split-Path $v -Leaf
    $gb   = [math]::Round((Get-Item $v).Length / 1GB, 2)
    $sparse = (& fsutil sparse queryflag $v 2>&1) -match 'set as sparse'
    $locked = $true
    try { $fs = [IO.File]::Open($v, 'Open', 'Read', 'None'); $fs.Close(); $locked = $false } catch {}
    Write-Host ("--- {0}: {1} GB | sparse={2} | locked={3}" -f $name, $gb, $sparse, $locked)
    if ($locked) {
        if (-not $elevated) {
            Write-Host "    holder names need elevation - re-run elevated, or see the 05:00 compactor log (handle.exe diagnosis is armed there)"
        } elseif (Test-Path $handle) {
            & $handle -accepteula -a -nobanner $v 2>&1 |
                Select-String -SimpleMatch -Pattern $v | Select-Object -First 6 |
                ForEach-Object { Write-Host "    holder: $_" }
        } else {
            Write-Host "    handle.exe not found at $handle - install from Sysinternals"
        }
    }
}

Write-Host "--- last compaction run (tail) ---"
if (Test-Path $log) { Get-Content $log -Tail 12 | ForEach-Object { Write-Host "  $_" } }
Write-Host "--- C: free ---"
Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | ForEach-Object {
    Write-Host ("  C: {0:N1} GB free of {1:N1} GB" -f ($_.FreeSpace/1GB), ($_.Size/1GB))
}
