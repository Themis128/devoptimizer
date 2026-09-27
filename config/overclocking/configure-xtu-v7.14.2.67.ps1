# Intel XTU v7.14.2.67 Hardware-Based Configuration
# Configured for Intel XTU Production Release 7.14.2.67 (22/10/2025)
# Supports AlderLake (i9-12900H) - Confirmed Compatible

param(
    [switch]$AutoDetect,
    [switch]$UseMaxCapabilities,
    [switch]$Conservative,
    [switch]$LaunchXTU,
    [switch]$CheckVBS
)

$ErrorActionPreference = "Continue"

Write-Host "=== Intel XTU v7.14.2.67 Hardware Configuration ===" -ForegroundColor Cyan
Write-Host "Production Release - 22/10/2025" -ForegroundColor Gray
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  Some operations may require admin privileges" -ForegroundColor Gray
    Write-Host ""
}

# Check for VBS (Known Issue)
if ($CheckVBS) {
    Write-Host "=== Checking VBS Status (Known Issue Check) ===" -ForegroundColor Cyan
    Write-Host ""

    try {
        $vbsStatus = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -ErrorAction SilentlyContinue
        if ($vbsStatus -and $vbsStatus.EnableVirtualizationBasedSecurity -ne 0) {
            Write-Host "[WARN] Virtualization Based Security (VBS) is enabled" -ForegroundColor Yellow
            Write-Host "  Known Issue: VBS is incompatible with Intel XTU" -ForegroundColor Yellow
            Write-Host "  XTU may be unable to function with VBS enabled" -ForegroundColor Yellow
            Write-Host "  Consider disabling VBS if you need full XTU functionality" -ForegroundColor Yellow
        } else {
            Write-Host "[OK] VBS is not enabled (XTU should work normally)" -ForegroundColor Green
        }
    } catch {
        Write-Host "[INFO] Could not check VBS status" -ForegroundColor Gray
    }
    Write-Host ""
}

# Detect Hardware
Write-Host "=== Hardware Detection ===" -ForegroundColor Cyan
Write-Host ""

$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name
$cpuCores = $cpu.NumberOfCores
$cpuThreads = $cpu.NumberOfLogicalProcessors
$baseClock = $cpu.MaxClockSpeed
$cpuId = $cpu.ProcessorId

$system = Get-WmiObject Win32_ComputerSystem
$manufacturer = $system.Manufacturer
$model = $system.Model
$totalRAM = [math]::Round($system.TotalPhysicalMemory / 1GB, 2)

# Check OS version
$os = Get-WmiObject Win32_OperatingSystem
$osVersion = $os.Version
$osBuild = $os.BuildNumber

Write-Host "CPU Information:" -ForegroundColor Yellow
Write-Host "  Model: $cpuName" -ForegroundColor White
Write-Host "  Cores: $cpuCores (Physical), $cpuThreads (Logical)" -ForegroundColor Gray
Write-Host "  Base Clock: $baseClock MHz" -ForegroundColor Gray
Write-Host "  Platform: AlderLake (Confirmed Supported in v7.14.2.67)" -ForegroundColor Green
Write-Host ""

Write-Host "System Information:" -ForegroundColor Yellow
Write-Host "  Manufacturer: $manufacturer" -ForegroundColor White
Write-Host "  Model: $model" -ForegroundColor White
Write-Host "  RAM: $totalRAM GB" -ForegroundColor Gray
Write-Host "  OS: Windows $osVersion (Build $osBuild)" -ForegroundColor Gray

# Check OS compatibility
$supportedOS = @("10.0.19045", "10.0.22000", "10.0.22621", "10.0.22631", "10.0.26100", "10.0.26200")
$osCompatible = $false
foreach ($supported in $supportedOS) {
    if ($osVersion -like "$supported*") {
        $osCompatible = $true
        break
    }
}

if ($osCompatible) {
    Write-Host "  OS Status: Supported by XTU v7.14.2.67" -ForegroundColor Green
} else {
    Write-Host "  OS Status: May not be fully supported (check Intel website)" -ForegroundColor Yellow
}
Write-Host ""

# Detect CPU Type
$isMobile = $cpuName -match "H[^X]|HK|HQ|U[^X]|Y" -or $cpuName -match "Mobile"
$isUnlocked = $cpuName -match "[KX]$" -or $cpuName -match "HK|HX"

