<#
.SYNOPSIS
    Register the weekly Devin restart scheduled task

.DESCRIPTION
    Creates a scheduled task that runs weekly on Sunday at 03:00
    to restart Devin Desktop and prevent memory leaks.
#>

param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$taskName = 'Devin-Weekly-Restart'
$taskPath = '\DevOptimizer\'
$scriptPath = 'D:\DevOptimizer\scripts\restart-devin-weekly.ps1'
$logPath = "$env:USERPROFILE\AppData\Local\DevOptimizer\logs\devin-restart.log"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Script not found: $scriptPath"
    exit 1
}

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
if ($existingTask -and -not $Force) {
    Write-Host "Task already exists. Use -Force to update." -ForegroundColor Yellow
    exit 0
}

# Create task action
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
    -WorkingDirectory 'D:\DevOptimizer\scripts'

# Create trigger - Weekly Sunday 03:00
$trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Sunday `
    -At 03:00

# Settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -Hidden `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 5)

# Principal - run whether user is logged on or not, with highest privileges
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Password `
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
    
    Write-Host "Task will run weekly on Sunday at 03:00" -ForegroundColor Cyan
    Write-Host "Logs: $logPath" -ForegroundColor Cyan
}
catch {
    Write-Error "Failed to register task: $_"
    exit 1
}