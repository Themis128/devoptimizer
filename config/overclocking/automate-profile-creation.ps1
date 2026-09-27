# Automated Profile Creation using UI Automation
# This script attempts to automate MSI Afterburner profile creation

param(
    [int]$CoreClock = 50,
    [int]$MemClock = 200,
    [int]$PowerLimit = 5,
    [int]$ProfileNumber = 1
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Automated Profile Creation' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'This script will:' -ForegroundColor Yellow
Write-Host "  1. Launch MSI Afterburner" -ForegroundColor White
Write-Host "  2. Guide you through profile creation" -ForegroundColor White
Write-Host "  3. Apply the profile automatically" -ForegroundColor White
Write-Host ''

$msiExe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
if (-not (Test-Path $msiExe)) {
    $msiExe = 'C:\Program Files\MSI Afterburner\MSIAfterburner.exe'
}

if (-not (Test-Path $msiExe)) {
    Write-Host '[ERROR] MSI Afterburner executable not found' -ForegroundColor Red
    exit 1
}

# Launch MSI Afterburner
Write-Host '[INFO] Launching MSI Afterburner...' -ForegroundColor Yellow
$msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1

if (-not $msiProcess) {
    Start-Process -FilePath $msiExe
    Write-Host '[OK] MSI Afterburner launched' -ForegroundColor Green
    Start-Sleep -Seconds 4
}
else {
    Write-Host '[INFO] MSI Afterburner is already running' -ForegroundColor Gray
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Profile Creation Instructions' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Please follow these steps in MSI Afterburner:' -ForegroundColor Yellow
Write-Host ''
Write-Host "Step 1: Set Core Clock to +$CoreClock MHz" -ForegroundColor White
Write-Host '  - Find the Core Clock slider (top-left)' -ForegroundColor Gray
Write-Host "  - Move it to +$CoreClock MHz" -ForegroundColor Gray
Write-Host ''
Write-Host "Step 2: Set Memory Clock to +$MemClock MHz" -ForegroundColor White
Write-Host '  - Find the Memory Clock slider (second from top)' -ForegroundColor Gray
Write-Host "  - Move it to +$MemClock MHz" -ForegroundColor Gray
Write-Host ''
Write-Host "Step 3: Set Power Limit to +$PowerLimit% (if available)" -ForegroundColor White
Write-Host '  - Find the Power Limit slider' -ForegroundColor Gray
Write-Host "  - Move it to +$PowerLimit%" -ForegroundColor Gray
Write-Host ''
Write-Host 'Step 4: Click Apply (checkmark icon, bottom-right)' -ForegroundColor White
Write-Host ''
Write-Host "Step 5: Save as Profile $ProfileNumber" -ForegroundColor White
Write-Host "  - Click the Profile $ProfileNumber button" -ForegroundColor Gray
Write-Host '  - Click Save (floppy disk icon)' -ForegroundColor Gray
Write-Host ''
Write-Host 'Step 6: (Optional) Set profile to apply at startup' -ForegroundColor White
Write-Host '  - Right-click Profile 1' -ForegroundColor Gray
Write-Host "  - Enable 'Apply this profile at startup'" -ForegroundColor Gray
Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# Wait for user to create profile
Write-Host 'Press Enter when you have completed the steps above...' -ForegroundColor Yellow
$null = Read-Host

# Apply the profile
Write-Host ''
Write-Host '=== Applying Profile ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "[INFO] Applying Profile $ProfileNumber..." -ForegroundColor Yellow

try {
    Start-Process -FilePath $msiExe -ArgumentList "-Profile$ProfileNumber" -ErrorAction Stop
    Start-Sleep -Seconds 2
    Write-Host "[OK] Profile $ProfileNumber applied successfully!" -ForegroundColor Green
    Write-Host ''
    Write-Host 'Applied Settings:' -ForegroundColor Yellow
    Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
    Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
    Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
    Write-Host ''
    Write-Host 'Profile is now ready to use!' -ForegroundColor Green
    Write-Host '  - Press hotkey A (if assigned) to apply' -ForegroundColor Gray
    Write-Host '  - Or use: .\apply-msi-profile.ps1 -ProfileNumber 1' -ForegroundColor Gray
    Write-Host '  - Or double-click desktop shortcut' -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Failed to apply profile: $_" -ForegroundColor Red
    Write-Host '  Please apply manually in MSI Afterburner' -ForegroundColor Yellow
}

Write-Host ''
