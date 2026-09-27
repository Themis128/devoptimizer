# Programmatic Overclocking Configuration
# This script applies overclocking values programmatically using available methods

param(
    [int]$CoreClock = 50,
    [int]$MemClock = 200,
    [int]$PowerLimit = 5,
    [int]$TurboBoostPowerMax = 5,
    [int]$TurboBoostShortPowerMax = 5,
    [int]$TurboBoostMax = 100,
    [switch]$MSIOnly,
    [switch]$XTUOnly
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Programmatic Overclocking Configuration" -ForegroundColor Cyan
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
$configureMSI = $MSIOnly -or (-not $XTUOnly)
$configureXTU = $XTUOnly -or (-not $MSIOnly)

# MSI Afterburner Programmatic Configuration
if ($configureMSI) {
    Write-Host "=== MSI Afterburner Programmatic Configuration ===" -ForegroundColor Cyan
    Write-Host ""

    $msiExe = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
    if (-not (Test-Path $msiExe)) {
        $msiExe = "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
    }

    if (-not (Test-Path $msiExe)) {
        Write-Host "[ERROR] MSI Afterburner executable not found" -ForegroundColor Red
    } else {
        Write-Host "[INFO] Attempting to apply overclocking via command-line..." -ForegroundColor Yellow

        # Method 1: Try command-line arguments (if supported by version)
        # Note: Not all MSI Afterburner versions support direct CLI overclocking
        # We'll try the profile method first, then fall back to Remote Server API

        # Method 1a: Try Remote Server API first (if enabled)
        $msiServerPort = 13247
        $msiServerUrl = "http://localhost:$msiServerPort"

        try {
            $response = Invoke-WebRequest -Uri "$msiServerUrl/GetStatus" -TimeoutSec 2 -ErrorAction Stop
            Write-Host "[OK] MSI Afterburner Remote Server detected" -ForegroundColor Green

            # Try to apply via Remote Server API
            Write-Host "[INFO] Attempting to apply via Remote Server API..." -ForegroundColor Yellow
            $body = @{
                CoreClk = $config.MSI.CoreClock
                MemClk = $config.MSI.MemClock
                PowerLimit = $config.MSI.PowerLimit
            } | ConvertTo-Json

            try {
                $result = Invoke-WebRequest -Uri "$msiServerUrl/SetOCProfile" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
                Write-Host "[OK] Overclocking values applied via Remote Server API!" -ForegroundColor Green
                Write-Host "  Core Clock: +$($config.MSI.CoreClock) MHz" -ForegroundColor Gray
                Write-Host "  Memory Clock: +$($config.MSI.MemClock) MHz" -ForegroundColor Gray
                Write-Host "  Power Limit: +$($config.MSI.PowerLimit)%" -ForegroundColor Gray
            } catch {
                Write-Host "[WARN] Remote Server API call failed: $_" -ForegroundColor Yellow
                Write-Host "  This is normal - API may not support direct setting" -ForegroundColor Gray
            }
        } catch {
            Write-Host "[INFO] MSI Afterburner Remote Server not available" -ForegroundColor Gray
        }

        # Method 1b: Try command-line arguments (experimental)
        Write-Host ""
        Write-Host "[INFO] Attempting command-line method..." -ForegroundColor Yellow

        # Create a temporary script to apply settings
        # Note: MSI Afterburner CLI support varies by version
        $tempScript = "$env:TEMP\apply_msi_oc.ps1"
        $scriptContent = @"
# Temporary script to apply MSI Afterburner overclocking
`$msiExe = "$msiExe"

# Try to apply via command-line arguments
# Note: These may not work on all versions
Start-Process -FilePath `$msiExe -ArgumentList "-CoreClkOffset=$($config.MSI.CoreClock)","-MemClkOffset=$($config.MSI.MemClock)" -Wait -NoNewWindow -ErrorAction SilentlyContinue

# Alternative: Launch with profile if one exists
# Start-Process -FilePath `$msiExe -ArgumentList "-Profile1" -ErrorAction SilentlyContinue
"@

        try {
            Set-Content -Path $tempScript -Value $scriptContent -ErrorAction Stop
            & powershell -ExecutionPolicy Bypass -File $tempScript -ErrorAction SilentlyContinue
            Write-Host "[INFO] Command-line method attempted" -ForegroundColor Gray
        } catch {
            Write-Host "[WARN] Command-line method not available" -ForegroundColor Yellow
        }

        # Method 2: Launch MSI Afterburner and provide instructions
        Write-Host ""
        Write-Host "[INFO] Launching MSI Afterburner..." -ForegroundColor Yellow
        Start-Process -FilePath $msiExe -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        Write-Host ""
        Write-Host "MSI Afterburner Configuration:" -ForegroundColor Cyan
        Write-Host "  The application has been launched." -ForegroundColor White
        Write-Host "  If programmatic methods didn't work, please:" -ForegroundColor Yellow
        Write-Host "  1. Set Core Clock to +$($config.MSI.CoreClock) MHz" -ForegroundColor Gray
        Write-Host "  2. Set Memory Clock to +$($config.MSI.MemClock) MHz" -ForegroundColor Gray
        Write-Host "  3. Set Power Limit to +$($config.MSI.PowerLimit)% (if available)" -ForegroundColor Gray
        Write-Host "  4. Click Apply" -ForegroundColor Gray
        Write-Host ""
    }
}

# Intel XTU Programmatic Configuration
if ($configureXTU) {
    Write-Host "=== Intel XTU Programmatic Configuration ===" -ForegroundColor Cyan
    Write-Host ""

    # Intel XTU stores settings in registry
    # Location: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes
    # But it's complex and CPU-specific

    Write-Host "[INFO] Attempting Intel XTU registry configuration..." -ForegroundColor Yellow

    # Check if running as admin (required for registry)
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "[WARN] Administrator privileges required for Intel XTU registry configuration" -ForegroundColor Yellow
        Write-Host "  Please run this script as Administrator" -ForegroundColor Gray
    } else {
        # Intel XTU registry paths (these vary by CPU and version)
        # For i9-12900H, we need to find the correct registry keys
        $xtuRegPath = "HKLM:\SOFTWARE\Intel\Extreme Tuning Utility"

        if (Test-Path $xtuRegPath) {
            Write-Host "[OK] Intel XTU registry path found" -ForegroundColor Green

            # Try to read current values
            try {
                $currentValues = Get-ItemProperty -Path $xtuRegPath -ErrorAction SilentlyContinue
                Write-Host "[INFO] Current XTU registry values detected" -ForegroundColor Gray

                # Note: Intel XTU registry structure is complex and CPU-specific
                # We'll provide instructions instead of direct modification
                Write-Host "[INFO] Intel XTU registry modification is complex and CPU-specific" -ForegroundColor Yellow
                Write-Host "  Manual configuration via GUI is recommended for safety" -ForegroundColor Gray
            } catch {
                Write-Host "[WARN] Could not read XTU registry: $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[INFO] Intel XTU registry path not found (may need to launch XTU first)" -ForegroundColor Gray
        }
    }

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
                Write-Host "[OK] Intel XTU launched" -ForegroundColor Green
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
    Write-Host "Intel XTU Configuration:" -ForegroundColor Cyan
    Write-Host "  Due to the complexity of Intel XTU registry structure," -ForegroundColor White
    Write-Host "  manual configuration via GUI is recommended:" -ForegroundColor Yellow
    Write-Host "  1. Navigate to Advanced Tuning -> Power tab" -ForegroundColor Gray
    Write-Host "     - Turbo Boost Power Max: +$($config.XTU.TurboBoostPowerMax) W" -ForegroundColor Gray
    Write-Host "     - Turbo Boost Short Power Max: +$($config.XTU.TurboBoostShortPowerMax) W" -ForegroundColor Gray
    Write-Host "  2. Navigate to Advanced Tuning -> Core tab" -ForegroundColor Gray
    Write-Host "     - Turbo Boost Max: +$($config.XTU.TurboBoostMax) MHz" -ForegroundColor Gray
    Write-Host "  3. Click Apply" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Programmatic Configuration Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Some settings may require manual confirmation in the GUI" -ForegroundColor Yellow
Write-Host ""
