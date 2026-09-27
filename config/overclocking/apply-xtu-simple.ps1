# Simple Intel XTU CLI Configuration
# Quick wrapper for hardware-based configuration

param(
    [int]$PL1 = 60,
    [int]$PL2 = 125,
    [int]$VoltageOffset = 20,
    [int]$TurboBoost = 5200,
    [switch]$Conservative,
    [switch]$Moderate,
    [switch]$Aggressive
)

$ErrorActionPreference = 'Continue'

# Predefined profiles
if ($Conservative) {
    $PL1 = 50
    $PL2 = 120
    $VoltageOffset = 10
    $TurboBoost = 5100
}
elseif ($Moderate) {
    $PL1 = 60
    $PL2 = 125
    $VoltageOffset = 20
    $TurboBoost = 5200
}
elseif ($Aggressive) {
    $PL1 = 60
    $PL2 = 130
    $VoltageOffset = 20
    $TurboBoost = 5200
}

Write-Host ''
Write-Host '=== Intel XTU CLI Configuration ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Settings:' -ForegroundColor Yellow
Write-Host "  PL1 (Base Power): $PL1 W" -ForegroundColor White
Write-Host "  PL2 (Short Power): $PL2 W" -ForegroundColor White
Write-Host "  Voltage Offset: +0.$VoltageOffset V ($VoltageOffset mV)" -ForegroundColor White
Write-Host "  Turbo Boost: $TurboBoost MHz" -ForegroundColor White
Write-Host ''

# Use existing hardware-based script
$xtuScript = Join-Path $PSScriptRoot 'configure-xtu-hardware-based.ps1'

if (Test-Path $xtuScript) {
    Write-Host '[INFO] Using hardware-based configuration script...' -ForegroundColor Yellow
    Write-Host ''

    & $xtuScript -TurboBoostPowerMax $PL1 -TurboBoostShortPowerMax $PL2 -CoreVoltageOffset $VoltageOffset -TurboBoostMax $TurboBoost

    Write-Host ''
    Write-Host '[OK] Configuration complete!' -ForegroundColor Green
}
else {
    Write-Host '[ERROR] Hardware-based script not found' -ForegroundColor Red
    Write-Host "  Expected: $xtuScript" -ForegroundColor Gray
    exit 1
}

Write-Host ''
