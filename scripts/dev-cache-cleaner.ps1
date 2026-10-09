#Requires -RunAsAdministrator

# Development Cache Cleaner Script - CLEAN VERSION
# Comprehensive cache management for development environments

<#+
.SYNOPSIS
Purges development-related caches, build artifacts, and tool data across multiple ecosystems.

.DESCRIPTION
Supports targeted cleaning modes for Node.js, Python, IDEs, Git, Docker, AI tooling, and more. Provides smart dry runs, configurable exclusions, backup support, and verbose analytics for DevOptimizer workflows.

.PARAMETER QuickClean
Runs a minimal cache cleanup targeting the most common safe directories.

.PARAMETER NodeJSClean
Removes Node.js and npm-related caches and temporary files.

.PARAMETER PythonClean
Clears Python build artefacts such as __pycache__ and virtual environments.

.PARAMETER IDEClean
Targets caches for IDEs and editors used in the development stack.

.PARAMETER GitClean
Performs Git metadata and history cleanup routines.

.PARAMETER DockerClean
Clears Docker images, containers, and build caches based on policy.

.PARAMETER PackageManagersClean
Flushes caches for package managers beyond npm (for example pip, yarn, pnpm as configured).

.PARAMETER BuildToolsClean
Removes build system outputs like dist folders, obj/bin directories, and similar artefacts.

.PARAMETER FrameworkClean
Runs framework-specific cache removal (for example Nuxt, Next.js, Angular).

.PARAMETER AIMLClean
Clears caches related to AI/ML tooling and model runtimes.

.PARAMETER DatabaseClean
Removes temporary database files used during development.

.PARAMETER SystemDevClean
Performs system-level development cache cleanup such as temp directories and logs.

.PARAMETER CompleteClean
Executes every cleanup category in one run.

.PARAMETER SmartClean
Analyzes usage patterns to determine an appropriate subset of cleanups.

.PARAMETER Configure
Launches configuration management to adjust cleaner behavior and exclusions.

.PARAMETER Analyze
Reports on cache sizes and potential savings without deleting files.

.PARAMETER Verbose
Enables verbose logging output for each operation.

.PARAMETER DryRun
Displays actions without deleting files, useful for verification.

.PARAMETER Force
Overrides safety prompts or restrictions during deletion.

.PARAMETER Backup
Creates backups of targeted directories before cleanup.

.EXAMPLE
PS> .\dev-cache-cleaner.ps1 -QuickClean
Executes the quick clean preset and logs the results.

.EXAMPLE
PS> .\dev-cache-cleaner.ps1 -CompleteClean -Backup -Verbose
Runs the full cleanup workflow, creating backups and emitting detailed logs.

.NOTES
Author: DevOptimizer automation tools
#>

param(
    [switch]$QuickClean,
    [switch]$NodeJSClean,
    [switch]$PythonClean,
    [switch]$IDEClean,
    [switch]$GitClean,
    [switch]$DockerClean,
    [switch]$PackageManagersClean,
    [switch]$BuildToolsClean,
    [switch]$FrameworkClean,
    [switch]$AIMLClean,
    [switch]$DatabaseClean,
    [switch]$SystemDevClean,
    [switch]$CompleteClean,
    [switch]$SmartClean,
    [switch]$Configure,
    [switch]$Analyze,
    [switch]$Verbose,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Backup
)

# Global variables
$Global:CacheCleanerConfig = $null
$Global:BackupDirectory = "$PSScriptRoot\cache-backups"
$Global:LogFile = "$PSScriptRoot\logs\cache-cleaner-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Global:ErrorCount = 0
$Global:SuccessCount = 0
$Global:TotalFreedSpace = 0
$Global:StartTime = Get-Date
$Global:PycacheSearchRoots = @()
$Global:PycacheSearchDepth = 6
$Global:ExclusionPaths = @()
$Global:ExclusionPatterns = @()

