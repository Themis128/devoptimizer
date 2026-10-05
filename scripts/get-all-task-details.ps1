$tasks = Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
foreach ($task in $tasks) {
    Write-Host "=== $($task.TaskName) ===" -ForegroundColor Cyan
    $task.Triggers | Format-List
    $task.Actions | Format-List
    $task.Settings | Select-Object ExecutionTimeLimit, StartWhenAvailable, WakeToRun, RunOnlyIfIdle, DisallowStartIfOnBatteries, StopIfGoingOnBatteries | Format-List
    Write-Host ""
}