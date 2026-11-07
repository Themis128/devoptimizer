<#
.SYNOPSIS
    Shared JSON state management module for DevOptimizer scripts
.DESCRIPTION
    Provides Load-State, Save-State, Merge-State, Get-StateValue, Set-StateValue,
    Is-CooledDown, Update-LastAction with schema normalization and defaults.
#>
#requires -Version 5.1

$ErrorActionPreference = 'SilentlyContinue'

function Load-State {
    param(
        [string]$StateFile,
        [hashtable]$Defaults = @{}
    )
    if (Test-Path $StateFile) {
        try {
            $json = Get-Content $StateFile -Raw -ErrorAction Stop | ConvertFrom-Json
            $state = @{}
            foreach ($key in $json.PSObject.Properties.Name) {
                $state[$key] = $json.$key
            }
            # Merge with defaults for any missing keys
            foreach ($key in $Defaults.Keys) {
                if (-not $state.ContainsKey($key)) {
                    $state[$key] = $Defaults[$key]
                }
            }
            return $state
        } catch {
            Write-Warning "Failed to load state from $StateFile: $($_.Exception.Message)"
            return $Defaults.Clone()
        }
    }
    return $Defaults.Clone()
}

function Save-State {
    param(
        [string]$StateFile,
        [hashtable]$State
    )
    try {
        $dir = Split-Path $StateFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        # Convert hashtable to ordered dictionary for consistent JSON
        $ordered = [ordered]@{}
        foreach ($key in $State.Keys) {
            $ordered[$key] = $State[$key]
        }
        $ordered | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $StateFile -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Error "Failed to save state to $StateFile: $($_.Exception.Message)"
    }
}

function Merge-State {
    param(
        [string]$StateFile,
        [hashtable]$Updates
    )
    $state = Load-State -StateFile $StateFile -Defaults @{}
    foreach ($key in $Updates.Keys) {
        $state[$key] = $Updates[$key]
    }
    Save-State -StateFile $StateFile -State $state
    return $state
}

function Get-StateValue {
    param(
        [string]$StateFile,
        [string]$Key,
        $Default = $null
    )
    $state = Load-State -StateFile $StateFile -Defaults @{}
    if ($state.ContainsKey($Key)) { return $state[$Key] }
    return $Default
}

function Set-StateValue {
    param(
        [string]$StateFile,
        [string]$Key,
        $Value
    )
    $state = Load-State -StateFile $StateFile -Defaults @{}
    $state[$Key] = $Value
    Save-State -StateFile $StateFile -State $state
}

function Is-CooledDown {
    param(
        [string]$StateFile,
        [string]$ActionKey,
        [int]$CooldownMinutes = 5
    )
    $state = Load-State -StateFile $StateFile -Defaults @{}
    $lastKey = "${ActionKey}LastRun"
    if ($state.ContainsKey($lastKey)) {
        $last = [DateTime]::Parse($state[$lastKey])
        if (($now - $last).TotalMinutes -lt $CooldownMinutes) {
            return $false
        }
    }
    return $true
}

function Update-LastAction {
    param(
        [string]$StateFile,
        [string]$ActionKey
    )
    $state = Load-State -StateFile $StateFile -Defaults @{}
    $state["${ActionKey}LastRun"] = (Get-Date).ToString('o')
    Save-State -StateFile $StateFile -State $state
}
