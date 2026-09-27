# Apply MSI Afterburner Profile Programmatically
# This script applies a saved MSI Afterburner profile using command-line

param(
    [int]$ProfileNumber = 1
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== Apply MSI Afterburner Profile ===" -ForegroundColor Cyan
Write-Host ""

$msiExe = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
if (-not (Test-Path $msiExe)) {
    $msiExe = "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
}

if (-not (Test-Path $msiExe)) {
    Write-Host "[ERROR] MSI Afterburner executable not found" -ForegroundColor Red
    exit 1
}

Write-Host "Applying Profile $ProfileNumber..." -ForegroundColor Yellow

# Method 1: Command-line argument (most reliable)
try {
    Write-Host "[INFO] Applying profile via command-line..." -ForegroundColor Yellow
    Start-Process -FilePath $msiExe -ArgumentList "-Profile$ProfileNumber" -ErrorAction Stop
    Write-Host "[OK] Profile $ProfileNumber applied!" -ForegroundColor Green
    Write-Host "  Command: MSIAfterburner.exe -Profile$ProfileNumber" -ForegroundColor Gray
} catch {
    Write-Host "[ERROR] Failed to apply profile: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Profile applied successfully!" -ForegroundColor Green
Write-Host "  Note: MSI Afterburner must be running for the profile to take effect" -ForegroundColor Gray
Write-Host ""
