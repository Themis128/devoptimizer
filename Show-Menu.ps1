<#
.SYNOPSIS
    DevOptimizer Script Hub - Interactive Menu System
    Displays a categorized, searchable menu of all registered commands with quick-access mode.

.DESCRIPTION
    This script loads the hub registry and presents an interactive console menu organized by category.
    Supports quick mode for rapid command execution, favorites, search/filter, and command details.

.PARAMETER RegistryPath
    Path to hub-registry.json. Defaults to config\hub-registry.json

.PARAMETER Quick
    Quick mode - shows flat list of commands with numbers for rapid selection.

.PARAMETER Category
    Filter to show only commands from specific category.

.PARAMETER Search
    Search/filter commands by name or description.

.PARAMETER Favorites
    Show only favorite commands.

.PARAMETER NoColor
    Disable colored output.

.EXAMPLE
    .\Show-Menu.ps1

.EXAMPLE
    .\Show-Menu.ps1 -Quick

.EXAMPLE
    .\Show-Menu.ps1 -Category "system-optimization" -Search "memory"

.EXAMPLE
    .\Show-Menu.ps1 -Favorites
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RegistryPath = "config\hub-registry.json",

    [Parameter()]
    [switch]$Quick,

    [Parameter()]
    [string]$Category,

    [Parameter()]
    [string]$Search,

    [Parameter()]
    [switch]$Favorites,

    [Parameter()]
    [switch]$NoColor
)

$RootPath = "D:\DevOptimizer"
$fullRegistryPath = Join-Path $RootPath $RegistryPath
$favoritesPath = Join-Path $RootPath "config\favorites.json"

# Color helpers
function Write-Color {
    param([string]$Text, [string]$Color = "White", [switch]$NoNewline)
    if ($NoColor) { Write-Host $Text -NoNewline:$NoNewline } else { Write-Host $Text -ForegroundColor $Color -NoNewline:$NoNewline }
}

function Write-Header {
    param([string]$Text)
    Write-Color "+==============================================================================+" "Cyan"
    Write-Color "| " "Cyan" -NoNewline
    Write-Color $Text.PadRight(76) "Yellow" -NoNewline
    Write-Color " |" "Cyan"
    Write-Color "+==============================================================================+" "Cyan"
}

function Write-SubHeader {
    param([string]$Text)
    Write-Color "-- $Text " "Gray" -NoNewline
    Write-Color ("-" * (76 - $Text.Length)) "Gray"
}

# Load registry
if (-not (Test-Path $fullRegistryPath)) {
    Write-Error "Registry not found at: $fullRegistryPath. Run Build-Registry.ps1 first."
    exit 1
}

$registry = Get-Content $fullRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Load favorites (use different variable name to avoid conflict with -Favorites switch)
$favList = @{}
if (Test-Path $favoritesPath) {
    $favJson = Get-Content $favoritesPath -Raw -Encoding UTF8
    if ($favJson) {
        $favData = $favJson | ConvertFrom-Json
        if ($favData.favorites) {
            $favList = @{}
            foreach ($fav in $favData.favorites) {
                $favList[$fav] = $true
            }
        }
    }
}

# Filter commands
$commands = $registry.commands

if ($Category) {
    $commands = $commands | Where-Object { $_.category -eq $Category }
}

if ($Search) {
    $searchLower = $Search.ToLower()
    $commands = $commands | Where-Object { 
        $_.name.ToLower().Contains($searchLower) -or 
        $_.description.ToLower().Contains($searchLower) -or
        $_.tags -contains $Search
    }
}

if ($Favorites) {
    $commands = $commands | Where-Object { $favList.ContainsKey($_.name) }
}

$commands = $commands | Sort-Object category, name

if ($commands.Count -eq 0) {
    Write-Color "No commands found matching criteria." "Yellow"
    exit 0
}

# Group by category
$groups = $commands | Group-Object category

