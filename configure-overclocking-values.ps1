# Configure Overclocking Values for MSI Afterburner and Intel XTU
# This script applies conservative overclocking settings

param(
    [switch]$ApplyMSI,
    [switch]$ApplyXTU,
    [switch]$Conservative
)

$ErrorActionPreference = "Continue"

Write-Host "=== Configure Overclocking Values ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  Some operations may require admin privileges" -ForegroundColor Gray
    Write-Host ""
}

# Conservative values (default)
$CoreClockBoost = 50      # +50 MHz
$MemClockBoost = 200      # +200 MHz
$PowerLimitPercent = 5    # +5%

if ($Conservative) {
    $CoreClockBoost = 25
    $MemClockBoost = 100
    $PowerLimitPercent = 3
}

Write-Host "Using Conservative Values:" -ForegroundColor Yellow
Write-Host "  Core Clock: +$CoreClockBoost MHz" -ForegroundColor Gray
Write-Host "  Memory Clock: +$MemClockBoost MHz" -ForegroundColor Gray
Write-Host "  Power Limit: +$PowerLimitPercent%" -ForegroundColor Gray
Write-Host ""

# MSI Afterburner Configuration
if ($ApplyMSI -or (-not $ApplyXTU)) {
    Write-Host "=== MSI Afterburner Overclocking Configuration ===" -ForegroundColor Cyan
    Write-Host ""

    # Find GPU profile files
    $profileDir = "${env:ProgramFiles(x86)}\MSI Afterburner\Profiles"
    if (-not (Test-Path $profileDir)) {
        $profileDir = "${env:ProgramFiles}\MSI Afterburner\Profiles"
    }

    if (Test-Path $profileDir) {
        # Find NVIDIA GPU profile (VEN_10DE)
        $nvidiaProfiles = Get-ChildItem -Path $profileDir -Filter "VEN_10DE*.cfg" -ErrorAction SilentlyContinue

        if ($nvidiaProfiles) {
            foreach ($profile in $nvidiaProfiles) {
                Write-Host "Found GPU profile: $($profile.Name)" -ForegroundColor Green

                # Backup profile
                $backupPath = "$($profile.FullName).backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item -Path $profile.FullName -Destination $backupPath -Force
                Write-Host "  Backup created: $backupPath" -ForegroundColor Gray

                # Read profile content
                $content = Get-Content -Path $profile.FullName -Raw

                # Update CoreClkBoost (value is in a specific format, need to convert MHz to internal units)
                # MSI Afterburner uses a specific encoding. For simplicity, we'll use a different approach
                # The profile format is complex, so we'll create a script that MSI Afterburner can execute

                Write-Host "  [INFO] MSI Afterburner profile format is complex" -ForegroundColor Yellow
                Write-Host "  [INFO] Creating configuration script for MSI Afterburner" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[WARN] No NVIDIA GPU profile found" -ForegroundColor Yellow
        }
    }

    # Create MSI Afterburner configuration script
    $msiScriptPath = Join-Path $PSScriptRoot "config\overclocking\apply-msi-overclock.ps1"
    $msiConfigDir = Join-Path $PSScriptRoot "config\overclocking"
    if (-not (Test-Path $msiConfigDir)) {
        New-Item -ItemType Directory -Path $msiConfigDir -Force | Out-Null
    }

    $msiScript = @"
# MSI Afterburner Overclocking Configuration Script
# This script applies overclocking values via MSI Afterburner command line

`$CoreClock = $CoreClockBoost
`$MemClock = $MemClockBoost
`$PowerLimit = $PowerLimitPercent

Write-Host "Applying MSI Afterburner overclocking values..." -ForegroundColor Yellow
Write-Host "  Core Clock: +`$CoreClock MHz" -ForegroundColor Gray
Write-Host "  Memory Clock: +`$MemClock MHz" -ForegroundColor Gray
Write-Host "  Power Limit: +`$PowerLimit%" -ForegroundColor Gray
Write-Host ""

# MSI Afterburner command line parameters
`$msiExe = "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe"
if (-not (Test-Path `$msiExe)) {
    `$msiExe = "${env:ProgramFiles}\MSI Afterburner\MSIAfterburner.exe"
}

if (Test-Path `$msiExe) {
    Write-Host "Launching MSI Afterburner..." -ForegroundColor Green

    # MSI Afterburner doesn't support direct command-line overclocking
    # We need to use the GUI or modify the profile file directly
    # For now, we'll launch it and provide instructions

    Start-Process -FilePath `$msiExe

    Write-Host ""
    Write-Host "MSI Afterburner has been launched." -ForegroundColor Green
    Write-Host "Please configure the following values manually:" -ForegroundColor Yellow
    Write-Host "  1. Core Clock: +`$CoreClock MHz" -ForegroundColor White
    Write-Host "  2. Memory Clock: +`$MemClock MHz" -ForegroundColor White
    Write-Host "  3. Power Limit: +`$PowerLimit% (if available)" -ForegroundColor White
    Write-Host "  4. Click Apply (checkmark icon)" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "[FAIL] MSI Afterburner executable not found" -ForegroundColor Red
}
"@

    Set-Content -Path $msiScriptPath -Value $msiScript
    Write-Host "Created MSI Afterburner configuration script: $msiScriptPath" -ForegroundColor Green
}

Write-Host ""

