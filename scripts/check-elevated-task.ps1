$tasks = Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue
foreach ($task in $tasks) {
    if ($task.TaskName -like '*elevated*' -or $task.TaskName -like '*vhdx*' -or $task.TaskName -like '*admin*') {
        Write-Host "Found: $($task.TaskName)"
    }
}