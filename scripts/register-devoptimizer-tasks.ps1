#requires -Version 5.1
# CATEGORY: cleanup
# Registers the DevOptimizer cleanup scheduled tasks and enables Storage Sense.
# Self-elevates via UAC RunAs (the SYSTEM task requires admin).
# Result log: D:\DevOptimizer\logs\register-devoptimizer-tasks.log

$logPath = 'D:\DevOptimizer\logs\register-devoptimizer-tasks.log'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
    )
    exit
}

try { Start-Transcript -Path $logPath -Force | Out-Null } catch { }
Write-Host "=== DevOptimizer task registration ===" -ForegroundColor Magenta
Write-Host ("Elevated as: {0}" -f $env:USERNAME)

$ps = (Get-Command powershell.exe).Source

# ─── Task 1: Extended-Cleanup (user-level, weekly Mon 02:30) ────
$extAction = New-ScheduledTaskAction -Execute $ps -Argument `
    '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\extended-cleanup.ps1"'
$extTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At '02:30'
$extSettings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName 'Extended-Cleanup' -TaskPath '\DevOptimizer\' `
    -Action $extAction -Trigger $extTrigger -Settings $extSettings -Force |
    Out-Null
Write-Host "[OK] \DevOptimizer\Extended-Cleanup - weekly Mon 02:30 (user-level, age-gated caches)" -ForegroundColor Green

# ─── Task 2: DevOptimizer-Elevated-Cleanup (SYSTEM, every 15 days 03:00) ────
$elevAction = New-ScheduledTaskAction -Execute $ps -Argument `
    '-NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\elevated-complete-cleanup.ps1"'
$elevTrigger = New-ScheduledTaskTrigger -Daily -DaysInterval 15 -At '03:00'
$elevSettings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4)
Register-ScheduledTask -TaskName 'DevOptimizer-Elevated-Cleanup' -TaskPath '\DevOptimizer\' `
    -Action $elevAction -Trigger $elevTrigger -User 'SYSTEM' -RunLevel Highest `
    -Settings $elevSettings -Force | Out-Null
Write-Host "[OK] \DevOptimizer\DevOptimizer-Elevated-Cleanup - every 15 days 03:00 (DISM/WU/DO/restore points/VHDX/WER)" -ForegroundColor Green

# ─── Storage Sense safety net (HKCU, conservative) ──────────────
$sp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
New-Item -Path $sp -Force | Out-Null
Set-ItemProperty -Path $sp -Name '01'   -Type DWord -Value 1    # Storage Sense on
Set-ItemProperty -Path $sp -Name '04'   -Type DWord -Value 1    # clean temp files
Set-ItemProperty -Path $sp -Name '08'   -Type DWord -Value 1    # auto-empty recycle bin
Set-ItemProperty -Path $sp -Name '256'  -Type DWord -Value 14   # recycle bin items after 14 days
Set-ItemProperty -Path $sp -Name '32'   -Type DWord -Value 0    # NEVER auto-clean Downloads
Set-ItemProperty -Path $sp -Name '2048' -Type DWord -Value 7    # cadence: weekly
Write-Host "[OK] Storage Sense enabled (temp files; recycle bin >14d; Downloads untouched)" -ForegroundColor Green

# ─── Verify ─────────────────────────────────────────────────────
Write-Host "`nRegistered tasks:" -ForegroundColor Cyan
Get-ScheduledTask -TaskPath '\DevOptimizer\' | Select-Object TaskName, State | Format-Table -AutoSize
Write-Host "=== Registration complete ===" -ForegroundColor Magenta
try { Stop-Transcript | Out-Null } catch { }
