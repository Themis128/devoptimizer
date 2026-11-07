<#
.SYNOPSIS
    Shared scheduled task utilities for DevOptimizer
.DESCRIPTION
    Provides consistent task registration/unregistration with standard settings.
    Eliminates duplication across 10+ scripts.
.NOTES
    Usage: Import-Module D:\DevOptimizer\scripts\lib\TaskUtil.ps1
    Then use: Register-DevOptTask, Unregister-DevOptTask
#>
#requires -Version 5.1

$ErrorActionPreference = 'Stop'

function Get-DevOptPrincipal {
    param(
        [ValidateSet('User','System')]
        [string]$Account = 'User',
        [ValidateSet('Interactive','ServiceAccount')]
        [string]$LogonType = 'Interactive',
        [ValidateSet('Limited','Highest')]
        [string]$RunLevel = 'Highest'
    )
    $userName = if ($Account -eq 'System') { 'SYSTEM' } else { (Get-CimInstance Win32_ComputerSystem).UserName }
    return New-ScheduledTaskPrincipal -UserId $userName -LogonType $LogonType -RunLevel $RunLevel
}

function Get-DevOptSettings {
    param(
        [switch]$AllowStartIfOnBatteries,
        [switch]$DontStopIfGoingOnBatteries,
        [switch]$StartWhenAvailable,
        [switch]$Hidden,
        [int]$ExecutionTimeLimitHours = 72
    )
    $params = @{
        AllowStartIfOnBatteries = $AllowStartIfOnBatteries.IsPresent
        DontStopIfGoingOnBatteries = $DontStopIfGoingOnBatteries.IsPresent
        StartWhenAvailable = $StartWhenAvailable.IsPresent
        Hidden = $Hidden.IsPresent
        ExecutionTimeLimit = (New-TimeSpan -Hours $ExecutionTimeLimitHours)
        Compatibility = 'Win8'
    }
    return New-ScheduledTaskSettingsSet @params
}

function Get-DevOptTrigger {
    [CmdletBinding(DefaultParameterSetName='Logon')]
    param(
        [Parameter(ParameterSetName='Logon')]
        [switch]$AtLogon,
        [Parameter(ParameterSetName='Logon')]
        [int]$RepetitionMinutes = 0,
        [Parameter(ParameterSetName='Logon')]
        [int]$RepetitionDurationHours = 24,
        [Parameter(ParameterSetName='Once')]
        [datetime]$At,
        [Parameter(ParameterSetName='Once')]
        [int]$RepetitionMinutes = 0,
        [Parameter(ParameterSetName='Once')]
        [int]$RepetitionDurationHours = 24,
        [Parameter(ParameterSetName='Daily')]
        [datetime]$At,
        [Parameter(ParameterSetName='Daily')]
        [int]$DaysInterval = 1,
        [Parameter(ParameterSetName='Weekly')]
        [datetime]$At,
        [Parameter(ParameterSetName='Weekly')]
        [int]$WeeksInterval = 1,
        [Parameter(ParameterSetName='Weekly')]
        [System.DayOfWeek[]]$DaysOfWeek = @('Sunday')
    )
    switch ($PSCmdlet.ParameterSetName) {
        'Logon' {
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            if ($RepetitionMinutes -gt 0) {
                $trigger.RepetitionInterval = (New-TimeSpan -Minutes $RepetitionMinutes)
                $trigger.RepetitionDuration = (New-TimeSpan -Hours $RepetitionDurationHours)
            }
            return $trigger
        }
        'Once' {
            $trigger = New-ScheduledTaskTrigger -Once -At $At
            if ($RepetitionMinutes -gt 0) {
                $trigger.RepetitionInterval = (New-TimeSpan -Minutes $RepetitionMinutes)
                $trigger.RepetitionDuration = (New-TimeSpan -Hours $RepetitionDurationHours)
            }
            return $trigger
        }
        'Daily' {
            return New-ScheduledTaskTrigger -Daily -At $At -DaysInterval $DaysInterval
        }
        'Weekly' {
            return New-ScheduledTaskTrigger -Weekly -At $At -WeeksInterval $WeeksInterval -DaysOfWeek $DaysOfWeek
        }
    }
}

function Register-DevOptTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TaskName,
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [string]$TaskPath = '\DevOptimizer\',
        [ValidateSet('User','System')]
        [string]$Account = 'User',
        [string[]]$Triggers,
        [hashtable]$TriggerParams = @{},
        [switch]$Force
    )
    
    # Build action
    $argString = '-NoProfile -ExecutionPolicy Bypass -File "' + $ScriptPath + '"'
    if ($Arguments.Count -gt 0) {
        $argString += ' ' + ($Arguments -join ' ')
    }
    $action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument $argString
    
    # Build triggers from params
    $triggerList = @()
    if ($Triggers) {
        foreach ($t in $Triggers) {
            $tp = @{}
            if ($TriggerParams.ContainsKey($t)) {
                $tp = $TriggerParams[$t]
            }
            $triggerList += Get-DevOptTrigger @tp
        }
    } else {
        # Default: at logon
        $triggerList += Get-DevOptTrigger -AtLogon
    }
    
    $settings = Get-DevOptSettings -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
    $principal = Get-DevOptPrincipal -Account $Account
    
    # Ensure task path exists
    $taskFolder = Get-ScheduledTaskFolder -Path $TaskPath -ErrorAction SilentlyContinue
    if (-not $taskFolder) {
        try { Register-ScheduledTask -TaskName 'DevOptimizer-Folder-Placeholder' -TaskPath $TaskPath -Action (New-ScheduledTaskAction -Execute 'cmd.exe' -Argument '/c exit 0') -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)) -Settings (New-ScheduledTaskSettingsSet) -Force -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName 'DevOptimizer-Folder-Placeholder' -TaskPath $TaskPath -Confirm:$false -ErrorAction SilentlyContinue } catch { }
    }
    
    Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Action $action -Trigger $triggerList -Settings $settings -Principal $principal -Force:$Force -ErrorAction Stop
    Write-Host "Registered scheduled task: $TaskPath$TaskName"
}

function Unregister-DevOptTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TaskName,
        [string]$TaskPath = '\DevOptimizer\'
    )
    Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Unregistered scheduled task: $TaskPath$TaskName"
}

function Get-DevOptTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TaskName,
        [string]$TaskPath = '\DevOptimizer\'
    )
    Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Register-DevOptTask, Unregister-DevOptTask, Get-DevOptTask, Get-DevOptPrincipal, Get-DevOptSettings, Get-DevOptTrigger