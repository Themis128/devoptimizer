<#
.SYNOPSIS
    Lower Devin Desktop process priority to BelowNormal

.DESCRIPTION
    Finds Devin processes and sets their priority class to BelowNormal
    to reduce CPU contention with other applications. This helps Devin
    be a "good citizen" on the system while still making progress.

.EXAMPLE
    .\lower-devin-priority.ps1
    # One-time priority adjustment
    
    .\lower-devin-priority.ps1 -Loop -Interval 30
    # Run continuously, checking every 30 seconds

.NOTES
    Requires: Run as Administrator for processes owned by other users
    Can be run as scheduled task or manually.
#>

param(
    [switch]$Loop,
    [int]$Interval = 30,
    [switch]$Verbose
)

$ErrorActionPreference = 'Continue'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    if ($Verbose -or $Level -in @('WARN', 'ERROR')) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "$timestamp [$Level] $Message"
    }
}

function Set-ProcessPriority {
    param(
        [System.Diagnostics.Process]$Process,
        [System.Diagnostics.ProcessPriorityClass]$Priority = 'BelowNormal'
    )
    
    try {
        $oldPriority = $Process.PriorityClass
        if ($oldPriority -ne $Priority) {
            $Process.PriorityClass = $Priority
            Write-Log "Set PID $($Process.Id) priority: $oldPriority -> $Priority"
            return $true
        } else {
            if ($Verbose) { Write-Log "PID $($Process.Id) already at $Priority" }
        }
    } catch {
        Write-Log "Failed to set priority for PID $($Process.Id): $_" 'WARN'
    }
    return $false
}

function Find-DevinProcesses {
    $processes = @()
    
    # Devin Desktop (Electron app)
    $processes += Get-Process -Name 'Devin' -ErrorAction SilentlyContinue
    $processes += Get-Process -Name 'devin' -ErrorAction SilentlyContinue
    
    # Devin CLI if running
    $cliProcs = Get-Process -Name 'devin' -ErrorAction SilentlyContinue | Where-Object { 
        $_.Path -and ($_.Path -like '*devin*' -or $_.Path -like '*Devin*') 
    }
    $processes += $cliProcs
    
    # Electron helper processes (renderer, GPU, utility)
    $electronProcs = Get-Process -Name 'Devin' -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -eq 'Devin' -and $_.MainModule -and $_.MainModule.FileName -like '*Devin*'
    }
    # Also catch child processes by parent
    $allDevin = Get-WmiObject Win32_Process -Filter "Name LIKE '%Devin%'" -ErrorAction SilentlyContinue
    if ($allDevin) {
        foreach ($wmi in $allDevin) {
            try {
                $proc = Get-Process -Id $wmi.ProcessId -ErrorAction SilentlyContinue
                if ($proc -and $processes.Id -notcontains $proc.Id) {
                    $processes += $proc
                }
            } catch { }
        }
    }
    
    return $processes | Sort-Object Id -Unique
}

Write-Log "=== Devin Priority Adjustment Started ==="

try {
    if ($Loop) {
        Write-Log "Running in loop mode (interval: ${Interval}s). Press Ctrl+C to stop."
        while ($true) {
            $devinProcs = Find-DevinProcesses
            if ($devinProcs) {
                $changed = 0
                foreach ($proc in $devinProcs) {
                    if (Set-ProcessPriority -Process $proc -Priority 'BelowNormal') {
                        $changed++
                    }
                }
                if ($changed -gt 0) {
                    Write-Log "Adjusted priority for $changed process(es)"
                }
            } else {
                if ($Verbose) { Write-Log "No Devin processes found" }
            }
            Start-Sleep -Seconds $Interval
        }
    } else {
        $devinProcs = Find-DevinProcesses
        if ($devinProcs) {
            $changed = 0
            foreach ($proc in $devinProcs) {
                if (Set-ProcessPriority -Process $proc -Priority 'BelowNormal') {
                    $changed++
                }
            }
            Write-Log "Adjusted priority for $changed of $($devinProcs.Count) process(es)"
        } else {
            Write-Log "No Devin processes found"
        }
    }
    
    Write-Log "=== Devin Priority Adjustment Completed ==="
    exit 0
}
catch {
    Write-Log "=== Devin Priority Adjustment FAILED: $_ ===" 'ERROR'
    exit 1
}