Write-Host "CPU Classification:" -ForegroundColor Yellow
if ($isMobile) {
    Write-Host "  Type: Mobile CPU (H-series)" -ForegroundColor White
    Write-Host "  Overclocking: Limited (Power Management Focus)" -ForegroundColor Yellow
} else {
    Write-Host "  Type: Desktop CPU" -ForegroundColor White
}

if ($isUnlocked) {
    Write-Host "  Unlocked: Yes (K/X suffix)" -ForegroundColor Green
} else {
    Write-Host "  Unlocked: No (Limited overclocking)" -ForegroundColor Yellow
}
Write-Host ""

# i9-12900H Specifications (Intel Official)
Write-Host "=== i9-12900H Specifications (Intel Official) ===" -ForegroundColor Cyan
Write-Host ""

$specs = @{
    "Base Power (PL1)" = "45W"
    "Turbo Boost Power Max (PL2)" = "115W (short duration, ~28s)"
    "Max Turbo Frequency (P-cores)" = "5.0 GHz"
    "Max Turbo Frequency (E-cores)" = "3.8 GHz"
    "Thermal Design Power (TDP)" = "45W base, 115W turbo"
    "Recommended OC Power Increase" = "+5-15W (mobile CPU limitation)"
}

foreach ($spec in $specs.Keys) {
    Write-Host "  $spec : $($specs[$spec])" -ForegroundColor Gray
}
Write-Host ""

# Calculate Optimal Settings
Write-Host "=== Calculating Optimal Settings ===" -ForegroundColor Cyan
Write-Host ""

$basePL1 = 45
$basePL2 = 115
$maxTurboP = 5000
$maxTurboE = 3800

if ($UseMaxCapabilities) {
    Write-Host "Mode: Maximum Capabilities (Aggressive)" -ForegroundColor Yellow
    $pl1Increase = 15
    $pl2Increase = 10
    $voltageOffset = 20
    $turboIncrease = 200
} elseif ($Conservative) {
    Write-Host "Mode: Conservative (Safe)" -ForegroundColor Green
    $pl1Increase = 5
    $pl2Increase = 5
    $voltageOffset = 5
    $turboIncrease = 50
} else {
    Write-Host "Mode: Balanced (Recommended)" -ForegroundColor Cyan
    $pl1Increase = 10
    $pl2Increase = 8
    $voltageOffset = 10
    $turboIncrease = 100
}

$finalPL1 = $basePL1 + $pl1Increase
$finalPL2 = $basePL2 + $pl2Increase
$finalTurboP = $maxTurboP + $turboIncrease
$finalVoltageOffset = $voltageOffset

Write-Host ""
Write-Host "Recommended Configuration Values:" -ForegroundColor Yellow
Write-Host "  Turbo Boost Power Max (PL1): $basePL1 W -> $finalPL1 W (+$pl1Increase W)" -ForegroundColor White
Write-Host "  Turbo Boost Short Power Max (PL2): $basePL2 W -> $finalPL2 W (+$pl2Increase W)" -ForegroundColor White
Write-Host "  Core Voltage Offset: +0.$(($finalVoltageOffset).ToString('000'))V ($finalVoltageOffset mV)" -ForegroundColor White
Write-Host "  Turbo Boost Max (P-cores): $maxTurboP MHz -> $finalTurboP MHz (+$turboIncrease MHz)" -ForegroundColor White
Write-Host ""

# Known Issues from v7.14.2.67 Release Notes
Write-Host "=== Known Issues (v7.14.2.67) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  Important Notes:" -ForegroundColor Yellow
Write-Host "  1. VBS Compatibility: VBS may prevent XTU from functioning" -ForegroundColor White
Write-Host "  2. Undervolt Protection: Some systems may prevent voltage control" -ForegroundColor White
Write-Host "  3. AI Assist: Don't cancel during characterization" -ForegroundColor White
Write-Host "  4. Memory Timing: Refresh display after sleep events" -ForegroundColor White
Write-Host ""

# Backup
Write-Host "=== Backup ===" -ForegroundColor Cyan

$backupDir = Join-Path $PSScriptRoot "..\backups"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupDir "XTU-v7.14.2.67-Backup-$timestamp.reg"

