<#
.SYNOPSIS
    Shared JSON state management module for DevOptimizer
.DESCRIPTION
    Provides Load-State/Save-State with schema normalization (like wsl-guardian Get-State/Set-State).
    Ensures backward compatibility when state schema evolves.
.NOTES
    Usage: Import-Module D:\DevOptimizer\scripts\lib\State.ps1
    Then use: Load-State, Save-State, Merge-State
#>
#requires -Version 5.1

$ErrorActionPreference = 'Stop'

function Load-State {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StateFile,
        [hashtable]$Defaults = @{}
    )
    if (Test-Path $StateFile) {
        try {
            $json = Get-Content $StateFile -Raw -ErrorAction Stop
            $state = $json | ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $state) { return $Defaults }
            
            # Normalize: ensure all default properties exist
            foreach ($key in $Defaults.Keys) {
                if (-not $state.PSObject.Properties[$key]) {
                    $val = $Defaults[$key]
                    $state | Add-Member -NotePropertyName $key -NotePropertyValue $val -Force
                }
            }
            return $state
        } catch {
            # Corrupted state file - return defaults, log warning
            Write-Warning "State file ${StateFile} corrupted, using defaults: $($_.Exception.Message)"
            return $Defaults
        }
    }
    return $Defaults
}

function Save-State {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StateFile,
        [Parameter(Mandatory)]
        $State,
        [int]$Depth = 3
    )
    $dir = Split-Path $StateFile -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    try {
        $State | ConvertTo-Json -Depth $Depth -Compress | Set-Content -Path $StateFile -Force -Encoding ASCII
    } catch {
        throw "Failed to save state to ${StateFile}: $($_.Exception.Message)"
    }
}

function Merge-State {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $State,
        [hashtable]$Updates
    )
    foreach ($key in $Updates.Keys) {
        if ($State.PSObject.Properties[$key]) {
            $State.$key = $Updates[$key]
        } else {
            $val = $Updates[$key]
            $State | Add-Member -NotePropertyName $key -NotePropertyValue $val -Force
        }
    }
    return $State
}

function Get-StateValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $State,
        [Parameter(Mandatory)]
        [string]$Key,
        $Default = $null
    )
    if ($State.PSObject.Properties[$Key]) {
        return $State.$Key
    }
    return $Default
}

function Set-StateValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $State,
        [Parameter(Mandatory)]
        [string]$Key,
        $Value
    )
    if ($State.PSObject.Properties[$Key]) {
        $State.$Key = $Value
    } else {
        $State | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force
    }
    return $State
}

# Time-based helpers
function Is-CooledDown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $State,
        [Parameter(Mandatory)]
        [string]$LastActionKey,
        [Parameter(Mandatory)]
        [int]$CooldownMinutes
    )
    $lastIso = Get-StateValue -State $State -Key $LastActionKey
    if (-not $lastIso) { return $true }
    try {
        $last = [DateTime]::Parse($lastIso)
        return ((Get-Date) - $last).TotalMinutes -ge $CooldownMinutes
    } catch {
        return $true
    }
}

function Update-LastAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $State,
        [Parameter(Mandatory)]
        [string]$LastActionKey
    )
    return Set-StateValue -State $State -Key $LastActionKey -Value (Get-Date).ToString('o')
}

