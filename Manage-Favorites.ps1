<#
.SYNOPSIS
    Favorites management for DevOptimizer Script Hub

.DESCRIPTION
    Add, remove, list, and manage favorite commands. Favorites are stored in config\favorites.json.

.PARAMETER Add
    Add a command to favorites (requires -Command)

.PARAMETER Remove
    Remove a command from favorites (requires -Command)

.PARAMETER List
    List all favorite commands

.PARAMETER Toggle
    Toggle favorite status for a command (requires -Command)

.PARAMETER Clear
    Clear all favorites

.PARAMETER Command
    Command name to add/remove/toggle

.PARAMETER RegistryPath
    Path to hub-registry.json (default: config\hub-registry.json)

.PARAMETER FavoritesPath
    Path to favorites.json (default: config\favorites.json)

.EXAMPLE
    Manage-Favorites.ps1 -List
    Manage-Favorites.ps1 -Add -Command "systemcleanup-v5"
    Manage-Favorites.ps1 -Remove -Command "systemcleanup-v5"
    Manage-Favorites.ps1 -Toggle -Command "systemcleanup-v5"
    Manage-Favorites.ps1 -Clear
#>

[CmdletBinding(DefaultParameterSetName="List")]
param(
    [Parameter(ParameterSetName="Add", Mandatory=$true)]
    [switch]$Add,

    [Parameter(ParameterSetName="Remove", Mandatory=$true)]
    [switch]$Remove,

    [Parameter(ParameterSetName="List")]
    [switch]$List,

    [Parameter(ParameterSetName="Toggle", Mandatory=$true)]
    [switch]$Toggle,

    [Parameter(ParameterSetName="Clear", Mandatory=$true)]
    [switch]$Clear,

    [Parameter(ParameterSetName="Add", Mandatory=$true)]
    [Parameter(ParameterSetName="Remove", Mandatory=$true)]
    [Parameter(ParameterSetName="Toggle", Mandatory=$true)]
    [string]$Command,

    [Parameter()]
    [string]$RegistryPath = "config\hub-registry.json",

    [Parameter()]
    [string]$FavoritesPath = "config\favorites.json"
)

# Resolve paths
$RootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fullRegistryPath = Join-Path $RootPath $RegistryPath
$fullFavoritesPath = Join-Path $RootPath $FavoritesPath

function Write-Color {
    param([string]$Text, [string]$Color = "White", [switch]$NoNewline)
    $fg = switch ($Color) {
        "Red" { [ConsoleColor]::Red }
        "Green" { [ConsoleColor]::Green }
        "Yellow" { [ConsoleColor]::Yellow }
        "Cyan" { [ConsoleColor]::Cyan }
        "Magenta" { [ConsoleColor]::Magenta }
        "Gray" { [ConsoleColor]::Gray }
        "DarkGray" { [ConsoleColor]::DarkGray }
        default { [ConsoleColor]::White }
    }
    if ($NoNewline) {
        Write-Host $Text -ForegroundColor $fg -NoNewline
    } else {
        Write-Host $Text -ForegroundColor $fg
    }
}

# Load registry
if (-not (Test-Path $fullRegistryPath)) {
    Write-Error "Registry not found at: $fullRegistryPath"
    exit 1
}
$registry = Get-Content $fullRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Load or initialize favorites
$favList = @{}
if (Test-Path $fullFavoritesPath) {
    try {
        $favData = Get-Content $fullFavoritesPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($favData.favorites) {
            foreach ($fav in $favData.favorites) {
                $favList[$fav] = $true
            }
        }
    } catch {
        Write-Warning "Could not parse favorites file, starting fresh"
    }
}

function Save-Favorites {
    $favData = @{ favorites = $favList.Keys | Sort-Object }
    $favData | ConvertTo-Json -Depth 3 | Set-Content -Path $fullFavoritesPath -Encoding UTF8
}

function Validate-Command {
    param([string]$CmdName)
    $cmd = $registry.commands | Where-Object { $_.name -eq $CmdName -or $_.name -ieq $CmdName }
    if (-not $cmd) {
        Write-Error "Command not found in registry: $CmdName"
        return $false
    }
    return $true
}

if ($List) {
    Write-Color "+==============================================================================+" "Cyan"
    Write-Color "| DevOptimizer Script Hub - Favorites                                         |" "Cyan"
    Write-Color "+==============================================================================+" "Cyan"
    Write-Color ""
    
    if ($favList.Count -eq 0) {
        Write-Color "No favorites yet. Use -Add -Command <name> to add commands." "Yellow"
    } else {
        $favCommands = $registry.commands | Where-Object { $favList.ContainsKey($_.name) } | Sort-Object name
        foreach ($cmd in $favCommands) {
            $adminTag = if ($cmd.requiresAdmin) { "[ADMIN] " } else { "" }
            Write-Color "  * $adminTag$($cmd.name)" "Yellow" -NoNewline
            Write-Color " - $($cmd.description)" "Gray"
        }
        Write-Color ""
        Write-Color "Total: $($favCommands.Count) favorites" "Cyan"
    }
}

if ($Add) {
    if (-not (Validate-Command $Command)) { exit 1 }
    if ($favList.ContainsKey($Command)) {
        Write-Color "Already in favorites: $Command" "Yellow"
    } else {
        $favList[$Command] = $true
        Save-Favorites
        Write-Color "Added to favorites: $Command" "Green"
    }
}

if ($Remove) {
    if (-not (Validate-Command $Command)) { exit 1 }
    if ($favList.ContainsKey($Command)) {
        $favList.Remove($Command)
        Save-Favorites
        Write-Color "Removed from favorites: $Command" "Green"
    } else {
        Write-Color "Not in favorites: $Command" "Yellow"
    }
}

if ($Toggle) {
    if (-not (Validate-Command $Command)) { exit 1 }
    if ($favList.ContainsKey($Command)) {
        $favList.Remove($Command)
        Save-Favorites
        Write-Color "Removed from favorites: $Command" "Green"
    } else {
        $favList[$Command] = $true
        Save-Favorites
        Write-Color "Added to favorites: $Command" "Green"
    }
}

if ($Clear) {
    $favList.Clear()
    Save-Favorites
    Write-Color "All favorites cleared" "Green"
}