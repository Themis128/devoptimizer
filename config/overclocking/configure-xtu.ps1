# Quick Intel XTU Configuration Script
# Simple wrapper for easy execution

param(
    [int]$TurboBoostPowerMax = 5,
    [int]$TurboBoostShortPowerMax = 5,
    [int]$CoreVoltageOffset = 10,
    [int]$TurboBoostMax = 100,
    [switch]$Conservative,
    [switch]$LaunchXTU,
    [switch]$Help
)

if ($Help) {
    Write-Host "Intel XTU Configuration Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\configure-xtu.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -TurboBoostPowerMax <W>        Turbo Boost Power Max increase (default: 5)" -ForegroundColor Gray
    Write-Host "  -TurboBoostShortPowerMax <W>    Turbo Boost Short Power Max increase (default: 5)" -ForegroundColor Gray
    Write-Host "  -CoreVoltageOffset <mV>         Core Voltage Offset in mV (default: 10 = 0.010V)" -ForegroundColor Gray
    Write-Host "  -TurboBoostMax <MHz>            Turbo Boost Max increase in MHz (default: 100)" -ForegroundColor Gray
    Write-Host "  -Conservative                   Use more conservative values (3W, 5mV, 50MHz)" -ForegroundColor Gray
    Write-Host "  -LaunchXTU                      Launch Intel XTU after configuration" -ForegroundColor Gray
    Write-Host "  -Help                           Show this help message" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\configure-xtu.ps1                    # Use default conservative values" -ForegroundColor White
    Write-Host "  .\configure-xtu.ps1 -Conservative      # Use extra conservative values" -ForegroundColor White
    Write-Host "  .\configure-xtu.ps1 -LaunchXTU         # Configure and launch XTU" -ForegroundColor White
    Write-Host "  .\configure-xtu.ps1 -TurboBoostPowerMax 10  # Custom power limit" -ForegroundColor White
    Write-Host ""
    exit 0
}

# Call the advanced configuration script
$scriptPath = Join-Path $PSScriptRoot "configure-xtu-advanced.ps1"

if (Test-Path $scriptPath) {
    & $scriptPath `
        -TurboBoostPowerMax $TurboBoostPowerMax `
        -TurboBoostShortPowerMax $TurboBoostShortPowerMax `
        -CoreVoltageOffset $CoreVoltageOffset `
        -TurboBoostMax $TurboBoostMax `
        -Conservative:$Conservative `
        -LaunchXTU:$LaunchXTU
} else {
    Write-Host "[ERROR] Advanced configuration script not found: $scriptPath" -ForegroundColor Red
    Write-Host "  Please ensure configure-xtu-advanced.ps1 is in the same directory" -ForegroundColor Yellow
    exit 1
}
