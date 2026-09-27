<#
.SYNOPSIS
    VS Code Insiders Dashboard PRO
.DESCRIPTION
    Enhanced monitoring with graphs, trends, and detailed statistics
#>

param(
    [int]$RefreshSeconds = 5,
    [switch]$Continuous
)

$script:HistoricalData = @()
$script:MaxHistory = 20

function Get-ColoredBar {
    param([double]$Percent, [int]$Width = 40)
    
    $filled = [math]::Floor(($Width * [math]::Min(100, $Percent)) / 100)
    $empty = $Width - $filled
    
    $color = if($Percent -gt 90){"Red"}
             elseif($Percent -gt 75){"Yellow"}
             else{"Green"}
    
    @{
        Bar = ("█" * $filled) + ("░" * $empty)
        Color = $color
    }
}

function Get-TrendIndicator {
    if ($script:HistoricalData.Count -lt 3) { 
        return @{Symbol="→"; Color="Gray"; Text="Stable"} 
    }
    
    $recent = $script:HistoricalData | Select-Object -Last 3
    $older = $script:HistoricalData | Select-Object -Skip ([math]::Max(0, $script:HistoricalData.Count - 6)) | Select-Object -First 3
    
    if ($older.Count -lt 2) { 
        return @{Symbol="→"; Color="Gray"; Text="Stable"} 
    }
    
    $avgRecent = ($recent | Measure-Object -Property Memory -Average).Average
    $avgOlder = ($older | Measure-Object -Property Memory -Average).Average
    
    $change = if($avgOlder -gt 0) { 
        (($avgRecent - $avgOlder) / $avgOlder) * 100 
    } else { 0 }
    
    if($change -gt 10) { @{Symbol="↗"; Color="Red"; Text="Rising"} }
    elseif($change -lt -10) { @{Symbol="↘"; Color="Green"; Text="Falling"} }
    else { @{Symbol="→"; Color="Cyan"; Text="Stable"} }
}

function Show-MiniGraph {
    param([array]$Data)
    
    if($Data.Count -lt 2) { return }
    
    $max = ($Data | Measure-Object -Maximum).Maximum
    if($max -eq 0) { $max = 1 }
    
    $width = 50
    $height = 5
    
    $points = @()
    for($i = 0; $i -lt [math]::Min($Data.Count, $width); $i++) {
        $value = $Data[$i]
        $normalized = ($value / $max) * $height
        $points += [math]::Round($normalized)
    }
    
    for($h = $height; $h -ge 0; $h--) {
        Write-Host "   " -NoNewline
        foreach($point in $points) {
            if($point -ge $h) {
                Write-Host "█" -NoNewline -ForegroundColor Cyan
            } else {
                Write-Host " " -NoNewline
            }
        }
        Write-Host ""
    }
}

