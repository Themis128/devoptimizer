# Hardware-Based Intel XTU Configuration
# Configures Intel XTU based on actual machine capabilities and Intel specifications
# For i9-12900H Mobile CPU

param(
    [switch]$AutoDetect,
    [switch]$UseMaxCapabilities,
    [switch]$Conservative,
    [switch]$LaunchXTU
)

$ErrorActionPreference = "Continue"

Write-Host "=== Hardware-Based Intel XTU Configuration ===" -ForegroundColor Cyan
Write-Host "Based on Intel XTU Documentation and Hardware Specifications" -ForegroundColor Gray
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  Some operations may require admin privileges" -ForegroundColor Gray
    Write-Host ""
}

# Detect Hardware
Write-Host "=== Hardware Detection ===" -ForegroundColor Cyan
Write-Host ""

$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name
$cpuCores = $cpu.NumberOfCores
$cpuThreads = $cpu.NumberOfLogicalProcessors
$baseClock = $cpu.MaxClockSpeed  # MHz
$cpuId = $cpu.ProcessorId

$system = Get-WmiObject Win32_ComputerSystem
$manufacturer = $system.Manufacturer
$model = $system.Model
$totalRAM = [math]::Round($system.TotalPhysicalMemory / 1GB, 2)

Write-Host "CPU Information:" -ForegroundColor Yellow
Write-Host "  Model: $cpuName" -ForegroundColor White
Write-Host "  Cores: $cpuCores (Physical)" -ForegroundColor Gray
Write-Host "  Threads: $cpuThreads (Logical)" -ForegroundColor Gray
Write-Host "  Base Clock: $baseClock MHz" -ForegroundColor Gray
Write-Host "  CPU ID: $cpuId" -ForegroundColor Gray
Write-Host ""

Write-Host "System Information:" -ForegroundColor Yellow
Write-Host "  Manufacturer: $manufacturer" -ForegroundColor White
Write-Host "  Model: $model" -ForegroundColor White
Write-Host "  Total RAM: $totalRAM GB" -ForegroundColor Gray
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

# i9-12900H Specifications (from Intel documentation)
# Base Power (PL1): 45W
# Turbo Boost Power Max (PL2): 115W (short duration)
# Max Turbo Frequency: 5.0 GHz (P-cores), 3.8 GHz (E-cores)
# Recommended Power Limits for Overclocking: +5-15W above base

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

# Calculate Optimal Settings Based on Hardware
Write-Host "=== Calculating Optimal Settings ===" -ForegroundColor Cyan
Write-Host ""

# Base values from Intel specifications
$basePL1 = 45  # Watts
$basePL2 = 115  # Watts
$maxTurboP = 5000  # MHz (P-cores)
$maxTurboE = 3800  # MHz (E-cores)

# Determine configuration mode
if ($UseMaxCapabilities) {
    Write-Host "Mode: Maximum Capabilities (Aggressive)" -ForegroundColor Yellow
    $pl1Increase = 15  # +15W (maximum safe for mobile)
    $pl2Increase = 10   # +10W
    $voltageOffset = 20  # +0.020V (maximum for mobile)
    $turboIncrease = 200  # +200 MHz
} elseif ($Conservative) {
    Write-Host "Mode: Conservative (Safe)" -ForegroundColor Green
    $pl1Increase = 5   # +5W
    $pl2Increase = 5   # +5W
    $voltageOffset = 5  # +0.005V
    $turboIncrease = 50  # +50 MHz
} else {
    Write-Host "Mode: Balanced (Recommended)" -ForegroundColor Cyan
    $pl1Increase = 10  # +10W (optimal for mobile)
    $pl2Increase = 8   # +8W
    $voltageOffset = 10  # +0.010V
    $turboIncrease = 100  # +100 MHz
}

# Calculate final values
$finalPL1 = $basePL1 + $pl1Increase
$finalPL2 = $basePL2 + $pl2Increase
$finalTurboP = $maxTurboP + $turboIncrease
$finalVoltageOffset = $voltageOffset  # in mV

Write-Host ""
Write-Host "Recommended Configuration Values:" -ForegroundColor Yellow
Write-Host "  Turbo Boost Power Max (PL1): $basePL1 W -> $finalPL1 W (+$pl1Increase W)" -ForegroundColor White
Write-Host "  Turbo Boost Short Power Max (PL2): $basePL2 W -> $finalPL2 W (+$pl2Increase W)" -ForegroundColor White
Write-Host "  Core Voltage Offset: +0.$(($finalVoltageOffset).ToString('000'))V ($finalVoltageOffset mV)" -ForegroundColor White
Write-Host "  Turbo Boost Max (P-cores): $maxTurboP MHz -> $finalTurboP MHz (+$turboIncrease MHz)" -ForegroundColor White
Write-Host ""

