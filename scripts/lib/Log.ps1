<#
.SYNOPSIS
    Shared structured logging module for DevOptimizer
.DESCRIPTION
    Provides consistent logging with levels (DEBUG/INFO/WARN/ERROR), rotation at 1MB,
    and structured output for parsing.
.NOTES
    Usage: Import-Module D:\DevOptimizer\scripts\lib\Log.ps1
    Then use: Log-Debug, Log-Info, Log-Warn, Log-Error
#>
#requires -Version 5.1

$ErrorActionPreference = 'Stop'

$script:LogDir = 'D:\DevOptimizer\logs'
$script:MaxLogSizeMB = 1
$script:DefaultLogName = 'devoptimizer.log'

function Ensure-LogDir {
    if (-not (Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null
    }
}

function Get-LogPath {
    param([string]$LogName = $script:DefaultLogName)
    Ensure-LogDir
    return Join-Path $script:LogDir $LogName
}

function Rotate-LogIfNeeded {
    param([string]$LogPath)
    try {
        $file = Get-Item $LogPath -ErrorAction SilentlyContinue
        if ($file -and $file.Length -gt ($script:MaxLogSizeMB * 1MB)) {
            $archive = "$LogPath.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
            Move-Item $LogPath $archive -Force
            # Keep only last 5 archives
            Get-ChildItem -Path $script:LogDir -Filter "$(Split-Path $LogPath -Leaf).*.bak" |
                Sort-Object LastWriteTime -Descending |
                Select-Object -Skip 5 | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

function Write-LogEntry {
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]$Level,
        [string]$Message,
        [string]$LogName = $script:DefaultLogName,
        [switch]$NoConsole
    )
    $logPath = Get-LogPath $LogName
    Rotate-LogIfNeeded $logPath

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $entry = "{0} [{1}] {2}" -f $timestamp, $Level, $Message

    Add-Content -Path $logPath -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue

    if (-not $NoConsole) {
        $color = switch ($Level) {
            'DEBUG' { 'Gray' }
            'INFO'  { 'White' }
            'WARN'  { 'Yellow' }
            'ERROR' { 'Red' }
        }
        Write-Host $entry -ForegroundColor $color
    }
}

function Log-Debug { param([string]$Message, [string]$LogName, [switch]$NoConsole) Write-LogEntry 'DEBUG' $Message $LogName $NoConsole }
function Log-Info  { param([string]$Message, [string]$LogName, [switch]$NoConsole) Write-LogEntry 'INFO'  $Message $LogName $NoConsole }
function Log-Warn  { param([string]$Message, [string]$LogName, [switch]$NoConsole) Write-LogEntry 'WARN'  $Message $LogName $NoConsole }
function Log-Error { param([string]$Message, [string]$LogName, [switch]$NoConsole) Write-LogEntry 'ERROR' $Message $LogName $NoConsole }

# Structured logging for machine parsing
function Log-Structured {
    param(
        [string]$Event,
        [hashtable]$Data,
        [string]$LogName = 'devoptimizer-structured.log'
    )
    $logPath = Get-LogPath $LogName
    Rotate-LogIfNeeded $logPath
    $entry = @{
        timestamp = (Get-Date -Format 'o')
        event     = $Event
        data      = $Data
    } | ConvertTo-Json -Compress -Depth 5
    Add-Content -Path $logPath -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
}

# Get recent log entries (for health dashboard)
function Get-RecentLogs {
    param(
        [string]$LogName = $script:DefaultLogName,
        [int]$Lines = 100
    )
    $logPath = Get-LogPath $LogName
    if (Test-Path $logPath) {
        Get-Content $logPath -Tail $Lines -ErrorAction SilentlyContinue
    }
}

