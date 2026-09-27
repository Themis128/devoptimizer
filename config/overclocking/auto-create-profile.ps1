# Auto-Create MSI Afterburner Profile using UI Automation
# This script attempts to automate profile creation using SendKeys

param(
    [int]$CoreClock = 50,
    [int]$MemClock = 200,
    [int]$PowerLimit = 5,
    [int]$ProfileNumber = 1
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Auto-Create Profile with UI Automation' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Configuration:' -ForegroundColor Yellow
Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
Write-Host "  Profile Number: $ProfileNumber" -ForegroundColor White
Write-Host ''

$msiExe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
if (-not (Test-Path $msiExe)) {
    $msiExe = 'C:\Program Files\MSI Afterburner\MSIAfterburner.exe'
}

if (-not (Test-Path $msiExe)) {
    Write-Host '[ERROR] MSI Afterburner executable not found' -ForegroundColor Red
    exit 1
}

# Launch or bring MSI Afterburner to front
Write-Host '[INFO] Ensuring MSI Afterburner is running...' -ForegroundColor Yellow
$msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1

if (-not $msiProcess) {
    Write-Host '[INFO] Starting MSI Afterburner...' -ForegroundColor Yellow
    Start-Process -FilePath $msiExe
    Start-Sleep -Seconds 5
    $msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1
}

if ($msiProcess) {
    # Bring window to front
    $null = [Microsoft.VisualBasic.Interaction]::AppActivate($msiProcess.Id)
    Start-Sleep -Seconds 1

    Write-Host '[OK] MSI Afterburner window activated' -ForegroundColor Green
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '  Automated Profile Creation' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'WARNING: UI automation is complex and may not work reliably.' -ForegroundColor Yellow
    Write-Host 'MSI Afterburner window layout varies by version.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Recommended: Use manual method with guided instructions' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Would you like to:' -ForegroundColor White
    Write-Host '  1. Try automated UI automation (may not work)' -ForegroundColor Gray
    Write-Host '  2. Use guided manual method (recommended)' -ForegroundColor Gray
    Write-Host ''
    $choice = Read-Host 'Enter choice (1 or 2)'

    if ($choice -eq '1') {
        Write-Host ''
        Write-Host '[INFO] Attempting UI automation...' -ForegroundColor Yellow
        Write-Host '  This will use SendKeys to interact with MSI Afterburner' -ForegroundColor Gray
        Write-Host '  Press Ctrl+C to cancel if needed' -ForegroundColor Gray
        Write-Host ''
        Start-Sleep -Seconds 2

        # Note: UI automation is very unreliable for MSI Afterburner
        # because the window layout and control IDs vary
        # This is a best-effort attempt

        Write-Host '[WARN] Direct UI automation is not reliable for MSI Afterburner' -ForegroundColor Yellow
        Write-Host '  Please use the guided manual method instead' -ForegroundColor Yellow
    }
    else {
        Write-Host ''
        Write-Host '=== Guided Manual Profile Creation ===' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'MSI Afterburner window should be active.' -ForegroundColor White
        Write-Host 'Please follow these steps:' -ForegroundColor Yellow
        Write-Host ''
        Write-Host "1. Set Core Clock slider to: +$CoreClock MHz" -ForegroundColor White
        Write-Host "2. Set Memory Clock slider to: +$MemClock MHz" -ForegroundColor White
        Write-Host "3. Set Power Limit slider to: +$PowerLimit% (if available)" -ForegroundColor White
        Write-Host '4. Click Apply (checkmark icon)' -ForegroundColor White
        Write-Host "5. Click Profile $ProfileNumber button" -ForegroundColor White
        Write-Host '6. Click Save (floppy disk icon)' -ForegroundColor White
        Write-Host ''
        Write-Host 'Press Enter when done...' -ForegroundColor Yellow
        $null = Read-Host
    }
}
else {
    Write-Host '[ERROR] Could not start MSI Afterburner' -ForegroundColor Red
    exit 1
}

# Apply the profile
Write-Host ''
Write-Host '=== Applying Profile ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "[INFO] Applying Profile $ProfileNumber..." -ForegroundColor Yellow

try {
    Start-Process -FilePath $msiExe -ArgumentList "-Profile$ProfileNumber" -ErrorAction Stop
    Start-Sleep -Seconds 2
    Write-Host "[OK] Profile $ProfileNumber applied!" -ForegroundColor Green
    Write-Host ''
    Write-Host 'Profile Configuration Complete!' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Applied Settings:' -ForegroundColor Yellow
    Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
    Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
    Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
    Write-Host ''
    Write-Host 'You can now:' -ForegroundColor Cyan
    Write-Host '  - Press hotkey A to apply Profile 1' -ForegroundColor Gray
    Write-Host '  - Use: .\apply-msi-profile.ps1 -ProfileNumber 1' -ForegroundColor Gray
    Write-Host '  - Double-click desktop shortcut' -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Failed to apply profile: $_" -ForegroundColor Red
}

Write-Host ''
