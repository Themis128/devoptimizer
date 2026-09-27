# Programmatic Overclocking Configuration (Admin Required)
# Run this script as Administrator for full programmatic control

param(
    [int]$CoreClock = 50,
    [int]$MemClock = 200,
    [int]$PowerLimit = 5,
    [int]$ProfileNumber = 1
)

$ErrorActionPreference = 'Continue'

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host '[ERROR] This script requires administrator privileges' -ForegroundColor Red
    Write-Host 'Please run PowerShell as Administrator and try again' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Programmatic Overclocking (Admin)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Configuration:' -ForegroundColor Yellow
Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
Write-Host "  Profile Number: $ProfileNumber" -ForegroundColor White
Write-Host ''

# MSI Afterburner Configuration
Write-Host '=== MSI Afterburner Configuration ===' -ForegroundColor Cyan
Write-Host ''

$msiExe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
if (-not (Test-Path $msiExe)) {
    $msiExe = 'C:\Program Files\MSI Afterburner\MSIAfterburner.exe'
}

if (-not (Test-Path $msiExe)) {
    Write-Host '[ERROR] MSI Afterburner executable not found' -ForegroundColor Red
}
else {
    # Method 1: Try Remote Server API
    $msiServerPort = 13247
    $msiServerUrl = "http://localhost:$msiServerPort"

    try {
        $response = Invoke-WebRequest -Uri "$msiServerUrl/GetStatus" -TimeoutSec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host '[OK] MSI Afterburner Remote Server detected' -ForegroundColor Green
        }

        # Try to apply settings
        $body = @{
            CoreClk    = $CoreClock
            MemClk     = $MemClock
            PowerLimit = $PowerLimit
        } | ConvertTo-Json

        try {
            $result = Invoke-WebRequest -Uri "$msiServerUrl/SetOCProfile" -Method POST -Body $body -ContentType 'application/json' -TimeoutSec 5 -ErrorAction Stop
            if ($result.StatusCode -eq 200) {
                Write-Host '[OK] Overclocking applied via Remote Server API!' -ForegroundColor Green
            }
        }
        catch {
            Write-Host "[WARN] Remote Server API call failed: $_" -ForegroundColor Yellow
            Write-Host '  Trying alternative method...' -ForegroundColor Gray
        }
    }
    catch {
        Write-Host '[INFO] MSI Afterburner Remote Server not available' -ForegroundColor Gray
        Write-Host '  Using profile method...' -ForegroundColor Gray
    }

    # Method 2: Apply existing profile (if it exists)
    # First, ensure MSI Afterburner is running
    $msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1

    if (-not $msiProcess) {
        Write-Host '[INFO] Starting MSI Afterburner...' -ForegroundColor Yellow
        Start-Process -FilePath $msiExe
        Start-Sleep -Seconds 3
    }

    # Try to apply profile via command-line
    Write-Host "[INFO] Applying Profile $ProfileNumber..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath $msiExe -ArgumentList "-Profile$ProfileNumber" -ErrorAction Stop
        Write-Host "[OK] Profile $ProfileNumber applied!" -ForegroundColor Green
        Write-Host "  Note: If profile doesn't exist, you'll need to create it first" -ForegroundColor Gray
        Write-Host '  Use: create-msi-profile.ps1 or configure manually' -ForegroundColor Gray
    }
    catch {
        Write-Host "[WARN] Could not apply profile: $_" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Configuration Complete!' -ForegroundColor Green
Write-Host ''
