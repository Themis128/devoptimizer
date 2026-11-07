<#
.SYNOPSIS
    Shared scheduled task utilities for DevOptimizer scripts
.DESCRIPTION
    Provides Register-DevOptTask, Unregister-DevOptTask, Get-DevOptTask,
    Get-DevOptPrincipal, Get-DevOptSettings, Get-DevOptTrigger with consistent settings.
#>
#requires -Version 5.1

$ErrorActionPreference = 'Stop'

function Get-DevOptPrincipal {
    param(
        [ValidateSet('User','System')][string]$Account = 'User',
        [switch]$HighestPrivileges
    )
    if ($Account -eq 'System') {
        return New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    }
    $runLevel = if ($HighestPrivileges) { 'Highest' } else { 'Limited' }
    return New-ScheduledTaskPrincipal -UserId (whoami) -LogonType Interactive -RunLevel $runLevel
}

function Get-DevOptSettings {
    param(
        [bool]$AllowStartIfOnBatteries = $true,
        [bool]$DontStopIfGoingOnBatteries = $true,
        [bool]$StartWhenAvailable = $true,
        [bool]$Hidden = $false
    )
    return New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries:$AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries:$DontStopIfGoingOnBatteries `
        -StartWhenAvailable:$StartWhenAvailable `
        -Hidden:$Hidden `
        -Compatibility Win8 `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2)
}

function Get-DevOptTrigger {
    param(
        [ValidateSet('Logon','Once','Daily','Weekly')][string]$Type,
        [string]$At,              # e.g. "03:00" for Daily/Weekly, "2026-11-07 15:00" for Once
        [int]$RepetitionMinutes = 0,
        [int]$RepetitionDurationHours = 24,
        [string[]]$DaysOfWeek = @('Sunday')  # for Weekly
    )
    switch ($Type) {
        'Logon' {
            return New-ScheduledTaskTrigger -AtLogOn
        }
        'Once' {
            $trigger = New-ScheduledTaskTrigger -Once -At $At
            if ($RepetitionMinutes -gt 0) {
                $trigger.Repetition = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $RepetitionMinutes) -RepetitionDuration (New-TimeSpan -Hours $RepetitionDurationHours)
            }
            return $trigger
        }
        'Daily' {
            $trigger = New-ScheduledTaskTrigger -Daily -At $At
            if ($RepetitionMinutes -gt 0) {
                $trigger.Repetition = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $RepetitionMinutes) -RepetitionDuration (New-TimeSpan -Hours $RepetitionDurationHours)
            }
            return $trigger
        }
        'Weekly' {
            $trigger = New-ScheduledTaskTrigger -Weekly -At $At -DaysOfWeek $DaysOfWeek
            if ($RepetitionMinutes -gt 0) {
                $trigger.Repetition = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $RepetitionMinutes) -RepetitionDuration (New-TimeSpan -Hours $RepetitionDurationHours)
            }
            return $trigger
        }
    }
    throw "Invalid trigger type: $Type"
}

function Register-DevOptTask {
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [ValidateSet('User','System')][string]$Account = 'User',
        [switch]$HighestPrivileges,
        [ValidateSet('Logon','Once','Daily','Weekly')][string]$TriggerType = 'Logon',
        [string]$TriggerAt = '',
        [int]$RepetitionMinutes = 0,
        [int]$RepetitionDurationHours = 24,
        [string[]]$DaysOfWeek = @('Sunday'),
        [string]$Description = '',
        [switch]$Force
    )
    
    $taskPath = "\DevOptimizer\$TaskName"
    
    # Check if task exists
    $existing = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing -and -not $Force) {
        Write-Warning "Task $taskPath already exists. Use -Force to update."
        return $existing
    }
    
    # Build action
    $pwshPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"
    if (-not (Test-Path $pwshPath)) {
        $pwshPath = 'pwsh.exe'  # fallback to PATH
    }
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    if ($Arguments.Count -gt 0) {
        $args += " " + ($Arguments -join ' ')
    }
    $action = New-ScheduledTaskAction -Execute $pwshPath -Argument $args -WorkingDirectory (Split-Path $ScriptPath -Parent)
    
    # Build principal
    $principal = Get-DevOptPrincipal -Account $Account -HighestPrivileges:$HighestPrivileges.IsPresent
    
    # Build settings
    $settings = Get-DevOptSettings
    
    # Build triggers
    $triggers = @()
    # Primary trigger
    if ($TriggerType -ne 'None') {
        $triggers += Get-DevOptTrigger -Type $TriggerType -At $TriggerAt -RepetitionMinutes $RepetitionMinutes -RepetitionDurationHours $RepetitionDurationHours -DaysOfWeek $DaysOfWeek
    }
    # Always add AtLogon trigger for resilience
    if ($TriggerType -ne 'Logon') {
        $triggers += Get-DevOptTrigger -Type 'Logon'
    }
    
    # Register
    $task = Register-ScheduledTask `
        -TaskName $TaskName `
        -TaskPath '\DevOptimizer\' `
        -Action $action `
        -Principal $principal `
        -Settings $settings `
        -Trigger $triggers `
        -Description $Description `
        -Force:$Force `
        -ErrorAction Stop
    
    Write-Host "Registered task: $taskPath" -ForegroundColor Green
    return $task
}

function Unregister-DevOptTask {
    param(
        [string]$TaskName,
        [switch]$Force
    )
    $taskPath = "\DevOptimizer\$TaskName"
    try {
        Unregister-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host "Unregistered task: $taskPath" -ForegroundColor Green
        return $true
    } catch {
        if ($Force) { return $false }
        throw
    }
}

function Get-DevOptTask {
    param(
        [string]$TaskName = '*'
    )
    Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName $TaskName -ErrorAction SilentlyContinue
}

function Enable-DevOptTask {
    param([string]$TaskName)
    Enable-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName $TaskName -ErrorAction Stop
    Write-Host "Enabled task: \DevOptimizer\$TaskName" -ForegroundColor Green
}

function Disable-DevOptTask {
    param([string]$TaskName)
    Disable-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName $TaskName -ErrorAction Stop
    Write-Host "Disabled task: \DevOptimizer\$TaskName" -ForegroundColor Yellow
}
