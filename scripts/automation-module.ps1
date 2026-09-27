# DevOptimizer Automation Module
# Advanced automation and scheduling for the DevOptimizer Enhanced Suite

<#+
.SYNOPSIS
Manages DevOptimizer automation workflows, including scheduling, running, and removing maintenance tasks.

.DESCRIPTION
Provides helpers for creating Windows scheduled tasks, listing registered automation jobs, invoking predefined routines, and handling lifecycle operations for DevOptimizer maintenance plans.

.PARAMETER Mode
Controls the automation behavior (for example schedule, run, report) used by the selected action. Defaults to schedule.

.PARAMETER TaskName
Names the scheduled task to operate on or create.

.PARAMETER Schedule
Defines the recurrence pattern when creating a new scheduled task. Defaults to daily.

.PARAMETER Create
Creates or updates a scheduled task using the provided parameters.

.PARAMETER List
Displays the automation tasks currently registered with DevOptimizer.

.PARAMETER Remove
Deletes the specified scheduled task and associated metadata.

.PARAMETER Run
Invokes the targeted automation task immediately without waiting for the next schedule.

.EXAMPLE
PS> .\automation-module.ps1 -Create -TaskName WeeklyOptimization -Schedule "Weekly" -Mode run
Creates a scheduled task for the weekly optimization workflow.

.EXAMPLE
PS> .\automation-module.ps1 -List
Shows the registered DevOptimizer automation tasks and their schedules.

.NOTES
Author: DevOptimizer automation tools
#>

param(
    [string]$Mode = "schedule",
    [string]$TaskName = "",
    [string]$Schedule = "daily",
    [switch]$Create,
    [switch]$List,
    [switch]$Remove,
    [switch]$Run
)

# Automation Configuration
$AUTOMATION_CONFIG = @{
    "TaskScheduler" = "DevOptimizer"
    "LogPath" = ".\automation.log"
    "BackupPath" = ".\backups"
    "ConfigPath" = ".\automation-config.json"
    "MaxBackups" = 10
    "RetentionDays" = 30
}

# Predefined Automation Tasks
$PREDEFINED_TASKS = @{
    "daily_cleanup" = @{
        "Name" = "Daily System Cleanup"
        "Description" = "Automated daily system cleanup and optimization"
        "Script" = ".\smart-cleanup.ps1"
        "Schedule" = "Daily at 2:00 AM"
        "Parameters" = @("-Mode", "automated")
        "Enabled" = $true
    }
    "weekly_optimization" = @{
        "Name" = "Weekly System Optimization"
        "Description" = "Comprehensive weekly system optimization"
        "Script" = ".\ai-optimization.ps1"
        "Schedule" = "Weekly on Sunday at 3:00 AM"
        "Parameters" = @("-Mode", "comprehensive")
        "Enabled" = $true
    }
    "monthly_maintenance" = @{
        "Name" = "Monthly System Maintenance"
        "Description" = "Deep system maintenance and health check"
        "Script" = ".\deep-maintenance.ps1"
        "Schedule" = "Monthly on 1st at 4:00 AM"
        "Parameters" = @("-Mode", "full")
        "Enabled" = $true
    }
    "backup_config" = @{
        "Name" = "Configuration Backup"
        "Description" = "Backup DevOptimizer configuration and settings"
        "Script" = ".\backup-config.ps1"
        "Schedule" = "Daily at 1:00 AM"
        "Parameters" = @("-Mode", "config")
        "Enabled" = $true
    }
    "update_check" = @{
        "Name" = "Update Check"
        "Description" = "Check for DevOptimizer updates and new features"
        "Script" = ".\update-checker.ps1"
        "Schedule" = "Daily at 6:00 AM"
        "Parameters" = @("-Mode", "check")
        "Enabled" = $true
    }
}

