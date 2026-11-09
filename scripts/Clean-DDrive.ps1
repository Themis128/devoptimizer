<#
.SYNOPSIS
    Automated D: drive cleanup - removes stale folders inactive for N months
.DESCRIPTION
    Scans major D: drive folders, identifies those not modified/accessed within the
    configured threshold, and removes them. Designed for scheduled automation.
    
    Folders tracked (configurable via -Targets):
    - Nuxt Projects subfolders (analyzed individually)
    - gdrive (Google Takeout exports)
    - tabby\models (local LLM models)
    - eset (security software installers)
    - Aomei (backup software)
    - DevOptimizer\backups\nas-staging (auto-managed by NAS backup retention)
    
.PARAMETER MonthsInactive
    Threshold in months for considering a folder stale (default: 2)
.PARAMETER Targets
    Hashtable of folder paths to descriptions for reporting
.PARAMETER DryRun
    If set, only reports what would be deleted without deleting
.PARAMETER Force
    Skip confirmation prompts
.PARAMETER LogPath
    Path to log file (default: D:\DevOptimizer\logs\d-drive-cleanup-<date>.log)
.EXAMPLE
    .\Clean-DDrive.ps1 -MonthsInactive 2 -Force
.EXAMPLE
    .\Clean-DDrive.ps1 -MonthsInactive 3 -DryRun
.EXAMPLE
    .\Clean-DDrive.ps1 -Targets @{'D:\custom\path'='Custom folder'} -Force
#>

[CmdletBinding()]
param(
    [int]$MonthsInactive = 2,
    [hashtable]$Targets = @{},
    [switch]$DryRun,
    [switch]$Force,
    [string]$LogPath = "D:\DevOptimizer\logs\d-drive-cleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Default targets if not provided
if ($Targets.Count -eq 0) {
    $Targets = @{
        'D:\gdrive'                        = 'Google Takeout ZIPs'
        'D:\tabby\models\TabbyML'          = 'Local LLM models'
        'D:\eset'                          = 'ESET installer'
        'D:\AomeiDateBackupper11213'       = 'Aomei Backupper'
    }
}

# Ensure log directory
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [ConsoleColor]$Color = 'White')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogPath -Value $line
}

function Get-FolderSize {
    param([string]$Path)
    try {
        $bytes = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round($bytes / 1GB, 2)
    } catch {
        return 0
    }
}

function Get-FolderLastWrite {
    param([string]$Path)
    try {
        return (Get-Item $Path -Force -ErrorAction SilentlyContinue).LastWriteTime
    } catch {
        return [DateTime]::MinValue
    }
}

function Get-NuxtSubfolders {
    param([string]$Root = 'D:\Nuxt Projects')
    if (-not (Test-Path $Root)) { return @() }
    return Get-ChildItem $Root -Directory -Force -ErrorAction SilentlyContinue | Select-Object FullName, LastWriteTime, Name
}

Write-Log "=== D: Drive Cleanup Started ===" -Color Cyan
Write-Log "Threshold: $MonthsInactive months inactive" -Color Cyan
Write-Log "DryRun: $DryRun" -Color Cyan
Write-Log "Log: $LogPath" -Color Cyan

$cutoff = (Get-Date).AddMonths(-$MonthsInactive)
$totalFreed = 0
$deleted = @()
$skipped = @()
$nuxtStale = @()

# Check standard targets
foreach ($path in $Targets.Keys) {
    $desc = $Targets[$path]
    if (-not (Test-Path $path)) {
        Write-Log "SKIP: $path (not found) - $desc" -Color Gray
        $skipped += "$path (not found)"
        continue
    }

    $sizeGB = Get-FolderSize $path
    $lastWrite = Get-FolderLastWrite $path
    $isStale = $lastWrite -lt $cutoff

    Write-Log "CHECK: $path ($sizeGB GB) - LastWrite: $lastWrite - Stale: $isStale - $desc" -Color (if ($isStale) { 'Yellow' } else { 'Green' })

    if ($isStale -and $sizeGB -gt 0) {
        if ($DryRun) {
            Write-Log "DRY-RUN: Would delete $path ($sizeGB GB) - $desc" -Color Yellow
        } else {
            Write-Log "DELETING: $path ($sizeGB GB) - $desc" -Color Red
            try {
                Remove-Item $path -Recurse -Force -ErrorAction Stop
                $totalFreed += $sizeGB
                $deleted += "$path ($sizeGB GB) - $desc"
                Write-Log "  Deleted successfully" -Color Green
            } catch {
                Write-Log "  ERROR: $_" -Color Red
                $skipped += "$path (error: $_)"
            }
        }
    } else {
        $skipped += "$path ($sizeGB GB) - active or empty"
    }
}

