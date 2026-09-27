<#
.SYNOPSIS
    DevOptimizer Script Hub - Auto-Discovery Engine
    Scans scripts/, modules/, tools/, portable/ directories to build a dynamic registry of available commands.

.DESCRIPTION
    This script discovers all executable scripts (PowerShell, Batch, Python) across the DevOptimizer
    repository, extracts metadata from headers/comments, and categorizes them using the category taxonomy.
    Output is a structured hashtable suitable for registry building.

.PARAMETER RootPath
    Root directory of DevOptimizer installation. Defaults to D:\DevOptimizer

.PARAMETER CategoriesPath
    Path to categories.json for category metadata. Defaults to config\categories.json

.PARAMETER OutputPath
    Optional path to write the discovery results as JSON.

.PARAMETER PassThru
    If specified, outputs the discovery hashtable to the pipeline.

.EXAMPLE
    .\Discover-Scripts.ps1 -RootPath "D:\DevOptimizer" -OutputPath "config\discovered-scripts.json"

.EXAMPLE
    $discovery = .\Discover-Scripts.ps1 -PassThru
    $discovery.Scripts.Count
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$RootPath = "D:\DevOptimizer",

    [Parameter(Position=1)]
    [string]$CategoriesPath = "config\categories.json",

    [Parameter(Position=2)]
    [string]$OutputPath,

    [Parameter()]
    [switch]$PassThru
)

# Load categories for metadata
$categoriesFullPath = Join-Path $RootPath $CategoriesPath
$categoryMetadata = @{}
if (Test-Path $categoriesFullPath) {
    $catJson = Get-Content $categoriesFullPath -Raw -Encoding UTF8
    $cats = $catJson | ConvertFrom-Json
    foreach ($cat in $cats) {
        $categoryMetadata[$cat.name] = $cat
    }
}

# Define scan directories
$scanDirs = @(
    @{ Path = Join-Path $RootPath "scripts"; Type = "Script"; Recurse = $true },
    @{ Path = Join-Path $RootPath "modules"; Type = "Module"; Recurse = $true },
    @{ Path = Join-Path $RootPath "tools"; Type = "Tool"; Recurse = $true },
    @{ Path = Join-Path $RootPath "portable"; Type = "Portable"; Recurse = $true }
)

# Supported script extensions
$scriptExtensions = @(".ps1", ".bat", ".cmd", ".py")

$discovered = @{
    Timestamp = (Get-Date).ToString("o")
    RootPath = $RootPath
    Scripts = @()
    Modules = @()
    Tools = @()
    Portable = @()
    Categories = @{}
    Statistics = @{
        TotalFiles = 0
        TotalScripts = 0
        ByType = @{}
        ByCategory = @{}
        ByExtension = @{}
    }
}

# Initialize type arrays
$typeArrays = @{
    Script = @()
    Module = @()
    Tool = @()
    Portable = @()
}

