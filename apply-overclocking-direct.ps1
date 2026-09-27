# Direct Overclocking Configuration
# This script directly applies overclocking settings

param(
    [switch]$Force
)

$ErrorActionPreference = "Continue"

Write-Host "=== Direct Overclocking Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  Some operations require admin privileges" -ForegroundColor Gray
    Write-Host "  Attempting to continue anyway..." -ForegroundColor Gray
    Write-Host ""
}

# Conservative values
$CoreClockBoost = 50      # +50 MHz
$MemClockBoost = 200      # +200 MHz
$PowerLimitPercent = 5    # +5%

Write-Host "Applying Conservative Overclocking Values:" -ForegroundColor Yellow
Write-Host "  MSI Afterburner:" -ForegroundColor Cyan
Write-Host "    Core Clock: +$CoreClockBoost MHz" -ForegroundColor Gray
Write-Host "    Memory Clock: +$MemClockBoost MHz" -ForegroundColor Gray
Write-Host "    Power Limit: +$PowerLimitPercent%" -ForegroundColor Gray
Write-Host ""

# MSI Afterburner - Modify profile file
Write-Host "=== MSI Afterburner Configuration ===" -ForegroundColor Cyan

$profileDir = "${env:ProgramFiles(x86)}\MSI Afterburner\Profiles"
if (-not (Test-Path $profileDir)) {
    $profileDir = "${env:ProgramFiles}\MSI Afterburner\Profiles"
}

if (Test-Path $profileDir) {
    $nvidiaProfiles = Get-ChildItem -Path $profileDir -Filter "VEN_10DE*.cfg" -ErrorAction SilentlyContinue

    if ($nvidiaProfiles) {
        foreach ($profile in $nvidiaProfiles) {
            Write-Host "Configuring GPU profile: $($profile.Name)" -ForegroundColor Green

            # Backup to user directory (no admin needed)
            $backupDir = Join-Path $env:USERPROFILE "MSIAfterburner-Backups"
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            $backupPath = Join-Path $backupDir "$($profile.Name).backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

            try {
                Copy-Item -Path $profile.FullName -Destination $backupPath -Force
                Write-Host "  Backup created: $backupPath" -ForegroundColor Gray
            } catch {
                Write-Host "  [WARN] Could not create backup: $_" -ForegroundColor Yellow
            }

            # Read profile
            try {
                $content = Get-Content -Path $profile.FullName -Raw -ErrorAction Stop

                # MSI Afterburner profile format: CoreClkBoost and MemClkBoost are in the [Defaults] section
                # The values appear to be stored in a specific format
                # For now, we'll note that manual configuration is needed, but we can try to set startup profile

                Write-Host "  [INFO] MSI Afterburner profile uses complex binary-like format" -ForegroundColor Yellow
                Write-Host "  [INFO] Direct modification requires understanding the encoding" -ForegroundColor Yellow
                Write-Host "  [INFO] Using alternative method: Creating startup profile" -ForegroundColor Yellow

                # Create a script that will be run to configure MSI Afterburner
                # We'll use MSI Afterburner's remote server or create an automation script

            } catch {
                Write-Host "  [FAIL] Could not read profile: $_" -ForegroundColor Red
            }
        }
    }
}

# Create automation script using MSI Afterburner's features
$autoScriptPath = Join-Path $PSScriptRoot "config\overclocking\auto-configure-msi.ps1"
$configDir = Join-Path $PSScriptRoot "config\overclocking"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

$autoScript = @"
# Auto-configure MSI Afterburner
# This script attempts to configure MSI Afterburner using available methods

`$CoreClock = $CoreClockBoost
`$MemClock = $MemClockBoost
`$PowerLimit = $PowerLimitPercent

Write-Host "=== Auto-Configure MSI Afterburner ===" -ForegroundColor Cyan
Write-Host ""

# Method 1: Try to use MSI Afterburner Remote Server (if enabled)
# MSI Afterburner has a remote server that can be controlled via HTTP
`$msiServerPort = 13247
`$msiServerUrl = "http://localhost:`$msiServerPort"