# Analyze Nuxt Projects subfolders individually
Write-Log "" -Color Cyan
Write-Log "=== Analyzing Nuxt Projects subfolders ===" -Color Cyan

$nuxtSubs = Get-NuxtSubfolders
if ($nuxtSubs.Count -gt 0) {
    foreach ($sub in $nuxtSubs) {
        $subPath = $sub.FullName
        $subName = $sub.Name
        $subLastWrite = $sub.LastWriteTime
        $subSizeGB = Get-FolderSize $subPath
        $isStale = $subLastWrite -lt $cutoff

        Write-Log "CHECK: $subName ($subSizeGB GB) - LastWrite: $subLastWrite - Stale: $isStale" -Color (if ($isStale) { 'Yellow' } else { 'Green' })

        if ($isStale -and $subSizeGB -gt 0) {
            $nuxtStale += @{ Path = $subPath; Name = $subName; SizeGB = $subSizeGB; LastWrite = $subLastWrite }
        }
    }

    if ($nuxtStale.Count -gt 0) {
        Write-Log "" -Color Cyan
        Write-Log "=== Stale Nuxt Projects found ($($nuxtStale.Count)) ===" -Color Yellow
        foreach ($stale in $nuxtStale) {
            Write-Log "  $($stale.Name) - $($stale.SizeGB) GB - LastWrite: $($stale.LastWrite)" -Color Yellow
        }

        if (-not $DryRun) {
            if ($Force -or (Read-Host "Delete $($nuxtStale.Count) stale Nuxt Projects? (y/N)").ToLower() -eq 'y') {
                foreach ($stale in $nuxtStale) {
                    Write-Log "DELETING: $($stale.Name) ($($stale.SizeGB) GB)..." -Color Red
                    try {
                        Remove-Item $stale.Path -Recurse -Force -ErrorAction Stop
                        $totalFreed += $stale.SizeGB
                        $deleted += "$($stale.Path) ($($stale.SizeGB) GB) - Nuxt project"
                        Write-Log "  Deleted successfully" -Color Green
                    } catch {
                        Write-Log "  ERROR: $_" -Color Red
                        $skipped += "$($stale.Path) (error: $_)"
                    }
                }
            } else {
                Write-Log "Nuxt Projects deletion skipped by user" -Color Gray
                foreach ($stale in $nuxtStale) {
                    $skipped += "$($stale.Path) ($($stale.SizeGB) GB) - skipped by user"
                }
            }
        } else {
            foreach ($stale in $nuxtStale) {
                Write-Log "DRY-RUN: Would delete $($stale.Name) ($($stale.SizeGB) GB)" -Color Yellow
            }
        }
    } else {
        Write-Log "No stale Nuxt Projects found" -Color Green
    }
} else {
    Write-Log "No Nuxt Projects found or not accessible" -Color Gray
}

# Summary
$totalFreedGB = [math]::Round($totalFreed, 2)
Write-Log "" -Color Cyan
Write-Log "=== CLEANUP SUMMARY ===" -Color Cyan
Write-Log "Total freed: $totalFreedGB GB" -Color Green
Write-Log "Deleted ($($deleted.Count)): " -Color Green
$deleted | ForEach-Object { Write-Log "  $_" -Color Green }
Write-Log "Skipped ($($skipped.Count)): " -Color Gray
$skipped | ForEach-Object { Write-Log "  $_" -Color Gray }

# Final drive status
$drive = Get-PSDrive D
$freeGB = [math]::Round($drive.Free / 1GB, 2)
$usedGB = [math]::Round($drive.Used / 1GB, 2)
Write-Log "" -Color Cyan
Write-Log "D: Final - Free: $freeGB GB, Used: $usedGB GB" -Color Cyan
Write-Log "=== D: Drive Cleanup Completed ===" -Color Cyan

# Exit code for scheduler monitoring
if ($totalFreed -gt 0 -or $deleted.Count -gt 0) { exit 0 } else { exit 1 }