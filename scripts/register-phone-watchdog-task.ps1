<#
.SYNOPSIS
    Registers/unregisters the DevOptimizer-Phone-Notify-Watchdog task.
.DESCRIPTION
    Every 15 minutes, current user, hidden/headless via portable pwsh.
    Runs scripts\repair-phone-notifications.ps1 which keeps the Nextcloud
    Android app under Android's 50-notification cap by force-stop +
    relaunch when stale notifications (e.g. upload conflicts) flood it -
    the flood silently suppresses real push notifications.
    Registered via schtasks.exe at task-path '\' (same as the other
    DevOptimizer-* tasks). Re-run to update; -Unregister removes it.
#>
#requires -Version 5.1
# CATEGORY: maintenance

[CmdletBinding()]
param(
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$taskName = 'DevOptimizer-Phone-Notify-Watchdog'
$script   = 'D:\DevOptimizer\scripts\repair-phone-notifications.ps1'
$pwshExe  = 'D:\DevOptimizer\pwsh\pwsh.exe'
if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }

if ($Unregister) {
    & schtasks.exe /Delete /TN $taskName /F 2>$null | Out-Null
    Write-Host "Unregistered $taskName"
    return
}

$tr = 'C:\Windows\System32\conhost.exe --headless "' + $pwshExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $script + '"'
& schtasks.exe /Create /TN $taskName /SC MINUTE /MO 15 /TR $tr /F /IT | Out-Null
if ($LASTEXITCODE -ne 0) { throw "schtasks /Create failed ($LASTEXITCODE)" }

Write-Host "Registered $taskName (every 15 min)"
Write-Host "Runs: $script"
Write-Host "Log:   D:\DevOptimizer\logs\phone-notify-watchdog.log"
Write-Host "Remove with: scripts\register-phone-watchdog-task.ps1 -Unregister"
