<#
.SYNOPSIS
    Register scheduled task to raise Devin process priority (simplified)

.DESCRIPTION
    Creates a scheduled task using the native PowerShell cmdlets.
    Run this script as Administrator.
#>

param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$taskName = 'Devin-Raise-Priority'
$taskPath = '\DevOptimizer\'
$scriptPath = 'D:\DevOptimizer\scripts\raise-devin-priority.ps1'

if (-not (Test-Path $scriptPath)) {
    Write-Error "Script not found: $scriptPath"
    exit 1
}

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
if ($existingTask -and -not $Force) {
    Write-Host "Task already exists. Use -Force to update." -ForegroundColor Yellow
    exit 0
}

# Create task action - run once at startup, then we'll use the script's -Loop mode
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Loop -Interval 30" `
    -WorkingDirectory 'D:\DevOptimizer\scripts'

# Trigger - At startup (runs when system starts, before logon)
$trigger = New-ScheduledTaskTrigger `
    -AtStartup

# Settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -Hidden `
    -ExecutionTimeLimit (New-TimeSpan -Hours 24) `
    -RestartCount 0

# Principal - run as SYSTEM (highest privileges, no user context needed)
$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Register the task
try {
    if ($existingTask) {
        Set-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
        Write-Host "Updated scheduled task: $taskPath$taskName" -ForegroundColor Green
    } else {
        Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
        Write-Host "Created scheduled task: $taskPath$taskName" -ForegroundColor Green
    }
    
    Write-Host "Task runs at system startup (as SYSTEM), script loops every 30 seconds" -ForegroundColor Cyan
}
catch {
    Write-Error "Failed to register task: $_"
    exit 1
}