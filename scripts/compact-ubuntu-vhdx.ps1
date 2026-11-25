# Compact Ubuntu ext4.vhdx with Admin Elevation
# Kill vmwp/wslservice first, then compact

$ErrorActionPreference = 'Continue'

try { Start-Transcript -Path 'D:\DevOptimizer\logs\compact-ubuntu-vhdx.log' -Append -ErrorAction Stop | Out-Null } catch {}

Write-Host "=== Compact Ubuntu ext4.vhdx ===" -ForegroundColor Magenta

# Kill vmwp processes that might be holding Ubuntu VHDX
Write-Host "[1] Killing vmwp processes..." -ForegroundColor Cyan
$vmwp = Get-Process vmwp -ErrorAction SilentlyContinue
if ($vmwp) {
    foreach ($p in $vmwp) {
        Write-Host "    Killing vmwp PID $($p.Id)"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "    No vmwp processes found"
}

# Also kill any wslservice that might be holding it
Write-Host "[2] Killing wslservice processes..." -ForegroundColor Cyan
$wslsvc = Get-Process wslservice -ErrorAction SilentlyContinue
if ($wslsvc) {
    foreach ($p in $wslsvc) {
        Write-Host "    Killing wslservice PID $($p.Id)"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "    No wslservice processes found"
}

Start-Sleep 3

# Now try compacting Ubuntu ext4.vhdx
Write-Host "[3] Compacting Ubuntu ext4.vhdx..." -ForegroundColor Cyan
$ubuntuVhdx = 'C:\WSL\Ubuntu-24.04\ext4.vhdx'
if (Test-Path $ubuntuVhdx) {
    $before = (Get-Item $ubuntuVhdx).Length
    Write-Host "    Before: $([math]::Round($before/1GB,2)) GB"
    try {
        wsl --manage Ubuntu-24.04 --set-sparse true 2>&1 | Out-Null
        Optimize-VHD -Path $ubuntuVhdx -Mode Full -ErrorAction Stop
        $after = (Get-Item $ubuntuVhdx).Length
        $freed = ($before - $after) / 1GB
        Write-Host ("    After:  {0:N2} GB (freed {1:N2} GB)" -f ($after/1GB), $freed) -ForegroundColor Green
    } catch {
        $msg = $_.Exception.Message -split "`n"
        Write-Host "    Optimize-VHD failed: $($msg[0])" -ForegroundColor Red
    }
} else {
    Write-Host "    Ubuntu ext4.vhdx not found" -ForegroundColor Yellow
}

Write-Host "`n=== Complete ===" -ForegroundColor Magenta

try { Stop-Transcript | Out-Null } catch {}