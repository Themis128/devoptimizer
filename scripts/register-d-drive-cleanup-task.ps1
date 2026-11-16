# Register D-Drive-Cleanup scheduled task (hardened per Microsoft best practices)
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -File "D:\DevOptimizer\scripts\Clean-DDrive.ps1" -MonthsInactive 2 -Force'
$trigger = New-ScheduledTaskTrigger -Daily -At 02:30
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 10) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -Priority 7  # Below normal for background maintenance
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'DevOptimizer\D-Drive-Cleanup' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
Write-Host 'Task registered successfully (SYSTEM, daily 02:30, restart-on-failure, battery-aware)'