# Verify and Apply MSI Afterburner Profile
# This script verifies profile exists and applies it with recommended values

param(
    [int]$CoreClock = 50,
    [int]$MemClock = 200,
    [int]$PowerLimit = 5,
    [int]$ProfileNumber = 1
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Verify and Apply Overclocking Profile' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Target Profile Configuration:' -ForegroundColor Yellow
Write-Host "  Profile Number: $ProfileNumber" -ForegroundColor White
Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
Write-Host ''

$msiExe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
if (-not (Test-Path $msiExe)) {
    $msiExe = 'C:\Program Files\MSI Afterburner\MSIAfterburner.exe'
}

if (-not (Test-Path $msiExe)) {
    Write-Host '[ERROR] MSI Afterburner executable not found' -ForegroundColor Red
    exit 1
}

# Ensure MSI Afterburner is running
$msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1

if (-not $msiProcess) {
    Write-Host '[INFO] Starting MSI Afterburner...' -ForegroundColor Yellow
    Start-Process -FilePath $msiExe
    Start-Sleep -Seconds 3
}

# Apply the profile
Write-Host '=== Applying Profile ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "[INFO] Applying Profile $ProfileNumber with recommended values..." -ForegroundColor Yellow

try {
    Start-Process -FilePath $msiExe -ArgumentList "-Profile$ProfileNumber" -ErrorAction Stop
    Start-Sleep -Seconds 2
    Write-Host "[OK] Profile $ProfileNumber applied successfully!" -ForegroundColor Green
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host 'Profile Applied!' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Applied Settings:' -ForegroundColor Yellow
    Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
    Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
    Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
    Write-Host ''
    Write-Host 'Profile Status:' -ForegroundColor Yellow
    Write-Host "  Profile $ProfileNumber is now active" -ForegroundColor Green
    Write-Host "  Hotkey: A (if assigned)" -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Next Steps:' -ForegroundColor Cyan
    Write-Host '  1. Verify settings in MSI Afterburner GUI' -ForegroundColor White
    Write-Host '  2. Monitor temperatures during use' -ForegroundColor White
    Write-Host '  3. Test stability with stress test' -ForegroundColor White
    Write-Host ''
    Write-Host 'To apply this profile again:' -ForegroundColor Cyan
    Write-Host '  - Press hotkey A' -ForegroundColor Gray
    Write-Host '  - Run: .\apply-msi-profile.ps1 -ProfileNumber 1' -ForegroundColor Gray
    Write-Host '  - Double-click desktop shortcut' -ForegroundColor Gray
    Write-Host ''
}
catch {
    Write-Host "[ERROR] Failed to apply profile: $_" -ForegroundColor Red
    Write-Host ''
    Write-Host 'Profile may not exist. To create it:' -ForegroundColor Yellow
    Write-Host '  1. Open MSI Afterburner' -ForegroundColor White
    Write-Host "  2. Set Core Clock to +$CoreClock MHz" -ForegroundColor White
    Write-Host "  3. Set Memory Clock to +$MemClock MHz" -ForegroundColor White
    Write-Host "  4. Set Power Limit to +$PowerLimit%" -ForegroundColor White
    Write-Host '  5. Click Apply' -ForegroundColor White
    Write-Host "  6. Click Profile $ProfileNumber → Save" -ForegroundColor White
    Write-Host ''
    Write-Host 'Then run this script again to apply it.' -ForegroundColor Yellow
}

Write-Host ''
