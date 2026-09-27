# Apply Conservative Overclocking Settings
# This script applies safe, conservative overclocking values

param(
    [int]$CoreClock = 50,
    [int]$MemClock = 200,
    [int]$PowerLimit = 5
)

Write-Host ""
Write-Host "=== Applying Conservative Overclocking ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Settings:" -ForegroundColor Yellow
Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
Write-Host ""

# MSI Afterburner doesn't support direct command-line overclocking
# We need to use the Remote Server API or provide manual instructions

$msiServerPort = 13247
$msiServerUrl = "http://localhost:$msiServerPort"

Write-Host "Attempting to connect to MSI Afterburner Remote Server..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri "$msiServerUrl/GetStatus" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "[OK] MSI Afterburner Remote Server detected" -ForegroundColor Green

    # Try to apply settings via Remote Server API
    # Note: The actual API format may vary - this is a best-effort attempt
    Write-Host "Attempting to apply overclocking values..." -ForegroundColor Yellow

    # MSI Afterburner Remote Server uses a specific format
    # This is experimental and may not work with all versions
    try {
        $params = @{
            CoreClk = $CoreClock
            MemClk = $MemClock
            PowerLimit = $PowerLimit
        }

        # Try POST request (format may vary by version)
        $body = $params | ConvertTo-Json
        $result = Invoke-WebRequest -Uri "$msiServerUrl/SetOCProfile" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop

        Write-Host "[OK] Overclocking values applied via Remote Server" -ForegroundColor Green
        Write-Host ""
        Write-Host "Please verify the settings in MSI Afterburner GUI" -ForegroundColor Yellow
        exit 0
    } catch {
        Write-Host "[WARN] Could not apply via Remote Server API" -ForegroundColor Yellow
        Write-Host "  Error: $_" -ForegroundColor Gray
        Write-Host "  This is normal - Remote Server API may not support this method" -ForegroundColor Gray
    }
} catch {
    Write-Host "[INFO] MSI Afterburner Remote Server not available" -ForegroundColor Gray
    Write-Host "  Remote Server is optional and may not be enabled" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Manual Configuration Required ===" -ForegroundColor Cyan
Write-Host ""

# Launch MSI Afterburner
$msiExe = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
if (-not (Test-Path $msiExe)) {
    $msiExe = "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
}

if (Test-Path $msiExe) {
    Write-Host "Launching MSI Afterburner..." -ForegroundColor Yellow
    Start-Process -FilePath $msiExe
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Please configure these values in MSI Afterburner:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Core Clock Slider:" -ForegroundColor White
Write-Host "   Move to: +$CoreClock MHz" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Memory Clock Slider:" -ForegroundColor White
Write-Host "   Move to: +$MemClock MHz" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Power Limit Slider (if available):" -ForegroundColor White
Write-Host "   Move to: +$PowerLimit%" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Click the Apply button (checkmark icon)" -ForegroundColor White
Write-Host ""
Write-Host "5. Optional: Save as Profile 1 for easy loading" -ForegroundColor Gray
Write-Host ""
Write-Host "6. Test for stability (15-30 minutes)" -ForegroundColor White
Write-Host "   - Monitor temperatures (keep below 83°C)" -ForegroundColor Gray
Write-Host "   - Watch for artifacts or crashes" -ForegroundColor Gray
Write-Host ""
