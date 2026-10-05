<#
.SYNOPSIS
    Registers vhdxcompaction.
.DESCRIPTION
    Registers vhdxcompaction.
#>

# Register-VhdxCompaction.ps1 - registers the nightly Devin-safe vhdx compaction
# task (\DevOptimizer\WSL-Vhdx-Compact, daily 03:45 as SYSTEM). Runs AFTER the
# 02:15-03:00 maintenance block; the script's own Devin gates protect active
# sessions, and RestartOnFailure gives deferred runs 8 more chances 30 min apart.
# Requires elevation (UAC RunAs, self-elevating). Safe to re-run; -Remove unregisters.
# -TriggerNow additionally starts the task once for the deferred-run verification
# (with Devin open the run must defer with exit 2 and touch nothing).
#requires -Version 5.1
param([switch]$Remove, [switch]$TriggerNow)

$taskName = 'WSL-Vhdx-Compact'
$taskPath = '\DevOptimizer\'
$scriptPath = 'D:\DevOptimizer\scripts\Invoke-VhdxCompaction.ps1'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating (UAC prompt) - SYSTEM task registration requires admin..." -ForegroundColor Yellow
    $elevArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($Remove) { $elevArgs += '-Remove' }
    if ($TriggerNow) { $elevArgs += '-TriggerNow' }
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList $elevArgs
    $sentinel = 'D:\DevOptimizer\logs\register-vhdxcompaction-result.json'
    if (Test-Path $sentinel) { Write-Host (Get-Content $sentinel -Raw) }
    else { Write-Host 'Elevated run did not complete - see logs\register-vhdxcompaction.log' }
    exit
}

try { Start-Transcript -Path 'D:\DevOptimizer\logs\register-vhdxcompaction.log' -Force | Out-Null } catch { }
Write-Host "=== WSL-Vhdx-Compact registration (elevated) ==="

if ($Remove) {
    Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed $taskPath$taskName"
    try { Stop-Transcript | Out-Null } catch { }
    return
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
    -WorkingDirectory 'D:\DevOptimizer'
$trigger = New-ScheduledTaskTrigger -Daily -At '03:45'
$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -RestartCount 8 -RestartInterval (New-TimeSpan -Minutes 30) `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew

# 2026-10-05: SYSTEM-principal registrations GHOST on this Insider build (task
# invisible from standard sessions and does not persist). Interactive + Highest
# for the owning user persists (proven by Admin-Cleanup-Weekly) and still runs
# elevated at 03:45 unattended as long as the user is logged on.
$principal = New-ScheduledTaskPrincipal -UserId 'tbaltzakis' -LogonType Interactive -RunLevel Highest

$ok = $false
try {
    Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null
    $ok = $true
} catch {
    Write-Host "REGISTER FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

$probe = if ($ok) { Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue } else { $null }
$elevatedView = if ($probe) { "State=$($probe.State) NextRun=$((($probe | Get-ScheduledTaskInfo).NextRunTime))" } else { 'NOT VISIBLE' }
Write-Host "elevated-view: $elevatedView"

$triggerNowResult = 'not-requested'
if ($ok -and $TriggerNow) {
    # Verification probe: with Devin active the run must DEFER (exit 2) and leave
    # WSL/Docker completely untouched. SYSTEM context can start/see the task.
    Write-Host "Triggering task for the deferred-run test (Devin gates active)..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskPath $taskPath -TaskName $taskName
    $waited = 0
    do {
        Start-Sleep 5; $waited += 5
        $probe = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName
        $info = $probe | Get-ScheduledTaskInfo
        $state = $probe.State
    } while ($state -eq 'Running' -and $waited -lt 180)
    $triggerNowResult = "lastResult=$($info.LastTaskResult) (2 = deferred-as-designed), ran at $($info.LastRunTime), waited ${waited}s"
    Write-Host $triggerNowResult
}

Write-Host "Registered $taskPath$taskName - daily 03:45 vhdx compaction as $taskName principal (tbaltzakis, Highest)."
Write-Host 'Devin gates: skips (and retries 8x30min) whenever Devin.exe or devin-server is active.'
Write-Host 'Growth threshold: 10 GB since last successful compaction. Docker + WSL restart afterward.'
[pscustomobject]@{ ok = $ok; elevatedView = $elevatedView; triggerNow = $triggerNowResult; at = (Get-Date).ToString('o') } |
    ConvertTo-Json | Set-Content 'D:\DevOptimizer\logs\register-vhdxcompaction-result.json'
try { Stop-Transcript | Out-Null } catch { }
