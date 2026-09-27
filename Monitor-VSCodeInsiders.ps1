#Requires -Version 5.1
<#
.SYNOPSIS
    VS Code Insiders Monitor - Real-time process and memory tracking
.DESCRIPTION
    Monitors VS Code Insiders processes in real-time, alerts when memory exceeds
    thresholds, and can auto-cleanup when needed.
.PARAMETER MonitorInterval
    Seconds between checks (default: 5)
.PARAMETER WarningThreshold
    Memory MB to trigger warning (default: 2000)
.PARAMETER CriticalThreshold
    Memory MB to trigger auto-cleanup (default: 4000)
.PARAMETER AutoCleanup
    Automatically cleanup when critical threshold reached
.PARAMETER Duration
    How long to monitor in minutes (default: continuous)
.EXAMPLE
    .\Monitor-VSCodeInsiders.ps1
    Monitor with default settings
.EXAMPLE
    .\Monitor-VSCodeInsiders.ps1 -AutoCleanup -CriticalThreshold 3000
    Auto-cleanup if memory exceeds 3GB
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Seconds between checks")]
    [ValidateRange(1, 300)]
    [int]$MonitorInterval = 5,
    
    [Parameter(HelpMessage = "Warning threshold in MB")]
    [int]$WarningThreshold = 2000,
    
    [Parameter(HelpMessage = "Critical threshold in MB")]
    [int]$CriticalThreshold = 4000,
    
    [Parameter(HelpMessage = "Auto-cleanup at critical threshold")]
    [switch]$AutoCleanup,
    
    [Parameter(HelpMessage = "Monitor duration in minutes (0 = continuous)")]
    [int]$Duration = 0
)

$script:MemoryHistory = @()
$script:MaxHistoryPoints = 50
$script:StartTime = Get-Date
$script:CleanupCount = 0

function Get-VSCodeInsidersProcesses {
    $processNames = @("Code - Insiders", "code-insiders", "Code")
    $allProcesses = @()
    
    foreach ($name in $processNames) {
        $found = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($found) {
            $allProcesses += $found
        }
    }
    
    return $allProcesses | Where-Object { 
        $_.Path -like "*Code - Insiders*" -or 
        $_.Path -like "*Code Insiders*" -or
        $_.MainWindowTitle -like "*Visual Studio Code - Insiders*"
    }
}

function Get-MemoryTrend {
    if ($script:MemoryHistory.Count -lt 2) {
        return "STABLE"
    }
    
    $recent = $script:MemoryHistory | Select-Object -Last 5
    $avg = ($recent | Measure-Object -Average).Average
    $current = $recent[-1]
    
    $percentChange = (($current - $avg) / $avg) * 100
    
    if ($percentChange -gt 10) { return "INCREASING ↑" }
    elseif ($percentChange -lt -10) { return "DECREASING ↓" }
    else { return "STABLE →" }
}

function Show-MonitorHeader {
    Clear-Host
    $runtime = [math]::Round(((Get-Date) - $script:StartTime).TotalMinutes, 1)
    
    Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       VS Code Insiders Real-Time Monitor & Auto-Cleanup          ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Runtime: $runtime min  |  Cleanups: $script:CleanupCount  |  Interval: $MonitorInterval sec" -ForegroundColor Gray
    Write-Host "  Warning: $WarningThreshold MB  |  Critical: $CriticalThreshold MB  |  Auto-Cleanup: $AutoCleanup" -ForegroundColor Gray
    Write-Host ""
}

function Show-ProcessStatus {
    param($Processes, $TotalMemoryMB)
    
    $trend = Get-MemoryTrend
    $color = "Green"
    $status = "✓ NORMAL"
    
    if ($TotalMemoryMB -ge $CriticalThreshold) {
        $color = "Red"
        $status = "✗ CRITICAL"
    } elseif ($TotalMemoryMB -ge $WarningThreshold) {
        $color = "Yellow"
        $status = "⚠ WARNING"
    }
    
    Write-Host "  Status: $status" -ForegroundColor $color -NoNewline
    Write-Host "  |  Trend: $trend" -ForegroundColor $(if($trend -like "*↑") {"Red"} elseif($trend -like "*↓") {"Green"} else {"Yellow"})
    Write-Host ""
    
    if ($Processes) {
        $count = ($Processes | Measure-Object).Count
        $mainWindows = @($Processes | Where-Object { $_.MainWindowTitle }).Count
        $background = $count - $mainWindows
        
        Write-Host "  📊 Processes: $count total ($mainWindows windows, $background background)" -ForegroundColor Cyan
        Write-Host "  💾 Memory: $TotalMemoryMB MB ($([math]::Round($TotalMemoryMB/1024,2)) GB)" -ForegroundColor $(if($TotalMemoryMB -ge $CriticalThreshold){"Red"} elseif($TotalMemoryMB -ge $WarningThreshold){"Yellow"} else{"Green"})
        
        # Show memory graph
        Show-MemoryGraph
        
        # Show top 5 processes
        Write-Host "`n  🔝 Top Memory Consumers:" -ForegroundColor Cyan
        $Processes | 
            Select-Object @{Name="PID";Expression={$_.Id}},
                          @{Name="MB";Expression={[math]::Round($_.WorkingSet64 / 1MB, 0)}},
                          @{Name="Title";Expression={
                              if($_.MainWindowTitle) {
                                  $_.MainWindowTitle.Substring(0,[Math]::Min(45,$_.MainWindowTitle.Length))
                              } else {
                                  "<Background Process>"
                              }
                          }} |
            Sort-Object MB -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                $color = if($_.MB -gt 500) {"Red"} elseif($_.MB -gt 300) {"Yellow"} else {"Gray"}
                Write-Host ("     {0,6} | {1,5} MB | {2}" -f $_.PID, $_.MB, $_.Title) -ForegroundColor $color
            }
    } else {
        Write-Host "  ✓ No VS Code Insiders processes running" -ForegroundColor Green
    }
}

