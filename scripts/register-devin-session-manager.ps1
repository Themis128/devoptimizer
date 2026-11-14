<#
.SYNOPSIS
    Register scheduled task for Devin Session Manager

.DESCRIPTION
    Creates a scheduled task that runs every 4 hours to manage Devin sessions:
    - Auto-close CLI sessions idle >4 hours
    - Limit concurrent sessions/processes to 2
    - Runs as current user with highest privileges
#>

param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$taskName = 'Devin-Session-Manager'
$taskPath = '\DevOptimizer\'
$scriptPath = 'D:\DevOptimizer\scripts\manage-devin-sessions.ps1'
$logPath = 'D:\DevOptimizer\logs\devin-session-manager.log'

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

# Create task action - runs with -WhatIf for safety initially
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -WhatIf" `
    -WorkingDirectory 'D:\DevOptimizer\scripts'

# Trigger - every 4 hours starting at 00:15 (staggered from other tasks)
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At 00:15 `
    -RepetitionInterval (New-TimeSpan -Hours 4) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

# Settings - longer time limit for potential WSL operations
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -Hidden `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 5)

# Principal - run as current user with highest privileges
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
    
    Write-Host "Task runs every 4 hours starting at 00:15 (WhatIf mode)" -ForegroundColor Cyan
    Write-Host "Logs: $logPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "NOTE: Task runs in WhatIf mode for safety." -ForegroundColor Yellow
    Write-Host "To enable real execution, edit the task and remove -WhatIf from Arguments." -ForegroundColor Yellow
}
catch {
    Write-Error "Failed to register task: $_"
    exit 1
}