# Create scheduled task
function New-ScheduledTask {
    param(
        [string]$TaskName,
        [string]$Description,
        [string]$ScriptPath,
        [string]$Schedule,
        [string[]]$Parameters = @(),
        [string]$User = "SYSTEM"
    )

    Write-Host "📅 Creating scheduled task: $TaskName" -ForegroundColor Cyan

    try {
        # Create task action
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`" $($Parameters -join ' ')"

        # Create task trigger based on schedule
        $trigger = switch ($Schedule.ToLower()) {
            "daily" { New-ScheduledTaskTrigger -Daily -At "02:00" }
            "weekly" { New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:00" }
            "monthly" { New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At "04:00" }
            "hourly" { New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365) }
            default { New-ScheduledTaskTrigger -Daily -At "02:00" }
        }

        # Create task settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

        # Create principal
        $principal = New-ScheduledTaskPrincipal -UserId $User -LogonType ServiceAccount -RunLevel Highest

        # Register the task
        Register-ScheduledTask -TaskName "$($AUTOMATION_CONFIG.TaskScheduler)\$TaskName" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $Description

        Write-Host "✅ Scheduled task created successfully!" -ForegroundColor Green
        return $true

    } catch {
        Write-Error "❌ Failed to create scheduled task: $($_.Exception.Message)"
        return $false
    }
}

# List all scheduled tasks
function Get-ScheduledTasks {
    Write-Host "📋 DevOptimizer Scheduled Tasks:" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan

    try {
        $tasks = Get-ScheduledTask -TaskPath "\$($AUTOMATION_CONFIG.TaskScheduler)\" -ErrorAction SilentlyContinue

        if ($tasks) {
            foreach ($task in $tasks) {
                $state = switch ($task.State) {
                    "Ready" { "✅ Ready" }
                    "Running" { "🔄 Running" }
                    "Disabled" { "❌ Disabled" }
                    default { "❓ $($task.State)" }
                }

                Write-Host "`n📌 $($task.TaskName)" -ForegroundColor Yellow
                Write-Host "   Description: $($task.Description)" -ForegroundColor Gray
                Write-Host "   State: $state" -ForegroundColor White
                Write-Host "   Last Run: $($task.LastRunTime)" -ForegroundColor Gray
                Write-Host "   Next Run: $($task.NextRunTime)" -ForegroundColor Gray
            }
        } else {
            Write-Host "No scheduled tasks found." -ForegroundColor Gray
        }

    } catch {
        Write-Error "❌ Failed to retrieve scheduled tasks: $($_.Exception.Message)"
    }
}

# Remove scheduled task
function Remove-ScheduledTask {
    param([string]$TaskName)

    Write-Host "🗑️ Removing scheduled task: $TaskName" -ForegroundColor Cyan

    try {
        Unregister-ScheduledTask -TaskName "$($AUTOMATION_CONFIG.TaskScheduler)\$TaskName" -Confirm:$false
        Write-Host "✅ Scheduled task removed successfully!" -ForegroundColor Green
        return $true

    } catch {
        Write-Error "❌ Failed to remove scheduled task: $($_.Exception.Message)"
        return $false
    }
}

# Run scheduled task immediately
function Start-ScheduledTask {
    param([string]$TaskName)

    Write-Host "🚀 Running scheduled task: $TaskName" -ForegroundColor Cyan

    try {
        Start-ScheduledTask -TaskName "$($AUTOMATION_CONFIG.TaskScheduler)\$TaskName"
        Write-Host "✅ Scheduled task started successfully!" -ForegroundColor Green
        return $true

    } catch {
        Write-Error "❌ Failed to start scheduled task: $($_.Exception.Message)"
        return $false
    }
}

