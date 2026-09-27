# Master Overclocking Configuration Script
# This script configures both MSI Afterburner and Intel XTU with conservative settings

param(
    [int]$CoreClock = 50,
    [int]$MemClock = 200,
    [int]$PowerLimit = 5,
    [int]$TurboBoostPowerMax = 5,
    [int]$TurboBoostShortPowerMax = 5,
    [int]$TurboBoostMax = 100,
    [switch]$ApplyMSI,
    [switch]$ApplyXTU,
    [switch]$LaunchOnly
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Overclocking Configuration Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration values
$config = @{
    MSI = @{
        CoreClock = $CoreClock
        MemClock = $MemClock
        PowerLimit = $PowerLimit
    }
    XTU = @{
        TurboBoostPowerMax = $TurboBoostPowerMax
        TurboBoostShortPowerMax = $TurboBoostShortPowerMax
        TurboBoostMax = $TurboBoostMax
    }
}

# Display configuration
Write-Host "Configuration Values:" -ForegroundColor Yellow
Write-Host "  MSI Afterburner:" -ForegroundColor White
Write-Host "    Core Clock: +$($config.MSI.CoreClock) MHz" -ForegroundColor Gray
Write-Host "    Memory Clock: +$($config.MSI.MemClock) MHz" -ForegroundColor Gray
Write-Host "    Power Limit: +$($config.MSI.PowerLimit)%" -ForegroundColor Gray
Write-Host "  Intel XTU:" -ForegroundColor White
Write-Host "    Turbo Boost Power Max: +$($config.XTU.TurboBoostPowerMax) W" -ForegroundColor Gray
Write-Host "    Turbo Boost Short Power Max: +$($config.XTU.TurboBoostShortPowerMax) W" -ForegroundColor Gray
Write-Host "    Turbo Boost Max: +$($config.XTU.TurboBoostMax) MHz" -ForegroundColor Gray
Write-Host ""

# Determine what to configure
$configureMSI = $ApplyMSI -or (-not $ApplyXTU -and -not $LaunchOnly)
$configureXTU = $ApplyXTU -or (-not $ApplyMSI -and -not $LaunchOnly)

# MSI Afterburner Configuration
if ($configureMSI) {
    Write-Host "=== MSI Afterburner Configuration ===" -ForegroundColor Cyan
    Write-Host ""

    # Check if config file exists in workspace
    $workspaceConfig = "D:\DevOptimizer\MSIAfterburner.cfg"
    $targetConfig = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.cfg"

    if (Test-Path $workspaceConfig) {
        Write-Host "[INFO] Updating MSI Afterburner config file..." -ForegroundColor Yellow

        # Check if running as admin
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin) {
            # Create backup
            if (Test-Path $targetConfig) {
                $backupFile = "$targetConfig.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item $targetConfig -Destination $backupFile -ErrorAction SilentlyContinue
                Write-Host "[OK] Backup created: $backupFile" -ForegroundColor Green
            }

            # Copy config
            try {
                Copy-Item $workspaceConfig -Destination $targetConfig -Force
                Write-Host "[OK] MSI Afterburner config updated" -ForegroundColor Green
            } catch {
                Write-Host "[WARN] Could not update config: $_" -ForegroundColor Yellow
                Write-Host "  You may need to manually copy the file" -ForegroundColor Gray
            }
        } else {
            Write-Host "[INFO] Admin privileges required to update config file" -ForegroundColor Yellow
            Write-Host "  Config file ready at: $workspaceConfig" -ForegroundColor Gray
            Write-Host "  Use save-msi-config.ps1 to apply it" -ForegroundColor Gray
        }
    }

    # Launch MSI Afterburner
    $msiExe = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
    if (-not (Test-Path $msiExe)) {
        $msiExe = "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
    }

    if (Test-Path $msiExe) {
        Write-Host "[INFO] Launching MSI Afterburner..." -ForegroundColor Yellow
        Start-Process -FilePath $msiExe -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        Write-Host ""
        Write-Host "MSI Afterburner Configuration Steps:" -ForegroundColor Cyan
        Write-Host "  1. Verify Settings (gear icon):" -ForegroundColor White
        Write-Host "     - Unlock Voltage Control: Enabled" -ForegroundColor Gray
        Write-Host "     - Unlock Voltage Monitoring: Enabled" -ForegroundColor Gray
        Write-Host "     - Start with Windows: Enabled" -ForegroundColor Gray
        Write-Host "  2. Set Overclocking Values:" -ForegroundColor White
        Write-Host "     - Core Clock: +$($config.MSI.CoreClock) MHz" -ForegroundColor Gray
        Write-Host "     - Memory Clock: +$($config.MSI.MemClock) MHz" -ForegroundColor Gray
        Write-Host "     - Power Limit: +$($config.MSI.PowerLimit)% (if available)" -ForegroundColor Gray
        Write-Host "  3. Click Apply (checkmark icon)" -ForegroundColor White
        Write-Host "  4. Save as Profile 1 (optional)" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "[WARN] MSI Afterburner not found at expected location" -ForegroundColor Yellow
    }
}

# Intel XTU Configuration
if ($configureXTU) {
    Write-Host "=== Intel XTU Configuration ===" -ForegroundColor Cyan
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
                Write-Host "[INFO] Launching Intel XTU..." -ForegroundColor Yellow
                Start-Process -FilePath $path -ErrorAction SilentlyContinue
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
    }

    Write-Host ""
    Write-Host "Intel XTU Configuration Steps:" -ForegroundColor Cyan
    Write-Host "  1. Navigate to Advanced Tuning -> Power tab" -ForegroundColor White
    Write-Host "     - Turbo Boost Power Max: +$($config.XTU.TurboBoostPowerMax) W" -ForegroundColor Gray
    Write-Host "     - Turbo Boost Short Power Max: +$($config.XTU.TurboBoostShortPowerMax) W" -ForegroundColor Gray
    Write-Host "  2. Navigate to Advanced Tuning -> Core tab" -ForegroundColor White
    Write-Host "     - Turbo Boost Max: +$($config.XTU.TurboBoostMax) MHz (optional)" -ForegroundColor Gray
    Write-Host "  3. Click Apply" -ForegroundColor White
    Write-Host "  4. Run Stress Test for 15-30 minutes" -ForegroundColor White
    Write-Host "     - Monitor Core Temperature (< 90°C)" -ForegroundColor Gray
    Write-Host "     - Monitor Package Temperature (< 95°C)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Apply the settings in each tool" -ForegroundColor White
Write-Host "  2. Test for stability (15-30 minutes)" -ForegroundColor White
Write-Host "  3. Monitor temperatures closely" -ForegroundColor White
Write-Host "  4. Adjust if needed (start conservative!)" -ForegroundColor White
Write-Host ""
Write-Host "Safety Reminders:" -ForegroundColor Yellow
Write-Host "  - Start with conservative values" -ForegroundColor White
Write-Host "  - Test thoroughly before increasing" -ForegroundColor White
Write-Host "  - Monitor temperatures continuously" -ForegroundColor White
Write-Host "  - Know how to reset to defaults" -ForegroundColor White
Write-Host ""
