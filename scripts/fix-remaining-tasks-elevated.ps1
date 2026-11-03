<#
.SYNOPSIS
    Fixes remaining DevOptimizer scheduled tasks to add -WindowStyle Hidden
.DESCRIPTION
    Run this script in an ELEVATED PowerShell window (Run as Administrator).
    Fixes 3 tasks that require elevation to modify:
    - Devin-Weekly-Restart
    - WSL-Memory-Watchdog  
    - Devin-Daily-Maintenance
#>

$tasksToFix = @(
    @{ 
        Name = 'Devin-Weekly-Restart'
        Args = '--headless C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\restart-devin-weekly.ps1"'
    },
    @{ 
        Name = 'WSL-Memory-Watchdog'
        Args = '--headless C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\check-wsl-memory-pressure.ps1"'
    },
    @{ 
        Name = 'Devin-Daily-Maintenance'
        Args = '--headless C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\devin\Invoke-DevinDailyMaintenance.ps1"'
    }
)

Write-Host "Fixing scheduled tasks (requires elevation)..." -ForegroundColor Cyan

foreach ($fix in $tasksToFix) {
    try {
        $task = Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName $fix.Name -ErrorAction Stop
        $action = $task.Actions[0]
        
        if ($action.Arguments -notmatch 'WindowStyle Hidden') {
            $oldArgs = $action.Arguments
            $action.Arguments = $fix.Args
            Set-ScheduledTask -InputObject $task -ErrorAction Stop
            Write-Host "Fixed: $($fix.Name)" -ForegroundColor Green
            Write-Host "   Old: $oldArgs" -ForegroundColor Gray
            Write-Host "   New: $($fix.Args)" -ForegroundColor Gray
        } else {
            Write-Host "Already has WindowStyle Hidden: $($fix.Name)" -ForegroundColor Yellow
        }
    } catch {
        Write-Error "Failed $($fix.Name): $($_.Exception.Message)"
    }
}

Write-Host "`nVerification:" -ForegroundColor Cyan
$tasks = Get-ScheduledTask -TaskPath '\DevOptimizer\'
foreach ($t in $tasks) {
    $args = ""
    foreach ($a in $t.Actions) { $args += $a.Arguments + " " }
    $hasHidden = $args -match 'WindowStyle Hidden'
    $status = if ($hasHidden) { '[OK]' } else { '[MISSING]' }
    Write-Host "$status $($t.TaskName)`t$($args.Trim())"
}
