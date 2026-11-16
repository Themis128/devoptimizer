<#
.SYNOPSIS
    Registers/unregisters the DevOptimizer-WSL-Repair watchdog task.
.DESCRIPTION
    Every 30 minutes, current user, hidden/headless via portable pwsh.
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
# 2026-11-14: was /MO 1 (a wsl.exe probe every minute is hot); 30 min is the
# AGENTS.md-documented cadence. /F overwrites in place.
& schtasks.exe /Create /TN $taskName /SC MINUTE /MO 30 /TR $tr /F /IT | Out-Null
if ($LASTEXITCODE -ne 0) { throw "schtasks /Create failed ($LASTEXITCODE)" }

Write-Host "Registered $taskName (every 30 min)"
Write-Host "Runs: $script"
Write-Host "Log:   D:\DevOptimizer\logs\wsl-repair.log"
Write-Host "Remove with: scripts\register-wsl-repair-task.ps1 -Unregister"
