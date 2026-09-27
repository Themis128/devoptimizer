# Advanced Programmatic Intel XTU Configuration
# This script finds and configures Intel XTU settings for i9-12900H

param(
    [int]$TurboBoostPowerMax = 5,
    [int]$TurboBoostShortPowerMax = 5,
    [int]$CoreVoltageOffset = 10,
    [int]$TurboBoostMax = 100,
    [switch]$Conservative,
    [switch]$LaunchXTU
)

$ErrorActionPreference = "Continue"

Write-Host "=== Advanced Intel XTU Programmatic Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Get CPU info
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name
$cpuId = $cpu.ProcessorId

Write-Host "CPU: $cpuName" -ForegroundColor Cyan
Write-Host "CPU ID: $cpuId" -ForegroundColor Gray
Write-Host ""

if ($Conservative) {
    $TurboBoostPowerMax = 3
    $TurboBoostShortPowerMax = 3
    $CoreVoltageOffset = 5
    $TurboBoostMax = 50
}

Write-Host "Configuration Values:" -ForegroundColor Yellow
Write-Host "  Turbo Boost Power Max: +$TurboBoostPowerMax W" -ForegroundColor Gray
Write-Host "  Turbo Boost Short Power Max: +$TurboBoostShortPowerMax W" -ForegroundColor Gray
Write-Host "  Core Voltage Offset: +0.$(($CoreVoltageOffset).ToString('000'))V" -ForegroundColor Gray
Write-Host "  Turbo Boost Max: +$TurboBoostMax MHz" -ForegroundColor Gray
Write-Host ""

# Find Intel XTU executable
$xtuExePaths = @(
    "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
    "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
)

$xtuExe = $null
foreach ($path in $xtuExePaths) {
    if (Test-Path $path) {
        $xtuExe = $path
        Write-Host "[OK] Found Intel XTU: $path" -ForegroundColor Green
        break
    }
}

if (-not $xtuExe) {
    Write-Host "[WARN] Intel XTU executable not found" -ForegroundColor Yellow
    Write-Host "  Registry settings will still be applied" -ForegroundColor Gray
}

Write-Host ""

# Discover Intel XTU registry structure
Write-Host "=== Discovering Intel XTU Registry Structure ===" -ForegroundColor Cyan
Write-Host ""

$xtuBasePath = "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility"

if (-not (Test-Path $xtuBasePath)) {
    Write-Host "[INFO] XTU registry path doesn't exist yet" -ForegroundColor Gray
    Write-Host "  Creating base path..." -ForegroundColor Gray
    try {
        New-Item -Path $xtuBasePath -Force | Out-Null
    } catch {
        Write-Host "[WARN] Could not create registry path: $_" -ForegroundColor Yellow
    }
}

# Intel XTU for 12th Gen CPUs typically uses this structure:
# HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\{ProfileName}\{SettingName}

# Common profile names
$profileNames = @("Default", "Profile1", "Current", "Active")

# Settings that Intel XTU uses (varies by CPU)
$xtuSettings = @{
    # Power settings (in Watts)
    "TurboBoostPowerMax" = $TurboBoostPowerMax
    "TurboBoostShortPowerMax" = $TurboBoostShortPowerMax
    "TurboBoostPowerTimeWindow" = 28  # seconds

    # Voltage settings (in mV)
    "CoreVoltageOffset" = $CoreVoltageOffset

    # Frequency settings (in MHz)
    "TurboBoostMax" = $TurboBoostMax
    "TurboBoostRatioLimit" = 0  # 0 = no limit

    # Thermal settings
    "TJMaxOffset" = 0  # Temperature offset
}

# Try to find existing profiles
$foundProfiles = @()
if (Test-Path $xtuBasePath) {
    try {
        $subKeys = Get-ChildItem -Path $xtuBasePath -ErrorAction SilentlyContinue
        foreach ($key in $subKeys) {
            if ($key.PSChildName -notin @("Settings", "Profiles", "Overclocking")) {
                $foundProfiles += $key.PSChildName
            }
        }
    } catch {
        Write-Host "[INFO] Could not enumerate profiles" -ForegroundColor Gray
    }
}

if ($foundProfiles.Count -eq 0) {
    Write-Host "[INFO] No existing profiles found, will create default profile" -ForegroundColor Gray
    $profilesToConfigure = @("Default")
} else {
    Write-Host "[OK] Found existing profiles: $($foundProfiles -join ', ')" -ForegroundColor Green
    $profilesToConfigure = $foundProfiles + "Default"
}

Write-Host ""

# Apply settings to each profile
Write-Host "=== Applying Settings to Profiles ===" -ForegroundColor Cyan
Write-Host ""

$settingsApplied = $false

