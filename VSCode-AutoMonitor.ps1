<#
.SYNOPSIS
    Auto-start VS Code Insiders Process Monitor
.DESCRIPTION
    Automatically monitors VS Code Insiders processes and stops when VS Code closes.
    Designed to run automatically when VS Code Insiders starts.
.AUTHOR
    Created for Themistoklis Baltzakis
.DATE
    February 7, 2026
#>

param(
    [int]$TotalMemoryThresholdMB = 8192,
    [int]$SingleProcessThresholdMB = 2048,
    [int]$MaxProcessCount = 35,
    [int]$CheckIntervalSeconds = 30,
    [switch]$DryRun,
    [switch]$ShowWindow = $false
)

# Configuration
$ProcessName = "Code - Insiders"
$LogPath = "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log"

# Ensure log directory exists
$logDir = Split-Path $LogPath -Parent
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Hide window by default unless ShowWindow is specified
if (!$ShowWindow) {
    # Minimize the PowerShell window
    $code = @"
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
"@
    Add-Type -MemberDefinition $code -Name "Win32ShowWindow" -Namespace Win32Functions -PassThru | Out-Null
    $hwnd = (Get-Process -Id $PID).MainWindowHandle
    [Win32Functions.Win32ShowWindow]::ShowWindow($hwnd, 6) | Out-Null  # 6 = Minimize
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Always write to file
    Add-Content -Path $LogPath -Value $logMessage -ErrorAction SilentlyContinue
    
    # Only write to console if window is shown
    if ($ShowWindow) {
        switch ($Level) {
            "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
            "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
            default   { Write-Host $logMessage -ForegroundColor White }
        }
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

# Check if another instance is already running
$existingMonitor = Get-Process -Name "powershell","pwsh" -ErrorAction SilentlyContinue | 
    Where-Object { $_.CommandLine -like "*VSCode-AutoMonitor.ps1*" -and $_.Id -ne $PID }

if ($existingMonitor) {
    Write-Log "Another monitor instance is already running (PID: $($existingMonitor.Id)). Exiting." "INFO"
    exit 0
}

Write-Log "Starting VS Code Insiders Auto-Monitor" "SUCCESS"
Write-Log "Configuration: TotalMem=$TotalMemoryThresholdMB MB, SingleProc=$SingleProcessThresholdMB MB, MaxProc=$MaxProcessCount" "INFO"
Write-Log "Monitor will auto-stop when VS Code Insiders closes" "INFO"

if ($DryRun) {
    Write-Log "RUNNING IN DRY RUN MODE - No processes will be killed" "WARNING"
}

$noProcessCount = 0
$maxNoProcessIterations = 10  # Stop after 5 minutes of no VS Code processes

while ($true) {
    $stats = Get-ProcessStats
    
    if ($null -eq $stats) {
        $noProcessCount++
        Write-Log "No VS Code Insiders processes running ($noProcessCount/$maxNoProcessIterations)" "INFO"
        
        # Auto-stop if VS Code has been closed for a while
        if ($noProcessCount -ge $maxNoProcessIterations) {
            Write-Log "VS Code Insiders has been closed. Auto-stopping monitor." "SUCCESS"
            break
        }
        
        Start-Sleep -Seconds $CheckIntervalSeconds
        continue
    }
    
    # Reset counter when processes are found
    $noProcessCount = 0
    
    # Display current status
    Write-Log "Status: $($stats.Count) processes, Total Memory: $($stats.TotalMemoryMB) MB" "INFO"
    
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

Write-Log "Monitor stopped successfully" "SUCCESS"

