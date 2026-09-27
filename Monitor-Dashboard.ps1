<#
.SYNOPSIS
    VS Code Monitor Dashboard - Fixed Percentage Display
#>

param(
    [int]$RefreshSeconds = 5,
    [switch]$Continuous
)

function Show-Dashboard {
    Clear-Host
    
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "       VS CODE INSIDERS MONITORING DASHBOARD" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor Cyan
    
    # VS Code processes
    $processes = Get-Process -Name "Code - Insiders" -ErrorAction SilentlyContinue
    
    if ($processes) {
        $count = ($processes | Measure-Object).Count
        $totalMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
        $avgMB = [math]::Round($totalMB / $count, 2)
        $maxMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Maximum).Maximum / 1MB, 2)
        
        Write-Host "CURRENT STATUS" -ForegroundColor Yellow
        
        # Process count with health indicator
        $countColor = if($count -gt 15){"Red"}elseif($count -gt 10){"Yellow"}else{"Green"}
        $countStatus = if($count -gt 15){"OVER LIMIT"}elseif($count -gt 10){"WARNING"}else{"OK"}
        Write-Host "   Processes: " -NoNewline
        Write-Host "$count " -NoNewline -ForegroundColor $countColor
        Write-Host "($countStatus - Limit: 15)" -ForegroundColor $countColor
        
        # Memory with health indicator
        $threshold = 4096
        $memPercent = [math]::Round(($totalMB / $threshold) * 100, 1)
        $memColor = if($totalMB -gt $threshold){"Red"}elseif($totalMB -gt ($threshold * 0.75)){"Yellow"}else{"Green"}
        $memStatus = if($totalMB -gt $threshold){"OVER LIMIT"}elseif($totalMB -gt ($threshold * 0.75)){"WARNING"}else{"OK"}
        
        Write-Host "   Memory:    " -NoNewline
        Write-Host "$totalMB MB " -NoNewline -ForegroundColor $memColor
        Write-Host "($memStatus - Limit: $threshold MB)" -ForegroundColor $memColor
        Write-Host "   Average:   $avgMB MB per process"
        Write-Host "   Peak:      $maxMB MB (largest process)`n"
        
        # Memory bar - scale to show current vs threshold
        # If over 100%, show bar at 100% but display actual percentage
        $barPercent = [math]::Min(100, $memPercent)
        $filled = [math]::Floor((50 * $barPercent) / 100)
        $bar = ("#" * $filled) + ("-" * (50 - $filled))
        
        # Color based on actual percentage
        if ($memPercent -gt 100) {
            $barColor = "Red"
            $statusText = "CRITICAL!"
        } elseif ($memPercent -gt 90) {
            $barColor = "Red"
            $statusText = "VERY HIGH"
        } elseif ($memPercent -gt 75) {
            $barColor = "Yellow"
            $statusText = "HIGH"
        } elseif ($memPercent -gt 50) {
            $barColor = "Yellow"
            $statusText = "MODERATE"
        } else {
            $barColor = "Green"
            $statusText = "GOOD"
        }
        
        Write-Host "   Usage: [" -NoNewline
        Write-Host $bar -ForegroundColor $barColor -NoNewline
        Write-Host "] " -NoNewline
        Write-Host "$memPercent%" -NoNewline -ForegroundColor $barColor
        Write-Host " - $statusText" -ForegroundColor $barColor
        
        # Warning if over threshold
        if ($totalMB -gt $threshold) {
            Write-Host "`n   ⚠ WARNING: Memory usage is " -NoNewline -ForegroundColor Red
            Write-Host "$([math]::Round($totalMB - $threshold, 2)) MB OVER the safe threshold!" -ForegroundColor Red
            Write-Host "   ⚠ Monitor should automatically reduce this if running" -ForegroundColor Yellow
        }
        Write-Host ""
        
        # Top 5
        Write-Host "TOP MEMORY CONSUMERS" -ForegroundColor Yellow
        $top = $processes | 
            Select-Object Id, 
                @{N="MB";E={[math]::Round($_.WorkingSet64/1MB,2)}},
                @{N="Threads";E={$_.Threads.Count}} |
            Sort-Object MB -Descending |
            Select-Object -First 5
        
        Write-Host "   PID      Memory (MB)  Threads" -ForegroundColor Gray
        Write-Host "   ───────  ───────────  ───────" -ForegroundColor Gray
        foreach ($p in $top) {
            $pColor = if($p.MB -gt 1024){"Red"}elseif($p.MB -gt 512){"Yellow"}else{"White"}
            Write-Host "   $($p.Id.ToString().PadRight(8)) " -NoNewline
            Write-Host "$($p.MB.ToString().PadRight(12)) " -NoNewline -ForegroundColor $pColor
            Write-Host "$($p.Threads)" -ForegroundColor White
        }
        Write-Host ""
        
    } else {
        Write-Host "VS Code Insiders is not running`n" -ForegroundColor Yellow
    }
    
    # Monitor
    Write-Host "MONITOR STATUS" -ForegroundColor Yellow
    $monitors = Get-Process -Name "pwsh","powershell" -ErrorAction SilentlyContinue |
        Where-Object { 
            try { $_.CommandLine -like "*Monitor*.ps1*" } catch { $false }
        }
    
    if ($monitors) {
        Write-Host "   Status: " -NoNewline
        Write-Host "ACTIVE (PID: $($monitors[0].Id))" -ForegroundColor Green
        $uptime = (Get-Date) - $monitors[0].StartTime
        $monMB = [math]::Round($monitors[0].WorkingSet64 / 1MB, 2)
        Write-Host "   Uptime: $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s"
        Write-Host "   Memory: $monMB MB (monitor overhead)"
    } else {
        Write-Host "   Status: " -NoNewline
        Write-Host "NOT RUNNING" -ForegroundColor Red
        Write-Host "   ⚠ No automatic protection active!" -ForegroundColor Yellow
        Write-Host "   Tip: Start with 'Launch-VSCode-Enhanced.ps1'"
    }
    Write-Host ""
    
    # System RAM
    Write-Host "SYSTEM MEMORY" -ForegroundColor Yellow
    $os = Get-CimInstance Win32_OperatingSystem
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedGB = [math]::Round($totalGB - $freeGB, 2)
    $ramPct = [math]::Round(($usedGB / $totalGB) * 100, 1)
    
    Write-Host "   Total: $totalGB GB"
    $ramColor = if($ramPct -gt 90){"Red"}elseif($ramPct -gt 75){"Yellow"}else{"Green"}
    Write-Host "   Used:  " -NoNewline
    Write-Host "$usedGB GB ($ramPct%)" -ForegroundColor $ramColor
    Write-Host "   Free:  $freeGB GB"
    Write-Host ""
    
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    if ($Continuous) {
        Write-Host "Press Ctrl+C to exit | Refreshing in $RefreshSeconds seconds..." -ForegroundColor DarkGray
    }
}

if ($Continuous) {
    while ($true) {
        Show-Dashboard
        Start-Sleep -Seconds $RefreshSeconds
    }
} else {
    Show-Dashboard
}