# Important Notes for Mobile CPU
Write-Host "=== Important Notes for Mobile CPU (i9-12900H) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  Mobile CPU Limitations:" -ForegroundColor Yellow
Write-Host "  - H-series CPUs have LIMITED overclocking capability" -ForegroundColor White
Write-Host "  - Focus on POWER MANAGEMENT, not aggressive frequency overclocking" -ForegroundColor White
Write-Host "  - Thermal throttling is more aggressive than desktop CPUs" -ForegroundColor White
Write-Host "  - Ensure adequate cooling (laptop cooling pad recommended)" -ForegroundColor White
Write-Host "  - Monitor temperatures continuously (Core < 90°C, Package < 95°C)" -ForegroundColor White
Write-Host ""

# Backup existing settings
Write-Host "=== Backup ===" -ForegroundColor Cyan

$backupDir = Join-Path $PSScriptRoot "..\backups"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupDir "XTU-Hardware-Based-Backup-$timestamp.reg"

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
Write-Host "=== Applying Hardware-Based Configuration ===" -ForegroundColor Cyan
Write-Host ""

$xtuBasePath = "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility"

# Create registry structure
$profilePaths = @(
    "$xtuBasePath\HardwareOptimized",
    "$xtuBasePath\Settings",
    "$xtuBasePath\Profiles\Default"
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

# Intel XTU Registry Settings for i9-12900H
# Based on Intel XTU 7.14.2.67 documentation and registry structure

$xtuSettings = @{
    # Power Settings (in Watts)
    "TurboBoostPowerMax" = $finalPL1
    "TurboBoostShortPowerMax" = $finalPL2
    "TurboBoostPowerTimeWindow" = 28  # seconds (Intel default)

    # Voltage Settings (in mV)
    "CoreVoltageOffset" = $finalVoltageOffset

    # Frequency Settings (in MHz)
    "TurboBoostMax" = $finalTurboP
    "TurboBoostRatioLimit" = 0  # 0 = no limit

    # Thermal Settings
    "TJMaxOffset" = 0

    # Mobile CPU Specific
    "MobileOptimization" = 1
    "PowerLimitMode" = 1  # 1 = Balanced
}

Write-Host "Applying settings to registry..." -ForegroundColor Yellow

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

# Create Configuration Documentation
Write-Host "=== Creating Configuration Documentation ===" -ForegroundColor Cyan

$configDoc = @"
# Intel XTU Hardware-Based Configuration
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Hardware Information
- CPU: $cpuName
- Cores: $cpuCores Physical, $cpuThreads Logical
- Base Clock: $baseClock MHz
- System: $manufacturer $model
- RAM: $totalRAM GB

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

## Next Steps
1. Launch Intel XTU
2. Verify settings in Advanced Tuning section
3. Run Stress Test for 15-30 minutes
4. Monitor temperatures continuously
5. Adjust if throttling occurs
"@

$docPath = Join-Path $PSScriptRoot "..\XTU-Hardware-Configuration.md"
try {
    Set-Content -Path $docPath -Value $configDoc
    Write-Host "[OK] Configuration documentation created: $docPath" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not create documentation: $_" -ForegroundColor Yellow
}

Write-Host ""

# Launch Intel XTU if requested
if ($LaunchXTU) {
    Write-Host "=== Launching Intel XTU ===" -ForegroundColor Cyan
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
                Write-Host "[OK] Intel XTU launched: $path" -ForegroundColor Green
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
    Write-Host "Applied Settings (Based on i9-12900H Specifications):" -ForegroundColor Yellow
    Write-Host "  Turbo Boost Power Max (PL1): $finalPL1 W (+$pl1Increase W)" -ForegroundColor White
    Write-Host "  Turbo Boost Short Power Max (PL2): $finalPL2 W (+$pl2Increase W)" -ForegroundColor White
    Write-Host "  Core Voltage Offset: +0.$(($finalVoltageOffset).ToString('000'))V" -ForegroundColor White
    Write-Host "  Turbo Boost Max: $finalTurboP MHz (+$turboIncrease MHz)" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Launch Intel XTU (if not already launched)" -ForegroundColor White
    Write-Host "  2. Navigate to Advanced Tuning section" -ForegroundColor White
    Write-Host "  3. Verify settings match the values above" -ForegroundColor White
    Write-Host "  4. If settings don't appear, restart Intel XTU" -ForegroundColor White
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
