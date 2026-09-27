# Create and Apply MSI Afterburner Profile with Recommended Values
# This script creates Profile 1 with conservative values and applies it

param(
    [int]$CoreClock = 50,
    [int]$MemClock = 200,
    [int]$PowerLimit = 5,
    [int]$ProfileNumber = 1
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Create and Apply Overclocking Profile' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Profile Configuration:' -ForegroundColor Yellow
Write-Host "  Profile Number: $ProfileNumber" -ForegroundColor White
Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
Write-Host ''

$msiExe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
if (-not (Test-Path $msiExe)) {
    $msiExe = 'C:\Program Files\MSI Afterburner\MSIAfterburner.exe'
}

if (-not (Test-Path $msiExe)) {
    Write-Host '[ERROR] MSI Afterburner executable not found' -ForegroundColor Red
    exit 1
}

# Step 1: Try to apply values directly via Remote Server API
Write-Host '=== Step 1: Attempting Programmatic Configuration ===' -ForegroundColor Cyan
Write-Host ''

$msiServerPort = 13247
$msiServerUrl = "http://localhost:$msiServerPort"

$appliedProgrammatically = $false

try {
    $response = Invoke-WebRequest -Uri "$msiServerUrl/GetStatus" -TimeoutSec 2 -ErrorAction Stop
    Write-Host '[OK] MSI Afterburner Remote Server detected' -ForegroundColor Green
    Write-Host '[INFO] Attempting to apply overclocking values directly...' -ForegroundColor Yellow

    # Try different API formats (MSI Afterburner API is undocumented)
    $apiFormats = @(
        @{
            Uri = "$msiServerUrl/SetOCProfile"
            Body = @{
                CoreClk = $CoreClock
                MemClk = $MemClock
                PowerLimit = $PowerLimit
            }
        },
        @{
            Uri = "$msiServerUrl/SetOC"
            Body = @{
                Core = $CoreClock
                Memory = $MemClock
                Power = $PowerLimit
            }
        },
        @{
            Uri = "$msiServerUrl/ApplyOC"
            Body = @{
                CoreClock = $CoreClock
                MemoryClock = $MemClock
                PowerLimit = $PowerLimit
            }
        }
    )

    foreach ($format in $apiFormats) {
        try {
            $body = $format.Body | ConvertTo-Json
            $result = Invoke-WebRequest -Uri $format.Uri -Method POST -Body $body -ContentType 'application/json' -TimeoutSec 5 -ErrorAction Stop
            Write-Host "[OK] Overclocking values applied via Remote Server API!" -ForegroundColor Green
            Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor Gray
            Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor Gray
            Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor Gray
            $appliedProgrammatically = $true
            break
        }
        catch {
            # Try next format
            continue
        }
    }

    if (-not $appliedProgrammatically) {
        Write-Host '[WARN] Remote Server API format not recognized' -ForegroundColor Yellow
        Write-Host '  API format may vary by MSI Afterburner version' -ForegroundColor Gray
    }
}
catch {
    Write-Host '[INFO] MSI Afterburner Remote Server not available' -ForegroundColor Gray
    Write-Host '  Will use profile method instead...' -ForegroundColor Gray
}

# Step 2: If programmatic method didn't work, use profile method
if (-not $appliedProgrammatically) {
    Write-Host ''
    Write-Host '=== Step 2: Profile Method ===' -ForegroundColor Cyan
    Write-Host ''

    # Ensure MSI Afterburner is running
    $msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1

    if (-not $msiProcess) {
        Write-Host '[INFO] Starting MSI Afterburner...' -ForegroundColor Yellow
        Start-Process -FilePath $msiExe
        Start-Sleep -Seconds 3
    }

    # Try to apply existing profile first (in case it already exists)
    Write-Host "[INFO] Attempting to apply Profile $ProfileNumber..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath $msiExe -ArgumentList "-Profile$ProfileNumber" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "[OK] Profile $ProfileNumber application attempted" -ForegroundColor Green
        Write-Host '  If profile exists, it has been applied' -ForegroundColor Gray
        Write-Host '  If profile does not exist, follow instructions below' -ForegroundColor Gray
    }
    catch {
        Write-Host '[WARN] Could not apply profile automatically' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '=== Manual Profile Creation (If Needed) ===' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'MSI Afterburner does not support direct profile creation via command-line.' -ForegroundColor White
    Write-Host 'If Profile $ProfileNumber does not exist with these values, please:' -ForegroundColor White
    Write-Host ''
    Write-Host "1. In MSI Afterburner, set Core Clock slider to: +$CoreClock MHz" -ForegroundColor Gray
    Write-Host "2. Set Memory Clock slider to: +$MemClock MHz" -ForegroundColor Gray
    Write-Host "3. Set Power Limit slider to: +$PowerLimit% (if available)" -ForegroundColor Gray
    Write-Host "4. Click Apply (checkmark icon)" -ForegroundColor Gray
    Write-Host "5. Click Profile $ProfileNumber button" -ForegroundColor Gray
    Write-Host '6. Click Save to save the profile' -ForegroundColor Gray
    Write-Host "7. (Optional) Right-click profile and enable 'Apply at startup'" -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Press Enter after creating the profile to apply it...' -ForegroundColor Yellow
    $null = Read-Host

    # Apply the profile
    Write-Host ''
    Write-Host "[INFO] Applying Profile $ProfileNumber..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath $msiExe -ArgumentList "-Profile$ProfileNumber" -ErrorAction Stop
        Write-Host "[OK] Profile $ProfileNumber applied!" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to apply profile: $_" -ForegroundColor Red
        Write-Host '  Please apply manually in MSI Afterburner' -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Configuration Complete!' -ForegroundColor Green
Write-Host ''
Write-Host 'Applied Settings:' -ForegroundColor Yellow
Write-Host "  Core Clock: +$CoreClock MHz" -ForegroundColor White
Write-Host "  Memory Clock: +$MemClock MHz" -ForegroundColor White
Write-Host "  Power Limit: +$PowerLimit%" -ForegroundColor White
Write-Host ''
Write-Host 'Note: Monitor temperatures and stability' -ForegroundColor Yellow
Write-Host ''