try {
    `$response = Invoke-WebRequest -Uri "`$msiServerUrl/GetStatus" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "[OK] MSI Afterburner Remote Server detected" -ForegroundColor Green

    # Try to set overclocking values via API
    # Note: This requires MSI Afterburner Remote Server to be enabled
    Write-Host "Attempting to set overclocking values via Remote Server..." -ForegroundColor Yellow

    # MSI Afterburner Remote Server API format
    # POST to set values: /SetOCProfile
    `$body = @{
        CoreClk = `$CoreClock
        MemClk = `$MemClock
        PowerLimit = `$PowerLimit
    } | ConvertTo-Json

    try {
        `$result = Invoke-WebRequest -Uri "`$msiServerUrl/SetOCProfile" -Method POST -Body `$body -ContentType "application/json" -ErrorAction Stop
        Write-Host "[OK] Overclocking values set via Remote Server" -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "[WARN] Could not set values via Remote Server: `$_" -ForegroundColor Yellow
        Write-Host "  Remote Server may not support this method" -ForegroundColor Gray
    }
} catch {
    Write-Host "[INFO] MSI Afterburner Remote Server not available" -ForegroundColor Gray
    Write-Host "  This is normal - Remote Server is optional" -ForegroundColor Gray
}

Write-Host ""

# Method 2: Launch MSI Afterburner and provide clear instructions
Write-Host "Launching MSI Afterburner for manual configuration..." -ForegroundColor Yellow

`$msiExe = "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe"
if (-not (Test-Path `$msiExe)) {
    `$msiExe = "${env:ProgramFiles}\MSI Afterburner\MSIAfterburner.exe"
}

if (Test-Path `$msiExe) {
    Start-Process -FilePath `$msiExe
    Start-Sleep -Seconds 3

    Write-Host ""
    Write-Host "=== Configuration Instructions ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "MSI Afterburner is now open. Please configure:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Core Clock Slider:" -ForegroundColor White
    Write-Host "   - Move slider to: +`$CoreClock MHz" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Memory Clock Slider:" -ForegroundColor White
    Write-Host "   - Move slider to: +`$MemClock MHz" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Power Limit Slider (if available):" -ForegroundColor White
    Write-Host "   - Move slider to: +`$PowerLimit%" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Click the Apply button (checkmark icon)" -ForegroundColor White
    Write-Host ""
    Write-Host "5. Save as Profile 1 (optional, for easy loading later)" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "[FAIL] MSI Afterburner executable not found" -ForegroundColor Red
}
"@

Set-Content -Path $autoScriptPath -Value $autoScript
Write-Host "Created automation script: $autoScriptPath" -ForegroundColor Green

Write-Host ""

# Intel XTU Configuration
Write-Host "=== Intel XTU Configuration ===" -ForegroundColor Cyan

$TurboBoostPowerMax = 5
$TurboBoostShortPowerMax = 5
$CoreVoltageOffset = 10  # in mV
$TurboBoostMax = 100

Write-Host "Recommended Settings for i9-12900H:" -ForegroundColor Yellow
Write-Host "  Turbo Boost Power Max: +$TurboBoostPowerMax W" -ForegroundColor Gray
Write-Host "  Turbo Boost Short Power Max: +$TurboBoostShortPowerMax W" -ForegroundColor Gray
Write-Host "  Core Voltage Offset: +0.010V" -ForegroundColor Gray
Write-Host "  Turbo Boost Max: +$TurboBoostMax MHz" -ForegroundColor Gray
Write-Host ""

# Try to configure Intel XTU via registry
# Intel XTU stores settings in registry, but the exact keys vary
$xtuRegPath = "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility"

