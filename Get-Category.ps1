<#
.SYNOPSIS
    Category management for DevOptimizer Script Hub

.DESCRIPTION
    Provides functions to list categories, get category details, and manage category metadata.

.PARAMETER List
    List all categories with command counts

.PARAMETER Name
    Get details for a specific category

.PARAMETER ShowCommands
    Show commands in the category

.PARAMETER RegistryPath
    Path to hub-registry.json (default: config\hub-registry.json)

.EXAMPLE
    Get-Category.ps1 -List
    Get-Category.ps1 -Name "System" -ShowCommands
    Get-Category.ps1 -Name "AI" -ShowCommands -RegistryPath ".\config\hub-registry.json"
#>

[CmdletBinding(DefaultParameterSetName="List")]
param(
    [Parameter(ParameterSetName="List")]
    [switch]$List,

    [Parameter(ParameterSetName="Detail", Mandatory=$true)]
    [string]$Name,

    [Parameter(ParameterSetName="Detail")]
    [switch]$ShowCommands,

    [Parameter()]
    [string]$RegistryPath = "config\hub-registry.json"
)

# Resolve paths
$RootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fullRegistryPath = Join-Path $RootPath $RegistryPath

if (-not (Test-Path $fullRegistryPath)) {
    Write-Error "Registry not found at: $fullRegistryPath"
    exit 1
}

$registry = Get-Content $fullRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json

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

if ($List) {
    # List all categories with command counts
    $categories = $registry.categories | Sort-Object order
    
    Write-Color "+==============================================================================+" "Cyan"
    Write-Color "| DevOptimizer Script Hub - Categories                                        |" "Cyan"
    Write-Color "+==============================================================================+" "Cyan"
    Write-Color ""
    
    foreach ($cat in $categories) {
        Write-Color "$($cat.icon) $($cat.name)".PadRight(30) "White" -NoNewline
        Write-Color " [$($cat.commandCount) commands]" "Gray"
        if ($cat.description) {
            Write-Color "   $($cat.description)" "DarkGray"
        }
    }
    
    Write-Color ""
    Write-Color "Total: $($categories.Count) categories, $($registry.commands.Count) commands" "Cyan"
}

if ($Name) {
    # Find category (case-insensitive)
    $category = $registry.categories | Where-Object { $_.name -ieq $Name }
    if (-not $category) {
        Write-Error "Category not found: $Name"
        exit 1
    }
    
    Write-Color "+==============================================================================+" "Cyan"
    Write-Color "| Category: $($category.name)                                                  |" "Cyan"
    Write-Color "+==============================================================================+" "Cyan"
    Write-Color ""
    Write-Color "Display Name: $($category.displayName)" "White"
    Write-Color "Description:  $($category.description)" "Gray"
    Write-Color "Command Count: $($category.commandCount)" "Yellow"
    Write-Color "Last Updated:  $($category.lastUpdated)" "Gray"
    Write-Color ""
    
    if ($ShowCommands) {
        $commands = $registry.commands | Where-Object { $_.category -eq $category.name } | Sort-Object name
        Write-Color "Commands in $($category.name):" "Cyan"
        Write-Color ""
        
        foreach ($cmd in $commands) {
            $adminTag = if ($cmd.requiresAdmin) { "[ADMIN] " } else { "" }
            Write-Color "  $adminTag$($cmd.name)" "White" -NoNewline
            Write-Color " - $($cmd.description)" "Gray"
            if ($cmd.parameters.Count -gt 0) {
                Write-Color "    Parameters:" "DarkGray"
                foreach ($param in $cmd.parameters) {
                    $req = if ($param.required) { "(required)" } else { "(optional)" }
                    $def = if ($param.default -ne $null) { " default='$($param.default)'" } else { "" }
                    Write-Color "      -$($param.name) [$($param.type)] $req$def" "DarkGray"
                }
            }
            Write-Color ""
        }
    }
}