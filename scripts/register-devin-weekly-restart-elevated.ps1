<#
.SYNOPSIS
    Register the weekly Devin restart scheduled task (COM-based, works with elevation)

.DESCRIPTION
    Creates a scheduled task that runs weekly on Sunday at 03:00
    to restart Devin Desktop and prevent memory leaks.
    Uses Schedule.Service COM object which can be elevated.
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

# Use COM object for task scheduler (supports elevation via UAC)
$service = New-Object -ComObject 'Schedule.Service'
$service.Connect()

$rootFolder = $service.GetFolder('\')
$devOptimizerFolder = $null

try {
    $devOptimizerFolder = $service.GetFolder('\DevOptimizer')
} catch {
    $rootFolder.CreateFolder('DevOptimizer')
    $devOptimizerFolder = $service.GetFolder('\DevOptimizer')
}

# Delete existing task if Force
if ($Force) {
    try {
        $devOptimizerFolder.DeleteTask($taskName, 0)
    } catch { }
}

$taskDefinition = $service.NewTask(0)

# General settings
$taskDefinition.RegistrationInfo.Description = 'Weekly Devin Desktop restart to prevent memory leaks and stale states'
$taskDefinition.RegistrationInfo.Author = $env:USERNAME
$taskDefinition.Settings.Enabled = $true
$taskDefinition.Settings.AllowDemandStart = $true
$taskDefinition.Settings.StartWhenAvailable = $true
$taskDefinition.Settings.RunOnlyIfNetworkAvailable = $true
$taskDefinition.Settings.ExecutionTimeLimit = 'PT2H'
$taskDefinition.Settings.RestartCount = 3
$taskDefinition.Settings.RestartInterval = 'PT5M'
$taskDefinition.Settings.DisallowStartIfOnBatteries = $false
$taskDefinition.Settings.StopIfGoingOnBatteries = $false
$taskDefinition.Settings.Hidden = $true

# Principal - run with highest privileges
$taskDefinition.Principal.RunLevel = 1  # Highest
$taskDefinition.Principal.LogonType = 3  # Password (interactive)

# Trigger - Weekly Sunday 03:00
$trigger = $taskDefinition.Triggers.Create(3)  # Weekly trigger
$trigger.DaysOfWeek = 1  # Sunday (1=Sunday, 2=Monday, 4=Tuesday, 8=Wednesday, 16=Thursday, 32=Friday, 64=Saturday)
$trigger.StartBoundary = (Get-Date).ToString('yyyy-MM-dd') + 'T03:00:00'
$trigger.Enabled = $true

# Action - PowerShell script
$action = $taskDefinition.Actions.Create(0)  # Execute action
$action.Path = 'powershell.exe'
$action.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$action.WorkingDirectory = 'D:\DevOptimizer\scripts'

# Register the task
# 6 = CREATE_OR_UPDATE, 'S-1-5-32-544' = Administrators group, 3 = TASK_LOGON_PASSWORD
$devOptimizerFolder.RegisterTaskDefinition(
    $taskName,
    $taskDefinition,
    6,  # CREATE_OR_UPDATE
    $null,  # User (null for system account)
    $null,  # Password
    3,  # TASK_LOGON_PASSWORD
    $null  # SDDL
)

Write-Host "Created/Updated scheduled task: $taskPath$taskName" -ForegroundColor Green
Write-Host "Task will run weekly on Sunday at 03:00" -ForegroundColor Cyan
Write-Host "Logs: $logPath" -ForegroundColor Cyan