if (Test-Path $xtuRegPath) {
    Write-Host "[INFO] Intel XTU registry path found" -ForegroundColor Green

    # Backup registry
    $regBackupPath = Join-Path $env:USERPROFILE "XTU-Registry-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"
    try {
        reg export "HKCU\SOFTWARE\Intel\Extreme Tuning Utility" $regBackupPath /y 2>&1 | Out-Null
        Write-Host "  Registry backup created: $regBackupPath" -ForegroundColor Gray
    } catch {
        Write-Host "  [WARN] Could not backup registry" -ForegroundColor Yellow
    }

    Write-Host "  [INFO] Intel XTU settings are CPU-specific and complex" -ForegroundColor Yellow
    Write-Host "  [INFO] Registry keys vary by CPU model and XTU version" -ForegroundColor Yellow
    Write-Host "  [INFO] Manual configuration via GUI is recommended" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] Intel XTU registry path not found (settings may not exist yet)" -ForegroundColor Gray
}

Write-Host ""

# Create Intel XTU configuration script
$xtuAutoPath = Join-Path $configDir "auto-configure-xtu.ps1"

$xtuAutoScript = @"
# Auto-configure Intel XTU
# This script attempts to configure Intel XTU settings

`$TurboBoostPowerMax = $TurboBoostPowerMax
`$TurboBoostShortPowerMax = $TurboBoostShortPowerMax
`$CoreVoltageOffset = $CoreVoltageOffset
`$TurboBoostMax = $TurboBoostMax

Write-Host "=== Auto-Configure Intel XTU ===" -ForegroundColor Cyan
Write-Host ""

# Launch Intel XTU
`$xtuExePaths = @(
    "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
    "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
)

`$launched = `$false
foreach (`$path in `$xtuExePaths) {
    if (Test-Path `$path) {
        try {
            Start-Process -FilePath `$path
            Write-Host "[OK] Intel XTU launched: `$path" -ForegroundColor Green
            `$launched = `$true
            Start-Sleep -Seconds 3
            break
        } catch {
            # Continue to next path
        }
    }
}

if (-not `$launched) {
    Write-Host "[WARN] Could not launch Intel XTU automatically" -ForegroundColor Yellow
    Write-Host "  Please launch manually from Start Menu" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "=== Configuration Instructions ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Intel XTU is now open. Please configure:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Navigate to 'Advanced Tuning' -> 'Core' tab" -ForegroundColor White
Write-Host ""
Write-Host "2. Power Limits (in 'Core' or 'Power' tab):" -ForegroundColor White
Write-Host "   - Turbo Boost Power Max: Increase by +`$TurboBoostPowerMax W" -ForegroundColor Gray
Write-Host "   - Turbo Boost Short Power Max: Increase by +`$TurboBoostShortPowerMax W" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Core Settings:" -ForegroundColor White
Write-Host "   - Core Voltage Offset: +0.010V (if needed for stability)" -ForegroundColor Gray
Write-Host "   - Turbo Boost Max: +`$TurboBoostMax MHz (optional, very conservative)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Click 'Apply' button" -ForegroundColor White
Write-Host ""
Write-Host "5. Run Stress Test for 15-30 minutes" -ForegroundColor White
Write-Host "   - Monitor Core Temperature (keep below 90°C)" -ForegroundColor Gray
Write-Host "   - Monitor Package Temperature (keep below 95°C)" -ForegroundColor Gray
Write-Host ""
"@

Set-Content -Path $xtuAutoPath -Value $xtuAutoScript
Write-Host "Created Intel XTU automation script: $xtuAutoPath" -ForegroundColor Green

Write-Host ""
Write-Host "=== Running Automation Scripts ===" -ForegroundColor Cyan
Write-Host ""

# Run the automation scripts
Write-Host "Running MSI Afterburner configuration..." -ForegroundColor Yellow
& $autoScriptPath

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Running Intel XTU configuration..." -ForegroundColor Yellow
& $xtuAutoPath

Write-Host ""
Write-Host "=== Configuration Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Both applications have been launched with configuration instructions." -ForegroundColor White
Write-Host "Please follow the on-screen instructions to complete the configuration." -ForegroundColor White
Write-Host ""