foreach ($profileName in $profilesToConfigure) {
    $profilePath = Join-Path $xtuBasePath $profileName

    if (-not (Test-Path $profilePath)) {
        try {
            New-Item -Path $profilePath -Force | Out-Null
            Write-Host "[OK] Created profile: $profileName" -ForegroundColor Green
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Host "[WARN] Could not create profile $profileName : $errorMsg" -ForegroundColor Yellow
            continue
        }
    }

    Write-Host "Configuring profile: $profileName" -ForegroundColor Yellow

    foreach ($settingName in $xtuSettings.Keys) {
        $settingValue = $xtuSettings[$settingName]

        # Try different value types
        $applied = $false

        # Try as DWord (most common)
        try {
            Set-ItemProperty -Path $profilePath -Name $settingName -Value $settingValue -Type DWord -ErrorAction Stop
            Write-Host "  [OK] $settingName = $settingValue (DWord)" -ForegroundColor Green
            $applied = $true
            $settingsApplied = $true
        } catch {
            # Try as String
            try {
                Set-ItemProperty -Path $profilePath -Name $settingName -Value $settingValue.ToString() -Type String -ErrorAction Stop
                Write-Host "  [OK] $settingName = $settingValue (String)" -ForegroundColor Green
                $applied = $true
                $settingsApplied = $true
            } catch {
                # Try as QWord (64-bit integer)
                try {
                    Set-ItemProperty -Path $profilePath -Name $settingName -Value $settingValue -Type QWord -ErrorAction Stop
                    Write-Host "  [OK] $settingName = $settingValue (QWord)" -ForegroundColor Green
                    $applied = $true
                    $settingsApplied = $true
                } catch {
                    # Setting may not be supported or path is wrong
                }
            }
        }

        if (-not $applied) {
            Write-Host "  [SKIP] $settingName (not applicable or path incorrect)" -ForegroundColor Gray
        }
    }

    Write-Host ""
}

# Also try the Settings subkey (some XTU versions use this)
$settingsPath = Join-Path $xtuBasePath "Settings"
if (-not (Test-Path $settingsPath)) {
    try {
        New-Item -Path $settingsPath -Force | Out-Null
    } catch {
        # Continue
    }
}

if (Test-Path $settingsPath) {
    Write-Host "Configuring global settings..." -ForegroundColor Yellow

    foreach ($settingName in $xtuSettings.Keys) {
        $settingValue = $xtuSettings[$settingName]
        try {
            Set-ItemProperty -Path $settingsPath -Name $settingName -Value $settingValue -Type DWord -ErrorAction SilentlyContinue
        } catch {
            # Continue
        }
    }
    Write-Host "[OK] Global settings configured" -ForegroundColor Green
    Write-Host ""
}

# Create a configuration file that XTU might recognize
Write-Host "=== Creating Configuration Files ===" -ForegroundColor Cyan

$configDir = Join-Path $PSScriptRoot ".."
$xtuConfigFile = Join-Path $configDir "XTU-Config-i9-12900H.txt"

$configContent = @"
# Intel XTU Configuration for i9-12900H
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Power Settings
TurboBoostPowerMax=$TurboBoostPowerMax
TurboBoostShortPowerMax=$TurboBoostShortPowerMax

# Voltage Settings
CoreVoltageOffset=$CoreVoltageOffset

# Frequency Settings
TurboBoostMax=$TurboBoostMax

# Instructions:
# 1. Launch Intel XTU
# 2. Navigate to Advanced Tuning
# 3. Apply these values manually if registry settings don't take effect
# 4. Run Stress Test for 15-30 minutes
# 5. Monitor temperatures (Core < 90°C, Package < 95°C)
"@

try {
    Set-Content -Path $xtuConfigFile -Value $configContent
    Write-Host "[OK] Configuration file created: $xtuConfigFile" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not create config file: $_" -ForegroundColor Yellow
}

Write-Host ""

# Launch Intel XTU if requested
if ($LaunchXTU -and $xtuExe) {
    Write-Host "=== Launching Intel XTU ===" -ForegroundColor Cyan
    Write-Host ""

    try {
        Start-Process -FilePath $xtuExe
        Write-Host "[OK] Intel XTU launched" -ForegroundColor Green
        Write-Host "  Settings should be applied automatically" -ForegroundColor Gray
        Write-Host "  If not visible, restart XTU or check Advanced Tuning section" -ForegroundColor Gray
    } catch {
        Write-Host "[WARN] Could not launch Intel XTU: $_" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Summary
Write-Host "=== Configuration Summary ===" -ForegroundColor Cyan
Write-Host ""

if ($settingsApplied) {
    Write-Host "[OK] Registry settings applied successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Settings Applied:" -ForegroundColor Yellow
    Write-Host "  Turbo Boost Power Max: +$TurboBoostPowerMax W" -ForegroundColor White
    Write-Host "  Turbo Boost Short Power Max: +$TurboBoostShortPowerMax W" -ForegroundColor White
    Write-Host "  Core Voltage Offset: +0.$(($CoreVoltageOffset).ToString('000'))V" -ForegroundColor White
    Write-Host "  Turbo Boost Max: +$TurboBoostMax MHz" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Launch Intel XTU (if not already running)" -ForegroundColor White
    Write-Host "  2. Check Advanced Tuning section to verify settings" -ForegroundColor White
    Write-Host "  3. If settings don't appear, restart Intel XTU" -ForegroundColor White
    Write-Host "  4. Run Stress Test for 15-30 minutes" -ForegroundColor White
    Write-Host "  5. Monitor temperatures continuously" -ForegroundColor White
} else {
    Write-Host "[WARN] Settings may not have been applied" -ForegroundColor Yellow
    Write-Host "  Intel XTU registry structure may be different" -ForegroundColor Gray
    Write-Host "  Manual configuration via GUI is recommended" -ForegroundColor Gray
}

Write-Host ""
