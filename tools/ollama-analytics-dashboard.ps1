# DevOptimizer System - Ollama Real-Time Analytics Dashboard
# Interactive real-time monitoring dashboard for Ollama operations

param(
    [int]$UpdateInterval = 5,
    [switch]$FullScreen = $false,
    [switch]$ExportData = $false,
    [string]$ExportFormat = "JSON"
)

# Import required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath = Join-Path $scriptDir "..\modules"

. (Join-Path $modulesPath "ollama-analytics.ps1")

# Global variables for dashboard
$Global:DashboardRunning = $true
$Global:LastUpdate = Get-Date

function Write-DashboardHeader {
    Clear-Host
    Write-Host "==================================================================================" -ForegroundColor Cyan
    Write-Host "                    DEVOPTIMIZER OLLAMA REAL-TIME ANALYTICS DASHBOARD" -ForegroundColor Yellow
    Write-Host "==================================================================================" -ForegroundColor Cyan
    Write-Host "Session Started: $($Global:AnalyticsData.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
    Write-Host "Last Update: $($Global:LastUpdate.ToString('HH:mm:ss')) | Update Interval: ${UpdateInterval}s" -ForegroundColor Green
    Write-Host "Press 'Q' to quit, 'E' to export data, 'H' for help" -ForegroundColor Gray
    Write-Host "==================================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-SystemMetrics {
    param([hashtable]$SystemMetrics)
    
    Write-Host "🖥️  SYSTEM METRICS" -ForegroundColor Yellow
    Write-Host "──────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    if ($SystemMetrics.CPU) {
        $cpuColor = if ($SystemMetrics.CPU.Usage -gt 80) { "Red" } elseif ($SystemMetrics.CPU.Usage -gt 60) { "Yellow" } else { "Green" }
        Write-Host "CPU Usage: " -NoNewline -ForegroundColor White
        Write-Host "$($SystemMetrics.CPU.Usage)%" -ForegroundColor $cpuColor
        Write-Host "  Cores: $($SystemMetrics.CPU.Cores) | Logical: $($SystemMetrics.CPU.LogicalProcessors)" -ForegroundColor Gray
    }
    
    if ($SystemMetrics.Memory) {
        $memColor = if ($SystemMetrics.Memory.UsagePercent -gt 85) { "Red" } elseif ($SystemMetrics.Memory.UsagePercent -gt 70) { "Yellow" } else { "Green" }
        Write-Host "Memory: " -NoNewline -ForegroundColor White
        Write-Host "$($SystemMetrics.Memory.Used)GB / $($SystemMetrics.Memory.Total)GB ($($SystemMetrics.Memory.UsagePercent)%)" -ForegroundColor $memColor
    }
    
    if ($SystemMetrics.Disk) {
        Write-Host "Disk Usage:" -ForegroundColor White
        foreach ($drive in $SystemMetrics.Disk.Keys) {
            $disk = $SystemMetrics.Disk[$drive]
            $diskColor = if ($disk.UsagePercent -gt 90) { "Red" } elseif ($disk.UsagePercent -gt 80) { "Yellow" } else { "Green" }
            Write-Host "  $drive : $($disk.Used)GB / $($disk.Total)GB ($($disk.UsagePercent)%)" -ForegroundColor $diskColor
        }
    }
    
    if ($SystemMetrics.Network) {
        Write-Host "Network: " -NoNewline -ForegroundColor White
        Write-Host "$($SystemMetrics.Network.Adapters) adapters active" -ForegroundColor Green
    }
    
    Write-Host ""
}

