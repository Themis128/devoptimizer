<#
.SYNOPSIS
    VS Code Monitor Status Checker
.DESCRIPTION
    Shows current status of VS Code Insiders and monitoring system
#>

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         VS Code Insiders Monitoring - System Status           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Check VS Code Insiders processes
Write-Host "🔍 VS Code Insiders Processes:" -ForegroundColor Yellow
$vscodeProcesses = Get-Process -Name "Code - Insiders" -ErrorAction SilentlyContinue

if ($vscodeProcesses) {
    $count = ($vscodeProcesses | Measure-Object).Count
    $totalMemoryMB = [math]::Round(($vscodeProcesses | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
    
    Write-Host "   Status: RUNNING" -ForegroundColor Green
    Write-Host "   Process Count: $count" -ForegroundColor White
    Write-Host "   Total Memory: $totalMemoryMB MB" -ForegroundColor White
    
    # Show top 5 memory consumers
    Write-Host "`n   Top Memory Consumers:" -ForegroundColor Cyan
    $vscodeProcesses | 
        Select-Object Id, @{Name="MemoryMB";Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}} | 
        Sort-Object MemoryMB -Descending | 
        Select-Object -First 5 | 
        Format-Table -AutoSize | 
        Out-String | 
        ForEach-Object { Write-Host $_ -ForegroundColor White }
    
    # Health check
    Write-Host "   Health Check:" -ForegroundColor Cyan
    if ($count -gt 15) {
        Write-Host "   ⚠ WARNING: Too many processes ($count > 15)" -ForegroundColor Red
    } elseif ($count -gt 10) {
        Write-Host "   ⚡ CAUTION: Process count is high ($count)" -ForegroundColor Yellow
    } else {
        Write-Host "   ✓ Process count is healthy ($count)" -ForegroundColor Green
    }
    
    if ($totalMemoryMB -gt 4096) {
        Write-Host "   ⚠ WARNING: Excessive memory usage ($totalMemoryMB MB > 4096 MB)" -ForegroundColor Red
    } elseif ($totalMemoryMB -gt 3000) {
        Write-Host "   ⚡ CAUTION: Memory usage is high ($totalMemoryMB MB)" -ForegroundColor Yellow
    } else {
        Write-Host "   ✓ Memory usage is healthy ($totalMemoryMB MB)" -ForegroundColor Green
    }
} else {
    Write-Host "   Status: NOT RUNNING" -ForegroundColor Gray
}

# Check monitor processes
Write-Host "`n🛡️ Monitor Processes:" -ForegroundColor Yellow
$monitorProcesses = Get-Process -Name "pwsh","powershell" -ErrorAction SilentlyContinue | 
    Where-Object { $_.CommandLine -like "*VSCode*Monitor*.ps1*" }

if ($monitorProcesses) {
    Write-Host "   Status: ACTIVE" -ForegroundColor Green
    foreach ($proc in $monitorProcesses) {
        $uptime = (Get-Date) - $proc.StartTime
        Write-Host "   Monitor PID: $($proc.Id)" -ForegroundColor White
        Write-Host "   Uptime: $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" -ForegroundColor White
        Write-Host "   Memory: $([math]::Round($proc.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor White
    }
} else {
    Write-Host "   Status: NOT RUNNING" -ForegroundColor Red
    Write-Host "   ⚠ No protection active!" -ForegroundColor Yellow
}

# Check scheduled task
Write-Host "`n📅 Scheduled Task:" -ForegroundColor Yellow
$scheduledTask = Get-ScheduledTask -TaskName "VSCode Insiders Auto-Monitor" -ErrorAction SilentlyContinue

if ($scheduledTask) {
    Write-Host "   Status: $($scheduledTask.State)" -ForegroundColor $(if ($scheduledTask.State -eq 'Ready') { 'Green' } else { 'Yellow' })
    Write-Host "   Last Run: $(if ($scheduledTask.LastRunTime) { $scheduledTask.LastRunTime } else { 'Never' })" -ForegroundColor White
    Write-Host "   Next Run: $(if ($scheduledTask.NextRunTime) { $scheduledTask.NextRunTime } else { 'Not scheduled' })" -ForegroundColor White
} else {
    Write-Host "   Status: NOT CONFIGURED" -ForegroundColor Gray
}

# Check today's log file
Write-Host "`n📝 Today's Log File:" -ForegroundColor Yellow
$logFile = "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log"

if (Test-Path $logFile) {
    $logSize = [math]::Round((Get-Item $logFile).Length / 1KB, 2)
    $logLines = (Get-Content $logFile).Count
    
    Write-Host "   Status: EXISTS" -ForegroundColor Green
    Write-Host "   Path: $logFile" -ForegroundColor White
    Write-Host "   Size: $logSize KB" -ForegroundColor White
    Write-Host "   Lines: $logLines" -ForegroundColor White
    
    # Show last 5 log entries
    Write-Host "`n   Last 5 Log Entries:" -ForegroundColor Cyan
    Get-Content $logFile -Tail 5 | ForEach-Object {
        if ($_ -match "SUCCESS") { Write-Host "   $_" -ForegroundColor Green }
        elseif ($_ -match "WARNING") { Write-Host "   $_" -ForegroundColor Yellow }
        elseif ($_ -match "ERROR") { Write-Host "   $_" -ForegroundColor Red }
        else { Write-Host "   $_" -ForegroundColor White }
    }
} else {
    Write-Host "   Status: NO LOG TODAY" -ForegroundColor Gray
}

# Desktop shortcuts
Write-Host "`n🖥️ Desktop Shortcuts:" -ForegroundColor Yellow
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcuts = @(
    "VS Code Insiders (Protected).lnk",
    "VS Code Monitor (Manual).lnk",
    "VS Code Emergency Cleanup.lnk"
)

foreach ($shortcut in $shortcuts) {
    $shortcutPath = Join-Path $desktopPath $shortcut
    if (Test-Path $shortcutPath) {
        Write-Host "   ✓ $shortcut" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $shortcut (missing)" -ForegroundColor Red
    }
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "`n💡 Quick Actions:" -ForegroundColor Cyan
Write-Host "   • Start protected VS Code: .\Launch-VSCode-Protected.ps1" -ForegroundColor White
Write-Host "   • Start monitor manually: .\Start-VSCodeMonitor-PROD.ps1" -ForegroundColor White
Write-Host "   • Emergency cleanup: .\Cleanup-VSCodeInsiders.ps1" -ForegroundColor White
Write-Host "   • Setup auto-start: .\Setup-AutoMonitor-Task.ps1`n" -ForegroundColor White
