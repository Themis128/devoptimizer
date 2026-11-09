<#
.SYNOPSIS
    Registers/unregisters the DevOptimizer-Housekeeping weekly scheduled task.
.DESCRIPTION
    Weekly Saturday 05:30, current user, hidden/headless via portable pwsh
    (conhost --headless), matching the TaskUtil headless pattern.
    Registered at task-path '\' because '\DevOptimizer\' requires elevation
    to write. Run from a normal (non-admin) PowerShell.
    Re-run to update; -Unregister removes it.
#>
#requires -Version 5.1
# CATEGORY: maintenance

[CmdletBinding()]
param(
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$taskName  = 'DevOptimizer-Housekeeping'
$taskPath  = '\'
$script    = 'D:\DevOptimizer\scripts\devoptimizer-housekeeping.ps1'
$pwshExe   = 'D:\DevOptimizer\pwsh\pwsh.exe'
if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }

if ($Unregister) {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Unregistered $taskPath$taskName"
    return
}

# Next Saturday 05:30
$nextSat = (Get-Date).Date
$nextSat = $nextSat.AddDays((6 - [int]$nextSat.DayOfWeek) % 7)
$at = $nextSat.AddHours(5).AddMinutes(30)

$action   = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' `
    -Argument ('--headless "' + $pwshExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $script + '"')
$trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At $at
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 1) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action `
    -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Registered $taskPath$taskName (weekly Saturday 05:30, next run $($at.ToString('yyyy-MM-dd HH:mm')))"
Write-Host "Runs: $script"
Write-Host "Remove with: scripts\register-housekeeping-task.ps1 -Unregister"
