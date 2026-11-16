<#
.SYNOPSIS
    Registers/unregisters the \Vhdx-Compact-DevinExit scheduled task.
.DESCRIPTION
    Every 5 minutes, current user, limited rights. Runs
    scripts\vhdx-compact-on-devin-exit.ps1 which waits for Devin.exe and
    devin-server to be gone, then fires the elevated Nightly-Vhdx-Compact
    task (full WSL/Docker vhdx compaction). Once per day via stamp file.
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

$taskName  = 'Vhdx-Compact-DevinExit'
$taskPath  = '\'
$script    = 'D:\DevOptimizer\scripts\vhdx-compact-on-devin-exit.ps1'

if ($Unregister) {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Unregistered $taskPath$taskName"
    return
}

$action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $script + '"')
$trigger  = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -Compatibility Win8
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action `
    -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Registered $taskPath$taskName (every 5 min)"
Write-Host "Runs: $script"
Write-Host "Remove with: scripts\register-vhdx-devin-exit-task.ps1 -Unregister"
