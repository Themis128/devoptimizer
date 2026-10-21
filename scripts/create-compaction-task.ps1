$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-File D:\DevOptimizer\scripts\compact-wsl-vhdx.ps1 -ForceAll -Force'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'DevOptimizer-VHDX-Compaction-OneTime' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force