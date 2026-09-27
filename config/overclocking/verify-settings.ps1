# Verify MSI Afterburner Settings
# This script helps verify that overclocking settings are correctly applied

param(
    [int]$ExpectedCoreClock = 50,
    [int]$ExpectedMemClock = 200,
    [int]$ExpectedPowerLimit = 5
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Verify MSI Afterburner Settings' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Expected Settings:' -ForegroundColor Yellow
Write-Host "  Core Clock: +$ExpectedCoreClock MHz" -ForegroundColor White
Write-Host "  Memory Clock: +$ExpectedMemClock MHz" -ForegroundColor White
Write-Host "  Power Limit: +$ExpectedPowerLimit%" -ForegroundColor White
Write-Host ''

# Check if MSI Afterburner is running
$msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1

if (-not $msiProcess) {
    Write-Host '[WARN] MSI Afterburner is not running' -ForegroundColor Yellow
    Write-Host '  Please start MSI Afterburner to verify settings' -ForegroundColor Gray
    Write-Host ''

    $msiExe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
    if (-not (Test-Path $msiExe)) {
        $msiExe = 'C:\Program Files\MSI Afterburner\MSIAfterburner.exe'
    }

    if (Test-Path $msiExe) {
        $launch = Read-Host 'Would you like to launch MSI Afterburner? (Y/N)'
        if ($launch -eq 'Y' -or $launch -eq 'y') {
            Start-Process -FilePath $msiExe
            Start-Sleep -Seconds 3
            Write-Host '[OK] MSI Afterburner launched' -ForegroundColor Green
        }
    }
}
else {
    Write-Host '[OK] MSI Afterburner is running' -ForegroundColor Green
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Manual Verification Steps' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Please check the following in MSI Afterburner:' -ForegroundColor Yellow
Write-Host ''
Write-Host '1. Core Clock Slider:' -ForegroundColor White
Write-Host "   - Should show: +$ExpectedCoreClock MHz" -ForegroundColor Gray
Write-Host "   - Current value: [Check in MSI Afterburner]" -ForegroundColor Gray
Write-Host ''
Write-Host '2. Memory Clock Slider:' -ForegroundColor White
Write-Host "   - Should show: +$ExpectedMemClock MHz" -ForegroundColor Gray
Write-Host "   - Current value: [Check in MSI Afterburner]" -ForegroundColor Gray
Write-Host ''
Write-Host '3. Power Limit Slider (if available):' -ForegroundColor White
Write-Host "   - Should show: +$ExpectedPowerLimit%" -ForegroundColor Gray
Write-Host "   - Current value: [Check in MSI Afterburner]" -ForegroundColor Gray
Write-Host ''
Write-Host '4. Temperature Limit:' -ForegroundColor White
Write-Host '   - Should show: 83°C (default)' -ForegroundColor Gray
Write-Host '   - DO NOT increase this value' -ForegroundColor Yellow
Write-Host ''
Write-Host '5. Apply Button:' -ForegroundColor White
Write-Host '   - Should show checkmark (settings applied)' -ForegroundColor Gray
Write-Host ''
Write-Host '6. Profile Status:' -ForegroundColor White
Write-Host '   - Profile 1 should be highlighted/active' -ForegroundColor Gray
Write-Host '   - Hotkey A should be assigned (if configured)' -ForegroundColor Gray
Write-Host ''

# Try to get GPU information via WMI
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  GPU Information' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

try {
    $gpu = Get-WmiObject -Class Win32_VideoController | Where-Object { $_.Name -like '*NVIDIA*' -or $_.Name -like '*RTX*' -or $_.Name -like '*GeForce*' } | Select-Object -First 1

    if ($gpu) {
        Write-Host 'GPU Detected:' -ForegroundColor Green
        Write-Host "  Name: $($gpu.Name)" -ForegroundColor White
        Write-Host "  Driver Version: $($gpu.DriverVersion)" -ForegroundColor White
        Write-Host "  Adapter RAM: $([math]::Round($gpu.AdapterRAM / 1GB, 2)) GB" -ForegroundColor White
    }
    else {
        Write-Host '[INFO] Could not detect GPU via WMI' -ForegroundColor Gray
    }
}
catch {
    Write-Host '[INFO] Could not retrieve GPU information' -ForegroundColor Gray
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Verification Checklist' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Please confirm:' -ForegroundColor Yellow
Write-Host ''
Write-Host "[ ] Core Clock is set to +$ExpectedCoreClock MHz" -ForegroundColor White
Write-Host "[ ] Memory Clock is set to +$ExpectedMemClock MHz" -ForegroundColor White
Write-Host "[ ] Power Limit is set to +$ExpectedPowerLimit%" -ForegroundColor White
Write-Host '[ ] Temperature Limit is at 83°C (default)' -ForegroundColor White
Write-Host '[ ] Settings are applied (checkmark visible)' -ForegroundColor White
Write-Host '[ ] Profile 1 is active' -ForegroundColor White
Write-Host ''
Write-Host 'If any values are incorrect:' -ForegroundColor Yellow
Write-Host '  1. Adjust sliders in MSI Afterburner' -ForegroundColor White
Write-Host '  2. Click Apply' -ForegroundColor White
Write-Host '  3. Save to Profile 1' -ForegroundColor White
Write-Host '  4. Run this script again to verify' -ForegroundColor White
Write-Host ''
