# Programmatic Intel XTU Configuration
# This script configures Intel XTU settings via registry for i9-12900H

param(
    [int]$TurboBoostPowerMax = 5,          # +5W increase
    [int]$TurboBoostShortPowerMax = 5,     # +5W increase
    [int]$CoreVoltageOffset = 10,          # +0.010V (in mV)
    [int]$TurboBoostMax = 100,             # +100 MHz
    [switch]$Conservative,
    [switch]$BackupOnly
)

$ErrorActionPreference = "Continue"

Write-Host "=== Programmatic Intel XTU Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin (recommended for registry access)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  Some registry operations may require admin privileges" -ForegroundColor Gray
    Write-Host "  Attempting to continue with current user privileges..." -ForegroundColor Gray
    Write-Host ""
}

# Get CPU info
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name
Write-Host "CPU: $cpuName" -ForegroundColor Cyan

# Adjust values if conservative
if ($Conservative) {
    $TurboBoostPowerMax = 3
    $TurboBoostShortPowerMax = 3
    $CoreVoltageOffset = 5
    $TurboBoostMax = 50
    Write-Host "Using conservative values" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Configuration Values:" -ForegroundColor Yellow
Write-Host "  Turbo Boost Power Max: +$TurboBoostPowerMax W" -ForegroundColor Gray
Write-Host "  Turbo Boost Short Power Max: +$TurboBoostShortPowerMax W" -ForegroundColor Gray
Write-Host "  Core Voltage Offset: +0.$(($CoreVoltageOffset).ToString('000'))V" -ForegroundColor Gray
Write-Host "  Turbo Boost Max: +$TurboBoostMax MHz" -ForegroundColor Gray
Write-Host ""

# Create backup directory
$backupDir = Join-Path $PSScriptRoot "..\backups"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupDir "XTU-Registry-Backup-$timestamp.reg"

# Backup existing registry settings
Write-Host "=== Backup ===" -ForegroundColor Cyan

$xtuRegPaths = @(
    "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility",
    "HKLM:\SOFTWARE\Intel\Extreme Tuning Utility",
    "HKCU:\SOFTWARE\Intel\XTU",
    "HKLM:\SOFTWARE\Intel\XTU"
)

$backupCreated = $false
foreach ($regPath in $xtuRegPaths) {
    if (Test-Path $regPath) {
        $regPathForExport = $regPath.Replace('HKCU:\', 'HKCU\').Replace('HKLM:\', 'HKLM\')
        try {
            reg export $regPathForExport $backupPath /y 2>&1 | Out-Null
            if (Test-Path $backupPath) {
                Write-Host "[OK] Registry backup created: $backupPath" -ForegroundColor Green
                $backupCreated = $true
                break
            }
        } catch {
            Write-Host "[WARN] Could not backup: $regPath" -ForegroundColor Yellow
        }
    }
}

if (-not $backupCreated) {
    Write-Host "[INFO] No existing XTU registry settings found to backup" -ForegroundColor Gray
    Write-Host "  This is normal if XTU hasn't been configured yet" -ForegroundColor Gray
}

if ($BackupOnly) {
    Write-Host ""
    Write-Host "[OK] Backup complete" -ForegroundColor Green
    exit 0
}

Write-Host ""

# Intel XTU Registry Configuration
# Note: Registry keys vary by CPU model and XTU version
# For i9-12900H with XTU 7.14.2.67, we'll use common registry paths

Write-Host "=== Applying Intel XTU Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Common registry paths for Intel XTU
$xtuBasePath = "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility"

# Create registry path if it doesn't exist
if (-not (Test-Path $xtuBasePath)) {
    try {
        New-Item -Path $xtuBasePath -Force | Out-Null
        Write-Host "[OK] Created registry path: $xtuBasePath" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Could not create registry path: $_" -ForegroundColor Yellow
    }
}

# Intel XTU stores settings in a complex structure
# For 12th Gen CPUs (Alder Lake), settings are typically under:
# HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\{CPU_ID}\{Profile_ID}

# Try to find existing CPU-specific paths
$xtuSubKeys = @()
try {
    if (Test-Path $xtuBasePath) {
        $xtuSubKeys = Get-ChildItem -Path $xtuBasePath -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "[INFO] Could not enumerate XTU registry keys" -ForegroundColor Gray
}

# For i9-12900H, we'll configure common settings
# Note: Exact registry keys may need adjustment based on XTU version

Write-Host "Configuring Intel XTU settings..." -ForegroundColor Yellow
Write-Host ""

# Method 1: Try to set values in common registry locations
$settingsApplied = $false

# Common registry value names for Intel XTU
$regSettings = @{
    "TurboBoostPowerMax" = $TurboBoostPowerMax
    "TurboBoostShortPowerMax" = $TurboBoostShortPowerMax
    "CoreVoltageOffset" = $CoreVoltageOffset
    "TurboBoostMax" = $TurboBoostMax
}

# Try different registry paths
$regPathsToTry = @(
    "$xtuBasePath\Settings",
    "$xtuBasePath\Profiles\Default",
    "$xtuBasePath\Overclocking"
)

foreach ($regPath in $regPathsToTry) {
    if (-not (Test-Path $regPath)) {
        try {
            New-Item -Path $regPath -Force | Out-Null
        } catch {
            continue
        }
    }

    Write-Host "Trying registry path: $regPath" -ForegroundColor Gray

    foreach ($settingName in $regSettings.Keys) {
        $settingValue = $regSettings[$settingName]
        try {
            Set-ItemProperty -Path $regPath -Name $settingName -Value $settingValue -Type DWord -ErrorAction Stop
            Write-Host "  [OK] Set $settingName = $settingValue" -ForegroundColor Green
            $settingsApplied = $true
        } catch {
            # Try as String instead of DWord
            try {
                Set-ItemProperty -Path $regPath -Name $settingName -Value $settingValue.ToString() -Type String -ErrorAction Stop
                Write-Host "  [OK] Set $settingName = $settingValue (as String)" -ForegroundColor Green
                $settingsApplied = $true
            } catch {
                # Setting may not exist or path is wrong
            }
        }
    }
}

# Method 2: Use Intel XTU's configuration file if accessible
# Intel XTU also stores settings in application data
$xtuAppData = Join-Path $env:APPDATA "Intel\Extreme Tuning Utility"
if (Test-Path $xtuAppData) {
    Write-Host ""
    Write-Host "[INFO] Found XTU application data: $xtuAppData" -ForegroundColor Gray

    # Look for configuration files
    $configFiles = Get-ChildItem -Path $xtuAppData -Filter "*.xml" -ErrorAction SilentlyContinue
    if ($configFiles) {
        Write-Host "[INFO] Found configuration files, but XML format requires parsing" -ForegroundColor Gray
        Write-Host "  Registry method is preferred for programmatic configuration" -ForegroundColor Gray
    }
}

# Method 3: Create a profile file that XTU can import
Write-Host ""
Write-Host "=== Alternative Method: Profile File ===" -ForegroundColor Cyan

$profileContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<Profile>
    <Name>Conservative Overclock</Name>
    <Description>Programmatically configured conservative overclock</Description>
    <Settings>
        <TurboBoostPowerMax>$TurboBoostPowerMax</TurboBoostPowerMax>
        <TurboBoostShortPowerMax>$TurboBoostShortPowerMax</TurboBoostShortPowerMax>
        <CoreVoltageOffset>$CoreVoltageOffset</CoreVoltageOffset>
        <TurboBoostMax>$TurboBoostMax</TurboBoostMax>
    </Settings>
</Profile>
"@

$profilePath = Join-Path $PSScriptRoot "..\XTU-Profile-Conservative.xml"
try {
    Set-Content -Path $profilePath -Value $profileContent
    Write-Host "[OK] Created XTU profile file: $profilePath" -ForegroundColor Green
    Write-Host "  Note: This profile can be imported into Intel XTU manually" -ForegroundColor Gray
} catch {
    Write-Host "[WARN] Could not create profile file: $_" -ForegroundColor Yellow
}

Write-Host ""

# Summary
Write-Host "=== Configuration Summary ===" -ForegroundColor Cyan
Write-Host ""

if ($settingsApplied) {
    Write-Host "[OK] Some settings were applied via registry" -ForegroundColor Green
    Write-Host "  Note: Intel XTU may need to be restarted to apply changes" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] Registry settings may not have been applied" -ForegroundColor Yellow
    Write-Host "  This could be because:" -ForegroundColor Gray
    Write-Host "    - XTU hasn't been run yet (registry keys don't exist)" -ForegroundColor Gray
    Write-Host "    - Registry key names vary by XTU version" -ForegroundColor Gray
    Write-Host "    - Settings require XTU to be running" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Recommended Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Launch Intel XTU" -ForegroundColor White
Write-Host "  2. Check if settings were applied" -ForegroundColor White
Write-Host "  3. If not, apply manually using the values shown above" -ForegroundColor White
Write-Host "  4. Run Stress Test for 15-30 minutes" -ForegroundColor White
Write-Host "  5. Monitor temperatures (Core < 90°C, Package < 95°C)" -ForegroundColor White
Write-Host ""

if ($backupCreated) {
    Write-Host "Backup location: $backupPath" -ForegroundColor Gray
}

Write-Host ""
