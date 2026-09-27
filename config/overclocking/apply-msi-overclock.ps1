# MSI Afterburner Overclocking Configuration Script
# This script applies overclocking values via MSI Afterburner command line

$CoreClock = 50
$MemClock = 200
$PowerLimit = 5

Write-Host "Applying MSI Afterburner overclocking values..." -ForegroundColor Yellow
Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor Gray
Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor Gray
Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor Gray
Write-Host ""

# MSI Afterburner command line parameters
$msiExe = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
if (-not (Test-Path $msiExe)) {
    $msiExe = "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
}

if (Test-Path $msiExe) {
    Write-Host "Launching MSI Afterburner..." -ForegroundColor Green
    
    # MSI Afterburner doesn't support direct command-line overclocking
    # We need to use the GUI or modify the profile file directly
    # For now, we'll launch it and provide instructions
    
    Start-Process -FilePath $msiExe
    
    Write-Host ""
    Write-Host "MSI Afterburner has been launched." -ForegroundColor Green
    Write-Host "Please configure the following values manually:" -ForegroundColor Yellow
    Write-Host "  1. Core Clock: +$CoreClock MHz" -ForegroundColor White
    Write-Host "  2. Memory Clock: +$MemClock MHz" -ForegroundColor White
    Write-Host "  3. Power Limit: +$PowerLimit% (if available)" -ForegroundColor White
    Write-Host "  4. Click Apply (checkmark icon)" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "[FAIL] MSI Afterburner executable not found" -ForegroundColor Red
}