function Show-MemoryGraph {
    if ($script:MemoryHistory.Count -lt 2) { return }
    
    $width = 50
    $height = 8
    $points = $script:MemoryHistory | Select-Object -Last $width
    
    if ($points.Count -lt 2) { return }
    
    $max = ($points | Measure-Object -Maximum).Maximum
    $min = ($points | Measure-Object -Minimum).Minimum
    $range = $max - $min
    
    if ($range -eq 0) { $range = 1 }
    
    Write-Host "`n  📈 Memory Trend (Last $($points.Count) samples):" -ForegroundColor Cyan
    
    # Draw graph
    for ($h = $height - 1; $h -ge 0; $h--) {
        $threshold = $min + ($range * $h / $height)
        Write-Host "  " -NoNewline
        
        foreach ($point in $points) {
            $normalized = ($point - $min) / $range * $height
            if ($normalized -ge $h) {
                $char = if($point -ge $CriticalThreshold) {"█"} elseif($point -ge $WarningThreshold) {"▓"} else {"░"}
                $color = if($point -ge $CriticalThreshold) {"Red"} elseif($point -ge $WarningThreshold) {"Yellow"} else {"Green"}
                Write-Host $char -NoNewline -ForegroundColor $color
            } else {
                Write-Host " " -NoNewline
            }
        }
        Write-Host ""
    }
    
    Write-Host "  $(" " * ($width + 2))" -NoNewline
    Write-Host "Min: $([math]::Round($min,0)) MB | Max: $([math]::Round($max,0)) MB" -ForegroundColor Gray
}

function Invoke-AutoCleanup {
    param($TotalMemoryMB)
    
    Write-Host "`n  🚨 CRITICAL THRESHOLD REACHED! Initiating auto-cleanup..." -ForegroundColor Red
    Write-Host "  Memory usage: $TotalMemoryMB MB (threshold: $CriticalThreshold MB)" -ForegroundColor Red
    
    $cleanupScript = "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1"
    
    if (Test-Path $cleanupScript) {
        try {
            & $cleanupScript -Force -Silent
            $script:CleanupCount++
            Write-Host "  ✓ Cleanup completed successfully!" -ForegroundColor Green
            Start-Sleep -Seconds 3
        } catch {
            Write-Host "  ✗ Cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ Cleanup script not found at: $cleanupScript" -ForegroundColor Red
    }
}

# Main monitoring loop
Write-Host "Starting VS Code Insiders Monitor..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop monitoring`n" -ForegroundColor Gray
Start-Sleep -Seconds 2

$endTime = if ($Duration -gt 0) {
    (Get-Date).AddMinutes($Duration)
} else {
    [DateTime]::MaxValue
}

try {
    while ((Get-Date) -lt $endTime) {
        $processes = Get-VSCodeInsidersProcesses
        
        if ($processes) {
            $totalMemoryMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
            $script:MemoryHistory += $totalMemoryMB
            
            if ($script:MemoryHistory.Count -gt $script:MaxHistoryPoints) {
                $script:MemoryHistory = $script:MemoryHistory | Select-Object -Last $script:MaxHistoryPoints
            }
            
            Show-MonitorHeader
            Show-ProcessStatus -Processes $processes -TotalMemoryMB $totalMemoryMB
            
            # Check for auto-cleanup
            if ($AutoCleanup -and $totalMemoryMB -ge $CriticalThreshold) {
                Invoke-AutoCleanup -TotalMemoryMB $totalMemoryMB
                # Clear history after cleanup
                $script:MemoryHistory = @()
            }
        } else {
            Show-MonitorHeader
            Show-ProcessStatus -Processes $null -TotalMemoryMB 0
            $script:MemoryHistory = @()
        }
        
        Write-Host "`n  ⏱️  Next check in $MonitorInterval seconds... (Ctrl+C to exit)" -ForegroundColor Gray
        Start-Sleep -Seconds $MonitorInterval
    }
    
    Write-Host "`n✓ Monitoring completed. Duration: $Duration minutes" -ForegroundColor Green
    
} catch {
    Write-Host "`n✗ Monitoring stopped: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Write-Host "`nFinal Statistics:" -ForegroundColor Cyan
    Write-Host "  Runtime: $([math]::Round(((Get-Date) - $script:StartTime).TotalMinutes, 1)) minutes" -ForegroundColor Gray
    Write-Host "  Auto-cleanups performed: $script:CleanupCount" -ForegroundColor Gray
    Write-Host "  Samples collected: $($script:MemoryHistory.Count)" -ForegroundColor Gray
}
