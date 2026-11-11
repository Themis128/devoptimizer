<#
.SYNOPSIS
    Registers/unregisters the DevOptimizer-Tailnet-Watchdog task.
.DESCRIPTION
    Every 5 minutes, current user, hidden/headless via portable pwsh.
    Runs scripts\tailnet-watchdog.ps1 which checks `tailscale status --json`
    against config\tailnet-watch.json and sends Telegram alerts on node
    online/offline transitions (state in logs\tailnet-watchdog-state.json).
    Registered via schtasks.exe at task-path '\' (same as other
    DevOptimizer-* tasks). Re-run to update; -Unregister removes it.
#>
#requires -Version 5.1
# CATEGORY: maintenance

[CmdletBinding()]
param(
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$taskName = 'DevOptimizer-Tailnet-Watchdog'
$script   = 'D:\DevOptimizer\scripts\tailnet-watchdog.ps1'
$pwshExe  = 'D:\DevOptimizer\pwsh\pwsh.exe'
if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }

if ($Unregister) {
    & schtasks.exe /Delete /TN $taskName /F 2>$null | Out-Null
    Write-Host "Unregistered $taskName"
    return
}

$tr = 'C:\Windows\System32\conhost.exe --headless "' + $pwshExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $script + '"'
& schtasks.exe /Create /TN $taskName /SC MINUTE /MO 5 /TR $tr /F /IT | Out-Null
if ($LASTEXITCODE -ne 0) { throw "schtasks /Create failed ($LASTEXITCODE)" }

Write-Host "Registered $taskName (every 5 min)"
Write-Host "Runs: $script"
Write-Host "Config: D:\DevOptimizer\config\tailnet-watch.json"
Write-Host "Log:    D:\DevOptimizer\logs\tailnet-watchdog.log"
Write-Host "Remove with: scripts\register-tailnet-watchdog.ps1 -Unregister"
