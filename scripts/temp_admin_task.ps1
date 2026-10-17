$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\admin-cleanup-elevated.ps1"'
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
Register-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -TaskName "TempAdminCleanup" -Force
Start-ScheduledTask -TaskName "TempAdminCleanup"
Start-Sleep -Seconds 40
Unregister-ScheduledTask -TaskName "TempAdminCleanup" -Force