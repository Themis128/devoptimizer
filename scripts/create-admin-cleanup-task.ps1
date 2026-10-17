# PowerShell script to create a scheduled task for admin cleanup
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\admin-cleanup-elevated.ps1"'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'Win11AdminCleanup' -Action $action -Trigger $trigger -Principal $principal -Force
Write-Host "Scheduled task 'Win11AdminCleanup' created successfully"
Write-Host "It will run in 1 minute with highest privileges"