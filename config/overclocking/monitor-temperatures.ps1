# Temperature Monitoring Script
# Monitors CPU and GPU temperatures during overclocking

param(
    [int]$DurationMinutes = 5,
    [int]$IntervalSeconds = 2
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Temperature Monitoring' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Monitoring Configuration:' -ForegroundColor Yellow
Write-Host "  Duration: $DurationMinutes minutes" -ForegroundColor White
Write-Host "  Update Interval: $IntervalSeconds seconds" -ForegroundColor White
Write-Host ''

# Temperature limits
$gpuTempLimit = 83
$cpuCoreTempLimit = 90
$cpuPackageTempLimit = 95

Write-Host 'Temperature Limits:' -ForegroundColor Yellow
Write-Host "  GPU: < $gpuTempLimit°C" -ForegroundColor White
Write-Host "  CPU Core: < $cpuCoreTempLimit°C" -ForegroundColor White
Write-Host "  CPU Package: < $cpuPackageTempLimit°C" -ForegroundColor White
Write-Host ''

# Check if Open Hardware Monitor or similar is available
$ohmAvailable = $false
try {
    $ohmProcess = Get-Process | Where-Object { $_.ProcessName -like '*OpenHardwareMonitor*' }
    if ($ohmProcess) {
        $ohmAvailable = $true
        Write-Host '[INFO] Open Hardware Monitor detected' -ForegroundColor Green
    }
}
catch {
    # Not available
}

# Try to get temperature data
Write-Host 'Attempting to retrieve temperature data...' -ForegroundColor Yellow
Write-Host ''

# Method 1: Try WMI (limited temperature data)
try {
    $cpu = Get-WmiObject -Class Win32_TemperatureProbe -ErrorAction SilentlyContinue
    if ($cpu) {
        Write-Host '[INFO] Temperature sensors detected via WMI' -ForegroundColor Green
    }
}
catch {
    # WMI temperature not available
}

# Method 2: Check for MSI Afterburner monitoring
$msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1

if ($msiProcess) {
    Write-Host '[OK] MSI Afterburner is running' -ForegroundColor Green
    Write-Host '  Use MSI Afterburner OSD (On-Screen Display) for real-time monitoring' -ForegroundColor Gray
    Write-Host ''
}

Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Monitoring Instructions' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Since direct temperature reading requires specialized tools,' -ForegroundColor White
Write-Host 'please use one of these methods:' -ForegroundColor White
Write-Host ''
Write-Host 'Method 1: MSI Afterburner OSD (Recommended)' -ForegroundColor Yellow
Write-Host '  1. Open MSI Afterburner' -ForegroundColor White
Write-Host '  2. Click Settings (gear icon)' -ForegroundColor White
Write-Host '  3. Go to "Monitoring" tab' -ForegroundColor White
Write-Host '  4. Enable "Show in On-Screen Display" for:' -ForegroundColor White
Write-Host '     - GPU temperature' -ForegroundColor Gray
Write-Host '     - GPU usage' -ForegroundColor Gray
Write-Host '     - GPU clock' -ForegroundColor Gray
Write-Host '     - Memory clock' -ForegroundColor Gray
Write-Host '  5. Enable OSD (RivaTuner Statistics Server)' -ForegroundColor White
Write-Host '  6. Temperatures will display during games/applications' -ForegroundColor White
Write-Host ''
Write-Host 'Method 2: HWiNFO64 (Comprehensive)' -ForegroundColor Yellow
Write-Host '  1. Download and install HWiNFO64' -ForegroundColor White
Write-Host '  2. Run HWiNFO64' -ForegroundColor White
Write-Host '  3. View real-time temperatures for:' -ForegroundColor White
Write-Host '     - CPU cores' -ForegroundColor Gray
Write-Host '     - CPU package' -ForegroundColor Gray
Write-Host '     - GPU' -ForegroundColor Gray
Write-Host '     - GPU memory' -ForegroundColor Gray
Write-Host ''
Write-Host 'Method 3: Task Manager' -ForegroundColor Yellow
Write-Host '  1. Open Task Manager (Ctrl+Shift+Esc)' -ForegroundColor White
Write-Host '  2. Go to "Performance" tab' -ForegroundColor White
Write-Host '  3. Select GPU to see basic temperature' -ForegroundColor White
Write-Host '  4. Select CPU to see usage (no temp in standard Task Manager)' -ForegroundColor White
Write-Host ''

# Create monitoring loop (simplified - actual temp reading requires specialized tools)
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Monitoring Session' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "Starting $DurationMinutes minute monitoring session..." -ForegroundColor Yellow
Write-Host "Update every $IntervalSeconds seconds" -ForegroundColor Gray
Write-Host ''
Write-Host 'Press Ctrl+C to stop monitoring early' -ForegroundColor Yellow
Write-Host ''

$startTime = Get-Date
$endTime = $startTime.AddMinutes($DurationMinutes)
$iteration = 0

try {
    while ((Get-Date) -lt $endTime) {
        $iteration++
        $elapsed = (Get-Date) - $startTime
        $remaining = $endTime - (Get-Date)

        Write-Host "=== Monitoring Update #$iteration ===" -ForegroundColor Cyan
        Write-Host "  Elapsed: $([math]::Floor($elapsed.TotalMinutes))m $($elapsed.Seconds)s" -ForegroundColor White
        Write-Host "  Remaining: $([math]::Floor($remaining.TotalMinutes))m $($remaining.Seconds)s" -ForegroundColor White
        Write-Host ''

        # Check MSI Afterburner process
        $msiRunning = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1
        if ($msiRunning) {
            Write-Host '[OK] MSI Afterburner is running' -ForegroundColor Green
            Write-Host '  Check MSI Afterburner window for current temperatures' -ForegroundColor Gray
        }
        else {
            Write-Host '[WARN] MSI Afterburner is not running' -ForegroundColor Yellow
        }

        Write-Host ''
        Write-Host 'Temperature Status:' -ForegroundColor Yellow
        Write-Host '  GPU: [Check MSI Afterburner or HWiNFO64]' -ForegroundColor White
        Write-Host '  CPU: [Check HWiNFO64 or Intel XTU]' -ForegroundColor White
        Write-Host ''
        Write-Host 'Action Required:' -ForegroundColor Yellow
        Write-Host '  - Monitor temperatures in MSI Afterburner or HWiNFO64' -ForegroundColor White
        Write-Host '  - Watch for values exceeding limits' -ForegroundColor White
        Write-Host '  - Stop if temperatures are too high' -ForegroundColor White
        Write-Host ''

        Start-Sleep -Seconds $IntervalSeconds
    }

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host 'Monitoring Session Complete!' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Monitored for $DurationMinutes minutes" -ForegroundColor White
    Write-Host ''
    Write-Host 'Review:' -ForegroundColor Yellow
    Write-Host '  - Maximum temperatures reached' -ForegroundColor White
    Write-Host '  - Any throttling occurred' -ForegroundColor White
    Write-Host '  - Stability during monitoring' -ForegroundColor White
    Write-Host ''
}
catch {
    Write-Host ''
    Write-Host 'Monitoring stopped by user' -ForegroundColor Yellow
}

Write-Host ''
