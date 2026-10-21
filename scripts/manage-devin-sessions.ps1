<#
.SYNOPSIS
    Manages Devin sessions - closes idle sessions >4h, limits concurrent to 2
.DESCRIPTION
    This script manages both Devin CLI sessions (via SQLite database) and 
    Devin Desktop processes (via process monitoring). It enforces:
    - Maximum 2 concurrent active sessions/processes
    - Auto-close sessions idle for more than 4 hours
    - Does not close recently started Desktop processes (active work)
    - Only manages main Devin Desktop window processes (not helpers)
.NOTES
    Author: DevOptimizer
    Date: 2026-10-21
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$MaxConcurrent = 2,
    
    [Parameter()]
    [int]$IdleTimeoutHours = 4,
    
    [Parameter()]
    [string]$LogPath = "D:\DevOptimizer\logs\devin-session-manager.log"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
    Write-Verbose $logEntry
}

function Get-DevinCLISessions {
    $dbPath = "C:\Users\tbaltzakis\AppData\Roaming\Devin\cli\sessions.db"
    $cliPath = "C:\Users\tbaltzakis\AppData\Local\Programs\Devin\resources\app\extensions\windsurf\devin\bin\devin.exe"
    
    if (-not (Test-Path $dbPath)) {
        Write-Log "CLI sessions database not found at $dbPath" "WARN"
        return @()
    }
    
    try {
        $pythonScript = @"
import sqlite3
import datetime
import json

conn = sqlite3.connect(r'$dbPath')
c = conn.cursor()
c.execute('SELECT id, created_at, last_activity_at, title, hidden, working_directory FROM sessions WHERE hidden=0 ORDER BY last_activity_at DESC')
rows = c.fetchall()
sessions = []
for row in rows:
    sessions.append({
        'id': row[0],
        'created_at': row[1],
        'last_activity_at': row[2],
        'title': row[3],
        'hidden': row[4],
        'working_directory': row[5]
    })
print(json.dumps(sessions))
conn.close()
"@
        $result = python -c $pythonScript
        $sessions = $result | ConvertFrom-Json
        return $sessions
    }
    catch {
        $err = $_.Exception.Message
        Write-Log "Error reading CLI sessions: $err" "ERROR"
        return @()
    }
}

function Get-DevinDesktopProcesses {
    # Get Devin processes that have a main window (likely main UI processes)
    $processes = Get-Process -Name "Devin" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle }
    $result = @()
    
    foreach ($proc in $processes) {
        $result += [pscustomobject]@{
            Id = $proc.Id
            ProcessName = $proc.ProcessName
            StartTime = $proc.StartTime
            CPU = $proc.CPU
            WorkingSet = $proc.WorkingSet
            MainWindowTitle = $proc.MainWindowTitle
        }
    }
    
    # If no windowed processes found, fall back to all Devin processes (but log warning)
    if ($result.Count -eq 0) {
        Write-Log "No windowed Devin processes found, checking all Devin processes" "WARN"
        $allProcesses = Get-Process -Name "Devin" -ErrorAction SilentlyContinue
        foreach ($proc in $allProcesses) {
            $result += [pscustomobject]@{
                Id = $proc.Id
                ProcessName = $proc.ProcessName
                StartTime = $proc.StartTime
                CPU = $proc.CPU
                WorkingSet = $proc.WorkingSet
                MainWindowTitle = $proc.MainWindowTitle
            }
        }
    }
    
    return $result
}

function Close-DevinCLISession {
    param([string]$SessionId)
    
    $cliPath = "C:\Users\tbaltzakis\AppData\Local\Programs\Devin\resources\app\extensions\windsurf\devin\bin\devin.exe"
    
    try {
        $result = & $cliPath rm --force $SessionId 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log ("Closed CLI session: {0}" -f $SessionId)
            return $true
        }
        else {
            Write-Log ("Failed to close CLI session {0}: {1}" -f $SessionId, $result) "ERROR"
            return $false
        }
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-Log ("Exception closing CLI session {0}: {1}" -f $SessionId, $errMsg) "ERROR"
        return $false
    }
}

function Close-DevinDesktopProcess {
    param([int]$ProcessId)
    
    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction Stop
        Write-Log ("Closed Desktop process: {0}" -f $ProcessId)
        return $true
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-Log ("Exception closing Desktop process {0}: {1}" -f $ProcessId, $errMsg) "ERROR"
        return $false
    }
}

# Main execution
Write-Log "=== Devin Session Manager Started ==="

