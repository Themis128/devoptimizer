# Copy DevOptimizer Menu to Public Desktop
# Run this script as Administrator

$source = 'D:\DevOptimizer\DevOptimizer-Menu.bat'
$publicDesktop = 'C:\Users\Public\Desktop'
$dest = Join-Path $publicDesktop 'DevOptimizer-Menu.bat'

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To copy to Public Desktop, please:" -ForegroundColor Yellow
    Write-Host "1. Right-click this file and select 'Run as administrator'" -ForegroundColor Yellow
    Write-Host "2. Or run: copy-to-public-desktop-admin.bat as Administrator" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternatively, the menu is available at:" -ForegroundColor Cyan
    Write-Host $source -ForegroundColor Cyan
    exit 1
}

# Check if source exists
if (-not (Test-Path $source)) {
    Write-Host "ERROR: Source file not found: $source" -ForegroundColor Red
    exit 1
}

# Try to copy
try {
    Copy-Item -Path $source -Destination $dest -Force -ErrorAction Stop
    Write-Host "SUCCESS! Menu file copied to Public Desktop" -ForegroundColor Green
    Write-Host "Location: $dest" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "You can now run DevOptimizer-Menu.bat from the Public Desktop!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to copy file" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