function Write-OllamaMetrics {
    param([hashtable]$OllamaMetrics)
    
    Write-Host "🤖 OLLAMA METRICS" -ForegroundColor Yellow
    Write-Host "──────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    # Health Status
    $healthColor = if ($OllamaMetrics.Health.IsHealthy) { "Green" } else { "Red" }
    Write-Host "Server Health: " -NoNewline -ForegroundColor White
    Write-Host "$(if ($OllamaMetrics.Health.IsHealthy) { 'HEALTHY' } else { 'UNHEALTHY' })" -ForegroundColor $healthColor
    
    # Response Time
    $responseColor = if ($OllamaMetrics.Health.ResponseTime -gt 5000) { "Red" } elseif ($OllamaMetrics.Health.ResponseTime -gt 2000) { "Yellow" } else { "Green" }
    Write-Host "Response Time: " -NoNewline -ForegroundColor White
    Write-Host "$($OllamaMetrics.Health.ResponseTime)ms" -ForegroundColor $responseColor
    
    # Models
    Write-Host "Models Available: " -NoNewline -ForegroundColor White
    Write-Host "$($OllamaMetrics.Health.ModelsAvailable)" -ForegroundColor Green
    
    # Server Info
    if ($OllamaMetrics.Server) {
        Write-Host "Server Version: " -NoNewline -ForegroundColor White
        Write-Host "$($OllamaMetrics.Server.Version)" -ForegroundColor Cyan
        Write-Host "Server Status: " -NoNewline -ForegroundColor White
        Write-Host "$($OllamaMetrics.Server.Status)" -ForegroundColor Cyan
    }
    
    # Model Details
    if ($OllamaMetrics.Models -and $OllamaMetrics.Models.ModelDetails) {
        Write-Host "Model Details:" -ForegroundColor White
        foreach ($model in $OllamaMetrics.Models.ModelDetails) {
            $size = if ($model.Details.Size) { [math]::Round($model.Details.Size / 1GB, 2) } else { "Unknown" }
            Write-Host "  • $($model.Name) (${size}GB)" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
}

function Write-PerformanceMetrics {
    param([hashtable]$PerformanceMetrics)
    
    Write-Host "📊 PERFORMANCE SUMMARY" -ForegroundColor Yellow
    Write-Host "──────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    if ($PerformanceMetrics.Uptime) {
        Write-Host "Session Uptime: " -NoNewline -ForegroundColor White
        Write-Host "$($PerformanceMetrics.Uptime)s" -ForegroundColor Green
    }
    
    if ($PerformanceMetrics.AverageCPU) {
        Write-Host "Average CPU: " -NoNewline -ForegroundColor White
        Write-Host "$($PerformanceMetrics.AverageCPU)%" -ForegroundColor Green
    }
    
    if ($PerformanceMetrics.AverageMemory) {
        Write-Host "Average Memory: " -NoNewline -ForegroundColor White
        Write-Host "$($PerformanceMetrics.AverageMemory)%" -ForegroundColor Green
    }
    
    if ($PerformanceMetrics.AverageResponseTime) {
        Write-Host "Average Response: " -NoNewline -ForegroundColor White
        Write-Host "$($PerformanceMetrics.AverageResponseTime)ms" -ForegroundColor Green
    }
    
    if ($PerformanceMetrics.DataPoints) {
        Write-Host "Data Points Collected: " -NoNewline -ForegroundColor White
        Write-Host "$($PerformanceMetrics.DataPoints)" -ForegroundColor Green
    }
    
    Write-Host ""
}

function Write-Alerts {
    param([array]$Alerts)
    
    if ($Alerts -and $Alerts.Count -gt 0) {
        Write-Host "🚨 ACTIVE ALERTS" -ForegroundColor Red
        Write-Host "──────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
        
        foreach ($alert in $Alerts) {
            $alertColor = if ($alert.Level -eq "ERROR") { "Red" } else { "Yellow" }
            Write-Host "[$($alert.Level)] $($alert.Message)" -ForegroundColor $alertColor
            if ($alert.Errors) {
                foreach ($error in $alert.Errors) {
                    Write-Host "  → $error" -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }
}

function Write-KeyBindings {
    Write-Host "⌨️  KEY BINDINGS" -ForegroundColor Yellow
    Write-Host "──────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "Q - Quit dashboard" -ForegroundColor White
    Write-Host "E - Export current data" -ForegroundColor White
    Write-Host "R - Refresh immediately" -ForegroundColor White
    Write-Host "H - Show this help" -ForegroundColor White
    Write-Host "C - Clear alerts" -ForegroundColor White
    Write-Host ""
}

function Show-Help {
    Clear-Host
    Write-Host "==================================================================================" -ForegroundColor Cyan
    Write-Host "                           OLLAMA ANALYTICS DASHBOARD HELP" -ForegroundColor Yellow
    Write-Host "==================================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This dashboard provides real-time monitoring of:" -ForegroundColor White
    Write-Host "• System performance (CPU, Memory, Disk, Network)" -ForegroundColor Green
    Write-Host "• Ollama server health and response times" -ForegroundColor Green
    Write-Host "• Model availability and status" -ForegroundColor Green
    Write-Host "• Performance trends and alerts" -ForegroundColor Green
    Write-Host ""
    Write-Host "Key Bindings:" -ForegroundColor White
    Write-KeyBindings
    Write-Host "Configuration:" -ForegroundColor White
    Write-Host "• Update interval: $UpdateInterval seconds" -ForegroundColor Gray
    Write-Host "• Data retention: Last 100 data points" -ForegroundColor Gray
    Write-Host "• Alert thresholds: Configurable in system-config.json" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press any key to return to dashboard..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Update-Dashboard {
    try {
        # Collect metrics
        $systemMetrics = Get-SystemMetrics
        $ollamaMetrics = Get-OllamaMetrics
        
        if ($systemMetrics -and $ollamaMetrics) {
            # Update performance tracking
            Update-PerformanceMetrics -SystemMetrics $systemMetrics -OllamaMetrics $ollamaMetrics
            
            # Check for alerts
            $alerts = Test-AlertThresholds -SystemMetrics $systemMetrics -OllamaMetrics $ollamaMetrics
            
            # Display dashboard
            Write-DashboardHeader
            Write-SystemMetrics -SystemMetrics $systemMetrics
            Write-OllamaMetrics -SystemMetrics $ollamaMetrics
            Write-PerformanceMetrics -PerformanceMetrics $Global:AnalyticsData.Metrics.Performance
            Write-Alerts -Alerts $alerts
            
            $Global:LastUpdate = Get-Date
        }
        else {
            Write-Host "❌ Failed to collect metrics. Check Ollama server status." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error updating dashboard: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Handle-UserInput {
    if ($Host.UI.RawUI.KeyAvailable) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.Character.ToString().ToUpper()) {
            'Q' {
                Write-AnalyticsLog "Dashboard stopped by user" -Level "INFO"
                $Global:DashboardRunning = $false
                return
            }
            'E' {
                $exportPath = Export-AnalyticsData -OutputPath "D:\DevOptimizer\logs\analytics" -Format $ExportFormat
                if ($exportPath) {
                    Write-Host "✅ Data exported to: $exportPath" -ForegroundColor Green
                }
                else {
                    Write-Host "❌ Export failed" -ForegroundColor Red
                }
                Start-Sleep -Seconds 2
            }
            'R' {
                Write-AnalyticsLog "Manual refresh requested" -Level "INFO"
                Update-Dashboard
            }
            'H' {
                Show-Help
            }
            'C' {
                $Global:AnalyticsData.Metrics.Alerts = @()
                Write-Host "✅ Alerts cleared" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Start-AnalyticsDashboard {
    <#
    .SYNOPSIS
    Starts the real-time analytics dashboard
    #>
    
    Write-AnalyticsLog "Starting Ollama Analytics Dashboard" -Level "INFO"
    
    # Initialize analytics
    if (-not (Initialize-Analytics)) {
        Write-Host "❌ Failed to initialize analytics system" -ForegroundColor Red
        return
    }
    
    # Initial update
    Update-Dashboard
    
    # Main loop
    while ($Global:DashboardRunning) {
        $startTime = Get-Date
        
        # Handle user input
        Handle-UserInput
        
        if (-not $Global:DashboardRunning) {
            break
        }
        
        # Wait for next update
        $elapsed = (Get-Date - $startTime).TotalSeconds
        $sleepTime = $UpdateInterval - $elapsed
        
        if ($sleepTime -gt 0) {
            Start-Sleep -Seconds $sleepTime
        }
        
        # Update dashboard
        Update-Dashboard
    }
    
    Write-AnalyticsLog "Analytics dashboard stopped" -Level "INFO"
    Write-Host "`n✅ Analytics session ended. Data saved." -ForegroundColor Green
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Start-AnalyticsDashboard
    }
    catch {
        Write-Host "❌ Fatal error in dashboard: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