if ($Quick) {
    # Quick mode: flat numbered list
    Write-Header "DevOptimizer Script Hub - Quick Mode"
    Write-Color ""
    
    $index = 1
    foreach ($cmd in $commands) {
        $favMarker = if ($favList.ContainsKey($cmd.name)) { "* " } else { "  " }
        $catShort = $cmd.category.Substring(0, [Math]::Min(3, $cmd.category.Length)).ToUpper()
        Write-Color "$index. " "Cyan" -NoNewline
        Write-Color "$favMarker" "Yellow" -NoNewline
        Write-Color "[$catShort] " "Gray" -NoNewline
        Write-Color "$($cmd.name) " "White" -NoNewline
        Write-Color "- $($cmd.description)" "Gray"
        $index++
    }
    
    Write-Color ""
    Write-Color "Enter command number (or 'q' to quit): " "Cyan" -NoNewline
    $input = Read-Host
    
    if ($input -match '^\d+$' -and [int]$input -ge 1 -and [int]$input -le $commands.Count) {
        $selected = $commands[[int]$input - 1]
        Write-Color "Executing: $($selected.name)..." "Green"
        & "$RootPath\Execute-Command.ps1" -Command $selected.name
    } elseif ($input -eq 'q') {
        Write-Color "Goodbye!" "Cyan"
    } else {
        Write-Color "Invalid selection." "Red"
    }
    
    exit 0
}