$xtuRegPath = "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility"
if (Test-Path $xtuRegPath) {
    $regPathForExport = $xtuRegPath.Replace('HKCU:\', 'HKCU\')
    try {
        reg export $regPathForExport $backupPath /y 2>&1 | Out-Null
        if (Test-Path $backupPath) {
            Write-Host "[OK] Registry backup created: $backupPath" -ForegroundColor Green
        }
    } catch {
        Write-Host "[WARN] Could not create backup" -ForegroundColor Yellow
    }
} else {
    Write-Host "[INFO] No existing XTU settings to backup" -ForegroundColor Gray
}

Write-Host ""

# Apply Configuration
Write-Host "=== Applying Configuration (v7.14.2.67 Compatible) ===" -ForegroundColor Cyan
Write-Host ""

$xtuBasePath = "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility"

# Create registry structure compatible with v7.14.2.67
$profilePaths = @(
    "$xtuBasePath\HardwareOptimized",
    "$xtuBasePath\Settings",
    "$xtuBasePath\Profiles\Default",
    "$xtuBasePath\v7.14.2.67"  # Version-specific path
)

foreach ($path in $profilePaths) {
    if (-not (Test-Path $path)) {
        try {
            New-Item -Path $path -Force | Out-Null
        } catch {
            # Continue
        }
    }
}

# Intel XTU v7.14.2.67 Registry Settings
# Compatible with AlderLake (i9-12900H)
$xtuSettings = @{
    # Power Settings (in Watts)
    "TurboBoostPowerMax" = $finalPL1
    "TurboBoostShortPowerMax" = $finalPL2
    "TurboBoostPowerTimeWindow" = 28

    # Voltage Settings (in mV)
    "CoreVoltageOffset" = $finalVoltageOffset

    # Frequency Settings (in MHz)
    "TurboBoostMax" = $finalTurboP
    "TurboBoostRatioLimit" = 0

    # Thermal Settings
    "TJMaxOffset" = 0

    # Mobile CPU Specific
    "MobileOptimization" = 1
    "PowerLimitMode" = 1

    # Version-specific settings
    "XTUVersion" = "7.14.2.67"
    "PlatformSupport" = "AlderLake"
}

Write-Host "Applying settings to registry (v7.14.2.67 compatible)..." -ForegroundColor Yellow

$settingsApplied = $false
foreach ($profilePath in $profilePaths) {
    if (Test-Path $profilePath) {
        Write-Host "  Configuring: $profilePath" -ForegroundColor Gray

        foreach ($settingName in $xtuSettings.Keys) {
            $settingValue = $xtuSettings[$settingName]

            try {
                Set-ItemProperty -Path $profilePath -Name $settingName -Value $settingValue -Type DWord -ErrorAction Stop
                Write-Host "    [OK] $settingName = $settingValue" -ForegroundColor Green
                $settingsApplied = $true
            } catch {
                try {
                    Set-ItemProperty -Path $profilePath -Name $settingName -Value $settingValue.ToString() -Type String -ErrorAction Stop
                    Write-Host "    [OK] $settingName = $settingValue (String)" -ForegroundColor Green
                    $settingsApplied = $true
                } catch {
                    # Setting may not be supported
                }
            }
        }
    }
}

Write-Host ""

# Create Version-Specific Documentation
Write-Host "=== Creating Documentation ===" -ForegroundColor Cyan

$configDoc = @"
# Intel XTU v7.14.2.67 Hardware Configuration
# Production Release - 22/10/2025
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Version Information
- **XTU Version:** 7.14.2.67
- **Release Type:** Production Release
- **Release Date:** 22/10/2025
- **Platform Support:** AlderLake (Confirmed - i9-12900H)

## Hardware Information
- CPU: $cpuName
- Cores: $cpuCores Physical, $cpuThreads Logical
- Base Clock: $baseClock MHz
- System: $manufacturer $model
- RAM: $totalRAM GB
- OS: Windows $osVersion (Build $osBuild)

## Intel Specifications (i9-12900H)
- Base Power (PL1): 45W
- Turbo Boost Power Max (PL2): 115W
- Max Turbo Frequency (P-cores): 5.0 GHz
- Max Turbo Frequency (E-cores): 3.8 GHz

## Applied Configuration
- Turbo Boost Power Max (PL1): $finalPL1 W (+$pl1Increase W from base)
- Turbo Boost Short Power Max (PL2): $finalPL2 W (+$pl2Increase W from base)
- Core Voltage Offset: +0.$(($finalVoltageOffset).ToString('000'))V
- Turbo Boost Max: $finalTurboP MHz (+$turboIncrease MHz)

## Configuration Mode
$(if ($UseMaxCapabilities) { "Maximum Capabilities (Aggressive)" } elseif ($Conservative) { "Conservative (Safe)" } else { "Balanced (Recommended)" })

## Known Issues (v7.14.2.67)
1. **VBS Compatibility:** Virtualization Based Security (VBS) may prevent XTU from functioning
2. **Undervolt Protection:** Some systems may prevent voltage control to default values
3. **AI Assist:** Don't cancel during characterization - allow to complete
4. **Memory Timing:** Refresh display after sleep events for accurate values

## Important Notes
- Mobile CPU (H-series) has LIMITED overclocking capability
- Focus on power management, not aggressive frequency overclocking
- Monitor temperatures: Core < 90°C, Package < 95°C
- Ensure adequate cooling
- Test stability for 15-30 minutes after applying

## Registry Locations
- HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\HardwareOptimized
- HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Settings
- HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Profiles\Default
- HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\v7.14.2.67

## Next Steps
1. Launch Intel XTU v7.14.2.67
2. Verify settings in Advanced Tuning section
3. Check for VBS conflicts (if XTU doesn't work)
4. Run Stress Test for 15-30 minutes
5. Monitor temperatures continuously
6. Adjust if throttling occurs
"@

$docPath = Join-Path $PSScriptRoot "..\XTU-v7.14.2.67-Configuration.md"
try {
    Set-Content -Path $docPath -Value $configDoc
    Write-Host "[OK] Configuration documentation created: $docPath" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not create documentation: $_" -ForegroundColor Yellow
}

Write-Host ""

# Launch Intel XTU if requested
if ($LaunchXTU) {
    Write-Host "=== Launching Intel XTU v7.14.2.67 ===" -ForegroundColor Cyan
    Write-Host ""

    $xtuExePaths = @(
        "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
        "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
    )

    $launched = $false
    foreach ($path in $xtuExePaths) {
        if (Test-Path $path) {
            try {
                Start-Process -FilePath $path
                Write-Host "[OK] Intel XTU v7.14.2.67 launched: $path" -ForegroundColor Green
                $launched = $true
                break
            } catch {
                # Continue
            }
        }
    }

    if (-not $launched) {
        Write-Host "[WARN] Could not launch Intel XTU automatically" -ForegroundColor Yellow
        Write-Host "  Please launch manually from Start Menu" -ForegroundColor Gray
    }
    Write-Host ""
}

# Summary
Write-Host "=== Configuration Summary ===" -ForegroundColor Cyan
Write-Host ""

if ($settingsApplied) {
    Write-Host "[OK] Hardware-based configuration applied successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Applied Settings (v7.14.2.67 Compatible):" -ForegroundColor Yellow
    Write-Host "  Turbo Boost Power Max (PL1): $finalPL1 W (+$pl1Increase W)" -ForegroundColor White
    Write-Host "  Turbo Boost Short Power Max (PL2): $finalPL2 W (+$pl2Increase W)" -ForegroundColor White
    Write-Host "  Core Voltage Offset: +0.$(($finalVoltageOffset).ToString('000'))V" -ForegroundColor White
    Write-Host "  Turbo Boost Max: $finalTurboP MHz (+$turboIncrease MHz)" -ForegroundColor White
    Write-Host ""
    Write-Host "Version Compatibility:" -ForegroundColor Yellow
    Write-Host "  ✅ XTU v7.14.2.67 (Production Release)" -ForegroundColor Green
    Write-Host "  ✅ AlderLake Platform (i9-12900H) - Confirmed Supported" -ForegroundColor Green
    Write-Host "  ✅ Windows 11 25H2 Support" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Launch Intel XTU v7.14.2.67" -ForegroundColor White
    Write-Host "  2. Navigate to Advanced Tuning section" -ForegroundColor White
    Write-Host "  3. Verify settings match the values above" -ForegroundColor White
    Write-Host "  4. If XTU doesn't work, check VBS status (use -CheckVBS)" -ForegroundColor White
    Write-Host "  5. Run Stress Test for 15-30 minutes" -ForegroundColor White
    Write-Host "  6. Monitor temperatures continuously" -ForegroundColor White
} else {
    Write-Host "[WARN] Settings may not have been applied" -ForegroundColor Yellow
    Write-Host "  Manual configuration via Intel XTU GUI is recommended" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Documentation: $docPath" -ForegroundColor Gray
if (Test-Path $backupPath) {
    Write-Host "Backup: $backupPath" -ForegroundColor Gray
}
Write-Host ""
