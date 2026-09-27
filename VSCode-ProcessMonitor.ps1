<#
.SYNOPSIS
    VS Code Insiders Process Monitor and Resource Manager
.DESCRIPTION
    Monitors VS Code Insiders processes and automatically manages them based on:
    - Total memory usage threshold
    - Individual process memory threshold
    - Total process count limit
.AUTHOR
    Created for Themistoklis Baltzakis
.DATE
    February 7, 2026
#>

param(
    [int]$TotalMemoryThresholdMB = 4096,      # Kill all if total exceeds 4GB
    [int]$SingleProcessThresholdMB = 1024,    # Kill individual process if exceeds 1GB
    [int]$MaxProcessCount = 15,                # Kill all if more than 15 processes
    [int]$CheckIntervalSeconds = 30,           # Check every 30 seconds
    [switch]$DryRun,                           # Preview mode - don't actually kill
    [switch]$LogToFile                         # Log actions to file
)

# Configuration
$ProcessName = "Code - Insiders"
$LogPath = "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log"

# Ensure log directory exists
if ($LogToFile) {
    $logDir = Split-Path $LogPath -Parent
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Color coding for console
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage -ForegroundColor White }
    }
    
    # Write to file if enabled
    if ($LogToFile) {
        Add-Content -Path $LogPath -Value $logMessage
    }
}

function Get-ProcessStats {
    $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    
    if (!$processes) {
        return $null
    }
    
    $stats = @{
        Count = ($processes | Measure-Object).Count
        TotalMemoryMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
        Processes = $processes | Select-Object Id, 
            @{Name="MemoryMB";Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}},
            @{Name="CPUTime";Expression={$_.CPU}},
            Path
    }
    
    return $stats
}

function Kill-ProcessesSafely {
    param(
        [Parameter(Mandatory=$true)]
        [array]$ProcessesToKill,
        [string]$Reason
    )
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would kill $($ProcessesToKill.Count) processes. Reason: $Reason" "WARNING"
        foreach ($proc in $ProcessesToKill) {
            Write-Log "  - Would kill PID $($proc.Id) using $($proc.MemoryMB) MB" "WARNING"
        }
        return
    }
    
    Write-Log "Killing $($ProcessesToKill.Count) processes. Reason: $Reason" "WARNING"
    
    foreach ($proc in $ProcessesToKill) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-Log "Killed process PID $($proc.Id) (Memory: $($proc.MemoryMB) MB)" "SUCCESS"
        }
        catch {
            Write-Log "Failed to kill PID $($proc.Id): $($_.Exception.Message)" "ERROR"
        }
    }
}

# Main monitoring loop
Write-Log "Starting VS Code Insiders Process Monitor" "SUCCESS"
Write-Log "Configuration:"
Write-Log "  - Total Memory Threshold: $TotalMemoryThresholdMB MB"
Write-Log "  - Single Process Threshold: $SingleProcessThresholdMB MB"
Write-Log "  - Max Process Count: $MaxProcessCount"
Write-Log "  - Check Interval: $CheckIntervalSeconds seconds"
Write-Log "  - Dry Run: $DryRun"
Write-Log "  - Log to File: $LogToFile"

if ($DryRun) {
    Write-Log "RUNNING IN DRY RUN MODE - No processes will be killed" "WARNING"
}

Write-Log "`nPress Ctrl+C to stop monitoring`n"

while ($true) {
    $stats = Get-ProcessStats
    
    if ($null -eq $stats) {
        Write-Log "No $ProcessName processes running" "INFO"
        Start-Sleep -Seconds $CheckIntervalSeconds
        continue
    }
    
    # Display current status
    Write-Log "Status: $($stats.Count) processes, Total Memory: $($stats.TotalMemoryMB) MB"
    
    # Check 1: Too many processes
    if ($stats.Count -gt $MaxProcessCount) {
        Kill-ProcessesSafely -ProcessesToKill $stats.Processes -Reason "Process count ($($stats.Count)) exceeds limit ($MaxProcessCount)"
        Start-Sleep -Seconds 5
        continue
    }
    
    # Check 2: Total memory threshold
    if ($stats.TotalMemoryMB -gt $TotalMemoryThresholdMB) {
        Kill-ProcessesSafely -ProcessesToKill $stats.Processes -Reason "Total memory ($($stats.TotalMemoryMB) MB) exceeds threshold ($TotalMemoryThresholdMB MB)"
        Start-Sleep -Seconds 5
        continue
    }
    
    # Check 3: Individual process threshold
    $bloatedProcesses = $stats.Processes | Where-Object { $_.MemoryMB -gt $SingleProcessThresholdMB }
    if ($bloatedProcesses) {
        foreach ($proc in $bloatedProcesses) {
            Write-Log "Found bloated process: PID $($proc.Id) using $($proc.MemoryMB) MB" "WARNING"
        }
        Kill-ProcessesSafely -ProcessesToKill $bloatedProcesses -Reason "Individual processes exceed $SingleProcessThresholdMB MB threshold"
        Start-Sleep -Seconds 5
        continue
    }
    
    # All checks passed
    Write-Log "All checks passed - system healthy" "SUCCESS"
    
    Start-Sleep -Seconds $CheckIntervalSeconds
}
