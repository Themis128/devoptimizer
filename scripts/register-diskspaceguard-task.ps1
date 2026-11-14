<#
.SYNOPSIS
    Registers/unregisters the DevOptimizer-DiskSpaceGuard hourly scheduled task.
.DESCRIPTION
    Hourly check of fixed-drive usage via scripts/check-drive-space.py.
    >=90% -> Telegram warning; >=95% -> Telegram critical + auto safe-cleanup.
    Uses pythonw.exe directly (AGENTS.md canonical for python scripts - no
    console, no conhost wrapper needed). The script's subprocess calls MUST
    carry creationflags=subprocess.CREATE_NO_WINDOW or the crit path would
    flash a window under the console-less host.
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

if ($Unregister) {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Unregistered $taskPath$taskName"
    return
}

$action    = New-ScheduledTaskAction -Execute 'pythonw.exe' `
    -Argument ('"' + $script + '"')
$trigger   = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours(1) `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action `
    -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Registered $taskPath$taskName (hourly, script: $script)"
Write-Host "Remove with: scripts\register-diskspaceguard-task.ps1 -Unregister"
