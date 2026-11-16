<#
.SYNOPSIS
    Registers the \DevOptimizer\Admin-Cleanup-Weekly scheduled task (Sundays 03:00, elevated).
.DESCRIPTION
    Must run elevated (RunLevel Highest registration). Creates the weekly task that runs
    win11-admin-cleanup-scheduled.ps1 (DISM component cleanup + RestoreHealth + SFC + WU
    cache) and appends the registration result to logs\register-admin-cleanup-weekly.log.
#>
#requires -Version 5.1
# CATEGORY: maintenance

# Registers \DevOptimizer\Admin-Cleanup-Weekly (Sundays 03:00, elevated).
# Must run elevated. Result appended to logs\register-admin-cleanup-weekly.log.
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$log = 'D:\DevOptimizer\logs\register-admin-cleanup-weekly.log'
try {
    $action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\win11-admin-cleanup-scheduled.ps1"'
    $trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '2026-10-11T03:00:00+03:00'
    $settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId 'tbaltzakis' -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Admin-Cleanup-Weekly' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Weekly elevated Windows admin cleanup (DISM component store + RestoreHealth + SFC + WU cache). Sundays 03:00.' -Force | Out-Null
    $t = Get-ScheduledTask -TaskName 'Admin-Cleanup-Weekly' -TaskPath '\DevOptimizer\'
    Add-Content -Path $log -Value "$stamp OK state=$($t.State) runlevel=$($t.Principal.RunLevel)"
} catch {
    Add-Content -Path $log -Value "$stamp FAIL $($_.Exception.Message)"
}
