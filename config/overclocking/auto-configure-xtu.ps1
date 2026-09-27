# Auto-configure Intel XTU
# This script attempts to configure Intel XTU settings

$TurboBoostPowerMax = 5
$TurboBoostShortPowerMax = 5
$CoreVoltageOffset = 10
$TurboBoostMax = 100

Write-Host "=== Auto-Configure Intel XTU ===" -ForegroundColor Cyan
Write-Host ""

# Launch Intel XTU
$xtuExePaths = @(
    "C:\Program Files (x86)\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
    "C:\Program Files\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
)

$launched = $false
foreach ($path in $xtuExePaths) {
    if (Test-Path $path) {
        try {
            Start-Process -FilePath $path
            Write-Host "[OK] Intel XTU launched: $path" -ForegroundColor Green
            $launched = $true
            Start-Sleep -Seconds 3
            break
        } catch {
            # Continue to next path
        }
    }
}

if (-not $launched) {
    Write-Host "[WARN] Could not launch Intel XTU automatically" -ForegroundColor Yellow
    Write-Host "  Please launch manually from Start Menu" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "=== Configuration Instructions ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Intel XTU is now open. Please configure:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Navigate to 'Advanced Tuning' -> 'Core' tab" -ForegroundColor White
Write-Host ""
Write-Host "2. Power Limits (in 'Core' or 'Power' tab):" -ForegroundColor White
Write-Host "   - Turbo Boost Power Max: Increase by +$TurboBoostPowerMax W" -ForegroundColor Gray
Write-Host "   - Turbo Boost Short Power Max: Increase by +$TurboBoostShortPowerMax W" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Core Settings:" -ForegroundColor White
Write-Host "   - Core Voltage Offset: +0.010V (if needed for stability)" -ForegroundColor Gray
Write-Host "   - Turbo Boost Max: +$TurboBoostMax MHz (optional, very conservative)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Click 'Apply' button" -ForegroundColor White
Write-Host ""
Write-Host "5. Run Stress Test for 15-30 minutes" -ForegroundColor White
Write-Host "   - Monitor Core Temperature (keep below 90°C)" -ForegroundColor Gray
Write-Host "   - Monitor Package Temperature (keep below 95°C)" -ForegroundColor Gray
Write-Host ""
