<#
.SYNOPSIS
    Registers/unregisters the \DevOptimizer\Daily-Full-Cleanup scheduled task.
.DESCRIPTION
    Daily 06:30, current user, hidden/headless via portable pwsh
    (conhost --headless), matching the TaskUtil headless pattern.
    06:30 sits after the 05:00 Nightly-Vhdx-Compact window so Docker
    Desktop is back up before the docker prune steps run.
    Registered at task-path '\DevOptimizer\' like the other DevOptimizer
    tasks. Run from a normal (non-admin) PowerShell.
    Re-run to update; -Unregister removes it.
#>
#requires -Version 5.1
# CATEGORY: maintenance

[CmdletBinding()]
param(
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$taskName  = 'Daily-Full-Cleanup'
$taskPath  = '\DevOptimizer\'
$script    = 'D:\DevOptimizer\scripts\daily-full-cleanup.ps1'
$pwshExe   = 'D:\DevOptimizer\pwsh\pwsh.exe'
if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }

if ($Unregister) {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Unregistered $taskPath$taskName"
    return
}

$action   = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' `
    -Argument ('--headless "' + $pwshExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $script + '"')
$trigger  = New-ScheduledTaskTrigger -Daily -At '06:30'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 2) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action `
    -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Registered $taskPath$taskName (daily 06:30)"
Write-Host "Runs: $script"
Write-Host "Remove with: scripts\register-daily-cleanup-task.ps1 -Unregister"
