# Intel XTU Overclocking Configuration Script
# This script attempts to configure Intel XTU settings

$TurboBoostPowerMax = 5
$TurboBoostShortPowerMax = 5
$CoreVoltageOffset = 10
$TurboBoostMax = 100

Write-Host "Intel XTU Configuration for i9-12900H" -ForegroundColor Cyan
Write-Host ""
Write-Host "Recommended Settings:" -ForegroundColor Yellow
Write-Host "  Turbo Boost Power Max: +$TurboBoostPowerMax W" -ForegroundColor Gray
Write-Host "  Turbo Boost Short Power Max: +$TurboBoostShortPowerMax W" -ForegroundColor Gray
Write-Host "  Core Voltage Offset: +0.$(('000' + $CoreVoltageOffset).Substring(('000' + $CoreVoltageOffset).Length - 3))V" -ForegroundColor Gray
Write-Host "  Turbo Boost Max: +$TurboBoostMax MHz" -ForegroundColor Gray
Write-Host ""

# Intel XTU configuration is complex and CPU-specific
# Registry keys vary by version and CPU model
# Manual configuration via GUI is strongly recommended

Write-Host "[INFO] Intel XTU settings are CPU-specific and complex" -ForegroundColor Yellow
Write-Host "[INFO] Manual configuration via GUI is strongly recommended for safety" -ForegroundColor Yellow
Write-Host ""

# Try to launch Intel XTU
$xtuExePaths = @(
    "C:\Program Files (x86)\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
    "C:\Program Files\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
)

$launched = $false
foreach ($path in $xtuExePaths) {
    if (Test-Path $path) {
        try {
            Start-Process -FilePath $path
            Write-Host "Intel XTU launched: $path" -ForegroundColor Green
            $launched = $true
            break
        } catch {
            # Continue to next path
        }
    }
}

if (-not $launched) {
    Write-Host "[WARN] Could not launch Intel XTU automatically" -ForegroundColor Yellow
    Write-Host "  Please launch manually from Start Menu: Intel Extreme Tuning Utility" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Configuration Steps:" -ForegroundColor Cyan
    Write-Host "  1. Navigate to Advanced Tuning -> Power tab" -ForegroundColor White
    Write-Host "  2. Set Turbo Boost Power Max: +$TurboBoostPowerMax W" -ForegroundColor White
    Write-Host "  3. Set Turbo Boost Short Power Max: +$TurboBoostShortPowerMax W" -ForegroundColor White
    Write-Host "  4. Navigate to Advanced Tuning -> Core tab" -ForegroundColor White
    Write-Host "  5. Set Core Voltage Offset: +0.$(('000' + $CoreVoltageOffset).Substring(('000' + $CoreVoltageOffset).Length - 3))V" -ForegroundColor White
    Write-Host "  6. Set Turbo Boost Max: +$TurboBoostMax MHz" -ForegroundColor White
    Write-Host "  7. Click Apply" -ForegroundColor White
    Write-Host "  8. Run Stress Test for 15-30 minutes" -ForegroundColor White
}
