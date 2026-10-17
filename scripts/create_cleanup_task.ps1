$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\admin-cleanup-elevated.ps1"'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
Register-ScheduledTask -TaskName 'AdminCleanupTask' -Action $action -Trigger $trigger -RunLevel Highest -Force