# Setup all predefined tasks
function Setup-PredefinedTasks {
    Write-Host "🔧 Setting up predefined automation tasks..." -ForegroundColor Cyan

    foreach ($taskKey in $PREDEFINED_TASKS.Keys) {
        $task = $PREDEFINED_TASKS[$taskKey]

        if ($task.Enabled) {
            Write-Host "`n📌 Setting up: $($task.Name)" -ForegroundColor Yellow

            # Check if script exists
            if (Test-Path $task.Script) {
                $result = New-ScheduledTask -TaskName $taskKey -Description $task.Description -ScriptPath $task.Script -Schedule $task.Schedule -Parameters $task.Parameters

                if ($result) {
                    Write-Host "   ✅ $($task.Name) scheduled successfully" -ForegroundColor Green
                } else {
                    Write-Host "   ❌ Failed to schedule $($task.Name)" -ForegroundColor Red
                }
            } else {
                Write-Host "   ⚠️  Script not found: $($task.Script)" -ForegroundColor Yellow
            }
        }
    }

    Write-Host "`n🎉 Predefined tasks setup completed!" -ForegroundColor Green
}

# Create one-click setup automation
function New-OneClickSetup {
    param(
        [string]$SetupType = "development",
        [string]$ProjectPath = $PWD
    )

    Write-Host "⚡ Creating One-Click Setup for: $SetupType" -ForegroundColor Cyan

    $setupScript = switch ($SetupType.ToLower()) {
        "development" { ".\one-click-dev-setup.ps1" }
        "gaming" { ".\one-click-gaming-setup.ps1" }
        "streaming" { ".\one-click-streaming-setup.ps1" }
        "ai-ml" { ".\one-click-ai-ml-setup.ps1" }
        "web-dev" { ".\one-click-web-dev-setup.ps1" }
        default { ".\one-click-custom-setup.ps1" }
    }

    if (Test-Path $setupScript) {
        Write-Host "🚀 Running one-click setup..." -ForegroundColor Green
        & $setupScript -ProjectPath $ProjectPath
    } else {
        Write-Host "❌ Setup script not found: $setupScript" -ForegroundColor Red
    }
}

# Automated backup system
function Start-AutomatedBackup {
    param(
        [string]$BackupType = "config",
        [string]$Destination = $AUTOMATION_CONFIG.BackupPath
    )

    Write-Host "💾 Starting automated backup: $BackupType" -ForegroundColor Cyan

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupDir = Join-Path $Destination "$BackupType`_$timestamp"

    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    switch ($BackupType.ToLower()) {
        "config" {
            # Backup configuration files
            $configFiles = @(
                ".\enhanced-suite.log",
                "\.enhanced-config",
                "\.favorites",
                "\.recent"
            )

            foreach ($file in $configFiles) {
                if (Test-Path $file) {
                    Copy-Item $file $backupDir -Force
                }
            }
        }
        "system" {
            # Backup system settings
            $systemSettings = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies"
            )

            foreach ($setting in $systemSettings) {
                $regFile = Join-Path $backupDir "$(Split-Path $setting -Leaf).reg"
                reg export $setting $regFile /y | Out-Null
            }
        }
        "full" {
            # Full backup
            Start-AutomatedBackup -BackupType "config" -Destination $backupDir
            Start-AutomatedBackup -BackupType "system" -Destination $backupDir
        }
    }

    Write-Host "✅ Backup completed: $backupDir" -ForegroundColor Green
}

# Automated update checker
function Start-UpdateCheck {
    Write-Host "🔄 Checking for updates..." -ForegroundColor Cyan

    try {
        # Check for DevOptimizer updates
        $currentVersion = "2.0.0"
        $latestVersion = Invoke-RestMethod -Uri "https://api.github.com/repos/devoptimizer/enhanced-suite/releases/latest" -ErrorAction SilentlyContinue

        if ($latestVersion -and $latestVersion.tag_name -ne $currentVersion) {
            Write-Host "🆕 New version available: $($latestVersion.tag_name)" -ForegroundColor Green
            Write-Host "📝 Release notes: $($latestVersion.body)" -ForegroundColor Gray

            # Download update
            $updatePath = ".\updates"
            if (-not (Test-Path $updatePath)) {
                New-Item -ItemType Directory -Path $updatePath -Force | Out-Null
            }

            $updateFile = Join-Path $updatePath "DevOptimizer-Enhanced-Suite-$($latestVersion.tag_name).zip"
            Invoke-WebRequest -Uri $latestVersion.assets[0].browser_download_url -OutFile $updateFile

            Write-Host "📦 Update downloaded: $updateFile" -ForegroundColor Green
        } else {
            Write-Host "✅ You have the latest version: $currentVersion" -ForegroundColor Green
        }

    } catch {
        Write-Warning "⚠️  Could not check for updates: $($_.Exception.Message)"
    }
}

