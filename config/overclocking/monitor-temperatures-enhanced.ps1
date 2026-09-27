# Enhanced Temperature Monitoring Script
# Attempts to read actual temperatures from available sources

param(
    [int]$DurationMinutes = 5,
    [int]$IntervalSeconds = 2
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Enhanced Temperature Monitoring' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# Temperature limits
$gpuTempLimit = 83
$cpuCoreTempLimit = 90
$cpuPackageTempLimit = 95

Write-Host 'Temperature Limits:' -ForegroundColor Yellow
Write-Host "  GPU: < $gpuTempLimit°C (Target: < 80°C)" -ForegroundColor White
Write-Host "  CPU Core: < $cpuCoreTempLimit°C (Target: < 85°C)" -ForegroundColor White
Write-Host "  CPU Package: < $cpuPackageTempLimit°C (Target: < 90°C)" -ForegroundColor White
Write-Host ''

# Function to get GPU temperature via WMI (if available)
function Get-GPUTemperature {
    try {
        # Try to get GPU temperature via WMI
        $gpu = Get-WmiObject -Class Win32_TemperatureProbe -ErrorAction SilentlyContinue |
            Where-Object { $_.Description -like '*GPU*' -or $_.Description -like '*Graphics*' } |
            Select-Object -First 1

        if ($gpu -and $gpu.CurrentReading) {
            # Convert from millidegrees to degrees
            $temp = [math]::Round($gpu.CurrentReading / 10, 1)
            return $temp
        }
    }
    catch {
        # WMI method not available
    }

    return $null
}

# Function to get CPU temperature via WMI (if available)
function Get-CPUTemperature {
    try {
        # Try to get CPU temperature via WMI
        $cpu = Get-WmiObject -Class Win32_TemperatureProbe -ErrorAction SilentlyContinue |
            Where-Object { $_.Description -like '*CPU*' -or $_.Description -like '*Processor*' } |
            Select-Object -First 1

        if ($cpu -and $cpu.CurrentReading) {
            # Convert from millidegrees to degrees
            $temp = [math]::Round($cpu.CurrentReading / 10, 1)
            return $temp
        }
    }
    catch {
        # WMI method not available
    }

    return $null
}

# Function to get GPU info via WMI
function Get-GPUInfo {
    try {
        $gpu = Get-WmiObject -Class Win32_VideoController |
            Where-Object { $_.Name -like '*NVIDIA*' -or $_.Name -like '*RTX*' -or $_.Name -like '*GeForce*' } |
            Select-Object -First 1

        if ($gpu) {
            return @{
                Name = $gpu.Name
                DriverVersion = $gpu.DriverVersion
            }
        }
    }
    catch {
        # Not available
    }

    return $null
}

# Check for MSI Afterburner
$msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1

Write-Host 'Detecting temperature sources...' -ForegroundColor Yellow
Write-Host ''

$gpuInfo = Get-GPUInfo
if ($gpuInfo) {
    Write-Host '[OK] GPU Detected:' -ForegroundColor Green
    Write-Host "  Name: $($gpuInfo.Name)" -ForegroundColor Gray
    Write-Host "  Driver: $($gpuInfo.DriverVersion)" -ForegroundColor Gray
}
else {
    Write-Host '[INFO] GPU information not available via WMI' -ForegroundColor Gray
}

if ($msiProcess) {
    Write-Host '[OK] MSI Afterburner is running' -ForegroundColor Green
    Write-Host '  Use MSI Afterburner window to view temperatures' -ForegroundColor Gray
}
else {
    Write-Host '[WARN] MSI Afterburner is not running' -ForegroundColor Yellow
    Write-Host '  Launch MSI Afterburner for better temperature monitoring' -ForegroundColor Gray
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Starting Monitoring Session' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "Duration: $DurationMinutes minutes" -ForegroundColor White
Write-Host "Update Interval: $IntervalSeconds seconds" -ForegroundColor White
Write-Host ''
Write-Host 'Press Ctrl+C to stop monitoring early' -ForegroundColor Yellow
Write-Host ''

$startTime = Get-Date
$endTime = $startTime.AddMinutes($DurationMinutes)
$iteration = 0
$maxGPUTemp = 0
$maxCPUTemp = 0
$warnings = 0

try {
    while ((Get-Date) -lt $endTime) {
        $iteration++
        $elapsed = (Get-Date) - $startTime
        $remaining = $endTime - (Get-Date)

        # Clear previous line for cleaner output
        if ($iteration -gt 1) {
            Write-Host "`r" -NoNewline
        }

        # Get temperatures
        $gpuTemp = Get-GPUTemperature
        $cpuTemp = Get-CPUTemperature

        # Update max temperatures
        if ($gpuTemp -and $gpuTemp -gt $maxGPUTemp) {
            $maxGPUTemp = $gpuTemp
        }
        if ($cpuTemp -and $cpuTemp -gt $maxCPUTemp) {
            $maxCPUTemp = $cpuTemp
        }

        # Display status
        $status = "Update #$iteration | Elapsed: $([math]::Floor($elapsed.TotalMinutes))m $($elapsed.Seconds)s | Remaining: $([math]::Floor($remaining.TotalMinutes))m $($remaining.Seconds)s"

        if ($gpuTemp -or $cpuTemp) {
            $tempInfo = ""
            if ($gpuTemp) {
                $gpuColor = if ($gpuTemp -lt 80) { "Green" } elseif ($gpuTemp -lt $gpuTempLimit) { "Yellow" } else { "Red" }
                $tempInfo += "GPU: $gpuTemp°C "

                if ($gpuTemp -ge $gpuTempLimit) {
                    $warnings++
                }
            }
            else {
                $tempInfo += "GPU: N/A "
            }

            if ($cpuTemp) {
                $cpuColor = if ($cpuTemp -lt 85) { "Green" } elseif ($cpuTemp -lt $cpuCoreTempLimit) { "Yellow" } else { "Red" }
                $tempInfo += "CPU: $cpuTemp°C"

                if ($cpuTemp -ge $cpuCoreTempLimit) {
                    $warnings++
                }
            }
            else {
                $tempInfo += "CPU: N/A"
            }

            Write-Host "$status | $tempInfo" -ForegroundColor White

            # Warning if temperatures are high
            if ($gpuTemp -and $gpuTemp -ge $gpuTempLimit) {
                Write-Host "  ⚠️  WARNING: GPU temperature is at or above limit ($gpuTempLimit°C)!" -ForegroundColor Red
            }
            if ($cpuTemp -and $cpuTemp -ge $cpuCoreTempLimit) {
                Write-Host "  ⚠️  WARNING: CPU temperature is at or above limit ($cpuCoreTempLimit°C)!" -ForegroundColor Red
            }
        }
        else {
            Write-Host "$status | GPU: [Check MSI Afterburner] CPU: [Check HWiNFO64/XTU]" -ForegroundColor White
            Write-Host "  Note: Direct temperature reading not available. Check MSI Afterburner window." -ForegroundColor Gray
        }

        Start-Sleep -Seconds $IntervalSeconds
    }

    Write-Host ''
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host 'Monitoring Session Complete!' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Session Duration: $DurationMinutes minutes" -ForegroundColor White
    Write-Host "Total Updates: $iteration" -ForegroundColor White

    if ($maxGPUTemp -gt 0 -or $maxCPUTemp -gt 0) {
        Write-Host ''
        Write-Host 'Maximum Temperatures Recorded:' -ForegroundColor Yellow
        if ($maxGPUTemp -gt 0) {
            $status = if ($maxGPUTemp -lt 80) { "✅ Good" } elseif ($maxGPUTemp -lt $gpuTempLimit) { "⚠️  Warm" } else { "❌ Hot" }
            Write-Host "  GPU: $maxGPUTemp°C $status" -ForegroundColor $(if ($maxGPUTemp -lt $gpuTempLimit) { "Green" } else { "Red" })
        }
        if ($maxCPUTemp -gt 0) {
            $status = if ($maxCPUTemp -lt 85) { "✅ Good" } elseif ($maxCPUTemp -lt $cpuCoreTempLimit) { "⚠️  Warm" } else { "❌ Hot" }
            Write-Host "  CPU: $maxCPUTemp°C $status" -ForegroundColor $(if ($maxCPUTemp -lt $cpuCoreTempLimit) { "Green" } else { "Red" })
        }
    }

    if ($warnings -gt 0) {
        Write-Host ''
        Write-Host "⚠️  Warnings: $warnings temperature limit warnings during monitoring" -ForegroundColor Yellow
        Write-Host '  Consider reducing overclocking values or improving cooling' -ForegroundColor White
    }
    else {
        Write-Host ''
        Write-Host '✅ No temperature warnings - temperatures stayed within limits!' -ForegroundColor Green
    }

    Write-Host ''
    Write-Host 'Recommendations:' -ForegroundColor Cyan
    if ($maxGPUTemp -gt 0 -and $maxGPUTemp -lt 80) {
        Write-Host '  GPU: Temperature is good - you may have headroom for higher overclocking' -ForegroundColor Green
    }
    elseif ($maxGPUTemp -gt 0 -and $maxGPUTemp -ge $gpuTempLimit) {
        Write-Host '  GPU: Temperature is at limit - reduce overclocking or improve cooling' -ForegroundColor Red
    }

    if ($maxCPUTemp -gt 0 -and $maxCPUTemp -lt 85) {
        Write-Host '  CPU: Temperature is good - you may have headroom for higher overclocking' -ForegroundColor Green
    }
    elseif ($maxCPUTemp -gt 0 -and $maxCPUTemp -ge $cpuCoreTempLimit) {
        Write-Host '  CPU: Temperature is at limit - reduce overclocking or improve cooling' -ForegroundColor Red
    }

    Write-Host ''
}
catch {
    Write-Host ''
    Write-Host 'Monitoring stopped by user' -ForegroundColor Yellow
    Write-Host ''

    if ($maxGPUTemp -gt 0 -or $maxCPUTemp -gt 0) {
        Write-Host 'Maximum Temperatures Recorded:' -ForegroundColor Yellow
        if ($maxGPUTemp -gt 0) {
            Write-Host "  GPU: $maxGPUTemp°C" -ForegroundColor White
        }
        if ($maxCPUTemp -gt 0) {
            Write-Host "  CPU: $maxCPUTemp°C" -ForegroundColor White
        }
    }
}

Write-Host ''
