<#
.SYNOPSIS
    Console-flash catcher - samples for visible console processes and logs
    the parent chain, to identify sources the task audit can't see.
.DESCRIPTION
    Scheduled-task actions are covered by popup_task_audit.ps1. Flashes that
    persist after that audit is clean come from non-task processes: an app
    spawning cmd/powershell/wsl visibly (e.g. com.docker.backend's
    `docker stats` poll, sync clients, updaters).

    Samples every -IntervalSec seconds for -DurationMin minutes. For every
    console-class process (cmd, powershell, pwsh, conhost, wsl, wscript,
    cscript, bash, schtasks, netsh, ipconfig, tasklist) that has a MAIN
    WINDOW HANDLE in the interactive session, logs:
      timestamp, pid, name, window title, parent pid+name, command line.

    Output: logs\popup-flashes.log (JSON lines). Run on demand when flashes
    are reported, or via the on-demand task \DevOptimizer\Popup-Flash-Watch.
#>
#requires -Version 5.1
# CATEGORY: diagnostics
param(
    [int]$DurationMin = 60,
    [int]$IntervalSec = 2
)

$ErrorActionPreference = 'Continue'
$logFile = 'D:\DevOptimizer\logs\popup-flashes.log'
$names = 'cmd','powershell','pwsh','conhost','wsl','wscript','cscript','bash','schtasks','netsh','ipconfig','tasklist','wslhost','vmmem','gh','git','git-remote-https','mintty','ssh','bash'

$deadline = (Get-Date).AddMinutes($DurationMin)
$seen = @{}   # pid -> first-seen stamp, so each flash logs once

while ((Get-Date) -lt $deadline) {
    foreach ($p in Get-Process -ErrorAction SilentlyContinue |
               Where-Object { $names -contains $_.ProcessName -and $_.MainWindowHandle -ne 0 -and $_.SessionId -eq (Get-Process -Id $PID).SessionId }) {
        if (-not $seen.ContainsKey($p.Id)) {
            $seen[$p.Id] = Get-Date
            $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue
            $pp = $null
            if ($parent -and $parent.ParentProcessId) {
                $pp = Get-Process -Id $parent.ParentProcessId -ErrorAction SilentlyContinue
            }
            $rec = [ordered]@{
                ts       = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                pid      = $p.Id
                name     = $p.ProcessName
                title    = $p.MainWindowTitle
                parent   = if ($pp) { "$($pp.ProcessName)($($pp.Id))" } else { 'unknown' }
                cmdline  = if ($parent) { $parent.CommandLine } else { '' }
            }
            ($rec | ConvertTo-Json -Compress) | Add-Content -Path $logFile
        }
    }
    Start-Sleep -Seconds $IntervalSec
}
Write-Host "popup-flash-watch done: $($seen.Count) visible-console process(es) logged to $logFile"