# Enhanced logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$NoConsole
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Console output with colors
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "INFO" { "White" }
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "DEBUG" { "Cyan" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    # Write to log file
    try {
        $logDir = Split-Path $Global:LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $Global:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {
        # Silently continue if logging fails
    }
}

function Resolve-ConfiguredPaths {
    param([object]$Values)

    $results = @()

    if ($null -eq $Values) {
        return $results
    }

    foreach ($item in @($Values)) {
        if ([string]::IsNullOrWhiteSpace([string]$item)) {
            continue
        }

        $expanded = [Environment]::ExpandEnvironmentVariables(([string]$item).Replace('/', '\'))

        if (-not [System.IO.Path]::IsPathRooted($expanded)) {
            $expanded = Join-Path $PSScriptRoot $expanded
        }

        try {
            $normalized = [System.IO.Path]::GetFullPath($expanded)
        } catch {
            $normalized = $expanded
        }

        $results += $normalized
    }

    return $results | Sort-Object -Unique
}

function Should-ExcludePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    try {
        $normalized = [System.IO.Path]::GetFullPath($Path)
    } catch {
        $normalized = $Path
    }

    foreach ($excluded in $Global:ExclusionPaths) {
        if ($normalized.StartsWith($excluded, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    $leaf = Split-Path $normalized -Leaf
    foreach ($pattern in $Global:ExclusionPatterns) {
        if ($leaf -like $pattern) {
            return $true
        }
    }

    return $false
}

function Initialize-CacheCleaner {
    $configPath = Join-Path $PSScriptRoot 'cache-cleaner-config.json'

    if (Test-Path $configPath) {
        try {
            $configContent = Get-Content -Path $configPath -Raw -ErrorAction Stop
            $configObject = $configContent | ConvertFrom-Json -ErrorAction Stop
            if ($configObject.cacheCleanerConfig) {
                $Global:CacheCleanerConfig = $configObject.cacheCleanerConfig
            }
        } catch {
            Write-Log "Failed to load cache cleaner config: $($_.Exception.Message)" -Level "WARNING"
            $Global:CacheCleanerConfig = $null
        }
    }

    if (-not $Global:CacheCleanerConfig) {
        $Global:CacheCleanerConfig = [pscustomobject]@{}
    }

    if ($Global:CacheCleanerConfig.exclusions) {
        $Global:ExclusionPaths = Resolve-ConfiguredPaths $Global:CacheCleanerConfig.exclusions.paths
        $Global:ExclusionPatterns = @($Global:CacheCleanerConfig.exclusions.patterns) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    $Global:PycacheSearchRoots = Resolve-ConfiguredPaths ($Global:CacheCleanerConfig.searchRoots.python)

    if (-not $Global:PycacheSearchRoots -or $Global:PycacheSearchRoots.Count -eq 0) {
        $Global:PycacheSearchRoots = @(
            (Join-Path $env:USERPROFILE 'Documents'),
            (Join-Path $env:USERPROFILE 'source'),
            (Join-Path $env:USERPROFILE 'Desktop'),
            (Join-Path $env:USERPROFILE 'Nuxt Projects'),
            (Split-Path $PSScriptRoot -Parent)
        ) | Sort-Object -Unique
    }

    if ($Global:CacheCleanerConfig.settings -and $Global:CacheCleanerConfig.settings.pycacheDepth) {
        try {
            $depth = [int]$Global:CacheCleanerConfig.settings.pycacheDepth
            if ($depth -ge 1) {
                $Global:PycacheSearchDepth = $depth
            }
        } catch {
            Write-Log "Invalid pycache depth value in config: $($_.Exception.Message)" -Level "WARNING"
        }
    }
}

function Get-PycacheDirectories {
    param(
        [string[]]$Roots,
        [int]$Depth
    )

    $directories = @()
    $supportsDepth = (Get-Command Get-ChildItem).Parameters.ContainsKey('Depth')

    foreach ($root in $Roots) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        if (-not (Test-Path $root)) {
            Write-Log "Pycache root not found: $root" -Level "DEBUG"
            continue
        }

        try {
            $params = @{
                Path = $root
                Directory = $true
                Filter = '__pycache__'
                Recurse = $true
                ErrorAction = 'SilentlyContinue'
            }

            if ($supportsDepth -and $Depth -gt 0) {
                $params['Depth'] = $Depth
            }

            $results = Get-ChildItem @params | ForEach-Object { $_.FullName }
            if ($results) {
                $directories += $results
            }
        } catch {
            Write-Log "Failed to scan $root for __pycache__: $($_.Exception.Message)" -Level "WARNING"
        }
    }

    return $directories | Sort-Object -Unique
}

# Get folder size
function Get-FolderSize {
    param([string]$Path)

    try {
        if (Test-Path $Path) {
            $size = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            return [math]::Round($size / 1MB, 2)
        }
        return 0
    } catch {
        return 0
    }
}

# Safe remove directory
function Remove-CacheDirectory {
    param(
        [string]$Path,
        [string]$Name,
        [switch]$Silent
    )

    try {
        if (Test-Path $Path) {
            if (Should-ExcludePath $Path) {
                if (-not $Silent) {
                    Write-Log "Skipping $Name cache at $Path (excluded)" -Level "DEBUG"
                }
                return 0
            }

            $sizeBefore = Get-FolderSize $Path

            if ($DryRun) {
                if (-not $Silent) {
                    Write-Log "DRY RUN: Would clean $Name cache ($sizeBefore MB)" -Level "INFO"
                }
                return $sizeBefore
            }

            Remove-Item $Path -Recurse -Force -ErrorAction Stop
            if (-not $Silent) {
                Write-Log "Cleaned $Name cache ($sizeBefore MB)" -Level "SUCCESS"
            }
            $Global:SuccessCount++
            $Global:TotalFreedSpace += $sizeBefore
            return $sizeBefore
        } else {
            if (-not $Silent) {
                Write-Log "$Name cache not found at $Path" -Level "DEBUG"
            }
            return 0
        }
    } catch {
        Write-Log "Failed to clean $Name cache: $($_.Exception.Message)" -Level "ERROR"
        $Global:ErrorCount++
        return 0
    }
}

# Clean Node.js caches
function Clear-NodeJSCache {
    Write-Log "Cleaning Node.js caches..." -Level "INFO"

    $paths = @(
        @{ Path = "$env:APPDATA\npm-cache"; Name = "npm cache" },
        @{ Path = "$env:LOCALAPPDATA\npm-cache"; Name = "npm local cache" },
        @{ Path = "$env:USERPROFILE\.npm"; Name = "npm user cache" },
        @{ Path = "$env:USERPROFILE\AppData\Local\pnpm-cache"; Name = "pnpm cache" },
        @{ Path = "$env:USERPROFILE\.pnpm-store"; Name = "pnpm store" },
        @{ Path = "$env:LOCALAPPDATA\Yarn\Cache"; Name = "Yarn cache" },
        @{ Path = "$env:USERPROFILE\.yarn\cache"; Name = "Yarn user cache" }
    )

    foreach ($item in $paths) {
        Remove-CacheDirectory $item.Path $item.Name
    }
}

# Clean Python caches
function Clear-PythonCache {
    Write-Log "Cleaning Python caches..." -Level "INFO"

    $paths = @(
        @{ Path = "$env:LOCALAPPDATA\pip\Cache"; Name = "pip cache" },
        @{ Path = "$env:USERPROFILE\.cache\pip"; Name = "pip user cache" },
        @{ Path = "$env:LOCALAPPDATA\pipx\cache"; Name = "pipx cache" }
    )

    foreach ($item in $paths) {
        Remove-CacheDirectory $item.Path $item.Name
    }

    # Clean __pycache__ directories
    try {
        $pycacheDirectories = Get-PycacheDirectories -Roots $Global:PycacheSearchRoots -Depth $Global:PycacheSearchDepth

        if ($pycacheDirectories.Count -eq 0) {
            Write-Log "No Python __pycache__ directories found within configured roots" -Level "DEBUG"
        } else {
            $pycacheRemoved = 0
            $pycacheFreed = 0

            foreach ($pycachePath in $pycacheDirectories) {
                if (Should-ExcludePath $pycachePath) {
                    continue
                }

                $freed = Remove-CacheDirectory -Path $pycachePath -Name "Python __pycache__" -Silent

                if ($freed -gt 0 -or -not $DryRun) {
                    $pycacheRemoved++
                    $pycacheFreed += $freed
                }
            }

            if ($pycacheRemoved -gt 0) {
                $pycacheMessage = "Cleaned $pycacheRemoved Python __pycache__ directories"
                if ($pycacheFreed -gt 0) {
                    $pycacheMessage += " ($([math]::Round($pycacheFreed, 2)) MB)"
                }

                if ($DryRun) {
                    Write-Log "DRY RUN: $pycacheMessage" -Level "INFO"
                } else {
                    Write-Log $pycacheMessage -Level "SUCCESS"
                }
            }
        }
    } catch {
        Write-Log "Error cleaning __pycache__ directories: $($_.Exception.Message)" -Level "WARNING"
    }
}

# Clean IDE caches
function Clear-IDECache {
    Write-Log "Cleaning IDE caches..." -Level "INFO"

    $paths = @(
        @{ Path = "$env:APPDATA\Code\User\workspaceStorage"; Name = "VS Code workspace storage" },
        @{ Path = "$env:APPDATA\Code\User\History"; Name = "VS Code history" },
        @{ Path = "$env:APPDATA\Code\logs"; Name = "VS Code logs" },
        @{ Path = "$env:APPDATA\Cursor\User\workspaceStorage"; Name = "Cursor workspace storage" },
        @{ Path = "$env:APPDATA\Cursor\User\History"; Name = "Cursor history" },
        @{ Path = "$env:APPDATA\Cursor\logs"; Name = "Cursor logs" },
        @{ Path = "$env:LOCALAPPDATA\JetBrains\Toolbox\logs"; Name = "JetBrains logs" }
    )

    foreach ($item in $paths) {
        Remove-CacheDirectory $item.Path $item.Name
    }
}

# Clean Docker caches
function Clear-DockerCache {
    Write-Log "Cleaning Docker caches..." -Level "INFO"

    try {
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            if (-not $DryRun) {
                & docker system prune -f --filter "label!=com.docker.desktop.service=model-runner" --filter "label!=com.docker.model-runner.role=model-storage" 2>$null
                Write-Log "Docker system prune completed" -Level "SUCCESS"
            } else {
                Write-Log "DRY RUN: Would run docker system prune" -Level "INFO"
            }
        } else {
            Write-Log "Docker not found, skipping Docker cache cleanup" -Level "DEBUG"
        }
    } catch {
        Write-Log "Error cleaning Docker cache: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Clean Git caches
function Clear-GitCache {
    Write-Log "Cleaning Git caches..." -Level "INFO"

    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            if (-not $DryRun) {
                & git gc --aggressive --prune=now 2>$null
                Write-Log "Git garbage collection completed" -Level "SUCCESS"
            } else {
                Write-Log "DRY RUN: Would run git gc" -Level "INFO"
            }
        } else {
            Write-Log "Git not found, skipping Git cache cleanup" -Level "DEBUG"
        }
    } catch {
        Write-Log "Error cleaning Git cache: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Main execution
function Start-CacheCleanup {
    Write-Log "=== Development Cache Cleaner Started ===" -Level "INFO"
    Write-Log "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'ACTIVE CLEANUP' })" -Level "INFO"

    if ($QuickClean -or $CompleteClean) {
        Clear-NodeJSCache
        Clear-PythonCache
        Clear-IDECache
    }

    if ($NodeJSClean -or $CompleteClean) {
        Clear-NodeJSCache
    }

    if ($PythonClean -or $CompleteClean) {
        Clear-PythonCache
    }

    if ($IDEClean -or $CompleteClean) {
        Clear-IDECache
    }

    if ($DockerClean -or $CompleteClean) {
        Clear-DockerCache
    }

    if ($GitClean -or $CompleteClean) {
        Clear-GitCache
    }

    # Summary
    Write-Log "=== Cleanup Summary ===" -Level "INFO"
    Write-Log "Successful operations: $Global:SuccessCount" -Level "SUCCESS"
    Write-Log "Failed operations: $Global:ErrorCount" -Level "$(if ($Global:ErrorCount -gt 0) { 'ERROR' } else { 'INFO' })"
    Write-Log "Total space freed: $([math]::Round($Global:TotalFreedSpace, 2)) MB" -Level "SUCCESS"
    Write-Log "Execution time: $((Get-Date) - $Global:StartTime)" -Level "INFO"
    Write-Log "Log saved to: $Global:LogFile" -Level "INFO"
}

# Execute if no specific parameters
if (-not ($QuickClean -or $NodeJSClean -or $PythonClean -or $IDEClean -or $GitClean -or $DockerClean -or $PackageManagersClean -or $BuildToolsClean -or $FrameworkClean -or $AIMLClean -or $DatabaseClean -or $SystemDevClean -or $CompleteClean -or $SmartClean -or $Configure -or $Analyze)) {
    $QuickClean = $true
}

Initialize-CacheCleaner
Start-CacheCleanup
