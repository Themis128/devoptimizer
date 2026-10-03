<#
.SYNOPSIS
    DevOptimizer Script Hub - Registry Builder
    Builds the hub registry from discovered scripts, validates against schema, and writes hub-registry.json.

.DESCRIPTION
    This script takes the output from Discover-Scripts.ps1, transforms it into the registry schema format,
    validates it against hub-registry.schema.json using the JSON validator, and writes the final registry.
    The registry is the single source of truth for all hub commands.

.PARAMETER DiscoveryPath
    Path to discovered scripts JSON (from Discover-Scripts.ps1 -OutputPath). 
    If not provided, runs discovery inline.

.PARAMETER SchemaPath
    Path to hub-registry.schema.json for validation. Defaults to config\hub-registry.schema.json

.PARAMETER OutputPath
    Path to write the final registry JSON. Defaults to config\hub-registry.json

.PARAMETER Validate
    If specified, validates the registry against the schema. Requires Validate-JsonSchema.ps1.

.PARAMETER Force
    If specified, overwrites existing registry without prompting.

.PARAMETER RootPath
    Root directory of DevOptimizer installation. Defaults to current directory.

.EXAMPLE
    .\Build-Registry.ps1 -DiscoveryPath "config\discovered-scripts.json" -Validate

.EXAMPLE
    .\Build-Registry.ps1 -Validate -Force -RootPath "D:\DevOptimizer"
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$DiscoveryPath,

    [Parameter(Position=1)]
    [string]$SchemaPath = "config\hub-registry.schema.json",

    [Parameter(Position=2)]
    [string]$OutputPath = "config\hub-registry.json",

    [Parameter()]
    [switch]$Validate,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [string]$RootPath = (Get-Location).Path
)

