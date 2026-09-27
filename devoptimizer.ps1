<#
.SYNOPSIS
    DevOptimizer Script Hub - Unified Entry Point

.DESCRIPTION
    Main entry point for the DevOptimizer Script Hub. Provides unified CLI access to all hub functions:
    - Command execution
    - Interactive menu
    - Category browsing
    - Favorites management
    - Health checks
    - Self-update
    - Registry management

.PARAMETER Command
    Execute a specific command by name

.PARAMETER Menu
    Launch interactive menu

.PARAMETER Quick
    Show quick command list

.PARAMETER Category
    Show commands in a specific category

.PARAMETER Search
    Search commands by term

.PARAMETER Favorites
    Show favorite commands

.PARAMETER AddFavorite
    Add command to favorites

.PARAMETER RemoveFavorite
    Remove command from favorites

.PARAMETER ListFavorites
    List all favorites

.PARAMETER Health
    Run health check

.PARAMETER AutoFix
    Auto-fix health issues (use with -Health)

.PARAMETER Update
    Check for updates

.PARAMETER UpdateSource
    Update source: git, local, release

.PARAMETER LocalPath
    Local source path for update

.PARAMETER Rollback
    Rollback to previous version

.PARAMETER ListBackups
    List available backups

.PARAMETER BuildRegistry
    Rebuild the command registry

.PARAMETER Validate
    Validate registry against schema (use with -BuildRegistry)

.PARAMETER Force
    Force operations without confirmation

.PARAMETER AsAdmin
    Run with administrator privileges

.PARAMETER CreateShortcut
    Create desktop shortcut for DevOptimizer

.PARAMETER RemoveShortcut
    Remove desktop shortcut

.PARAMETER PassThru
    Return result object instead of exiting

.EXAMPLE
    devoptimizer.ps1 -Menu
    devoptimizer.ps1 -Quick
    devoptimizer.ps1 -Command "systemcleanup-v5"
    devoptimizer.ps1 -Category "ai-ml"
    devoptimizer.ps1 -Search "cleanup"
    devoptimizer.ps1 -Health -AutoFix
    devoptimizer.ps1 -BuildRegistry -Validate
    devoptimizer.ps1 -CreateShortcut
    devoptimizer.ps1 -Update
    devoptimizer.ps1 -Rollback
#>

[CmdletBinding(DefaultParameterSetName="Default")]
param(
    # Execution
    [Parameter(ParameterSetName="Execute", Position=0)]
    [string]$Command,

    [Parameter(ParameterSetName="Execute")]
    [hashtable]$Parameters = @{},

    # Menu
    [Parameter(ParameterSetName="Menu")]
    [switch]$Menu,

    [Parameter(ParameterSetName="Menu")]
    [switch]$Quick,

    [Parameter(ParameterSetName="Menu")]
    [string]$Category,

    [Parameter(ParameterSetName="Menu")]
    [string]$Search,

    [Parameter(ParameterSetName="Menu")]
    [switch]$Favorites,

    # Favorites
    [Parameter(ParameterSetName="FavAdd", Mandatory=$true)]
    [string]$AddFavorite,

    [Parameter(ParameterSetName="FavRemove", Mandatory=$true)]
    [string]$RemoveFavorite,

    [Parameter(ParameterSetName="FavList")]
    [switch]$ListFavorites,

    # Health
    [Parameter(ParameterSetName="Health")]
    [switch]$Health,

    [Parameter(ParameterSetName="Health")]
    [switch]$AutoFix,

    # Update
    [Parameter(ParameterSetName="Update")]
    [switch]$Update,

    [Parameter(ParameterSetName="Update")]
    [ValidateSet("git", "local", "release")]
    [string]$UpdateSource = "git",

    [Parameter(ParameterSetName="Update")]
    [string]$LocalPath,

    [Parameter(ParameterSetName="Update")]
    [switch]$Rollback,

    [Parameter(ParameterSetName="Update")]
    [switch]$ListBackups,

    # Registry
    [Parameter(ParameterSetName="Registry")]
    [switch]$BuildRegistry,

    [Parameter(ParameterSetName="Registry")]
    [switch]$Validate,

    # Shortcut
    [Parameter(ParameterSetName="Shortcut")]
    [switch]$CreateShortcut,

    [Parameter(ParameterSetName="Shortcut")]
    [switch]$RemoveShortcut,

    # General
    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$AsAdmin,

    [Parameter()]
    [switch]$PassThru
)

$RootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ModulesPath = Join-Path $RootPath "modules"

# Check for admin elevation
if ($AsAdmin -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Re-launching as Administrator..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Definition
    $params = $MyInvocation.UnboundArguments -join " "
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" $params" -Verb RunAs
    exit 0
}

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

function Show-Help {
    Write-Color "+==============================================================================+" "Cyan"
    Write-Color "| DevOptimizer Script Hub - Unified CLI                                       |" "Cyan"
    Write-Color "+==============================================================================+" "Cyan"
    Write-Color ""
    Write-Color "USAGE:" "Yellow"
    Write-Color "  devoptimizer.ps1 [options]" "White"
    Write-Color ""
    Write-Color "EXECUTION:" "Yellow"
    Write-Color "  -Command <name>          Execute a command by name" "White"
    Write-Color "  -Parameters @{...}       Parameters for command execution" "White"
    Write-Color ""
    Write-Color "MENU & DISCOVERY:" "Yellow"
    Write-Color "  -Menu                    Launch interactive menu" "White"
    Write-Color "  -Quick                   Show flat command list" "White"
    Write-Color "  -Category <name>         Show commands in category" "White"
    Write-Color "  -Search <term>           Search commands" "White"
    Write-Color "  -Favorites               Show favorite commands" "White"
    Write-Color ""
    Write-Color "FAVORITES:" "Yellow"
    Write-Color "  -AddFavorite <name>      Add command to favorites" "White"
    Write-Color "  -RemoveFavorite <name>   Remove command from favorites" "White"
    Write-Color "  -ListFavorites           List all favorites" "White"
    Write-Color ""
    Write-Color "HEALTH & MAINTENANCE:" "Yellow"
    Write-Color "  -Health                  Run health check" "White"
    Write-Color "  -AutoFix                 Auto-fix issues (with -Health)" "White"
    Write-Color "  -BuildRegistry           Rebuild command registry" "White"
    Write-Color "  -Validate                Validate registry (with -BuildRegistry)" "White"
    Write-Color ""
    Write-Color "UPDATE & BACKUP:" "Yellow"
    Write-Color "  -Update                  Check/update from source" "White"
    Write-Color "  -UpdateSource <type>     git|local|release (default: git)" "White"
    Write-Color "  -LocalPath <path>        Local source path" "White"
    Write-Color "  -Rollback                Rollback to previous version" "White"
    Write-Color "  -ListBackups             List available backups" "White"
    Write-Color ""
    Write-Color "SHORTCUT:" "Yellow"
    Write-Color "  -CreateShortcut          Create desktop shortcut" "White"
    Write-Color "  -RemoveShortcut          Remove desktop shortcut" "White"
    Write-Color ""
    Write-Color "GENERAL:" "Yellow"
    Write-Color "  -Force                   Skip confirmations" "White"
    Write-Color "  -AsAdmin                 Run as Administrator" "White"
    Write-Color "  -PassThru                Return result object" "White"
    Write-Color ""
    Write-Color "EXAMPLES:" "Yellow"
    Write-Color "  devoptimizer.ps1 -Menu" "Gray"
    Write-Color "  devoptimizer.ps1 -Command systemcleanup-v5" "Gray"
    Write-Color "  devoptimizer.ps1 -Category ai-ml" "Gray"
    Write-Color "  devoptimizer.ps1 -Health -AutoFix" "Gray"
    Write-Color "  devoptimizer.ps1 -CreateShortcut" "Gray"
    Write-Color ""
}

