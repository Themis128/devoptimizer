# Apply Intel XTU Configuration via CLI/Registry
# Configure i9-12900H overclocking settings programmatically

param(
    [int]$PL1Increase = 15,
    [int]$PL2Increase = 10,
    [int]$VoltageOffset = 20,
    [int]$TurboBoostIncrease = 200,
    [switch]$ApplyOnly,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Intel XTU CLI Configuration' -ForegroundColor Cyan
Write-Host '  i9-12900H Mobile CPU' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# Base values for i9-12900H
$basePL1 = 45
$basePL2 = 115
$baseTurboBoost = 5000

# Calculate target values
$targetPL1 = $basePL1 + $PL1Increase
$targetPL2 = $basePL2 + $PL2Increase
$targetTurboBoost = $baseTurboBoost + $TurboBoostIncrease

Write-Host 'Configuration Values:' -ForegroundColor Yellow
Write-Host "  Base Power (PL1): $basePL1 W" -ForegroundColor White
Write-Host "  Target PL1: $targetPL1 W (+$PL1Increase W)" -ForegroundColor White
Write-Host "  Base Short Power (PL2): $basePL2 W" -ForegroundColor White
Write-Host "  Target PL2: $targetPL2 W (+$PL2Increase W)" -ForegroundColor White
Write-Host "  Base Turbo Boost: $baseTurboBoost MHz" -ForegroundColor White
Write-Host "  Target Turbo Boost: $targetTurboBoost MHz (+$TurboBoostIncrease MHz)" -ForegroundColor White
Write-Host "  Core Voltage Offset: +0.$VoltageOffset V ($VoltageOffset mV)" -ForegroundColor White
Write-Host ''

# Check if running as admin (required for registry)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host '[ERROR] Administrator privileges required for registry modification' -ForegroundColor Red
    Write-Host 'Please run PowerShell as Administrator' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'To run as admin:' -ForegroundColor Cyan
    Write-Host '  1. Right-click PowerShell' -ForegroundColor White
    Write-Host '  2. Select "Run as Administrator"' -ForegroundColor White
    Write-Host '  3. Navigate to: D:\DevOptimizer\config\overclocking' -ForegroundColor White
    Write-Host '  4. Run: .\apply-xtu-cli.ps1' -ForegroundColor White
    Write-Host ''
    exit 1
}

# Create backup
Write-Host '=== Creating Registry Backup ===' -ForegroundColor Cyan
Write-Host ''

$backupDir = 'D:\DevOptimizer\config\backups'
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$backupFile = "$backupDir\XTU-CLI-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"
$xtuRegPath = 'HKCU:\SOFTWARE\Intel\Extreme Tuning Utility'

