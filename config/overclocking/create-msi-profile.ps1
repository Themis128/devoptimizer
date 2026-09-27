# Create MSI Afterburner Profile Programmatically
# This script creates a profile in MSI Afterburner by applying settings and saving them

param(
    [int]$CoreClock = 50,
    [int]$MemClock = 200,
    [int]$PowerLimit = 5,
    [int]$ProfileNumber = 1
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== Create MSI Afterburner Profile ===" -ForegroundColor Cyan
Write-Host ""

$msiExe = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
if (-not (Test-Path $msiExe)) {
    $msiExe = "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
}

if (-not (Test-Path $msiExe)) {
    Write-Host "[ERROR] MSI Afterburner executable not found" -ForegroundColor Red
    exit 1
}

Write-Host "Profile Configuration:" -ForegroundColor Yellow
Write-Host "  Profile Number: $ProfileNumber" -ForegroundColor White
Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
Write-Host ""

# Method 1: Try Remote Server API
$msiServerPort = 13247
$msiServerUrl = "http://localhost:$msiServerPort"

try {
    $response = Invoke-WebRequest -Uri "$msiServerUrl/GetStatus" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "[OK] MSI Afterburner Remote Server detected" -ForegroundColor Green

    # Try to apply and save profile
    $body = @{
        CoreClk = $CoreClock
        MemClk = $MemClock
        PowerLimit = $PowerLimit
        Profile = $ProfileNumber
    } | ConvertTo-Json

    try {
        $result = Invoke-WebRequest -Uri "$msiServerUrl/SetOCProfile" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
        Write-Host "[OK] Profile created via Remote Server API!" -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "[WARN] Could not create profile via API: $_" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[INFO] MSI Afterburner Remote Server not available" -ForegroundColor Gray
}

# Method 2: Use AutoHotkey or similar automation (if available)
# Method 3: Provide instructions for manual profile creation

Write-Host ""
Write-Host "=== Manual Profile Creation Required ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "MSI Afterburner doesn't support direct profile creation via command-line." -ForegroundColor Yellow
Write-Host "Please follow these steps:" -ForegroundColor White
Write-Host ""
Write-Host "1. MSI Afterburner should be open" -ForegroundColor White
Write-Host "2. Set the following values:" -ForegroundColor White
Write-Host "   - Core Clock: +$CoreClock MHz" -ForegroundColor Gray
Write-Host "   - Memory Clock: +$MemClock MHz" -ForegroundColor Gray
Write-Host "   - Power Limit: +$PowerLimit% (if available)" -ForegroundColor Gray
Write-Host "3. Click Apply (checkmark icon)" -ForegroundColor White
Write-Host "4. Click Profile $ProfileNumber button" -ForegroundColor White
Write-Host "5. Click Save to save the profile" -ForegroundColor White
Write-Host "6. (Optional) Right-click profile and enable 'Apply at startup'" -ForegroundColor Gray
Write-Host ""

# Launch MSI Afterburner if not running
$msiProcess = Get-Process | Where-Object { $_.ProcessName -like "*Afterburner*" -or $_.ProcessName -like "*MSI*" } | Select-Object -First 1

if (-not $msiProcess) {
    Write-Host "[INFO] Launching MSI Afterburner..." -ForegroundColor Yellow
    Start-Process -FilePath $msiExe
    Start-Sleep -Seconds 2
}

Write-Host "Once the profile is saved, you can apply it programmatically using:" -ForegroundColor Cyan
Write-Host "  MSIAfterburner.exe -Profile$ProfileNumber" -ForegroundColor White
Write-Host ""
