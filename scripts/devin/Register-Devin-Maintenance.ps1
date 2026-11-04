<#
.SYNOPSIS
    Registers devin maintenance.
.DESCRIPTION
    Registers devin maintenance.
#>

# Register-Devin-Maintenance.ps1 - registers the daily unattended Devin
# maintenance task (Invoke-DevinDailyMaintenance.ps1) at 04:30 - after the
# 02:15/02:30/03:00 cleanup block and before work hours, when Devin.exe is
# normally closed so bundle repairs are enabled. Safe to re-run; -Remove
# unregisters.
param([switch]$Remove)

$taskName = 'Devin-Daily-Maintenance'
$taskPath = '\DevOptimizer\'

if ($Remove) {
    Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed $taskPath$taskName"
    return
}

# conhost --headless wrapper = the hub's popup-suppression pattern (same shape as
# Devin-Session-Manager / Devin-Weekly-Restart). Do NOT put --headless on
# powershell.exe itself: it only parses conhost's flag set and dies instantly.
$action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument '--headless powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\devin\Invoke-DevinDailyMaintenance.ps1"' `
    -WorkingDirectory 'D:\DevOptimizer'
$trigger = New-ScheduledTaskTrigger -Daily -At '04:30'
$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Force | Out-Null

Write-Host "Registered $taskPath$taskName - daily 04:30 maintenance for Devin Desktop (cache sweep, log retention, bundle self-heal, report to D:\DevOptimizer\logs\devin-maintenance\latest.json)."
Write-Host 'Bundle repairs only execute when Devin.exe is closed; while it runs they are deferred.'
