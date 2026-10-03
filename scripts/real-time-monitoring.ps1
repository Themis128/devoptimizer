<#
.SYNOPSIS
    DevOptimizer automation script: real-time-monitoring.
.DESCRIPTION
    DevOptimizer automation script: real-time-monitoring.
#>

# DevOptimizer Real-time Monitoring Module
# Advanced system monitoring and analytics for the DevOptimizer Enhanced Suite

param(
    [string]$Mode = "dashboard",
    [int]$RefreshInterval = 5,
    [switch]$LogToFile,
    [string]$LogPath = ".\monitoring.log"
)

# Monitoring Configuration
$MONITORING_CONFIG = @{
    "CPU_Threshold" = 80
    "Memory_Threshold" = 85
    "Disk_Threshold" = 90
    "Network_Threshold" = 1000
    "Temperature_Threshold" = 80
    "Log_Retention_Days" = 7
    "Alert_Email" = $null
    "Webhook_URL" = $null
}

# Performance Counters
$PERFORMANCE_COUNTERS = @{
    "CPU" = '\Processor(_Total)\% Processor Time'
    "Memory" = '\Memory\Available MBytes'
    "Disk_Read" = '\PhysicalDisk(_Total)\Disk Reads/sec'
    "Disk_Write" = '\PhysicalDisk(_Total)\Disk Writes/sec'
    "Network_Sent" = '\Network Interface(*)\Bytes Sent/sec'
    "Network_Received" = '\Network Interface(*)\Bytes Received/sec'
    "Processes" = '\System\Processes'
    "Threads" = '\System\Threads'
}

# Historical Data Storage
$HISTORICAL_DATA = @{
    "CPU_History" = @()
    "Memory_History" = @()
    "Disk_History" = @()
    "Network_History" = @()
    "Process_History" = @()
    "Alerts" = @()
}

# Real-time Dashboard
function Show-RealtimeDashboard {
    param(
        [int]$RefreshInterval = 5
    )

    Clear-Host

    while ($true) {
        $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Get current system metrics
        $metrics = Get-SystemMetrics

        # Clear screen and show header
        Clear-Host
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "           📊 REAL-TIME SYSTEM MONITORING DASHBOARD" -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "Last Updated: $currentTime" -ForegroundColor Gray
        Write-Host ""

        # System Overview
        Show-SystemOverview -Metrics $metrics

        # Performance Charts
        Show-PerformanceCharts -Metrics $metrics

        # Process Monitor
        Show-ProcessMonitor -Metrics $metrics

        # Alerts
        Show-Alerts -Metrics $metrics

        # Controls
        Write-Host ""
        Write-Host "Controls: Press 'Q' to quit, 'R' to refresh, 'A' to show alerts" -ForegroundColor Yellow
        Write-Host "Refresh Interval: $RefreshInterval seconds" -ForegroundColor Gray

        # Check for user input
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'Q' { break }
                'R' { continue }
                'A' { Show-AlertHistory }
            }
        }

        Start-Sleep -Seconds $RefreshInterval
    }
}

