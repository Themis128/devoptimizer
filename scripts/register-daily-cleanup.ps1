# Register VHDX Compaction Task (daily, with Devin gates built-in)
# Runs at 05:30 - AFTER the 02:15-05:00 maintenance storm (SocialAuto 04:00 /
# Devin-Daily 04:30 need Docker+WSL up; compaction shuts both down when it fires,
# so it must not sit inside that window - collision found 2026-10-07).
# The script Invoke-VhdxCompaction.ps1 has built-in Devin protection gates

$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\Invoke-VhdxCompaction.ps1" -ForceAll'
$trigger = New-ScheduledTaskTrigger -Daily -At '05:30'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName 'WSL-Vhdx-Compact' -TaskPath '\DevOptimizer\' -Action $action -Trigger $trigger -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force -Description 'Daily WSL/Docker VHDX compaction with Devin protection gates (defers if Devin active)'

Write-Host "Registered WSL-Vhdx-Compact task" -ForegroundColor Green

# Windows-Admin-Cleanup (weekly Sunday admin cleanup) was removed here on
# 2026-10-07: it was Disabled (superseded by register-admin-cleanup-weekly.ps1 /
# Admin-Cleanup-Weekly), and re-running this script with -Force re-enabled it.

# Show all DevOptimizer tasks
Get-ScheduledTask -TaskPath '\DevOptimizer\' -ErrorAction SilentlyContinue | Select-Object TaskName, State | Format-Table -AutoSize