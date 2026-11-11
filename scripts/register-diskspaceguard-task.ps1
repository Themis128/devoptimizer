<#
.SYNOPSIS
    Registers/unregisters the DevOptimizer-DiskSpaceGuard hourly scheduled task.
.DESCRIPTION
    Hourly check of fixed-drive usage via scripts/check-drive-space.py.
    >=90% -> Telegram warning; >=95% -> Telegram critical + auto safe-cleanup.
    Uses python.exe directly (script is stdlib-only, no pwsh needed).
    Registered at task-path '\' because '\DevOptimizer\' requires elevation.
    Re-run to update; -Unregister removes it.
#>
#requires -Version 5.1
# CATEGORY: maintenance

[CmdletBinding()]
param(
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$taskName = 'DevOptimizer-DiskSpaceGuard'
$taskPath = '\'
$script   = 'D:\DevOptimizer\scripts\check-drive-space.py'
$pyExe    = 'python'

if ($Unregister) {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Unregistered $taskPath$taskName"
    return
}

$action    = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' `
    -Argument ('--headless "' + $pyExe + '" "' + $script + '"')
$trigger   = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours(1) `
    -RepetitionInterval (New-TimeSpan -Hours 1)
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action `
    -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Registered $taskPath$taskName (hourly, script: $script)"
Write-Host "Remove with: scripts\register-diskspaceguard-task.ps1 -Unregister"
