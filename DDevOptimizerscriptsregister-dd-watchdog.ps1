<#
.SYNOPSIS
    Registers DD-Settings-Watchdog as user scheduled task (every 5 min + at logon)
.DESCRIPTION
    Creates \DevOptimizer\DD-Settings-Watchdog task running as current user.
    Run this script from REGULAR PowerShell (NOT elevated).
#>
#requires -Version 5.1

$ErrorActionPreference = 'Stop'

# Import shared module
. "$PSScriptRoot\lib\TaskUtil.ps1"

$scriptPath = "D:\DevOptimizer\scripts\dd-settings-watchdog.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Script not found: $scriptPath"
    exit 1
}

Write-Host "Registering DD-Settings-Watchdog as user task..." -ForegroundColor Cyan

$task = Register-DevOptTask `
    -TaskName 'DD-Settings-Watchdog' `
    -ScriptPath $scriptPath `
    -Account 'User' `
    -TriggerType 'Logon' `
    -RepetitionMinutes 5 `
    -RepetitionDurationHours 24 `
    -Description 'Docker Desktop settings persistence watchdog - prevents updates from reverting hardened config (disableWSLIntegrationAutoConfig, manageDockerGroup, userns-remap)' `
    -Force

Write-Host "`nTask registered successfully!" -ForegroundColor Green
Write-Host "Task Path: \DevOptimizer\DD-Settings-Watchdog" -ForegroundColor Cyan
Write-Host "Account: Current user" -ForegroundColor Cyan
Write-Host "Schedule: At logon + every 5 minutes" -ForegroundColor Cyan
Write-Host "`nTo verify: Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'DD-Settings-Watchdog'" -ForegroundColor DarkGray
Write-Host "To run manually: Start-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'DD-Settings-Watchdog'" -ForegroundColor DarkGray

# Verify
$verify = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'DD-Settings-Watchdog' -ErrorAction SilentlyContinue
if ($verify) {
    Write-Host "`nVerification: Task exists and is ready." -ForegroundColor Green
} else {
    Write-Warning "Verification failed: Task not found after registration"
}
