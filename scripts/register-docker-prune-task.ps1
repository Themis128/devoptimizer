<#
.SYNOPSIS
    Registers/unregisters the DevOptimizer-Docker-Prune monthly scheduled task.
.DESCRIPTION
    Monthly on the 1st at 04:30, current user, hidden/headless via portable pwsh.
    Runs devoptimizer-housekeeping.ps1 -PruneDocker, which executes
    'docker image prune -a -f' + 'docker builder prune -af' (DESTRUCTIVE:
    removes all unused tagged images and build cache; images must be
    re-pulled later). Host-side reclaim happens via the nightly
    WSL-Vhdx-Compact task.
    Registered at task-path '\' (same as DevOptimizer-Housekeeping).
    Re-run to update; -Unregister removes it.
#>
#requires -Version 5.1
# CATEGORY: maintenance

[CmdletBinding()]
param(
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$taskName  = 'DevOptimizer-Docker-Prune'
$taskPath  = '\'
$script    = 'D:\DevOptimizer\scripts\devoptimizer-housekeeping.ps1'
$pwshExe   = 'D:\DevOptimizer\pwsh\pwsh.exe'
if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }

if ($Unregister) {
    & schtasks.exe /Delete /TN $taskName /F 2>$null | Out-Null
    Write-Host "Unregistered $taskName"
    return
}

# schtasks /SC MONTHLY - New-ScheduledTaskTrigger has no -Monthly and the CIM
# trigger route fails Register-ScheduledTask type checks on this build.
$tr = 'C:\Windows\System32\conhost.exe --headless "' + $pwshExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $script + '" -PruneDocker'
& schtasks.exe /Create /TN $taskName /SC MONTHLY /M '*' /D 1 /ST 04:30 /TR $tr /F /IT | Out-Null
if ($LASTEXITCODE -ne 0) { throw "schtasks /Create failed ($LASTEXITCODE)" }

Write-Host "Registered \$taskName (monthly 1st 04:30)"
Write-Host "Runs: $script -PruneDocker  (destructive: docker image prune -a + builder prune -af)"
Write-Host "Remove with: scripts\register-docker-prune-task.ps1 -Unregister"