try {
    # Export registry keys
    $regExport = "reg export `"HKCU\SOFTWARE\Intel\Extreme Tuning Utility`" `"$backupFile`" /y"
    Invoke-Expression $regExport | Out-Null

    if (Test-Path $backupFile) {
        Write-Host "[OK] Registry backup created: $backupFile" -ForegroundColor Green
    }
    else {
        Write-Host '[WARN] Could not create registry backup' -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[WARN] Backup creation failed: $_" -ForegroundColor Yellow
}

Write-Host ''

# Apply configuration
if (-not $VerifyOnly) {
    Write-Host '=== Applying Intel XTU Configuration ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Configuring registry keys...' -ForegroundColor Yellow
    Write-Host ''

    # Registry paths for Intel XTU
    $regPaths = @(
        'HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\HardwareOptimized',
        'HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Settings',
        'HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Profiles\Default'
    )

    $settingsApplied = 0
    $settingsFailed = 0

    foreach ($regPath in $regPaths) {
        # Create registry path if it doesn't exist
        if (-not (Test-Path $regPath)) {
            try {
                New-Item -Path $regPath -Force | Out-Null
                Write-Host "[INFO] Created registry path: $regPath" -ForegroundColor Gray
            }
            catch {
                Write-Host "[WARN] Could not create path: $regPath" -ForegroundColor Yellow
                continue
            }
        }

        Write-Host "  Configuring: $regPath" -ForegroundColor White

        # Apply settings
        $settings = @{
            'TurboBoostPowerMax' = $targetPL1
            'TurboBoostShortPowerMax' = $targetPL2
            'TurboBoostPowerTimeWindow' = 28
            'CoreVoltageOffset' = $VoltageOffset
            'TurboBoostMax' = $targetTurboBoost
            'TurboBoostRatioLimit' = 0
            'TJMaxOffset' = 0
            'MobileOptimization' = 1
            'PowerLimitMode' = 1
        }

        foreach ($setting in $settings.Keys) {
            try {
                Set-ItemProperty -Path $regPath -Name $setting -Value $settings[$setting] -ErrorAction Stop
                Write-Host "    [OK] $setting = $($settings[$setting])" -ForegroundColor Green
                $settingsApplied++
            }
            catch {
                Write-Host "    [WARN] Failed to set $setting : $_" -ForegroundColor Yellow
                $settingsFailed++
            }
        }

        Write-Host ''
    }

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host 'Configuration Applied!' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Settings Applied: $settingsApplied" -ForegroundColor Green
    if ($settingsFailed -gt 0) {
        Write-Host "Settings Failed: $settingsFailed" -ForegroundColor Yellow
    }
    Write-Host ''
}

# Verify configuration
Write-Host '=== Verifying Configuration ===' -ForegroundColor Cyan
Write-Host ''

$verifyPath = 'HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Settings'

if (Test-Path $verifyPath) {
    Write-Host 'Current Registry Values:' -ForegroundColor Yellow
    Write-Host ''

    $valuesToCheck = @{
        'TurboBoostPowerMax' = $targetPL1
        'TurboBoostShortPowerMax' = $targetPL2
        'CoreVoltageOffset' = $VoltageOffset
        'TurboBoostMax' = $targetTurboBoost
    }

    foreach ($valueName in $valuesToCheck.Keys) {
        try {
            $currentValue = Get-ItemProperty -Path $verifyPath -Name $valueName -ErrorAction SilentlyContinue
            if ($currentValue) {
                $actualValue = $currentValue.$valueName
                $expectedValue = $valuesToCheck[$valueName]

                if ($actualValue -eq $expectedValue) {
                    Write-Host "  [OK] $valueName = $actualValue (matches expected)" -ForegroundColor Green
                }
                else {
                    Write-Host "  [WARN] $valueName = $actualValue (expected: $expectedValue)" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "  [INFO] $valueName = Not set" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "  [INFO] $valueName = Could not read" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host '[WARN] Registry path not found - settings may not be applied' -ForegroundColor Yellow
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Configuration Summary' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Applied Settings:' -ForegroundColor Yellow
Write-Host "  Turbo Boost Power Max (PL1): $targetPL1 W (+$PL1Increase W)" -ForegroundColor White
Write-Host "  Turbo Boost Short Power Max (PL2): $targetPL2 W (+$PL2Increase W)" -ForegroundColor White
Write-Host "  Core Voltage Offset: +0.$VoltageOffset V ($VoltageOffset mV)" -ForegroundColor White
Write-Host "  Turbo Boost Max: $targetTurboBoost MHz (+$TurboBoostIncrease MHz)" -ForegroundColor White
Write-Host ''
Write-Host 'Next Steps:' -ForegroundColor Yellow
Write-Host '  1. Launch Intel XTU (if not already running)' -ForegroundColor White
Write-Host '  2. Navigate to Advanced Tuning section' -ForegroundColor White
Write-Host '  3. Verify settings match the values above' -ForegroundColor White
Write-Host '  4. If settings don''t appear, restart Intel XTU' -ForegroundColor White
Write-Host '  5. Run Stress Test for 15-30 minutes' -ForegroundColor White
Write-Host '  6. Monitor temperatures (Core < 90C, Package < 95C)' -ForegroundColor White
Write-Host ''
Write-Host 'Backup Location:' -ForegroundColor Cyan
Write-Host "  $backupFile" -ForegroundColor Gray
Write-Host ''
Write-Host 'Important Notes:' -ForegroundColor Yellow
Write-Host '  - Mobile CPU (i9-12900H) has limited overclocking capability' -ForegroundColor White
Write-Host '  - Monitor temperatures continuously' -ForegroundColor White
Write-Host '  - Thermal throttling is aggressive on mobile CPUs' -ForegroundColor White
Write-Host '  - Ensure adequate cooling' -ForegroundColor White
Write-Host ''
