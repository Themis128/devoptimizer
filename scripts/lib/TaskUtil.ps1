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
        [int]$LogonRepetitionMinutes = 0,
        [Parameter(ParameterSetName='Logon')]
        [int]$LogonRepetitionDurationHours = 24,
        [Parameter(ParameterSetName='Once')]
        [datetime]$OnceAt,
        [Parameter(ParameterSetName='Once')]
        [int]$OnceRepetitionMinutes = 0,
        [Parameter(ParameterSetName='Once')]
        [int]$OnceRepetitionDurationHours = 24,
        [Parameter(ParameterSetName='Daily')]
        [datetime]$DailyAt,
        [Parameter(ParameterSetName='Daily')]
        [int]$DaysInterval = 1,
        [Parameter(ParameterSetName='Weekly')]
        [datetime]$WeeklyAt,
        [Parameter(ParameterSetName='Weekly')]
        [int]$WeeksInterval = 1,
        [Parameter(ParameterSetName='Weekly')]
        [System.DayOfWeek[]]$DaysOfWeek = @('Sunday')
    )
    switch ($PSCmdlet.ParameterSetName) {
        'Logon' {
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            if ($LogonRepetitionMinutes -gt 0) {
                $trigger.RepetitionInterval = (New-TimeSpan -Minutes $LogonRepetitionMinutes)
                $trigger.RepetitionDuration = (New-TimeSpan -Hours $LogonRepetitionDurationHours)
            }
            return $trigger
        }
        'Once' {
            $trigger = New-ScheduledTaskTrigger -Once -At $OnceAt
            if ($OnceRepetitionMinutes -gt 0) {
                $trigger.RepetitionInterval = (New-TimeSpan -Minutes $OnceRepetitionMinutes)
                $trigger.RepetitionDuration = (New-TimeSpan -Hours $OnceRepetitionDurationHours)
            }
            return $trigger
        }
        'Daily' {
            return New-ScheduledTaskTrigger -Daily -At $DailyAt -DaysInterval $DaysInterval
        }
        'Weekly' {
            return New-ScheduledTaskTrigger -Weekly -At $WeeklyAt -WeeksInterval $WeeksInterval -DaysOfWeek $DaysOfWeek
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
    
    # Headless action: conhost --headless + portable pwsh (pwsh.exe on PATH is the
    # broken Store stub). Keeps scheduled runs popup-free.
    $pwshExe = 'D:\DevOptimizer\pwsh\pwsh.exe'
    if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }
    $argString = '-NoProfile -ExecutionPolicy Bypass -File "' + $ScriptPath + '"'
    if ($Arguments.Count -gt 0) {
        $argString += ' ' + ($Arguments -join ' ')
    }
    $action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' -Argument ('--headless "' + $pwshExe + '" ' + $argString)
    
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
    
    # Ensure task path exists (folders map to C:\Windows\System32\Tasks\<path>)
    $folderFs = 'C:\Windows\System32\Tasks' + ($TaskPath -replace '/', '\').TrimEnd('\')
    if (-not (Test-Path $folderFs)) {
        try {
            New-Item -ItemType Directory -Force -Path $folderFs -ErrorAction Stop | Out-Null
        } catch {
            Write-Warning "Could not create task folder $folderFs`: $_"
        }
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

if ($MyInvocation.MyCommand.Module) {
    Export-ModuleMember -Function Register-DevOptTask, Unregister-DevOptTask, Get-DevOptTask, Get-DevOptPrincipal, Get-DevOptSettings, Get-DevOptTrigger
}