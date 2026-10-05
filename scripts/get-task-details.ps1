$task = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Safe-Cleanup-Daily' -ErrorAction SilentlyContinue
$task.Triggers
$task.Actions
$task.Settings