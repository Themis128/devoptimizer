$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `\"D:\DevOptimizer\scripts\lower-devin-priority.ps1`\" -Loop -Interval 30"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 24)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'Devin-Lower-Priority' -TaskPath '\DevOptimizer\' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
Write-Host "Task created"