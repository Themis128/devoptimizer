<#
.SYNOPSIS
    Registers Admin-Cleanup-System as SYSTEM scheduled task (weekly Sunday 03:00)
.DESCRIPTION
    Must be run from ELEVATED PowerShell (Run as Administrator).
#>
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\admin-cleanup-system.ps1"'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 03:00
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'Admin-Cleanup-System' -TaskPath '\DevOptimizer\' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
Write-Host 'Registered Admin-Cleanup-System task (SYSTEM account)'