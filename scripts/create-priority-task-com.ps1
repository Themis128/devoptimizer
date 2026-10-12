<#
.SYNOPSIS
    Create Devin priority task using COM (works with elevation)
#>

param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$taskName = 'Devin-Lower-Priority'
$taskPath = '\DevOptimizer\'
$scriptPath = 'D:\DevOptimizer\scripts\lower-devin-priority.ps1'

if (-not (Test-Path $scriptPath)) {
    Write-Error "Script not found: $scriptPath"
    exit 1
}

# Use COM object
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

if ($Force) {
    try { $devOptimizerFolder.DeleteTask($taskName, 0) } catch { }
}

$taskDefinition = $service.NewTask(0)

# General settings
$taskDefinition.RegistrationInfo.Description = 'Lower Devin Desktop process priority to BelowNormal to reduce CPU contention'
$taskDefinition.RegistrationInfo.Author = $env:USERNAME
$taskDefinition.Settings.Enabled = $true
$taskDefinition.Settings.AllowDemandStart = $true
$taskDefinition.Settings.StartWhenAvailable = $true
$taskDefinition.Settings.RunOnlyIfNetworkAvailable = $false
$taskDefinition.Settings.ExecutionTimeLimit = 'PT24H'
$taskDefinition.Settings.DisallowStartIfOnBatteries = $false
$taskDefinition.Settings.StopIfGoingOnBatteries = $false
$taskDefinition.Settings.Hidden = $true

# Principal - SYSTEM with highest privileges
$taskDefinition.Principal.RunLevel = 1  # Highest
$taskDefinition.Principal.LogonType = 3  # Password (for SYSTEM)
$taskDefinition.Principal.UserId = 'SYSTEM'

# Trigger - At startup
$trigger = $taskDefinition.Triggers.Create(8)  # On system start
$trigger.Enabled = $true

# Action - PowerShell script with loop
$action = $taskDefinition.Actions.Create(0)  # Execute
$action.Path = 'powershell.exe'
$action.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Loop -Interval 30"
$action.WorkingDirectory = 'D:\DevOptimizer\scripts'

# Register
# 6 = CREATE_OR_UPDATE, 3 = TASK_LOGON_PASSWORD (for SYSTEM)
$devOptimizerFolder.RegisterTaskDefinition(
    $taskName,
    $taskDefinition,
    6,
    'SYSTEM',
    $null,
    3,
    $null
)

Write-Host "Created/Updated scheduled task: $taskPath$taskName" -ForegroundColor Green
Write-Host "Task runs at system startup (as SYSTEM), script loops every 30 seconds" -ForegroundColor Cyan