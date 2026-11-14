$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\health-dashboard.ps1"'
$trigger1 = New-ScheduledTaskTrigger -AtLogOn
# 2026-11-14: 24h duration expires and silently kills the cadence
# (StopAtDurationEnd) - same bug class as register-dd-watchdog. 3650d.
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance Win32_ComputerSystem).UserName -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'Health-Dashboard' -TaskPath '\DevOptimizer\' -Action $action -Trigger $trigger1,$trigger2 -Settings $settings -Principal $principal -Force
Write-Host 'Registered Health-Dashboard task'