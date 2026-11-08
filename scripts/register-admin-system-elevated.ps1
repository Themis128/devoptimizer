<#
.SYNOPSIS
    Registers Admin-Cleanup-System as SYSTEM scheduled task - MUST RUN ELEVATED
.DESCRIPTION
    Run from Administrator PowerShell: Start-Process pwsh -Verb RunAs -ArgumentList '-File "D:\DevOptimizer\scripts\register-admin-system-elevated.ps1"'
#>

$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\admin-cleanup-system.ps1"'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 03:00
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 72) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

try {
    Register-ScheduledTask -TaskName 'Admin-Cleanup-System' -TaskPath '\DevOptimizer\' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop
    Write-Host "SUCCESS: Admin-Cleanup-System task registered (SYSTEM account, Highest run level)"
    Get-ScheduledTask -TaskName 'Admin-Cleanup-System' -TaskPath '\DevOptimizer\' | Select-Object TaskName, State, TaskPath, UserId, RunLevel | Format-Table -AutoSize
} catch {
    Write-Error "FAILED: $($_.Exception.Message)"
    exit 1
}