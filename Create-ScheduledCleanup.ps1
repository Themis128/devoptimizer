# Create Scheduled Task for DevOptimizer Elevated Cleanup
# Runs every 15 days with SYSTEM privileges (highest/admin)

$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\elevated-complete-cleanup.ps1"'

# Trigger: Start in 5 minutes, repeat every 15 days indefinitely
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Days 15)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -DontStopOnIdleEnd

# Run as SYSTEM with highest privileges (bypasses UAC, has full admin access)
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
    Write-Host "  Next Run: $($task.Triggers.Repetition.Interval)"
    Write-Host "  User: $($task.Principal.UserId)"
    Write-Host "  Run Level: $($task.Principal.RunLevel)"
    Write-Host "  Action: $($task.Actions.Execute) $($task.Actions.Arguments)"
    
} catch {
    Write-Host "❌ Failed to create task: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}