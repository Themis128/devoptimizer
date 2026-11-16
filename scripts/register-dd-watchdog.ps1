$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\dd-settings-watchdog.ps1"'
$trigger1 = New-ScheduledTaskTrigger -AtLogOn
# 2026-11-14: 24h duration expired on 11-08 and silently killed the 5-min
# cadence (StopAtDurationEnd) - the watchdog slept through the DD 4.98
# settings migration. 3650d matches the other long-lived watchdogs
# ([TimeSpan]::MaxValue serializes out of range for Task Scheduler).
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance Win32_ComputerSystem).UserName -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'DD-Settings-Watchdog' -TaskPath '\DevOptimizer\' -Action $action -Trigger $trigger1,$trigger2 -Settings $settings -Principal $principal -Force
Write-Host 'Registered DD-Settings-Watchdog task'