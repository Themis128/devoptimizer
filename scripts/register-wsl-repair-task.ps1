<#
.SYNOPSIS
    Registers/unregisters the DevOptimizer-WSL-Repair watchdog task.
.DESCRIPTION
    Every 1 minute, current user, hidden/headless via portable pwsh.
    Runs scripts\repair-wsl-docker-integration.ps1 which detects and fixes
    the WSL2/Docker-Desktop integration failure modes (root-owned ~,
    missing /var/run/docker.sock, stopped distro) before Docker Desktop
    can show its "integration unexpectedly stopped" popup.
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

$taskName = 'DevOptimizer-WSL-Repair'
$script   = 'D:\DevOptimizer\scripts\repair-wsl-docker-integration.ps1'
$pwshExe  = 'D:\DevOptimizer\pwsh\pwsh.exe'
if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }

if ($Unregister) {
    & schtasks.exe /Delete /TN $taskName /F 2>$null | Out-Null
    Write-Host "Unregistered $taskName"
    return
}

$tr = 'C:\Windows\System32\conhost.exe --headless "' + $pwshExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $script + '"'
& schtasks.exe /Create /TN $taskName /SC MINUTE /MO 1 /TR $tr /F /IT | Out-Null
if ($LASTEXITCODE -ne 0) { throw "schtasks /Create failed ($LASTEXITCODE)" }

Write-Host "Registered $taskName (every 1 min)"
Write-Host "Runs: $script"
Write-Host "Log:   D:\DevOptimizer\logs\wsl-repair.log"
Write-Host "Remove with: scripts\register-wsl-repair-task.ps1 -Unregister"