function Create-DesktopShortcut {
    $shell = New-Object -ComObject WScript.Shell
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "DevOptimizer.lnk"
    
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`" -Menu"
    $shortcut.WorkingDirectory = $RootPath
    $shortcut.Description = "DevOptimizer Script Hub - Unified CLI"
    $shortcut.IconLocation = Join-Path $RootPath "icon.ico"
    $shortcut.Save()
    
    Write-Color "Desktop shortcut created: $shortcutPath" "Green"
}

function Remove-DesktopShortcut {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "DevOptimizer.lnk"
    
    if (Test-Path $shortcutPath) {
        Remove-Item -Path $shortcutPath -Force
        Write-Color "Desktop shortcut removed" "Green"
    } else {
        Write-Color "No desktop shortcut found" "Yellow"
    }
}

# Default: show help
if ($PSBoundParameters.Count -eq 0) {
    Show-Help
    if ($PassThru) { return @{ success = $true; action = "help" } }
    exit 0
}

# Create shortcut
if ($CreateShortcut) {
    Create-DesktopShortcut
    if ($PassThru) { return @{ success = $true; action = "create-shortcut" } }
    exit 0
}

if ($RemoveShortcut) {
    Remove-DesktopShortcut
    if ($PassThru) { return @{ success = $true; action = "remove-shortcut" } }
    exit 0
}

# Import master module
try {
    Import-Module (Join-Path $ModulesPath "DevOptimizer-Master.psm1") -Force -ErrorAction Stop
} catch {
    Write-Color "Failed to load DevOptimizer modules: $($_.Exception.Message)" "Red"
    if ($PassThru) { return @{ success = $false; error = $_.Exception.Message } }
    exit 1
}

# Execute command
if ($Command) {
    Write-Color "Executing: $Command" "Cyan"
    $result = & "$RootPath\Execute-Command.ps1" -Command $Command -Parameters $Parameters -PassThru
    if ($PassThru) { return $result }
    if (-not $result.success) { exit 1 }
    exit 0
}

# Menu modes
if ($Menu -or $Quick -or $Category -or $Search -or $Favorites) {
    $menuArgs = @{}
    if ($Quick) { $menuArgs.Quick = $true }
    if ($Category) { $menuArgs.Category = $Category }
    if ($Search) { $menuArgs.Search = $Search }
    if ($Favorites) { $menuArgs.Favorites = $true }
    & "$RootPath\Show-Menu.ps1" @menuArgs
    if ($PassThru) { return @{ success = $true; action = "menu" } }
    exit 0
}

# Favorites management
if ($AddFavorite) {
    & "$RootPath\Manage-Favorites.ps1" -Add -Command $AddFavorite
    if ($PassThru) { return @{ success = $true; action = "add-favorite"; command = $AddFavorite } }
    exit 0
}

if ($RemoveFavorite) {
    & "$RootPath\Manage-Favorites.ps1" -Remove -Command $RemoveFavorite
    if ($PassThru) { return @{ success = $true; action = "remove-favorite"; command = $RemoveFavorite } }
    exit 0
}

if ($ListFavorites) {
    & "$RootPath\Manage-Favorites.ps1" -List
    if ($PassThru) { return @{ success = $true; action = "list-favorites" } }
    exit 0
}

# Health check
if ($Health) {
    $healthArgs = @()
    if ($AutoFix) { $healthArgs += "-AutoFix" }
    & "$RootPath\Check-Health.ps1" @healthArgs
    if ($PassThru) { return @{ success = $true; action = "health" } }
    exit 0
}

# Update
if ($Update -or $Rollback -or $ListBackups) {
    $updateArgs = @()
    if ($Rollback) { $updateArgs += "-Rollback" }
    elseif ($ListBackups) { $updateArgs += "-ListBackups" }
    else {
        $updateArgs += "-Source"; $updateArgs += $UpdateSource
        if ($LocalPath) { $updateArgs += "-LocalPath"; $updateArgs += $LocalPath }
    }
    if ($Force) { $updateArgs += "-Force" }
    & "$RootPath\Update-Hub.ps1" @updateArgs
    if ($PassThru) { return @{ success = $true; action = "update" } }
    exit 0
}

# Build registry
if ($BuildRegistry) {
    # Bind switches by name: array splatting (@buildArgs) passes elements as
    # POSITIONAL values, so "-Force" would bind to Build-Registry's
    # [string]$DiscoveryPath and never set its Force switch.
    & "$RootPath\Build-Registry.ps1" -Validate:$Validate -Force:$Force
    if ($PassThru) { return @{ success = $true; action = "build-registry" } }
    exit 0
}

# Category
if ($Category -and -not $Menu) {
    & "$RootPath\Get-Category.ps1" -Name $Category -ShowCommands
    if ($PassThru) { return @{ success = $true; action = "category"; category = $Category } }
    exit 0
}

Show-Help
if ($PassThru) { return @{ success = $true; action = "help" } }
exit 0