function Show-Dashboard {
    Clear-Host
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "        VS CODE INSIDERS MONITORING DASHBOARD PRO" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $processes = @(Get-Process -Name "Code - Insiders" -ErrorAction SilentlyContinue)
    
    if($processes.Count -gt 0) {
        $count = $processes.Count
        $totalMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
        $avgMB = [math]::Round($totalMB / $count, 2)
        $maxMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Maximum).Maximum / 1MB, 2)
        $totalCPU = [math]::Round(($processes | Measure-Object -Property CPU -Sum).Sum, 1)
        $totalThreads = ($processes | ForEach-Object { $_.Threads.Count } | Measure-Object -Sum).Sum
        
        $script:HistoricalData += @{Memory = $totalMB; Processes = $count}
        if($script:HistoricalData.Count -gt $script:MaxHistory) {
            $script:HistoricalData = $script:HistoricalData | Select-Object -Last $script:MaxHistory
        }
        
        $trend = Get-TrendIndicator
        
        # Overview
        Write-Host "┌─ OVERVIEW ────────────────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host ""
        
        $procThreshold = 35
        $memThreshold = 8192
        
        $procPercent = [math]::Round(($count / $procThreshold) * 100, 1)
        $procBar = Get-ColoredBar -Percent $procPercent
        $procStatus = if($count -gt $procThreshold){"⚠ OVER"}
                      elseif($count -gt 12){"⚡ HIGH"}
                      else{"✓ OK"}
        
        Write-Host "   Processes: " -NoNewline -ForegroundColor Gray
        Write-Host "$count " -NoNewline -ForegroundColor $procBar.Color
        Write-Host "/ $procThreshold  " -NoNewline
        Write-Host "[$procStatus]" -ForegroundColor $procBar.Color
        Write-Host "   [$($procBar.Bar)] " -NoNewline -ForegroundColor $procBar.Color
        Write-Host "$procPercent%" -ForegroundColor $procBar.Color
        Write-Host ""
        
        $memPercent = [math]::Round(($totalMB / $memThreshold) * 100, 1)
        $memBar = Get-ColoredBar -Percent $memPercent
        $memStatus = if($totalMB -gt $memThreshold){"⚠ OVER"}
                     elseif($totalMB -gt 3000){"⚡ HIGH"}
                     else{"✓ OK"}
        
        Write-Host "   Memory:    " -NoNewline -ForegroundColor Gray
        Write-Host "$totalMB MB " -NoNewline -ForegroundColor $memBar.Color
        Write-Host "/ $memThreshold MB  " -NoNewline
        Write-Host "[$memStatus]" -ForegroundColor $memBar.Color
        Write-Host "   [$($memBar.Bar)] " -NoNewline -ForegroundColor $memBar.Color
        Write-Host "$memPercent%" -ForegroundColor $memBar.Color
        Write-Host ""
        
        Write-Host "   Trend:     " -NoNewline -ForegroundColor Gray
        Write-Host "$($trend.Symbol) $($trend.Text)" -ForegroundColor $trend.Color
        Write-Host ""
        
        # Statistics
        Write-Host "┌─ STATISTICS ──────────────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   Average Memory:  " -NoNewline -ForegroundColor Gray
        Write-Host "$avgMB MB" -ForegroundColor Cyan
        Write-Host "   Peak Memory:     " -NoNewline -ForegroundColor Gray
        Write-Host "$maxMB MB" -ForegroundColor Yellow
        Write-Host "   Total CPU Time:  " -NoNewline -ForegroundColor Gray
        Write-Host "${totalCPU}s" -ForegroundColor White
        Write-Host "   Total Threads:   " -NoNewline -ForegroundColor Gray
        Write-Host "$totalThreads" -ForegroundColor Cyan
        Write-Host ""
        
        # Memory trend graph
        if($script:HistoricalData.Count -gt 2) {
            Write-Host "┌─ MEMORY TREND (Last $($script:HistoricalData.Count) samples) ──────────────────────┐" -ForegroundColor Yellow
            Write-Host ""
            $memData = $script:HistoricalData | ForEach-Object { $_.Memory }
            Show-MiniGraph -Data $memData
            Write-Host ""
        }
        
        # Top processes
        Write-Host "┌─ TOP MEMORY CONSUMERS ────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host ""
        
        $top5 = $processes | 
            Select-Object Id, 
                @{N="MB";E={[math]::Round($_.WorkingSet64/1MB,2)}},
                @{N="CPU";E={[math]::Round($_.CPU,1)}},
                @{N="Threads";E={$_.Threads.Count}} |
            Sort-Object MB -Descending |
            Select-Object -First 5
        
        Write-Host "   PID      Memory (MB)  CPU (s)  Threads" -ForegroundColor Gray
        Write-Host "   ───────  ───────────  ───────  ───────" -ForegroundColor DarkGray
        
        foreach($p in $top5) {
            $color = if($p.MB -gt 1024){"Red"}
                     elseif($p.MB -gt 512){"Yellow"}
                     else{"White"}
            Write-Host "   $($p.Id.ToString().PadRight(8)) " -NoNewline
            Write-Host "$($p.MB.ToString().PadRight(12)) " -NoNewline -ForegroundColor $color
            Write-Host "$($p.CPU.ToString().PadRight(8)) " -NoNewline -ForegroundColor Cyan
            Write-Host "$($p.Threads)" -ForegroundColor White
        }
        Write-Host ""
        
    } else {
        Write-Host "⚠ VS Code Insiders is not currently running" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Monitor status
    Write-Host "┌─ MONITOR STATUS ──────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host ""
    
    $monitors = @(Get-Process -Name "pwsh","powershell" -ErrorAction SilentlyContinue |
        Where-Object { 
            try { $_.CommandLine -like "*Monitor*.ps1*" } catch { $false }
        })
    
    if($monitors.Count -gt 0) {
        $mon = $monitors[0]
        $uptime = (Get-Date) - $mon.StartTime
        $monMB = [math]::Round($mon.WorkingSet64 / 1MB, 2)
        
        Write-Host "   Status:  " -NoNewline -ForegroundColor Gray
        Write-Host "● ACTIVE" -ForegroundColor Green
        Write-Host "   PID:     " -NoNewline -ForegroundColor Gray
        Write-Host "$($mon.Id)" -ForegroundColor White
        Write-Host "   Uptime:  " -NoNewline -ForegroundColor Gray
        Write-Host "$($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" -ForegroundColor Cyan
        Write-Host "   Memory:  " -NoNewline -ForegroundColor Gray
        Write-Host "$monMB MB" -ForegroundColor White
    } else {
        Write-Host "   Status:  " -NoNewline -ForegroundColor Gray
        Write-Host "○ INACTIVE" -ForegroundColor Red
        Write-Host "   ⚠ No protection active" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # System RAM
    Write-Host "┌─ SYSTEM RESOURCES ────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host ""
    
    $os = Get-CimInstance Win32_OperatingSystem
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedGB = [math]::Round($totalGB - $freeGB, 2)
    $ramPct = [math]::Round(($usedGB / $totalGB) * 100, 1)
    
    $ramBar = Get-ColoredBar -Percent $ramPct
    
    Write-Host "   Total RAM:  " -NoNewline -ForegroundColor Gray
    Write-Host "$totalGB GB" -ForegroundColor White
    Write-Host "   Used RAM:   " -NoNewline -ForegroundColor Gray
    Write-Host "$usedGB GB " -NoNewline -ForegroundColor $ramBar.Color
    Write-Host "($ramPct%)" -ForegroundColor $ramBar.Color
    Write-Host "   [$($ramBar.Bar)] " -ForegroundColor $ramBar.Color
    
    if($processes.Count -gt 0) {
        $vscodePct = [math]::Round(($totalMB / 1024 / $totalGB) * 100, 1)
        Write-Host ""
        Write-Host "   VS Code:    " -NoNewline -ForegroundColor Gray
        Write-Host "$([math]::Round($totalMB/1024, 2)) GB " -NoNewline -ForegroundColor Cyan
        Write-Host "($vscodePct% of total)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Footer
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -NoNewline -ForegroundColor Gray
    if($Continuous) {
        Write-Host " | Refresh: ${RefreshSeconds}s | Ctrl+C to exit" -ForegroundColor DarkGray
    } else {
        Write-Host ""
    }
}

# Main execution
if($Continuous) {
    while($true) {
        Show-Dashboard
        Start-Sleep -Seconds $RefreshSeconds
    }
} else {
    Show-Dashboard
}

