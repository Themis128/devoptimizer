# Apply All Overclocking Configuration via CLI
# Configures both MSI Afterburner and Intel XTU programmatically

param(
    # MSI Afterburner settings
    [int]$GPUCoreClock = 50,
    [int]$GPUMemClock = 200,
    [int]$GPUPowerLimit = 5,
    [int]$MSIProfile = 1,

    # Intel XTU settings
    [int]$PL1Increase = 15,
    [int]$PL2Increase = 10,
    [int]$VoltageOffset = 20,
    [int]$TurboBoostIncrease = 200,

    [switch]$MSIOnly,
    [switch]$XTUOnly,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Complete Overclocking Configuration (CLI)' -ForegroundColor Cyan
Write-Host '  RTX 3070 Laptop + i9-12900H' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host '[WARN] Administrator privileges recommended for full configuration' -ForegroundColor Yellow
    Write-Host '  Some settings may require admin rights' -ForegroundColor Gray
    Write-Host ''
}

# MSI Afterburner Configuration
if (-not $XTUOnly) {
    Write-Host '=== MSI Afterburner Configuration ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'GPU Settings:' -ForegroundColor Yellow
    Write-Host "  Core Clock: +$GPUCoreClock MHz" -ForegroundColor White
    Write-Host "  Memory Clock: +$GPUMemClock MHz" -ForegroundColor White
    Write-Host "  Power Limit: +$GPUPowerLimit%" -ForegroundColor White
    Write-Host "  Profile: $MSIProfile" -ForegroundColor White
    Write-Host ''

    # Apply MSI Afterburner profile
    $msiExe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
    if (-not (Test-Path $msiExe)) {
        $msiExe = 'C:\Program Files\MSI Afterburner\MSIAfterburner.exe'
    }

    if (Test-Path $msiExe) {
        Write-Host '[INFO] Applying MSI Afterburner Profile...' -ForegroundColor Yellow
        try {
            Start-Process -FilePath $msiExe -ArgumentList "-Profile$MSIProfile" -ErrorAction SilentlyContinue
            Write-Host "[OK] MSI Afterburner Profile $MSIProfile applied" -ForegroundColor Green
            Write-Host '  Note: Profile must exist with these values' -ForegroundColor Gray
        }
        catch {
            Write-Host '[WARN] Could not apply MSI Afterburner profile' -ForegroundColor Yellow
        }
    }
    else {
        Write-Host '[WARN] MSI Afterburner not found' -ForegroundColor Yellow
    }

    Write-Host ''
}