function Extract-ScriptMetadata {
    param(
        [string]$FilePath,
        [string]$Type
    )

    $metadata = @{
        Name = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
        FullPath = $FilePath
        RelativePath = $FilePath.Substring($RootPath.Length + 1).Replace('\', '/')
        Extension = [System.IO.Path]::GetExtension($FilePath)
        Type = $Type
        Category = "utilities"
        Description = ""
        Version = "1.0.0"
        Author = ""
        Tags = @()
        RequiresAdmin = $false
        RequiresWSL = $false
        RequiresInternet = $false
        Parameters = @()
        Examples = @()
        EntryPoint = ""
        LastModified = (Get-Item $FilePath).LastWriteTime.ToString("o")
        Size = (Get-Item $FilePath).Length
        Hash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.Substring(0, 16)
    }

    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8
        
        # Extract metadata from comment-based help (PowerShell)
        if ($metadata.Extension -eq ".ps1") {
            # .SYNOPSIS
            if ($content -match '(?s)\.SYNOPSIS\s*\n\s*(.+?)\s*\n\s*\.(?:DESCRIPTION|PARAMETER|EXAMPLE|$)') {
                $metadata.Description = $matches[1].Trim()
            }
            # .DESCRIPTION
            if ($content -match '(?s)\.DESCRIPTION\s*\n\s*(.+?)\s*\n\s*\.(?:PARAMETER|EXAMPLE|$)') {
                $metadata.Description = $matches[1].Trim()
            }
            # .PARAMETER
            # Terminator is a LOOKAHEAD: a consuming terminator (\.PARAMETER)
            # eats the next directive's dot, making Matches skip every second
            # parameter block.
            $paramMatches = [regex]::Matches($content, '(?s)\.PARAMETER\s+(\w+)\s*\n\s*(.+?)\s*(?=\n\s*\.(?:PARAMETER|EXAMPLE)|\z)')
            foreach ($match in $paramMatches) {
                $metadata.Parameters += @{ Name = $match.Groups[1].Value; Description = $match.Groups[2].Value.Trim() }
            }
            # .EXAMPLE
            $exampleMatches = [regex]::Matches($content, '(?s)\.EXAMPLE\s*\n\s*(.+?)\s*\n\s*\.(?:PARAMETER|EXAMPLE|$)')
            foreach ($match in $exampleMatches) {
                $metadata.Examples += $match.Groups[1].Value.Trim()
            }
            # Custom tags: # TAGS: tag1, tag2
            if ($content -match '#\s*TAGS?\s*:\s*(.+)') {
                $metadata.Tags = $matches[1].Split(',') | ForEach-Object { $_.Trim() }
            }
            # Custom category: # CATEGORY: category-name
            if ($content -match '#\s*CATEGORY\s*:\s*(\w+)') {
                $metadata.Category = $matches[1].Trim().ToLower()
            }
            # Custom requires: # REQUIRES: admin,wsl,internet
            if ($content -match '#\s*REQUIRES\s*:\s*(.+)') {
                $reqs = $matches[1].ToLower()
                $metadata.RequiresAdmin = $reqs -match 'admin'
                $metadata.RequiresWSL = $reqs -match 'wsl'
                $metadata.RequiresInternet = $reqs -match 'internet'
            }
        }
        # Batch files - look for :: comments
        elseif ($metadata.Extension -in @(".bat", ".cmd")) {
            if ($content -match '(?m)^::\s*SYNOPSIS:\s*(.+)$') {
                $metadata.Description = $matches[1].Trim()
            }
            if ($content -match '(?m)^::\s*CATEGORY:\s*(\w+)$') {
                $metadata.Category = $matches[1].Trim().ToLower()
            }
            if ($content -match '(?m)^::\s*TAGS:\s*(.+)$') {
                $metadata.Tags = $matches[1].Split(',') | ForEach-Object { $_.Trim() }
            }
            if ($content -match '(?m)^::\s*REQUIRES:\s*(.+)$') {
                $reqs = $matches[1].ToLower()
                $metadata.RequiresAdmin = $reqs -match 'admin'
                $metadata.RequiresWSL = $reqs -match 'wsl'
                $metadata.RequiresInternet = $reqs -match 'internet'
            }
        }
        # Python files - look for """ docstrings or # comments
        elseif ($metadata.Extension -eq ".py") {
            if ($content -match '(?s)"""\s*(.+?)\s*"""') {
                $metadata.Description = $matches[1].Trim()
            }
            if ($content -match '#\s*CATEGORY:\s*(\w+)') {
                $metadata.Category = $matches[1].Trim().ToLower()
            }
            if ($content -match '#\s*TAGS:\s*(.+)') {
                $metadata.Tags = $matches[1].Split(',') | ForEach-Object { $_.Trim() }
            }
        }

        # Infer category from path if not explicitly set
        if ($metadata.Category -eq "utilities") {
            $pathLower = $metadata.RelativePath.ToLower()
            foreach ($catName in $categoryMetadata.Keys) {
                $catTags = $categoryMetadata[$catName].tags
                foreach ($tag in $catTags) {
                    if ($pathLower -like "*$tag*" -or $metadata.Name.ToLower() -like "*$tag*") {
                        $metadata.Category = $catName
                        break
                    }
                }
                if ($metadata.Category -ne "utilities") { break }
            }
        }

        # Apply category metadata if available
        if ($categoryMetadata.ContainsKey($metadata.Category)) {
            $catMeta = $categoryMetadata[$metadata.Category]
            $metadata.RequiresAdmin = $catMeta.requiresAdmin
            $metadata.RequiresWSL = $catMeta.requiresWSL
            $metadata.RequiresInternet = $catMeta.requiresInternet
            $metadata.Icon = $catMeta.icon
            $metadata.DisplayName = $catMeta.displayName
        } else {
            $metadata.Icon = "🛠️"
            $metadata.DisplayName = $metadata.Category
        }

        # Generate entry point command
        switch ($metadata.Extension) {
            ".ps1" { $metadata.EntryPoint = "powershell -ExecutionPolicy Bypass -File `"$($metadata.FullPath)`"" }
            ".bat" { $metadata.EntryPoint = "cmd /c `"$($metadata.FullPath)`"" }
            ".cmd" { $metadata.EntryPoint = "cmd /c `"$($metadata.FullPath)`"" }
            ".py"  { $metadata.EntryPoint = "python `"$($metadata.FullPath)`"" }
        }

        return $metadata
    }
    catch {
        $err = $_.Exception.Message
        Write-Warning ("Failed to extract metadata from {0}: {1}" -f $FilePath, $err)
        return $metadata
    }
}

Write-Host "[DISCOVERY] Starting script discovery..." -ForegroundColor Cyan
Write-Host "[DISCOVERY] Root path: $RootPath" -ForegroundColor Gray

# Scan each directory
foreach ($scanDir in $scanDirs) {
    if (-not (Test-Path $scanDir.Path)) {
        Write-Host "[DISCOVERY] Directory not found: $($scanDir.Path)" -ForegroundColor Yellow
        continue
    }

    Write-Host "[DISCOVERY] Scanning $($scanDir.Type): $($scanDir.Path)" -ForegroundColor Green
    
    $files = Get-ChildItem -Path $scanDir.Path -Recurse:$scanDir.Recurse -File -ErrorAction SilentlyContinue |
             Where-Object { $scriptExtensions -contains $_.Extension }

    foreach ($file in $files) {
        # Skip backup files
        if ($file.Name -match '\.backup' -or $file.Name -match '\.bak$') { continue }
        if ($file.DirectoryName -match '\\logs?$' -or $file.DirectoryName -match '\\backup') { continue }

        $metadata = Extract-ScriptMetadata -FilePath $file.FullName -Type $scanDir.Type
        
        $typeArrays[$scanDir.Type] += $metadata
        $discovered.Statistics.TotalFiles++
        $discovered.Statistics.TotalScripts++
        
        # Update statistics
        $type = $scanDir.Type
        $ext = $metadata.Extension
        $cat = $metadata.Category
        
        if (-not $discovered.Statistics.ByType[$type]) { $discovered.Statistics.ByType[$type] = 0 }
        $discovered.Statistics.ByType[$type]++
        
        if (-not $discovered.Statistics.ByExtension[$ext]) { $discovered.Statistics.ByExtension[$ext] = 0 }
        $discovered.Statistics.ByExtension[$ext]++
        
        if (-not $discovered.Statistics.ByCategory[$cat]) { $discovered.Statistics.ByCategory[$cat] = 0 }
        $discovered.Statistics.ByCategory[$cat]++
    }
}

# Assign collected arrays to discovered object
$discovered.Scripts = $typeArrays.Script
$discovered.Modules = $typeArrays.Module
$discovered.Tools = $typeArrays.Tool
$discovered.Portable = $typeArrays.Portable

# Build category summary
foreach ($catName in $categoryMetadata.Keys) {
    $catScripts = $discovered.Scripts + $discovered.Modules + $discovered.Tools + $discovered.Portable |
                  Where-Object { $_.Category -eq $catName }
    
    $discovered.Categories[$catName] = @{
        Name = $catName
        DisplayName = $categoryMetadata[$catName].displayName
        Description = $categoryMetadata[$catName].description
        Icon = $categoryMetadata[$catName].icon
        Order = $categoryMetadata[$catName].order
        Count = $catScripts.Count
        Scripts = $catScripts | Select-Object Name, RelativePath, Description, RequiresAdmin, Extension
    }
}

# Sort categories by order
# $discovered.Categories = $discovered.Categories.GetEnumerator() | 
#     Sort-Object { $_.Value.Order } | 
#     ForEach-Object { @{ $_.Key = $_.Value } } | 
#     ForEach-Object { $_ }

Write-Host "[DISCOVERY] Discovery complete!" -ForegroundColor Green
Write-Host "[DISCOVERY] Total scripts found: $($discovered.Statistics.TotalScripts)" -ForegroundColor Cyan

$typeParts = @()
foreach ($item in $discovered.Statistics.ByType.GetEnumerator()) {
    $typeParts += "$($item.Key)=$($item.Value)"
}
Write-Host "[DISCOVERY] By type: $($typeParts -join ', ')" -ForegroundColor Gray

$catParts = @()
foreach ($item in $discovered.Statistics.ByCategory.GetEnumerator()) {
    $catParts += "$($item.Key)=$($item.Value)"
}
Write-Host "[DISCOVERY] By category: $($catParts -join ', ')" -ForegroundColor Gray

# Write output file if specified
if ($OutputPath) {
    $outPath = if ($OutputPath -match '^[A-Z]:') { $OutputPath } else { Join-Path $RootPath $OutputPath }
    $json = $discovered | ConvertTo-Json -Depth 10 -Compress
    $json | Set-Content -Path $outPath -Encoding UTF8
    Write-Host "[DISCOVERY] Results written to: $outPath" -ForegroundColor Green
}

# Output to pipeline if requested
if ($PassThru) {
    return $discovered
}

# Default output summary
$discovered.Statistics