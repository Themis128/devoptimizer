$tasks = Get-ScheduledTask
$tasks | Where-Object { $_.TaskName -like '*Mainten*' -or $_.TaskName -like '*WinSAT*' } | Format-Table TaskName, TaskPath, State, LastRunTime, NextRunTime -AutoSize