# Normalize RootPath
$RootPath = $RootPath.TrimEnd('\')
$fullSchemaPath = Join-Path $RootPath $SchemaPath
$fullOutputPath = Join-Path $RootPath $OutputPath

# Load or run discovery
    $discovery = $null
    if ($DiscoveryPath -and (Test-Path (Join-Path $RootPath $DiscoveryPath))) {
        Write-Host "[REGISTRY] Loading discovery from: $DiscoveryPath" -ForegroundColor Cyan
        $json = Get-Content (Join-Path $RootPath $DiscoveryPath) -Raw -Encoding UTF8
        $discovery = $json | ConvertFrom-Json
    } else {
        Write-Host "[REGISTRY] Running inline discovery..." -ForegroundColor Cyan
        $discovery = & "$RootPath\Discover-Scripts.ps1" -RootPath $RootPath -PassThru
    }

    if (-not $discovery) {
        Write-Error "[REGISTRY] No discovery data available"
        exit 1
    }

    Write-Host "[REGISTRY] Building registry from $($discovery.Statistics.TotalScripts) discovered scripts..." -ForegroundColor Green

    # Convert Categories from hashtable to lookup hashtable
    $categoryLookup = @{}
    if ($discovery['Categories']) {
        foreach ($catName in $discovery['Categories'].Keys) {
            $categoryLookup[$catName] = $discovery['Categories'][$catName]
        }
    }

# Process each type of discovered item
$allItems = @()
$allItems += $discovery.Scripts
$allItems += $discovery.Modules
$allItems += $discovery.Tools
$allItems += $discovery.Portable

# Group by category
$categoryGroups = $allItems | Group-Object { $_.Item('Category') }

$commandsArray = @()
$categoriesArray = @()
$commandIds = @{}  # Track used command IDs for uniqueness

foreach ($group in $categoryGroups) {
    $catName = $group.Name
    $catDisplayName = $catName
    $catIcon = "🛠️"
    $catDescription = ""
    $catOrder = 99
    
    # Get category metadata from discovery
    if ($categoryLookup.ContainsKey($catName)) {
        $catMeta = $categoryLookup[$catName]
        $catDisplayName = $catMeta.DisplayName
        $catIcon = $catMeta.Icon
        $catDescription = $catMeta.Description
        $catOrder = $catMeta.Order
    }
    
    $catCommands = @()
    foreach ($item in $group.Group) {
        # Command IDs must be schema-valid kebab-case (^[a-z0-9-]+$). Filenames with
        # emoji/non-ASCII (e.g. '📋-UI-ACCESS-GUIDE-Admin.bat') are stripped to their
        # ASCII core; an empty result skips the file rather than emitting an invalid ID.
        $baseId = ($item.Item('Name').ToLower() -replace '[^a-z0-9 _-]', '') -replace '\s+', '-'
        if (-not $baseId -or $baseId -notmatch '^[a-z0-9-]+$') {
            Write-Host "[REGISTRY] Skipping '$($item.Item('Name'))': filename yields no valid command id" -ForegroundColor Yellow
            continue
        }
        # Ensure unique command IDs
        $cmdId = $baseId
        $counter = 1
        while ($commandIds.ContainsKey($cmdId)) {
            $cmdId = "$baseId-$counter"
            $counter++
        }
        $commandIds[$cmdId] = $true
        
        # Map entry point to schema enum
        $entryPointMap = @{
            "powershell" = "powershell"
            "cmd" = "cmd"
            "batch" = "cmd"
            "bash" = "bash"
            "python" = "python"
            "node" = "node"
            "wsl" = "wsl"
        }
        $entryPoint = if ($entryPointMap.ContainsKey($item.Item('Type'))) { $entryPointMap[$item.Item('Type')] } else { "powershell" }
        if ($item.Item('Extension') -eq ".bat" -or $item.Item('Extension') -eq ".cmd") { $entryPoint = "cmd" }
        if ($item.Item('Extension') -eq ".py") { $entryPoint = "python" }
        if ($item.Item('Extension') -eq ".sh") { $entryPoint = "bash" }
        
        # Transform parameters to schema format
        $schemaParams = @()
        if ($item.Item('Parameters')) {
            foreach ($param in $item.Item('Parameters')) {
                # Discovery parses comment-based help; multi-function scripts can yield
                # garbage entries. Enforce the schema's parameter-name pattern.
                $paramName = [string]$param.Item('Name')
                if ($paramName -notmatch '^[A-Za-z][A-Za-z0-9_]*$') { continue }
                $schemaParam = @{
                    name = $paramName
                    type = if ($param.Item('Type')) { $param.Item('Type') } else { "string" }
                    description = if ($param.Item('Description')) { $param.Item('Description') } else { "" }
                    required = $param.Item('Required') -eq $true
                }
                if ($param.Item('Default')) { $schemaParam.default = $param.Item('Default') }
                if ($param.Item('Enum')) { $schemaParam.enum = $param.Item('Enum') }
                if ($param.Item('MinLength')) { $schemaParam.minLength = $param.Item('MinLength') }
                if ($param.Item('MaxLength')) { $schemaParam.maxLength = $param.Item('MaxLength') }
                if ($param.Item('Minimum')) { $schemaParam.minimum = $param.Item('Minimum') }
                if ($param.Item('Maximum')) { $schemaParam.maximum = $param.Item('Maximum') }
                $schemaParams += $schemaParam
            }
        }
        
        # Build metadata object per schema
        $now = (Get-Date).ToString("o")
        $metadata = @{
            author = if ($item.Item('Author')) { $item.Item('Author') } else { "Unknown" }
            created = if ($item.Item('LastModified')) { $item.Item('LastModified') } else { $now }
            modified = if ($item.Item('LastModified')) { $item.Item('LastModified') } else { $now }
            version = if ($item.Item('Version')) { $item.Item('Version') } else { "1.0.0" }
            sourceUrl = "https://github.com/devoptimizer/devoptimizer"
        }
        if ($item.Item('License')) { $metadata.license = $item.Item('License') }
        if ($item.Item('Dependencies')) { $metadata.dependencies = $item.Item('Dependencies') }
        if ($item.Item('TestedOn')) { $metadata.testedOn = $item.Item('TestedOn') }
        
        # Elevation metadata: honor the target script's own '#Requires -RunAsAdministrator'
        # so registry metadata matches actual runtime requirements (Execute-Command.ps1
        # auto-elevates from requiresAdmin). 2026-09-26: dev-cache-cleaner hit
        # ScriptRequiresElevation while its metadata said requiresAdmin=false.
        # NOTE: metadata values arrive with inconsistent typing depending on the
        # discovery source (bool vs string 'False'; extension '.ps1' vs 'ps1') -
        # normalize both, and never trust truthiness of a non-empty string.
        $requiresAdmin = $false
        $metaAdmin = $item.Item('RequiresAdmin')
        if ($metaAdmin -is [bool]) { $requiresAdmin = $metaAdmin }
        elseif ($metaAdmin -is [string]) { $requiresAdmin = ($metaAdmin -match '^(?i)true$') }
        elseif ($metaAdmin -is [int]) { $requiresAdmin = ($metaAdmin -ne 0) }

        $ext = ([string]$item.Item('Extension')).TrimStart('.')
        if (-not $requiresAdmin -and $ext -eq 'ps1') {
            $targetScript = Join-Path $RootPath $item.Item('RelativePath')
            if (Test-Path -LiteralPath $targetScript) {
                $targetText = Get-Content -LiteralPath $targetScript -Raw -ErrorAction SilentlyContinue
                if ($targetText -match '(?im)^\s*#\s*requires\s+-RunAsAdministrator') { $requiresAdmin = $true }
            }
        }

        # Description: cap to the schema's 500-char limit (discovery can glue whole
        # function bodies from multi-function scripts into one description).
        $desc = if ($item.Item('Description')) { $item.Item('Description') } else { "No description available" }
        if ($desc.Length -gt 500) { $desc = $desc.Substring(0, 497) + '...' }

        $command = @{
            name = $cmdId
            category = $catName
            path = $item.Item('RelativePath')
            description = $desc
            parameters = $schemaParams
            requiresAdmin = $requiresAdmin
            tags = @(if ($item.Item('Tags')) { $item.Item('Tags') } else { @() })
            entryPoint = $entryPoint
            metadata = $metadata
        }
        
        $commandsArray += $command
        $catCommands += $cmdId
    }
    
    # Calculate lastUpdated for category
    $catItems = $group.Group
    $lastUpdated = ($catItems | ForEach-Object { $_.LastModified } | Sort-Object -Descending | Select-Object -First 1)
    if (-not $lastUpdated) { $lastUpdated = (Get-Date).ToString("o") }
    
    # Get full category metadata from discovery
    $catMeta = $categoryLookup[$catName]
    
    $categoriesArray += @{
        name = $catName
        commandCount = $catCommands.Count
        lastUpdated = $lastUpdated
        # Internal sort key only - stripped before emission (schema forbids
        # additional properties; display metadata lives in config/categories.json).
        sortOrder = if ($catMeta) { [int]$catMeta.Order } else { 99 }
    }
}

# Sort categories by their config-defined order, then emit schema-conformant objects
$categoriesArray = @(
    @($categoriesArray | Sort-Object sortOrder) | ForEach-Object {
        @{
            name = $_.name
            commandCount = $_.commandCount
            lastUpdated = $_.lastUpdated
        }
    }
)

# Build final registry object matching schema
$registry = @{
    version = "1.0.0"
    generated = (Get-Date).ToString("o")
    commands = $commandsArray
    categories = $categoriesArray
}

Write-Host "[REGISTRY] Built registry with $($commandsArray.Count) commands in $($categoriesArray.Count) categories" -ForegroundColor Green

# Validate against schema if requested
if ($Validate) {
    Write-Host "[REGISTRY] Validating against schema: $fullSchemaPath" -ForegroundColor Yellow
    
    $validatorPath = "$RootPath\Validate-JsonSchema.ps1"
    if (Test-Path $validatorPath) {
        # Write temp registry for validation
        $tempPath = "$env:TEMP\hub-registry-temp.json"
        $registry | ConvertTo-Json -Depth 10 -Compress | Set-Content -Path $tempPath -Encoding UTF8
        
        $result = & $validatorPath -SchemaPath $fullSchemaPath -JsonPath $tempPath
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "[REGISTRY] Schema validation PASSED" -ForegroundColor Green
        } else {
            Write-Error "[REGISTRY] Schema validation FAILED"
            Write-Host $result
            Remove-Item $tempPath -ErrorAction SilentlyContinue
            exit 1
        }
        
        Remove-Item $tempPath -ErrorAction SilentlyContinue
    } else {
        Write-Warning "[REGISTRY] Validator not found at $validatorPath, skipping validation"
    }
}

# Check if output exists and force not specified
if ((Test-Path $fullOutputPath) -and (-not $Force)) {
    Write-Host "[REGISTRY] Registry already exists at $fullOutputPath. Use -Force to overwrite." -ForegroundColor Yellow
    exit 0
}

# Write registry
$registryJson = $registry | ConvertTo-Json -Depth 10 -Compress
$registryJson | Set-Content -Path $fullOutputPath -Encoding UTF8

Write-Host "[REGISTRY] Registry written to: $fullOutputPath" -ForegroundColor Green
Write-Host "[REGISTRY] Commands: $($commandsArray.Count), Categories: $($categoriesArray.Count)" -ForegroundColor Cyan

# Output summary
@{
    totalCommands = $commandsArray.Count
    totalCategories = $categoriesArray.Count
    discoveryTimestamp = $discovery.Timestamp
    rootPath = $discovery.RootPath
}