# Interactive mode
while ($true) {
    Clear-Host
    Write-Header "DevOptimizer Script Hub - Interactive Menu"
    Write-Color ""
    
    # Show category navigation
    $catIndex = 1
    $catMap = @{}
    foreach ($group in $groups) {
        $catMeta = $registry.categories | Where-Object { $_.name -eq $group.Name } | Select-Object -First 1
        $icon = if ($catMeta -and $catMeta.icon) { $catMeta.icon } else { "+" }
        $cmdCount = $group.Count
        Write-Color "$catIndex. " "Cyan" -NoNewline
        Write-Color "$icon " "Yellow" -NoNewline
        Write-Color "$($group.Name) " "White" -NoNewline
        Write-Color "($cmdCount commands)" "Gray"
        $catMap[$catIndex] = $group.Name
        $catIndex++
    }
    
    Write-Color ""
    Write-Color "F. Favorites" "Yellow"
    Write-Color "S. Search" "Yellow"
    Write-Color "A. All Commands" "Yellow"
    Write-Color "R. Rebuild Registry" "Yellow"
    Write-Color "Q. Quit" "Red"
    Write-Color ""
    
    Write-Color "Select category (1-$($groups.Count)) or option: " "Cyan" -NoNewline
    $choice = Read-Host
    
    if ($choice -eq 'q' -or $choice -eq 'Q') {
        Write-Color "Goodbye!" "Cyan"
        break
    }
    
    if ($choice -eq 'f' -or $choice -eq 'F') {
        # Show favorites
        $favCommands = $registry.commands | Where-Object { $favList.ContainsKey($_.name) }
        if ($favCommands.Count -eq 0) {
            Write-Color "No favorites yet. Press 'f' on a command to toggle favorite." "Yellow"
            Write-Color "Press any key to continue..." "Gray" -NoNewline
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            continue
        }
        
        while ($true) {
            Clear-Host
            Write-Header "Favorites"
            Write-Color ""
            
            $idx = 1
            foreach ($cmd in $favCommands) {
                Write-Color "$idx. " "Cyan" -NoNewline
                Write-Color "* " "Yellow" -NoNewline
                Write-Color "$($cmd.name) " "White" -NoNewline
                Write-Color "- $($cmd.description)" "Gray"
                $idx++
            }
            
            Write-Color ""
            Write-Color "B. Back to main menu" "Yellow"
            Write-Color "Enter number to execute, or 'u <num>' to unfavorite: " "Cyan" -NoNewline
            $input = Read-Host
            
            if ($input -eq 'b' -or $input -eq 'B') { break }
            
            if ($input -match '^u\s+(\d+)$') {
                $num = [int]$matches[1]
                if ($num -ge 1 -and $num -le $favCommands.Count) {
                    $unfav = $favCommands[$num - 1].name
                    $favList.Remove($unfav)
                    $favData = @{ favorites = $favList.Keys | Sort-Object }
                    $favData | ConvertTo-Json -Depth 3 | Set-Content -Path $favoritesPath -Encoding UTF8
                    Write-Color "Removed from favorites: $unfav" "Green"
                    Start-Sleep -Seconds 1
                }
                continue
            }
            
            if ($input -match '^\d+$' -and [int]$input -ge 1 -and [int]$input -le $favCommands.Count) {
                $selected = $favCommands[[int]$input - 1]
                & "$RootPath\Execute-Command.ps1" -Command $selected.name
                Write-Color "Press any key to continue..." "Gray" -NoNewline
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        continue
    }
    
    if ($choice -eq 's' -or $choice -eq 'S') {
        Write-Color "Enter search term: " "Cyan" -NoNewline
        $searchTerm = Read-Host
        if ($searchTerm) {
            & "$RootPath\Show-Menu.ps1" -Search $searchTerm
        }
        continue
    }
    
    if ($choice -eq 'a' -or $choice -eq 'A') {
        & "$RootPath\Show-Menu.ps1"
        continue
    }
    
    if ($choice -eq 'r' -or $choice -eq 'R') {
        Write-Color "Rebuilding registry..." "Yellow"
        & "$RootPath\Build-Registry.ps1" -Validate -Force
        Write-Color "Press any key to continue..." "Gray" -NoNewline
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        continue
    }
    
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $groups.Count) {
        $selectedCategory = $catMap[[int]$choice]
        $catCommands = $commands | Where-Object { $_.category -eq $selectedCategory }
        
        while ($true) {
            Clear-Host
            $catMeta = $registry.categories | Where-Object { $_.name -eq $selectedCategory } | Select-Object -First 1
            $icon = if ($catMeta -and $catMeta.icon) { $catMeta.icon } else { "+" }
            Write-Header "$icon $selectedCategory ($($catCommands.Count) commands)"
            Write-Color ""
            
            $idx = 1
            foreach ($cmd in $catCommands) {
                $favMarker = if ($favList.ContainsKey($cmd.name)) { "* " } else { "  " }
                Write-Color "$idx. " "Cyan" -NoNewline
                Write-Color "$favMarker" "Yellow" -NoNewline
                Write-Color "$($cmd.name) " "White" -NoNewline
                Write-Color "- $($cmd.description)" "Gray"
                $idx++
            }
            
            Write-Color ""
            Write-Color "B. Back to categories" "Yellow"
            Write-Color "Enter number to execute, 'd <num>' for details, 'f <num>' to toggle favorite: " "Cyan" -NoNewline
            $input = Read-Host
            
            if ($input -eq 'b' -or $input -eq 'B') { break }
            
            if ($input -match '^d\s+(\d+)$') {
                $num = [int]$matches[1]
                if ($num -ge 1 -and $num -le $catCommands.Count) {
                    $cmd = $catCommands[$num - 1]
                    Clear-Host
                    Write-Header "Command Details: $($cmd.name)"
                    Write-Color ""
                    Write-Color "Category: " "Cyan" -NoNewline; Write-Color "$($cmd.category)"
                    Write-Color "Type: " "Cyan" -NoNewline; Write-Color "$($cmd.entryPoint)"
                    Write-Color "Path: " "Cyan" -NoNewline; Write-Color "$($cmd.path)"
                    Write-Color "Requires Admin: " "Cyan" -NoNewline; Write-Color "$($cmd.requiresAdmin)"
                    Write-Color "Description: " "Cyan" -NoNewline; Write-Color "$($cmd.description)"
                    Write-Color ""
                    Write-Color "Parameters:" "Yellow"
                    if ($cmd.parameters.Count -eq 0) {
                        Write-Color "  (none)" "Gray"
                    } else {
                        foreach ($p in $cmd.parameters) {
                            $req = if ($p.required) { " [REQUIRED]" } else { " [optional]" }
                            $def = if ($p.default) { " (default: $($p.default))" } else { "" }
                            Write-Color "  - $($p.name) ($($p.type))$req$def" "White"
                            Write-Color "    $($p.description)" "Gray"
                        }
                    }
                    Write-Color ""
                    Write-Color "Press any key to continue..." "Gray" -NoNewline
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
                continue
            }
            
            if ($input -match '^f\s+(\d+)$') {
                $num = [int]$matches[1]
                if ($num -ge 1 -and $num -le $catCommands.Count) {
                    $cmd = $catCommands[$num - 1]
                    if ($favList.ContainsKey($cmd.name)) {
                        $favList.Remove($cmd.name)
                        Write-Color "Removed from favorites: $($cmd.name)" "Green"
                    } else {
                        $favorites[$cmd.name] = $true
                        Write-Color "Added to favorites: $($cmd.name)" "Green"
                    }
                    $favData = @{ favorites = $favList.Keys | Sort-Object }
                    $favData | ConvertTo-Json -Depth 3 | Set-Content -Path $favoritesPath -Encoding UTF8
                    Start-Sleep -Seconds 1
                }
                continue
            }
            
            if ($input -match '^\d+$' -and [int]$input -ge 1 -and [int]$input -le $catCommands.Count) {
                $selected = $catCommands[[int]$input - 1]
                & "$RootPath\Execute-Command.ps1" -Command $selected.name
                Write-Color "Press any key to continue..." "Gray" -NoNewline
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        continue
    }
    
    Write-Color "Invalid selection. Press any key to continue..." "Red" -NoNewline
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}