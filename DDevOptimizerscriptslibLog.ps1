<#
.SYNOPSIS
    Shared structured logging module for DevOptimizer scripts
.DESCRIPTION
    Provides Log-Debug, Log-Info, Log-Warn, Log-Error, Log-Structured, Get-RecentLogs
    with rotation at 1MB, keep 5 archives, level-based console colors.
#>
#requires -Version 5.1

$ErrorActionPreference = 'SilentlyContinue'

$LogDir = "D:\DevOptimizer\logs"
$LogFile = "$LogDir\devoptimizer.log"
$MaxSizeMB = 1
$MaxArchives = 5

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Rotate-Log {
    if (Test-Path $LogFile) {
        $sizeMB = (Get-Item $LogFile).Length / 1MB
        if ($sizeMB -ge $MaxSizeMB) {
            for ($i = $MaxArchives - 1; $i -ge 1; $i--) {
                $src = "$LogFile.$i"
                $dst = "$LogFile.$($i + 1)"
                if (Test-Path $src) {
                    if ($i -eq $MaxArchives - 1) { Remove-Item $src -Force -ErrorAction SilentlyContinue }
                    else { Move-Item $src $dst -Force -ErrorAction SilentlyContinue }
                }
            }
            Move-Item $LogFile "$LogFile.1" -Force -ErrorAction SilentlyContinue
        }
    }
}

function Write-LogEntry {
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR')][string]$Level,
        [string]$Message,
        [hashtable]$Structured = $null
    )
    Rotate-Log
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $entry = "$timestamp [$Level] $Message"
    if ($Structured) {
        $entry += " | " + ($Structured | ConvertTo-Json -Compress -Depth 3)
    }
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
    
    # Console output with colors
    $color = switch ($Level) {
        'DEBUG' { 'DarkGray' }
        'INFO'  { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'White' }
    }
    if ($Level -ne 'DEBUG' -or $VerbosePreference -ne 'SilentlyContinue') {
        Write-Host "  [$Level] $Message" -ForegroundColor $color
    }
}

function Log-Debug { param([string]$Message, [hashtable]$Structured) Write-LogEntry 'DEBUG' $Message $Structured }
function Log-Info  { param([string]$Message, [hashtable]$Structured) Write-LogEntry 'INFO'  $Message $Structured }
function Log-Warn  { param([string]$Message, [hashtable]$Structured) Write-LogEntry 'WARN'  $Message $Structured }
function Log-Error { param([string]$Message, [hashtable]$Structured) Write-LogEntry 'ERROR' $Message $Structured }

function Log-Structured {
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR')][string]$Level = 'INFO',
        [string]$Message,
        [hashtable]$Data
    )
    Write-LogEntry $Level $Message $Data
}

function Get-RecentLogs {
    param(
        [int]$Lines = 100,
        [ValidateSet('DEBUG','INFO','WARN','ERROR')][string]$Level = $null
    )
    if (-not (Test-Path $LogFile)) { return @() }
    $logs = Get-Content $LogFile -Tail $Lines -ErrorAction SilentlyContinue
    if ($Level) {
        $logs = $logs | Where-Object { $_ -match " \[$Level\] " }
    }
    return $logs
}

function Get-LogStats {
    $files = Get-ChildItem "$LogDir\devoptimizer.log*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    $totalSize = ($files | Measure-Object Length -Sum).Sum
    return @{
        CurrentLog = if (Test-Path $LogFile) { (Get-Item $LogFile).Length } else { 0 }
        ArchiveCount = $files.Count - 1
        TotalSizeMB = [math]::Round($totalSize / 1MB, 2)
        OldestArchive = if ($files.Count -gt 1) { $files[-1].LastWriteTime } else { $null }
    }
}
