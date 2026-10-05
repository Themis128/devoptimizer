# Register VHDX Compaction Task (daily, with Devin gates built-in)
# Runs at 03:45 - when Devin is typically not active
# The script Invoke-VhdxCompaction.ps1 has built-in Devin protection gates

$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\Invoke-VhdxCompaction.ps1" -ForceAll'
$trigger = New-ScheduledTaskTrigger -Daily -At '03:45'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName 'WSL-Vhdx-Compact' -TaskPath '\DevOptimizer\' -Action $action -Trigger $trigger -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force -Description 'Daily WSL/Docker VHDX compaction with Devin protection gates (defers if Devin active)'

Write-Host "Registered WSL-Vhdx-Compact task" -ForegroundColor Green

# Register Admin Cleanup Task (weekly on Sunday at 04:00)
$action2 = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\elevated-complete-cleanup.ps1" -SkipVhdx'
$trigger2 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '04:00'
$settings2 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 3)

Register-ScheduledTask -TaskName 'Windows-Admin-Cleanup' -TaskPath '\DevOptimizer\' -Action $action2 -Trigger $trigger2 -Settings $settings2 -User 'SYSTEM' -RunLevel Highest -Force -Description 'Weekly Windows admin cleanup (DISM, Windows Update cache, shadow copies) - VHDX handled separately daily'

Write-Host "Registered Windows-Admin-Cleanup task" -ForegroundColor Green

Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue | Select-Object TaskName, State | Format-Table -AutoSize