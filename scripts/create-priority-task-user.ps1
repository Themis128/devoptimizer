<#
.SYNOPSIS
    Create Devin priority task as current user using COM (works reliably)
    
.DESCRIPTION
    Creates a scheduled task that runs at user logon and repeats every 30 minutes.
    Runs as the current user with highest privileges.
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

# Use COM object for task scheduler
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

# Principal - run as current user with highest privileges
$taskDefinition.Principal.RunLevel = 1  # Highest
$taskDefinition.Principal.LogonType = 3  # Password (will prompt for creds)
$taskDefinition.Principal.UserId = $env:USERNAME

# Trigger 1 - At logon
$trigger1 = $taskDefinition.Triggers.Create(9)  # On logon
$trigger1.Enabled = $true
$trigger1.UserId = $env:USERNAME

# Trigger 2 - Daily at 00:00, repeating every 30 minutes
$trigger2 = $taskDefinition.Triggers.Create(2)  # Daily
$trigger2.StartBoundary = (Get-Date).ToString('yyyy-MM-dd') + 'T00:00:00'
$trigger2.DaysInterval = 1
$trigger2.Repetition.Interval = 'PT30M'
$trigger2.Repetition.Duration = 'P1D'
$trigger2.Repetition.StopAtDurationEnd = $false
$trigger2.Enabled = $true

# Action - PowerShell script with loop
$action = $taskDefinition.Actions.Create(0)  # Execute
$action.Path = 'powershell.exe'
$action.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Loop -Interval 30"
$action.WorkingDirectory = 'D:\DevOptimizer\scripts'

# Register
# 6 = CREATE_OR_UPDATE, 3 = TASK_LOGON_PASSWORD
$devOptimizerFolder.RegisterTaskDefinition(
    $taskName,
    $taskDefinition,
    6,
    $env:USERNAME,
    $null,  # Will prompt for password if needed
    3,
    $null
)

Write-Host "Created/Updated scheduled task: $taskPath$taskName" -ForegroundColor Green
Write-Host "Task runs at logon and repeats every 30 minutes as current user" -ForegroundColor Cyan