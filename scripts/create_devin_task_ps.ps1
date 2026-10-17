# Simple script to create Devin priority scheduled task using PowerShell cmdlets
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
try {
    $existingTask = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop
    $taskExists = $true
} catch {
    $taskExists = $false
}

if ($taskExists -and -not $Force) {
    Write-Host "Task already exists. Use -Force to update." -ForegroundColor Yellow
    exit 0
}

# Create task action - run the script in loop mode
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Loop -Interval 30" `
    -WorkingDirectory 'D:\DevOptimizer\scripts'

# Trigger - At logon (so it runs when user logs in)
$trigger = New-ScheduledTaskTrigger -AtLogOn

# Settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -Hidden `
    -ExecutionTimeLimit (New-TimeSpan -Hours 24) `
    -RestartCount 0

# Principal - run as current user with highest privileges
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType InteractiveToken `
    -RunLevel Highest

# Register the task
try {
    if ($taskExists) {
        Set-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
        Write-Host "Updated scheduled task: $taskPath$taskName" -ForegroundColor Green
    } else {
        Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
        Write-Host "Created scheduled task: $taskPath$taskName" -ForegroundColor Green
    }
    
    Write-Host "Task runs at logon, script loops every 30 seconds" -ForegroundColor Cyan
}
catch {
    Write-Error "Failed to register task: $_"
    exit 1
}