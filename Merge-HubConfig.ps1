<#
.SYNOPSIS
    Merges a base configuration with an overlay configuration using deep merge semantics.
    Objects are merged recursively, arrays are replaced entirely, overlay values win on conflicts.

.DESCRIPTION
    This script implements the config merge logic for DevOptimizer Script Hub.
    Base config (devoptimizer-config.json) + Overlay config (hub-config.json) = Merged config
    
    Merge rules:
    - If both values are hashtables (objects): recurse and merge
    - If both values are arrays: overlay completely replaces base
    - Otherwise: overlay value wins
    - Keys only in base are preserved
    - Keys only in overlay are added

.PARAMETER BaseConfigPath
    Path to the base configuration JSON file (e.g., devoptimizer-config.json)

.PARAMETER OverlayConfigPath
    Path to the overlay configuration JSON file (e.g., hub-config.json)

.PARAMETER OutputPath
    Optional path to write the merged configuration as JSON

.PARAMETER PassThru
    If specified, outputs the merged hashtable to the pipeline

.EXAMPLE
    .\Merge-HubConfig.ps1 -BaseConfigPath config\devoptimizer-config.json -OverlayConfigPath config\hub-config.json -OutputPath config\merged-config.json

.EXAMPLE
    $merged = .\Merge-HubConfig.ps1 -BaseConfigPath config\devoptimizer-config.json -OverlayConfigPath config\hub-config.json -PassThru
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$BaseConfigPath,

    [Parameter(Mandatory=$true, Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]$OverlayConfigPath,

    [Parameter(Position=2)]
    [string]$OutputPath,

    [Parameter()]
    [switch]$PassThru
)

function Merge-Hashtable {
    param(
        [hashtable]$Base,
        [hashtable]$Overlay
    )

    $result = @{}
    
    # Copy all base keys first
    foreach ($key in $Base.Keys) {
        $result[$key] = $Base[$key]
    }
    
    # Merge overlay keys
    foreach ($key in $Overlay.Keys) {
        $baseValue = $Base[$key]
        $overlayValue = $Overlay[$key]
        
        if ($null -ne $baseValue -and $baseValue -is [hashtable] -and $overlayValue -is [hashtable]) {
            # Both are objects - deep merge recursively
            $result[$key] = Merge-Hashtable -Base $baseValue -Overlay $overlayValue
        }
        elseif ($baseValue -is [array] -and $overlayValue -is [array]) {
            # Both are arrays - overlay replaces entirely
            $result[$key] = $overlayValue
        }
        else {
            # Any other case - overlay wins
            $result[$key] = $overlayValue
        }
    }
    
    return $result
}

# Read and parse base config
$basePath = Resolve-Path -Path $BaseConfigPath -ErrorAction Stop
$baseJson = Get-Content -Path $basePath -Raw -Encoding UTF8
$baseObj = $baseJson | ConvertFrom-Json
$baseConfig = @{}
$baseObj.PSObject.Properties | ForEach-Object { $baseConfig[$_.Name] = $_.Value }

# Read and parse overlay config
$overlayPath = Resolve-Path -Path $OverlayConfigPath -ErrorAction Stop
$overlayJson = Get-Content -Path $overlayPath -Raw -Encoding UTF8
$overlayObj = $overlayJson | ConvertFrom-Json
$overlayConfig = @{}
$overlayObj.PSObject.Properties | ForEach-Object { $overlayConfig[$_.Name] = $_.Value }

# Perform deep merge
$merged = Merge-Hashtable -Base $baseConfig -Overlay $overlayConfig

# Write to output file if specified
if ($OutputPath) {
    $mergedJson = $merged | ConvertTo-Json -Depth 10 -Compress
    $mergedJson | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "Merged configuration written to: $OutputPath" -ForegroundColor Green
}

# Output to pipeline if requested
if ($PassThru) {
    return $merged
}

# Default: output as JSON to stdout
$merged | ConvertTo-Json -Depth 10 -Compress