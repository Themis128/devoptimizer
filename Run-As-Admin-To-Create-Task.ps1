# ============================================================
# RUN THIS FROM AN ELEVATED POWERSHELL WINDOW (Right-click → Run as Administrator)
# ============================================================
# This creates a scheduled task that runs every 15 days as SYSTEM (highest privileges)

$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\elevated-complete-cleanup.ps1"'

# Trigger: Start in 5 minutes, repeat every 15 days
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Days 15)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -DontStopOnIdleEnd

# Run as SYSTEM with highest privileges
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

try {
    Register-ScheduledTask `
        -TaskName 'DevOptimizer-Elevated-Cleanup' `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description 'Runs DevOptimizer elevated cleanup (DISM, VHDX compaction, Windows Update cache, etc.) every 15 days' `
        -Force `
        -ErrorAction Stop
    
    Write-Host "✅ Scheduled task created successfully!" -ForegroundColor Green
    
    # Verify
    $task = Get-ScheduledTask -TaskName 'DevOptimizer-Elevated-Cleanup'
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($task.TaskName)"
    Write-Host "  State: $($task.State)"
    Write-Host "  Next Run: $($task.Triggers[0].StartBoundary)"
    Write-Host "  Repetition: Every 15 days"
    Write-Host "  User: $($task.Principal.UserId)"
    Write-Host "  Run Level: $($task.Principal.RunLevel)"
    Write-Host "  Action: $($task.Actions.Execute) $($task.Actions.Arguments)"
    
} catch {
    Write-Host "❌ Failed to create task: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