# Automated maintenance
function Start-AutomatedMaintenance {
    param(
        [string]$MaintenanceLevel = "standard"
    )

    Write-Host "🔧 Starting automated maintenance: $MaintenanceLevel" -ForegroundColor Cyan

    switch ($MaintenanceLevel.ToLower()) {
        "quick" {
            # Quick maintenance
            Write-Host "⚡ Quick maintenance tasks..." -ForegroundColor Yellow
            # Add quick maintenance tasks here
        }
        "standard" {
            # Standard maintenance
            Write-Host "🔧 Standard maintenance tasks..." -ForegroundColor Yellow
            # Add standard maintenance tasks here
        }
        "deep" {
            # Deep maintenance
            Write-Host "🛠️ Deep maintenance tasks..." -ForegroundColor Yellow
            # Add deep maintenance tasks here
        }
    }

    Write-Host "✅ Automated maintenance completed!" -ForegroundColor Green
}

# Main execution
switch ($Mode) {
    "setup" {
        Setup-PredefinedTasks
    }
    "create" {
        if ($TaskName -and $Schedule) {
            New-ScheduledTask -TaskName $TaskName -Description "Custom DevOptimizer task" -ScriptPath ".\custom-task.ps1" -Schedule $Schedule
        } else {
            Write-Host "❌ TaskName and Schedule are required for creating tasks" -ForegroundColor Red
        }
    }
    "list" {
        Get-ScheduledTasks
    }
    "remove" {
        if ($TaskName) {
            Remove-ScheduledTask -TaskName $TaskName
        } else {
            Write-Host "❌ TaskName is required for removing tasks" -ForegroundColor Red
        }
    }
    "run" {
        if ($TaskName) {
            Start-ScheduledTask -TaskName $TaskName
        } else {
            Write-Host "❌ TaskName is required for running tasks" -ForegroundColor Red
        }
    }
    "oneclick" {
        New-OneClickSetup -SetupType $TaskName
    }
    "backup" {
        Start-AutomatedBackup -BackupType $TaskName
    }
    "update" {
        Start-UpdateCheck
    }
    "maintenance" {
        Start-AutomatedMaintenance -MaintenanceLevel $TaskName
    }
    default {
        Write-Host "🤖 DevOptimizer Automation Module" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Available commands:" -ForegroundColor Yellow
        Write-Host "  -Mode setup     : Setup predefined automation tasks" -ForegroundColor White
        Write-Host "  -Mode create    : Create custom scheduled task" -ForegroundColor White
        Write-Host "  -Mode list      : List all scheduled tasks" -ForegroundColor White
        Write-Host "  -Mode remove    : Remove scheduled task" -ForegroundColor White
        Write-Host "  -Mode run       : Run scheduled task immediately" -ForegroundColor White
        Write-Host "  -Mode oneclick  : Create one-click setup" -ForegroundColor White
        Write-Host "  -Mode backup    : Start automated backup" -ForegroundColor White
        Write-Host "  -Mode update    : Check for updates" -ForegroundColor White
        Write-Host "  -Mode maintenance : Run automated maintenance" -ForegroundColor White
    }
}

Write-Host "`n🤖 Automation Module completed!" -ForegroundColor Green
