@echo off
REM Register Admin-Cleanup-System as SYSTEM task
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File \"D:\DevOptimizer\scripts\admin-cleanup-system.ps1\"'; ^
  $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 03:00; ^
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8; ^
  $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest; ^
  Register-ScheduledTask -TaskName 'Admin-Cleanup-System' -TaskPath '\DevOptimizer\' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force; ^
  Write-Host 'Registered Admin-Cleanup-System task (SYSTEM account)'"