# Get CLI sessions
$cliSessions = Get-DevinCLISessions
Write-Log ("Found {0} active CLI sessions" -f $cliSessions.Count)

# Get Desktop processes
$desktopProcesses = Get-DevinDesktopProcesses
Write-Log ("Found {0} Desktop processes (main windows)" -f $desktopProcesses.Count)

$now = Get-Date
$cutoffTime = $now.AddHours(-$IdleTimeoutHours)

# Track what we close
$closedCLISessions = @()
$closedDesktopProcesses = @()

# Check CLI sessions for idle timeout
foreach ($session in $cliSessions) {
    if ($session.last_activity_at) {
        $epoch = [datetime]::ParseExact("1970-01-01", "yyyy-MM-dd", $null)
        $lastActivity = $epoch.AddSeconds($session.last_activity_at)
        
        $idleDuration = $now - $lastActivity
        
        if ($idleDuration.TotalHours -gt $IdleTimeoutHours) {
            Write-Log ("CLI session {0} idle for {1}h - closing" -f $session.id, [math]::Round($idleDuration.TotalHours, 1))
            if (Close-DevinCLISession $session.id) {
                $closedCLISessions += $session.id
            }
        }
        else {
            Write-Log ("CLI session {0} active (idle {1}h)" -f $session.id, [math]::Round($idleDuration.TotalHours, 1))
        }
    }
}

# Check Desktop processes for idle timeout
foreach ($proc in $desktopProcesses) {
    $idleDuration = $now - $proc.StartTime
    
    if ($idleDuration.TotalHours -gt $IdleTimeoutHours) {
        Write-Log ("Desktop process {0} idle for {1}h - closing" -f $proc.Id, [math]::Round($idleDuration.TotalHours, 1))
        if (Close-DevinDesktopProcess $proc.Id) {
            $closedDesktopProcesses += $proc.Id
        }
    }
    else {
        Write-Log ("Desktop process {0} active (running {1}h)" -f $proc.Id, [math]::Round($idleDuration.TotalHours, 1))
    }
}

# Re-query active sessions after cleanup
$remainingCLISessions = Get-DevinCLISessions
$remainingDesktopProcesses = Get-DevinDesktopProcesses

$totalActive = $remainingCLISessions.Count + $remainingDesktopProcesses.Count

# Enforce max concurrent limit - only close idle ones, not active work
if ($totalActive -gt $MaxConcurrent) {
    $excess = $totalActive - $MaxConcurrent
    Write-Log ("Exceeded max concurrent ({0}), need to close {1} idle session(s)" -f $MaxConcurrent, $excess) "WARN"
    
    # Close oldest idle CLI sessions first (that weren't already closed)
    $idleCLISessions = $remainingCLISessions | Where-Object { 
        $closedCLISessions -notcontains $_.id -and 
        ($now - [datetime]::ParseExact("1970-01-01", "yyyy-MM-dd", $null).AddSeconds($_.last_activity_at)).TotalHours -gt $IdleTimeoutHours
    } | Sort-Object { 
        $epoch = [datetime]::ParseExact("1970-01-01", "yyyy-MM-dd", $null)
        $epoch.AddSeconds($_.last_activity_at) 
    }
    foreach ($session in $idleCLISessions) {
        if ($excess -le 0) { break }
        Write-Log ("Closing excess idle CLI session: {0}" -f $session.id)
        if (Close-DevinCLISession $session.id) {
            $excess--
        }
    }
    
    # Close oldest idle Desktop processes if still over limit
    $idleDesktopProcesses = $remainingDesktopProcesses | Where-Object { 
        $closedDesktopProcesses -notcontains $_.Id -and
        ($now - $_.StartTime).TotalHours -gt $IdleTimeoutHours
    } | Sort-Object StartTime
    
    foreach ($proc in $idleDesktopProcesses) {
        if ($excess -le 0) { break }
        Write-Log ("Closing excess idle Desktop process: {0}" -f $proc.Id)
        if (Close-DevinDesktopProcess $proc.Id) {
            $excess--
        }
    }
    
    # If still over limit, we don't close active work - just log warning
    if ($excess -gt 0) {
        Write-Log ("Still {0} over limit after closing idle sessions - keeping active work" -f $excess) "WARN"
    }
}
else {
    Write-Log ("Concurrent count ({0}) within limit ({1})" -f $totalActive, $MaxConcurrent)
}

Write-Log "=== Devin Session Manager Completed ==="