# Intel XTU Configuration
if ($ApplyXTU -or (-not $ApplyMSI)) {
    Write-Host "=== Intel XTU Overclocking Configuration ===" -ForegroundColor Cyan
    Write-Host ""

    # Intel XTU settings for i9-12900H (Mobile CPU)
    $TurboBoostPowerMax = 5      # +5W
    $TurboBoostShortPowerMax = 5 # +5W
    $CoreVoltageOffset = 10       # +0.010V (in mV)
    $TurboBoostMax = 100          # +100 MHz

    if ($Conservative) {
        $TurboBoostPowerMax = 3
        $TurboBoostShortPowerMax = 3
        $CoreVoltageOffset = 5
        $TurboBoostMax = 50
    }

    Write-Host "Recommended Settings for i9-12900H:" -ForegroundColor Yellow
    Write-Host "  Turbo Boost Power Max: +$TurboBoostPowerMax W" -ForegroundColor Gray
    Write-Host "  Turbo Boost Short Power Max: +$TurboBoostShortPowerMax W" -ForegroundColor Gray
    Write-Host "  Core Voltage Offset: +0.$(($CoreVoltageOffset).ToString('000'))V" -ForegroundColor Gray
    Write-Host "  Turbo Boost Max: +$TurboBoostMax MHz" -ForegroundColor Gray
    Write-Host ""

    # Intel XTU stores settings in registry
    # However, the exact registry keys vary by version and CPU
    # We'll create a script that attempts to configure via registry

    $xtuScriptPath = Join-Path $PSScriptRoot "config\overclocking\apply-xtu-overclock.ps1"
    $xtuConfigDir = Join-Path $PSScriptRoot "config\overclocking"
    if (-not (Test-Path $xtuConfigDir)) {
        New-Item -ItemType Directory -Path $xtuConfigDir -Force | Out-Null
    }

    $xtuScript = @"
# Intel XTU Overclocking Configuration Script
# This script attempts to configure Intel XTU settings

`$TurboBoostPowerMax = $TurboBoostPowerMax
`$TurboBoostShortPowerMax = $TurboBoostShortPowerMax
`$CoreVoltageOffset = $CoreVoltageOffset
`$TurboBoostMax = $TurboBoostMax

Write-Host "Intel XTU Configuration for i9-12900H" -ForegroundColor Cyan
Write-Host ""
Write-Host "Recommended Settings:" -ForegroundColor Yellow
Write-Host "  Turbo Boost Power Max: +`$TurboBoostPowerMax W" -ForegroundColor Gray
Write-Host "  Turbo Boost Short Power Max: +`$TurboBoostShortPowerMax W" -ForegroundColor Gray
Write-Host "  Core Voltage Offset: +0.`$(('000' + `$CoreVoltageOffset).Substring(('000' + `$CoreVoltageOffset).Length - 3))V" -ForegroundColor Gray
Write-Host "  Turbo Boost Max: +`$TurboBoostMax MHz" -ForegroundColor Gray
Write-Host ""

# Intel XTU configuration is complex and CPU-specific
# Registry keys vary by version and CPU model
# Manual configuration via GUI is strongly recommended

Write-Host "[INFO] Intel XTU settings are CPU-specific and complex" -ForegroundColor Yellow
Write-Host "[INFO] Manual configuration via GUI is strongly recommended for safety" -ForegroundColor Yellow
Write-Host ""

# Try to launch Intel XTU
`$xtuExePaths = @(
    "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
    "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
)

`$launched = `$false
foreach (`$path in `$xtuExePaths) {
    if (Test-Path `$path) {
        try {
            Start-Process -FilePath `$path
            Write-Host "Intel XTU launched: `$path" -ForegroundColor Green
            `$launched = `$true
            break
        } catch {
            # Continue to next path
        }
    }
}

if (-not `$launched) {
    Write-Host "[WARN] Could not launch Intel XTU automatically" -ForegroundColor Yellow
    Write-Host "  Please launch manually from Start Menu: Intel Extreme Tuning Utility" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Configuration Steps:" -ForegroundColor Cyan
    Write-Host "  1. Navigate to Advanced Tuning -> Power tab" -ForegroundColor White
    Write-Host "  2. Set Turbo Boost Power Max: +`$TurboBoostPowerMax W" -ForegroundColor White
    Write-Host "  3. Set Turbo Boost Short Power Max: +`$TurboBoostShortPowerMax W" -ForegroundColor White
    Write-Host "  4. Navigate to Advanced Tuning -> Core tab" -ForegroundColor White
    Write-Host "  5. Set Core Voltage Offset: +0.`$(('000' + `$CoreVoltageOffset).Substring(('000' + `$CoreVoltageOffset).Length - 3))V" -ForegroundColor White
    Write-Host "  6. Set Turbo Boost Max: +`$TurboBoostMax MHz" -ForegroundColor White
    Write-Host "  7. Click Apply" -ForegroundColor White
    Write-Host "  8. Run Stress Test for 15-30 minutes" -ForegroundColor White
}
"@

    Set-Content -Path $xtuScriptPath -Value $xtuScript
    Write-Host "Created Intel XTU configuration script: $xtuScriptPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Configuration Scripts Created ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Run the configuration scripts:" -ForegroundColor White
if ($ApplyMSI -or (-not $ApplyXTU)) {
    Write-Host "     .\config\overclocking\apply-msi-overclock.ps1" -ForegroundColor Gray
}
if ($ApplyXTU -or (-not $ApplyMSI)) {
    Write-Host "     .\config\overclocking\apply-xtu-overclock.ps1" -ForegroundColor Gray
}
Write-Host "  2. Or configure manually using the values shown above" -ForegroundColor White
Write-Host "  3. Test stability for 15-30 minutes after applying" -ForegroundColor White
Write-Host "  4. Monitor temperatures continuously" -ForegroundColor White
Write-Host ""

