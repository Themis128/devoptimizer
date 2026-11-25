# Full VHDX Unlock Chain with Admin Elevation
# Based on AGENTS.md: stop com.docker.service, wsl --shutdown, kill vmmemWSL, restart vmcompute/WslService, Optimize-VHD

$ErrorActionPreference = 'Continue'

try { Start-Transcript -Path 'D:\DevOptimizer\logs\full-vhdx-unlock.log' -Append -ErrorAction Stop | Out-Null } catch {}

Write-Host "=== Full VHDX Unlock Chain ===" -ForegroundColor Magenta

# 1. Stop Docker Desktop service (prevents it from relaunching VM mid-compaction)
Write-Host "[1] Stopping com.docker.service..." -ForegroundColor Cyan
Stop-Service com.docker.service -Force -ErrorAction SilentlyContinue
Start-Sleep 3
Write-Host "    Docker service stopped"

# 2. Full WSL shutdown
Write-Host "[2] Running wsl --shutdown (ALL distros stop)..." -ForegroundColor Cyan
wsl --shutdown 2>&1 | Out-Null
Start-Sleep 10
Write-Host "    WSL shutdown complete"

# 3. Kill any remaining vmmemWSL processes
Write-Host "[3] Killing zombie vmmemWSL processes..." -ForegroundColor Cyan
$vmmem = Get-Process vmmemWSL -ErrorAction SilentlyContinue
if ($vmmem) {
    foreach ($p in $vmmem) {
        Write-Host "    Killing vmmemWSL PID $($p.Id)"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "    No vmmemWSL processes found"
}

# 4. Restart vmcompute (Hyper-V VM Compute Service) - clears orphaned VHDMP sections
Write-Host "[4] Restarting vmcompute (Hyper-V VM Compute Service)..." -ForegroundColor Cyan
Restart-Service vmcompute -Force -ErrorAction SilentlyContinue
Write-Host "    vmcompute restarted"

# 5. Restart WslService (WSL Service) - clears remaining locks
Write-Host "[5] Restarting WslService..." -ForegroundColor Cyan
Restart-Service WslService -Force -ErrorAction SilentlyContinue
Write-Host "    WslService restarted"

Start-Sleep 5

# 6. Compact docker_data.vhdx
Write-Host "[6] Compacting docker_data.vhdx..." -ForegroundColor Cyan
$dockerData = "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx"
if (Test-Path $dockerData) {
    $before = (Get-Item $dockerData).Length
    Write-Host "    Before: $([math]::Round($before/1GB,2)) GB"
    try {
        # Set sparse flag first (as per AGENTS.md)
        wsl --manage docker-desktop --set-sparse true 2>&1 | Out-Null
        Optimize-VHD -Path $dockerData -Mode Full -ErrorAction Stop
        $after = (Get-Item $dockerData).Length
        $freed = ($before - $after) / 1GB
        Write-Host ("    After:  {0:N2} GB (freed {1:N2} GB)" -f ($after/1GB), $freed) -ForegroundColor Green
    } catch {
        $msg = $_.Exception.Message -split "`n"
        Write-Host "    Optimize-VHD failed: $($msg[0])" -ForegroundColor Red
    }
} else {
    Write-Host "    docker_data.vhdx not found at $dockerData" -ForegroundColor Yellow
}

# 7. Compact Ubuntu ext4.vhdx
Write-Host "[7] Compacting Ubuntu ext4.vhdx..." -ForegroundColor Cyan
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
    Write-Host "    Ubuntu ext4.vhdx not found at $ubuntuVhdx" -ForegroundColor Yellow
}

# 8. Restart Docker Desktop service
Write-Host "[8] Restarting com.docker.service..." -ForegroundColor Cyan
Start-Service com.docker.service -ErrorAction SilentlyContinue
Write-Host "    Docker service restarted"

Write-Host "`n=== Complete ===" -ForegroundColor Magenta

try { Stop-Transcript | Out-Null } catch {}