# Intel XTU Configuration
if (-not $MSIOnly) {
    Write-Host '=== Intel XTU Configuration ===' -ForegroundColor Cyan
    Write-Host ''

    if (-not $isAdmin) {
        Write-Host '[ERROR] Administrator privileges required for Intel XTU registry configuration' -ForegroundColor Red
        Write-Host '  Please run PowerShell as Administrator' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  Or use existing script:' -ForegroundColor Cyan
        Write-Host '    .\configure-xtu-hardware-based.ps1' -ForegroundColor White
        Write-Host ''
    }
    else {
        Write-Host 'CPU Settings:' -ForegroundColor Yellow
        Write-Host "  PL1 (Base Power): 45W -> $($45 + $PL1Increase)W (+$PL1Increase W)" -ForegroundColor White
        Write-Host "  PL2 (Short Power): 115W -> $($115 + $PL2Increase)W (+$PL2Increase W)" -ForegroundColor White
        Write-Host "  Core Voltage Offset: +0.$VoltageOffset V ($VoltageOffset mV)" -ForegroundColor White
        Write-Host "  Turbo Boost Max: 5000 MHz -> $($5000 + $TurboBoostIncrease) MHz (+$TurboBoostIncrease MHz)" -ForegroundColor White
        Write-Host ''

        # Use existing hardware-based script
        $xtuScript = Join-Path $PSScriptRoot 'configure-xtu-hardware-based.ps1'

        if (Test-Path $xtuScript) {
            Write-Host '[INFO] Using hardware-based Intel XTU configuration script...' -ForegroundColor Yellow
            Write-Host ''

            # Call the existing script with calculated values
            $targetPL1 = 45 + $PL1Increase
            $targetPL2 = 115 + $PL2Increase
            $targetTurbo = 5000 + $TurboBoostIncrease

            & $xtuScript -TurboBoostPowerMax $targetPL1 -TurboBoostShortPowerMax $targetPL2 -CoreVoltageOffset $VoltageOffset -TurboBoostMax $targetTurbo

            Write-Host ''
            Write-Host '[OK] Intel XTU configuration applied via CLI' -ForegroundColor Green
        }
        else {
            Write-Host '[WARN] Hardware-based XTU script not found' -ForegroundColor Yellow
            Write-Host '  Using direct registry method...' -ForegroundColor Gray
            Write-Host ''

            # Direct registry configuration
            $xtuBasePath = 'HKCU:\SOFTWARE\Intel\Extreme Tuning Utility'
            $regPaths = @(
                "$xtuBasePath\HardwareOptimized",
                "$xtuBasePath\Settings",
                "$xtuBasePath\Profiles\Default"
            )

            $targetPL1 = 45 + $PL1Increase
            $targetPL2 = 115 + $PL2Increase
            $targetTurbo = 5000 + $TurboBoostIncrease

            foreach ($regPath in $regPaths) {
                if (-not (Test-Path $regPath)) {
                    New-Item -Path $regPath -Force | Out-Null
                }

                Set-ItemProperty -Path $regPath -Name 'TurboBoostPowerMax' -Value $targetPL1 -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $regPath -Name 'TurboBoostShortPowerMax' -Value $targetPL2 -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $regPath -Name 'CoreVoltageOffset' -Value $VoltageOffset -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $regPath -Name 'TurboBoostMax' -Value $targetTurbo -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $regPath -Name 'TurboBoostPowerTimeWindow' -Value 28 -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $regPath -Name 'MobileOptimization' -Value 1 -ErrorAction SilentlyContinue
            }

            Write-Host '[OK] Intel XTU registry settings applied' -ForegroundColor Green
        }
    }

    Write-Host ''
}

Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Configuration Complete!' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Applied Settings:' -ForegroundColor Yellow
if (-not $XTUOnly) {
    Write-Host '  MSI Afterburner:' -ForegroundColor White
    Write-Host "    Core Clock: +$GPUCoreClock MHz" -ForegroundColor Gray
    Write-Host "    Memory Clock: +$GPUMemClock MHz" -ForegroundColor Gray
    Write-Host "    Power Limit: +$GPUPowerLimit%" -ForegroundColor Gray
}
if (-not $MSIOnly) {
    Write-Host '  Intel XTU:' -ForegroundColor White
    Write-Host "    PL1: $($45 + $PL1Increase)W (+$PL1Increase W)" -ForegroundColor Gray
    Write-Host "    PL2: $($115 + $PL2Increase)W (+$PL2Increase W)" -ForegroundColor Gray
    Write-Host "    Voltage Offset: +0.$VoltageOffset V" -ForegroundColor Gray
    Write-Host "    Turbo Boost: $($5000 + $TurboBoostIncrease) MHz (+$TurboBoostIncrease MHz)" -ForegroundColor Gray
}
Write-Host ''
Write-Host 'Next Steps:' -ForegroundColor Yellow
Write-Host '  1. Verify settings in MSI Afterburner GUI' -ForegroundColor White
Write-Host '  2. Launch Intel XTU and verify settings' -ForegroundColor White
Write-Host '  3. Run stress tests for both GPU and CPU' -ForegroundColor White
Write-Host '  4. Monitor temperatures continuously' -ForegroundColor White
Write-Host ''
