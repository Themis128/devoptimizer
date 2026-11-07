<#
.SYNOPSIS
    Registers Health-Dashboard as user scheduled task (every 2 min + at logon)
.DESCRIPTION
    Creates \DevOptimizer\Health-Dashboard task running as current user.
    Run this script from REGULAR PowerShell (NOT elevated).
#>
#requires -Version 5.1

$ErrorActionPreference = 'Stop'

# Import shared module
. "$PSScriptRoot\lib\TaskUtil.ps1"

$scriptPath = "D:\DevOptimizer\scripts\health-dashboard.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Script not found: $scriptPath"
    exit 1
}

Write-Host "Registering Health-Dashboard as user task..." -ForegroundColor Cyan

$task = Register-DevOptTask `
    -TaskName 'Health-Dashboard' `
    -ScriptPath $scriptPath `
    -Account 'User' `
    -TriggerType 'Logon' `
    -RepetitionMinutes 2 `
    -RepetitionDurationHours 24 `
    -Description 'DevOptimizer health dashboard generator - produces HTML + JSON with real-time subsystem status (WSL, Guardian, Host Guard, Docker Sync, Settings Watchdog, Admin Cleanup)' `
    -Force

Write-Host "`nTask registered successfully!" -ForegroundColor Green
Write-Host "Task Path: \DevOptimizer\Health-Dashboard" -ForegroundColor Cyan
Write-Host "Account: Current user" -ForegroundColor Cyan
Write-Host "Schedule: At logon + every 2 minutes" -ForegroundColor Cyan
Write-Host "`nTo verify: Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Health-Dashboard'" -ForegroundColor DarkGray
Write-Host "To run manually: Start-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Health-Dashboard'" -ForegroundColor DarkGray
Write-Host "Dashboard: D:\DevOptimizer\logs\health-dashboard.html" -ForegroundColor DarkGray

# Verify
$verify = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Health-Dashboard' -ErrorAction SilentlyContinue
if ($verify) {
    Write-Host "`nVerification: Task exists and is ready." -ForegroundColor Green
} else {
    Write-Warning "Verification failed: Task not found after registration"
}
