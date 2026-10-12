<#
.SYNOPSIS
    Restart Devin Desktop application gracefully

.DESCRIPTION
    Finds and stops Devin processes, then restarts the application.
    This scheduled task runs weekly on Sunday at 03:00 to prevent memory leaks and stale states.

.NOTES
    Task: \DevOptimizer\Devin-Weekly-Restart
    Trigger: Weekly, Sunday 03:00
    Run whether user is logged on or not: Yes
    Run with highest privileges: Yes
#>

param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logPath = "$env:USERPROFILE\AppData\Local\DevOptimizer\logs\devin-restart.log"
    $dir = Split-Path $logPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    "$timestamp [$Level] $Message" | Tee-Object -FilePath $logPath -Append
}

Write-Log "=== Devin Weekly Restart Started ==="

try {
    # Find Devin processes
    $devinProcesses = Get-Process -Name 'Devin' -ErrorAction SilentlyContinue
    if (-not $devinProcesses) {
        $devinProcesses = Get-Process -Name 'devin' -ErrorAction SilentlyContinue
    }
    
    if ($devinProcesses) {
        Write-Log "Found $($devinProcesses.Count) Devin process(es)"
        foreach ($proc in $devinProcesses) {
            Write-Log "Stopping Devin PID $($proc.Id) (CPU: $($proc.CPU)s, WS: $([math]::Round($proc.WorkingSet64/1MB)) MB)"
            try {
                $proc.CloseMainWindow()
                $proc.WaitForExit(10000)
                if (-not $proc.HasExited) {
                    Write-Log "Process $($proc.Id) didn't exit gracefully, forcing..." 'WARN'
                    $proc.Kill()
                    $proc.WaitForExit(5000)
                }
                Write-Log "Stopped Devin PID $($proc.Id)"
            } catch {
                Write-Log "Error stopping PID $($proc.Id): $_" 'ERROR'
            }
        }
    } else {
        Write-Log "No Devin processes found"
    }

    # Also stop Devin CLI if running
    $cliProcesses = Get-Process -Name 'devin' -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*devin*' }
    if ($cliProcesses) {
        Write-Log "Found $($cliProcesses.Count) Devin CLI process(es)"
        foreach ($proc in $cliProcesses) {
            Write-Log "Stopping Devin CLI PID $($proc.Id)"
            $proc.Kill()
            $proc.WaitForExit(5000)
        }
    }

    # Wait a moment for cleanup
    Start-Sleep -Seconds 5

    # Start Devin
    $devinPath = "${env:LOCALAPPDATA}\Programs\Devin\Devin.exe"
    if (Test-Path $devinPath) {
        Write-Log "Starting Devin from $devinPath"
        $proc = Start-Process -FilePath $devinPath -PassThru -WindowStyle Normal
        Write-Log "Devin started with PID $($proc.Id)"
    } else {
        # Try alternative locations
        $altPaths = @(
            "${env:PROGRAMFILES}\Devin\Devin.exe",
            "${env:PROGRAMFILES(X86)}\Devin\Devin.exe",
            "${env:LOCALAPPDATA}\Devin\Devin.exe"
        )
        $found = $false
        foreach ($path in $altPaths) {
            if (Test-Path $path) {
                Write-Log "Starting Devin from $path"
                $proc = Start-Process -FilePath $path -PassThru -WindowStyle Normal
                Write-Log "Devin started with PID $($proc.Id)"
                $found = $true
                break
            }
        }
        if (-not $found) {
            Write-Log "Devin executable not found in standard locations" 'ERROR'
            throw "Devin.exe not found"
        }
    }

    Write-Log "=== Devin Weekly Restart Completed Successfully ==="
    exit 0
}
catch {
    Write-Log "=== Devin Weekly Restart FAILED: $_ ===" 'ERROR'
    exit 1
}