# Get comprehensive system metrics
function Get-SystemMetrics {
    $metrics = @{}

    try {
        # CPU Usage
        $cpuCounter = Get-Counter $PERFORMANCE_COUNTERS.CPU -SampleInterval 1 -MaxSamples 1
        $metrics.CPU_Usage = [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)

        # Memory Usage
        $memoryCounter = Get-Counter $PERFORMANCE_COUNTERS.Memory -SampleInterval 1 -MaxSamples 1
        $totalMemory = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB
        $availableMemory = $memoryCounter.CounterSamples[0].CookedValue / 1024
        $metrics.Memory_Usage = [math]::Round((($totalMemory - $availableMemory) / $totalMemory) * 100, 2)
        $metrics.Memory_Available = [math]::Round($availableMemory, 2)
        $metrics.Memory_Total = [math]::Round($totalMemory, 2)

        # Disk Usage
        $diskInfo = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"}
        if ($diskInfo) {
            $metrics.Disk_Usage = [math]::Round((($diskInfo.Size - $diskInfo.FreeSpace) / $diskInfo.Size) * 100, 2)
            $metrics.Disk_Free = [math]::Round($diskInfo.FreeSpace / 1GB, 2)
            $metrics.Disk_Total = [math]::Round($diskInfo.Size / 1GB, 2)
        }

        # Network Usage
        $networkCounters = Get-Counter $PERFORMANCE_COUNTERS.Network_Sent, $PERFORMANCE_COUNTERS.Network_Received -SampleInterval 1 -MaxSamples 1
        $metrics.Network_Sent = [math]::Round($networkCounters.CounterSamples[0].CookedValue / 1024, 2)
        $metrics.Network_Received = [math]::Round($networkCounters.CounterSamples[1].CookedValue / 1024, 2)

        # Process Count
        $processCounter = Get-Counter $PERFORMANCE_COUNTERS.Processes -SampleInterval 1 -MaxSamples 1
        $metrics.Process_Count = $processCounter.CounterSamples[0].CookedValue

        # Thread Count
        $threadCounter = Get-Counter $PERFORMANCE_COUNTERS.Threads -SampleInterval 1 -MaxSamples 1
        $metrics.Thread_Count = $threadCounter.CounterSamples[0].CookedValue

        # Top Processes
        $metrics.Top_Processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU, WorkingSet, @{Name='MemoryMB';Expression={[math]::Round($_.WorkingSet/1MB,2)}}

        # System Uptime
        $bootTime = (Get-WmiObject -Class Win32_OperatingSystem).LastBootUpTime
        $metrics.Uptime = (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($bootTime)

        # Temperature (if available)
        try {
            $temperature = Get-WmiObject -Namespace root/wmi -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($temperature) {
                $metrics.Temperature = [math]::Round(($temperature.CurrentTemperature / 10) - 273.15, 2)
            }
        } catch {
            $metrics.Temperature = $null
        }

    } catch {
        Write-Warning "Error collecting metrics: $($_.Exception.Message)"
    }

    return $metrics
}

# Display system overview
function Show-SystemOverview {
    param([hashtable]$Metrics)

    Write-Host "🖥️  SYSTEM OVERVIEW" -ForegroundColor Green
    Write-Host "────────────────────────────────────────────────" -ForegroundColor Green

    # CPU Status
    $cpuColor = if ($Metrics.CPU_Usage -gt $MONITORING_CONFIG.CPU_Threshold) { "Red" } else { "Green" }
    Write-Host "CPU Usage: " -NoNewline
    Write-Host "$($Metrics.CPU_Usage)%" -ForegroundColor $cpuColor -NoNewline
    Write-Host " " -NoNewline
    Show-ProgressBar -Value $Metrics.CPU_Usage -Max 100 -Color $cpuColor

    # Memory Status
    $memoryColor = if ($Metrics.Memory_Usage -gt $MONITORING_CONFIG.Memory_Threshold) { "Red" } else { "Green" }
    Write-Host "Memory:   " -NoNewline
    Write-Host "$($Metrics.Memory_Usage)%" -ForegroundColor $memoryColor -NoNewline
    Write-Host " ($($Metrics.Memory_Available)GB / $($Metrics.Memory_Total)GB) " -NoNewline
    Show-ProgressBar -Value $Metrics.Memory_Usage -Max 100 -Color $memoryColor

    # Disk Status
    $diskColor = if ($Metrics.Disk_Usage -gt $MONITORING_CONFIG.Disk_Threshold) { "Red" } else { "Green" }
    Write-Host "Disk:     " -NoNewline
    Write-Host "$($Metrics.Disk_Usage)%" -ForegroundColor $diskColor -NoNewline
    Write-Host " ($($Metrics.Disk_Free)GB / $($Metrics.Disk_Total)GB) " -NoNewline
    Show-ProgressBar -Value $Metrics.Disk_Usage -Max 100 -Color $diskColor

    # Network Status
    Write-Host "Network:  " -NoNewline
    Write-Host "↑ $($Metrics.Network_Sent)KB/s ↓ $($Metrics.Network_Received)KB/s" -ForegroundColor Cyan

    # System Info
    Write-Host "Uptime:   " -NoNewline
    Write-Host "$($Metrics.Uptime.Days)d $($Metrics.Uptime.Hours)h $($Metrics.Uptime.Minutes)m" -ForegroundColor Yellow

    if ($Metrics.Temperature) {
        $tempColor = if ($Metrics.Temperature -gt $MONITORING_CONFIG.Temperature_Threshold) { "Red" } else { "Green" }
        Write-Host "Temp:     " -NoNewline
        Write-Host "$($Metrics.Temperature)°C" -ForegroundColor $tempColor
    }

    Write-Host ""
}

# Display performance charts
function Show-PerformanceCharts {
    param([hashtable]$Metrics)

    Write-Host "📈 PERFORMANCE CHARTS" -ForegroundColor Green
    Write-Host "────────────────────────────────────────────────" -ForegroundColor Green

    # CPU Chart
    Write-Host "CPU Usage:" -ForegroundColor Yellow
    Show-ASCIIChart -Value $Metrics.CPU_Usage -Max 100 -Width 50 -Color "Red"

    # Memory Chart
    Write-Host "Memory Usage:" -ForegroundColor Yellow
    Show-ASCIIChart -Value $Metrics.Memory_Usage -Max 100 -Width 50 -Color "Blue"

    # Disk Chart
    Write-Host "Disk Usage:" -ForegroundColor Yellow
    Show-ASCIIChart -Value $Metrics.Disk_Usage -Max 100 -Width 50 -Color "Green"

    Write-Host ""
}

# Display process monitor
function Show-ProcessMonitor {
    param([hashtable]$Metrics)

    Write-Host "🔄 TOP PROCESSES" -ForegroundColor Green
    Write-Host "────────────────────────────────────────────────" -ForegroundColor Green
    Write-Host "Name".PadRight(20) "CPU".PadRight(10) "Memory (MB)".PadRight(15) "Status" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────" -ForegroundColor Gray

    foreach ($process in $Metrics.Top_Processes) {
        $status = if ($process.Responding) { "Running" } else { "Not Responding" }
        $statusColor = if ($process.Responding) { "Green" } else { "Red" }

        Write-Host $process.Name.PadRight(20) -NoNewline
        Write-Host $process.CPU.ToString().PadRight(10) -NoNewline
        Write-Host $process.MemoryMB.ToString().PadRight(15) -NoNewline
        Write-Host $status -ForegroundColor $statusColor
    }

    Write-Host ""
}

# Display alerts
function Show-Alerts {
    param([hashtable]$Metrics)

    $alerts = @()

    # Check for alerts
    if ($Metrics.CPU_Usage -gt $MONITORING_CONFIG.CPU_Threshold) {
        $alerts += "⚠️  High CPU Usage: $($Metrics.CPU_Usage)%"
    }

    if ($Metrics.Memory_Usage -gt $MONITORING_CONFIG.Memory_Threshold) {
        $alerts += "⚠️  High Memory Usage: $($Metrics.Memory_Usage)%"
    }

    if ($Metrics.Disk_Usage -gt $MONITORING_CONFIG.Disk_Threshold) {
        $alerts += "⚠️  Low Disk Space: $($Metrics.Disk_Usage)% used"
    }

    if ($Metrics.Temperature -and $Metrics.Temperature -gt $MONITORING_CONFIG.Temperature_Threshold) {
        $alerts += "⚠️  High Temperature: $($Metrics.Temperature)°C"
    }

    if ($alerts.Count -gt 0) {
        Write-Host "🚨 ALERTS" -ForegroundColor Red
        Write-Host "────────────────────────────────────────────────" -ForegroundColor Red
        foreach ($alert in $alerts) {
            Write-Host $alert -ForegroundColor Red
        }
        Write-Host ""
    }
}

# Show progress bar
function Show-ProgressBar {
    param(
        [double]$Value,
        [double]$Max = 100,
        [string]$Color = "Green",
        [int]$Width = 20
    )

    $percentage = [math]::Round(($Value / $Max) * 100, 1)
    $filledWidth = [math]::Round(($Value / $Max) * $Width)

    Write-Host "[" -NoNewline
    for ($i = 0; $i -lt $Width; $i++) {
        if ($i -lt $filledWidth) {
            Write-Host "█" -ForegroundColor $Color -NoNewline
        } else {
            Write-Host "░" -ForegroundColor Gray -NoNewline
        }
    }
    Write-Host "] $percentage%" -NoNewline
    Write-Host ""
}

# Show ASCII chart
function Show-ASCIIChart {
    param(
        [double]$Value,
        [double]$Max = 100,
        [string]$Color = "Green",
        [int]$Width = 50
    )

    $filledWidth = [math]::Round(($Value / $Max) * $Width)

    for ($i = 0; $i -lt $Width; $i++) {
        if ($i -lt $filledWidth) {
            Write-Host "█" -ForegroundColor $Color -NoNewline
        } else {
            Write-Host "░" -ForegroundColor Gray -NoNewline
        }
    }
    Write-Host " $Value%" -ForegroundColor $Color
}

# Show alert history
function Show-AlertHistory {
    Clear-Host
    Write-Host "🚨 ALERT HISTORY" -ForegroundColor Red
    Write-Host "=================" -ForegroundColor Red
    Write-Host ""

    if ($HISTORICAL_DATA.Alerts.Count -gt 0) {
        foreach ($alert in $HISTORICAL_DATA.Alerts) {
            Write-Host "$($alert.Timestamp): $($alert.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No alerts recorded." -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Press any key to return to dashboard..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Generate performance report
function Generate-PerformanceReport {
    param(
        [string]$OutputPath = ".\performance-report.html"
    )

    $metrics = Get-SystemMetrics
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>DevOptimizer Performance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .metric { background-color: #ecf0f1; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .alert { background-color: #e74c3c; color: white; padding: 10px; border-radius: 5px; }
        .good { background-color: #27ae60; color: white; padding: 10px; border-radius: 5px; }
        .warning { background-color: #f39c12; color: white; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 DevOptimizer Performance Report</h1>
        <p>Generated: $timestamp</p>
    </div>

    <div class="metric">
        <h3>🖥️ System Overview</h3>
        <p><strong>CPU Usage:</strong> $($metrics.CPU_Usage)%</p>
        <p><strong>Memory Usage:</strong> $($metrics.Memory_Usage)% ($($metrics.Memory_Available)GB / $($metrics.Memory_Total)GB)</p>
        <p><strong>Disk Usage:</strong> $($metrics.Disk_Usage)% ($($metrics.Disk_Free)GB / $($metrics.Disk_Total)GB)</p>
        <p><strong>System Uptime:</strong> $($metrics.Uptime.Days) days, $($metrics.Uptime.Hours) hours, $($metrics.Uptime.Minutes) minutes</p>
    </div>

    <div class="metric">
        <h3>🔄 Top Processes</h3>
        <ul>
"@

    foreach ($process in $metrics.Top_Processes) {
        $html += "<li><strong>$($process.Name):</strong> CPU: $($process.CPU)%, Memory: $($process.MemoryMB)MB</li>"
    }

    $html += @"
        </ul>
    </div>

    <div class="metric">
        <h3>🌐 Network Activity</h3>
        <p><strong>Bytes Sent:</strong> $($metrics.Network_Sent) KB/s</p>
        <p><strong>Bytes Received:</strong> $($metrics.Network_Received) KB/s</p>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "📊 Performance report generated: $OutputPath" -ForegroundColor Green
}

# Main execution
switch ($Mode) {
    "dashboard" {
        Show-RealtimeDashboard -RefreshInterval $RefreshInterval
    }
    "report" {
        Generate-PerformanceReport
    }
    "metrics" {
        $metrics = Get-SystemMetrics
        $metrics | ConvertTo-Json -Depth 3
    }
    "alerts" {
        Show-AlertHistory
    }
}

Write-Host "`n📊 Real-time Monitoring Module completed!" -ForegroundColor Green
