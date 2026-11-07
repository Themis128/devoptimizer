<#
.SYNOPSIS
    Registers Admin-Cleanup-System as SYSTEM scheduled task (weekly Sunday 03:00)
.DESCRIPTION
    Creates \DevOptimizer\Admin-Cleanup-System task running as SYSTEM with highest privileges.
    Run this script from ELEVATED PowerShell (Run as Administrator).
#>
#requires -Version 5.1
#requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# Import shared module
. "$PSScriptRoot\lib\TaskUtil.ps1"

$scriptPath = "D:\DevOptimizer\scripts\admin-cleanup-system.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Script not found: $scriptPath"
    exit 1
}

Write-Host "Registering Admin-Cleanup-System as SYSTEM task..." -ForegroundColor Cyan

$task = Register-DevOptTask `
    -TaskName 'Admin-Cleanup-System' `
    -ScriptPath $scriptPath `
    -Account 'System' `
    -TriggerType 'Weekly' `
    -TriggerAt '03:00' `
    -DaysOfWeek @('Sunday') `
    -Description 'SYSTEM-level Windows cleanup: DISM, Windows Update, Delivery Optimization, shadow copies, Windows.old, WER, temp' `
    -Force

Write-Host "`nTask registered successfully!" -ForegroundColor Green
Write-Host "Task Path: \DevOptimizer\Admin-Cleanup-System" -ForegroundColor Cyan
Write-Host "Account: SYSTEM (highest privileges)" -ForegroundColor Cyan
Write-Host "Schedule: Weekly Sunday 03:00" -ForegroundColor Cyan
Write-Host "`nTo verify: Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Admin-Cleanup-System'" -ForegroundColor DarkGray
Write-Host "To run manually: Start-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Admin-Cleanup-System'" -ForegroundColor DarkGray

# Verify
$verify = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Admin-Cleanup-System' -ErrorAction SilentlyContinue
if ($verify) {
    Write-Host "`nVerification: Task exists and is ready." -ForegroundColor Green
} else {
    Write-Warning "Verification failed: Task not found after registration"
}
