# Auto-configure MSI Afterburner
# This script attempts to configure MSI Afterburner using available methods

$CoreClock = 50
$MemClock = 200
$PowerLimit = 5

Write-Host "=== Auto-Configure MSI Afterburner ===" -ForegroundColor Cyan
Write-Host ""

# Method 1: Try to use MSI Afterburner Remote Server (if enabled)
# MSI Afterburner has a remote server that can be controlled via HTTP
$msiServerPort = 13247
$msiServerUrl = "http://localhost:$msiServerPort"

try {
    $response = Invoke-WebRequest -Uri "$msiServerUrl/GetStatus" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "[OK] MSI Afterburner Remote Server detected" -ForegroundColor Green
    
    # Try to set overclocking values via API
    # Note: This requires MSI Afterburner Remote Server to be enabled
    Write-Host "Attempting to set overclocking values via Remote Server..." -ForegroundColor Yellow
    
    # MSI Afterburner Remote Server API format
    # POST to set values: /SetOCProfile
    $body = @{
        CoreClk = $CoreClock
        MemClk = $MemClock
        PowerLimit = $PowerLimit
    } | ConvertTo-Json
    
    try {
        $result = Invoke-WebRequest -Uri "$msiServerUrl/SetOCProfile" -Method POST -Body $body -ContentType "application/json" -ErrorAction Stop
        Write-Host "[OK] Overclocking values set via Remote Server" -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "[WARN] Could not set values via Remote Server: $_" -ForegroundColor Yellow
        Write-Host "  Remote Server may not support this method" -ForegroundColor Gray
    }
} catch {
    Write-Host "[INFO] MSI Afterburner Remote Server not available" -ForegroundColor Gray
    Write-Host "  This is normal - Remote Server is optional" -ForegroundColor Gray
}

Write-Host ""

# Method 2: Launch MSI Afterburner and provide clear instructions
Write-Host "Launching MSI Afterburner for manual configuration..." -ForegroundColor Yellow

$msiExe = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
if (-not (Test-Path $msiExe)) {
    $msiExe = "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
}

if (Test-Path $msiExe) {
    Start-Process -FilePath $msiExe
    Start-Sleep -Seconds 3
    
    Write-Host ""
    Write-Host "=== Configuration Instructions ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "MSI Afterburner is now open. Please configure:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Core Clock Slider:" -ForegroundColor White
    Write-Host "   - Move slider to: +$CoreClock MHz" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Memory Clock Slider:" -ForegroundColor White
    Write-Host "   - Move slider to: +$MemClock MHz" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Power Limit Slider (if available):" -ForegroundColor White
    Write-Host "   - Move slider to: +$PowerLimit%" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Click the Apply button (checkmark icon)" -ForegroundColor White
    Write-Host ""
    Write-Host "5. Save as Profile 1 (optional, for easy loading later)" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "[FAIL] MSI Afterburner executable not found" -ForegroundColor Red
}
