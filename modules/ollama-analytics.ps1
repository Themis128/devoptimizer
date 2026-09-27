# DevOptimizer System - Ollama Real-Time Analytics Module
# Provides comprehensive real-time monitoring and analytics for Ollama operations

param(
    [string]$ServerUrl = "http://127.0.0.1:11434",
    [int]$UpdateInterval = 5,
    [string]$LogLevel = "INFO"
)

# Import required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath = $scriptDir

. (Join-Path $modulesPath "config-loader.ps1")
. (Join-Path $modulesPath "ollama-rest.ps1")

# Global variables for analytics
$Global:AnalyticsData = @{
    StartTime = Get-Date
    Metrics = @{
        System = @{}
        Ollama = @{}
        Performance = @{}
        Alerts = @()
    }
    History = @()
    Config = $null
}

function Write-AnalyticsLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [Analytics] [$Level] $Message"

    switch ($Level.ToUpper()) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
}

function Initialize-Analytics {
    <#
    .SYNOPSIS
    Initializes the analytics system with configuration
    #>
    
    try {
        $Global:AnalyticsData.Config = Get-SystemConfiguration
        Write-AnalyticsLog "Analytics system initialized" -Level "INFO"
        return $true
    }
    catch {
        Write-AnalyticsLog "Failed to initialize analytics: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-SystemMetrics {
    <#
    .SYNOPSIS
    Collects real-time system metrics
    #>
    
    $metrics = @{
        Timestamp = Get-Date
        CPU = @{}
        Memory = @{}
        Disk = @{}
        Network = @{}
        Processes = @{}
    }

    try {
        # CPU Metrics
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
        if ($cpu) {
            $metrics.CPU = @{
                Usage = [math]::Round($cpu.CounterSamples.CookedValue, 2)
                Cores = (Get-CimInstance -ClassName Win32_Processor).NumberOfCores
                LogicalProcessors = (Get-CimInstance -ClassName Win32_Processor).NumberOfLogicalProcessors
            }
        }

        # Memory Metrics
        $memory = Get-CimInstance -ClassName Win32_OperatingSystem
        $totalMemory = [math]::Round($memory.TotalVisibleMemorySize / 1MB, 2)
        $freeMemory = [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
        $usedMemory = $totalMemory - $freeMemory
        
        $metrics.Memory = @{
            Total = $totalMemory
            Used = [math]::Round($usedMemory, 2)
            Free = $freeMemory
            UsagePercent = [math]::Round(($usedMemory / $totalMemory) * 100, 2)
        }

        # Disk Metrics
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        $metrics.Disk = @{}
        foreach ($disk in $disks) {
            $total = [math]::Round($disk.Size / 1GB, 2)
            $free = [math]::Round($disk.FreeSpace / 1GB, 2)
            $used = $total - $free
            $metrics.Disk[$disk.DeviceID] = @{
                Total = $total
                Used = [math]::Round($used, 2)
                Free = $free
                UsagePercent = [math]::Round(($used / $total) * 100, 2)
            }
        }

        # Network Metrics
        $networkAdapters = Get-CimInstance -ClassName Win32_PerfRawData_Tcpip_NetworkInterface | Where-Object { $_.Name -notlike "*Loopback*" -and $_.Name -notlike "*isatap*" }
        $metrics.Network = @{
            Adapters = $networkAdapters.Count
            BytesReceived = ($networkAdapters | Measure-Object -Property BytesReceivedPerSec -Sum).Sum
            BytesSent = ($networkAdapters | Measure-Object -Property BytesSentPerSec -Sum).Sum
        }

        # Process Metrics
        $ollamaProcess = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
        $metrics.Processes = @{
            OllamaRunning = $ollamaProcess -ne $null
            OllamaPID = if ($ollamaProcess) { $ollamaProcess.Id } else { $null }
            OllamaMemory = if ($ollamaProcess) { [math]::Round($ollamaProcess.WorkingSet / 1MB, 2) } else { 0 }
            TotalProcesses = (Get-Process).Count
        }

        return $metrics
    }
    catch {
        Write-AnalyticsLog "Error collecting system metrics: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-OllamaMetrics {
    <#
    .SYNOPSIS
    Collects Ollama-specific metrics via REST API
    #>
    
    $metrics = @{
        Timestamp = Get-Date
        Server = @{}
        Models = @{}
        Performance = @{}
        Health = @{}
    }

    try {
        # Server Health
        $health = Test-OllamaServerHealth -ServerUrl $ServerUrl
        $metrics.Health = @{
            IsHealthy = $health.IsHealthy
            ResponseTime = $health.ResponseTime
            ModelsAvailable = $health.Models.Count
            Errors = $health.Errors
        }

        # Server Info
        $serverInfo = Get-OllamaServerInfo -ServerUrl $ServerUrl -ErrorAction SilentlyContinue
        if ($serverInfo) {
            $metrics.Server = @{
                Version = $serverInfo.Version
                Status = $serverInfo.Status
                Uptime = if ($serverInfo.Uptime) { $serverInfo.Uptime } else { "Unknown" }
            }
        }

        # Model Information
        $models = Get-OllamaModels -ServerUrl $ServerUrl -ErrorAction SilentlyContinue
        if ($models) {
            $metrics.Models = @{
                TotalModels = $models.Count
                LoadedModels = ($models | Where-Object { $_.Details.Size -gt 0 }).Count
                ModelDetails = $models
            }
        }

        # Performance Metrics
        $metrics.Performance = @{
            LastResponseTime = $Global:AnalyticsData.Metrics.Ollama.LastResponseTime
            AverageResponseTime = $Global:AnalyticsData.Metrics.Ollama.AverageResponseTime
            TotalRequests = $Global:AnalyticsData.Metrics.Ollama.TotalRequests
            ErrorRate = $Global:AnalyticsData.Metrics.Ollama.ErrorRate
        }

        return $metrics
    }
    catch {
        Write-AnalyticsLog "Error collecting Ollama metrics: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Update-PerformanceMetrics {
    param(
        [hashtable]$SystemMetrics,
        [hashtable]$OllamaMetrics
    )

    try {
        $currentTime = Get-Date
        $elapsed = ($currentTime - $Global:AnalyticsData.StartTime).TotalSeconds

        # Update performance tracking
        if (-not $Global:AnalyticsData.Metrics.Performance.ContainsKey("StartTime")) {
            $Global:AnalyticsData.Metrics.Performance.StartTime = $Global:AnalyticsData.StartTime
        }

        # Calculate averages
        $historyCount = $Global:AnalyticsData.History.Count
        if ($historyCount -gt 0) {
            $avgCpu = ($Global:AnalyticsData.History | ForEach-Object { $_.System.CPU.Usage } | Measure-Object -Average).Average
            $avgMemory = ($Global:AnalyticsData.History | ForEach-Object { $_.System.Memory.UsagePercent } | Measure-Object -Average).Average
            $avgResponse = ($Global:AnalyticsData.History | ForEach-Object { $_.Ollama.Health.ResponseTime } | Measure-Object -Average).Average

            $Global:AnalyticsData.Metrics.Performance = @{
                StartTime = $Global:AnalyticsData.StartTime
                Uptime = [math]::Round($elapsed, 2)
                AverageCPU = [math]::Round($avgCpu, 2)
                AverageMemory = [math]::Round($avgMemory, 2)
                AverageResponseTime = [math]::Round($avgResponse, 2)
                DataPoints = $historyCount
            }
        }

        # Store current metrics
        $Global:AnalyticsData.Metrics.System = $SystemMetrics
        $Global:AnalyticsData.Metrics.Ollama = $OllamaMetrics

        # Add to history (keep last 100 points)
        $Global:AnalyticsData.History += @{
            Timestamp = $currentTime
            System = $SystemMetrics
            Ollama = $OllamaMetrics
        }

        if ($Global:AnalyticsData.History.Count -gt 100) {
            $Global:AnalyticsData.History = $Global:AnalyticsData.History[-100..-1]
        }

    }
    catch {
        Write-AnalyticsLog "Error updating performance metrics: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Test-AlertThresholds {
    param(
        [hashtable]$SystemMetrics,
        [hashtable]$OllamaMetrics
    )

    $alerts = @()
    $config = $Global:AnalyticsData.Config.ollama.analytics

    if (-not $config.alerts.enabled) {
        return $alerts
    }

    try {
        # CPU Alert
        if ($config.alerts.thresholds.highCpuUsage -and $SystemMetrics.CPU.Usage -gt $config.alerts.thresholds.highCpuUsage) {
            $alerts += @{
                Type = "CPU"
                Level = "WARNING"
                Message = "High CPU usage: $($SystemMetrics.CPU.Usage)%"
                Value = $SystemMetrics.CPU.Usage
                Threshold = $config.alerts.thresholds.highCpuUsage
                Timestamp = Get-Date
            }
        }

        # Memory Alert
        if ($config.alerts.thresholds.highMemoryUsage -and $SystemMetrics.Memory.UsagePercent -gt $config.alerts.thresholds.highMemoryUsage) {
            $alerts += @{
                Type = "MEMORY"
                Level = "WARNING"
                Message = "High memory usage: $($SystemMetrics.Memory.UsagePercent)%"
                Value = $SystemMetrics.Memory.UsagePercent
                Threshold = $config.alerts.thresholds.highMemoryUsage
                Timestamp = Get-Date
            }
        }

        # Response Time Alert
        if ($config.alerts.thresholds.slowResponse -and $OllamaMetrics.Health.ResponseTime -gt $config.alerts.thresholds.slowResponse) {
            $alerts += @{
                Type = "RESPONSE"
                Level = "WARNING"
                Message = "Slow Ollama response: $($OllamaMetrics.Health.ResponseTime)ms"
                Value = $OllamaMetrics.Health.ResponseTime
                Threshold = $config.alerts.thresholds.slowResponse
                Timestamp = Get-Date
            }
        }

        # Ollama Health Alert
        if (-not $OllamaMetrics.Health.IsHealthy) {
            $alerts += @{
                Type = "HEALTH"
                Level = "ERROR"
                Message = "Ollama server is not healthy"
                Errors = $OllamaMetrics.Health.Errors
                Timestamp = Get-Date
            }
        }

        # Update alerts in global data
        $Global:AnalyticsData.Metrics.Alerts = $alerts

        # Display alerts
        foreach ($alert in $alerts) {
            $color = if ($alert.Level -eq "ERROR") { "Red" } else { "Yellow" }
            Write-Host "[ALERT] $($alert.Message)" -ForegroundColor $color
        }

        return $alerts
    }
    catch {
        Write-AnalyticsLog "Error checking alert thresholds: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Export-AnalyticsData {
    param(
        [string]$OutputPath = "D:\DevOptimizer\logs\analytics",
        [string]$Format = "JSON"
    )

    try {
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        
        if ($Format -eq "JSON") {
            $filePath = Join-Path $OutputPath "analytics-$timestamp.json"
            $Global:AnalyticsData | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
        }
        elseif ($Format -eq "CSV") {
            $filePath = Join-Path $OutputPath "analytics-$timestamp.csv"
            $Global:AnalyticsData.History | ForEach-Object {
                [PSCustomObject]@{
                    Timestamp = $_.Timestamp
                    CPUUsage = $_.System.CPU.Usage
                    MemoryUsage = $_.System.Memory.UsagePercent
                    ResponseTime = $_.Ollama.Health.ResponseTime
                    OllamaHealthy = $_.Ollama.Health.IsHealthy
                    ModelsAvailable = $_.Ollama.Health.ModelsAvailable
                }
            } | Export-Csv -Path $filePath -NoTypeInformation
        }

        Write-AnalyticsLog "Analytics data exported to: $filePath" -Level "INFO"
        return $filePath
    }
    catch {
        Write-AnalyticsLog "Error exporting analytics data: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-AnalyticsSummary {
    <#
    .SYNOPSIS
    Returns a summary of current analytics data
    #>
    
    $summary = @{
        Session = @{
            StartTime = $Global:AnalyticsData.StartTime
            Uptime = [math]::Round((Get-Date - $Global:AnalyticsData.StartTime).TotalSeconds, 2)
            DataPoints = $Global:AnalyticsData.History.Count
        }
        Current = @{
            System = $Global:AnalyticsData.Metrics.System
            Ollama = $Global:AnalyticsData.Metrics.Ollama
            Performance = $Global:AnalyticsData.Metrics.Performance
        }
        Alerts = $Global:AnalyticsData.Metrics.Alerts
        Config = $Global:AnalyticsData.Config.ollama.analytics
    }

    return $summary
}

# Export functions for module usage
if ($MyInvocation.MyCommand.Module) {
    Export-ModuleMember -Function @(
        'Initialize-Analytics',
        'Get-SystemMetrics',
        'Get-OllamaMetrics',
        'Update-PerformanceMetrics',
        'Test-AlertThresholds',
        'Export-AnalyticsData',
        'Get-AnalyticsSummary',
        'Write-AnalyticsLog'
    )
}
