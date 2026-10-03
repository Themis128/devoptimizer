<#
.SYNOPSIS
    DevOptimizer automation script: Tune-Windows-For-Devin.
.DESCRIPTION
    DevOptimizer automation script: Tune-Windows-For-Devin.
#>

# Tune-Windows-For-Devin.ps1 - one-time Windows 11 tuning so the daily Devin
# maintenance (Invoke-DevinDailyMaintenance.ps1, task \DevOptimizer\Devin-Daily-Maintenance)
# can actually succeed unattended.
# CATEGORY: maintenance
#
#  1. Enables the Task Scheduler operational history channel (disabled by
#     default on Windows 11) so unattended runs leave an OS-level audit trail.
#  2. Raises the system UNATTENDED SLEEP timeout (AC 1800 s / DC 600 s, only
#     where lower): after a WakeToRun start Windows sleeps after 2 minutes of
#     no user input by default - which would kill a ~700 MB bundle re-download
#     mid-run. Only applied where the current value is smaller.
#  3. Creates the 'DevOptimizer' event source (Application log) so the daily
#     orchestrator can write its heartbeat/warning/error events.
#
# Requires elevation (UAC RunAs, self-elevating). Safe to re-run: every step
# checks current state first.
#requires -Version 5.1

$logPath = 'D:\DevOptimizer\logs\tune-windows-for-devin.log'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Elevating (UAC prompt)..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
    )
    exit
}

try { Start-Transcript -Path $logPath -Force | Out-Null } catch { }
Write-Host "=== Windows tuning for Devin maintenance ===" -ForegroundColor Magenta

# --- 1. Task Scheduler history channel ---------------------------------------
$channel = 'Microsoft-Windows-TaskScheduler/Operational'
$state = & wevtutil gl $channel 2>$null | Select-String '^enabled: (.+)$'
$enabled = ($state.Matches.Count -gt 0 -and $state.Matches[0].Groups[1].Value -eq 'true')
if ($enabled) {
    Write-Host "[ OK ] Task Scheduler history already enabled" -ForegroundColor Green
} else {
    & wevtutil sl $channel /e:true
    $state = & wevtutil gl $channel 2>$null | Select-String '^enabled: (.+)$'
    $enabled = ($state.Matches.Count -gt 0 -and $state.Matches[0].Groups[1].Value -eq 'true')
    if ($enabled) { Write-Host "[ OK ] Task Scheduler history ENABLED ($channel)" -ForegroundColor Green }
    else { Write-Host "[FAIL] could not enable $channel" -ForegroundColor Red }
}

# --- 2. Unattended sleep timeout ---------------------------------------------
# "System unattended sleep timeout" is a HIDDEN setting: subgroup aliases fail
# to resolve it on this build, so the explicit GUIDs are used (SUB_SLEEP =
# 238c9fa8-..., UNATTENDSLEEP = 9d7815a6-7ee4-497e-8888-515a05f02364). WakeToRun
# tasks are subject to it: default 120 s would sleep the box mid re-download.
$targetAC = 1800; $targetDC = 600
$sleepGroup = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
$unattendSleep = '9d7815a6-7ee4-497e-8888-515a05f02364'
$q = & powercfg /q SCHEME_CURRENT $sleepGroup $unattendSleep 2>$null
$curAC = $null; $curDC = $null
switch -Regex ($q) {
    'Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)' { $curAC = [int]("0x" + $Matches[1]) }
    'Current DC Power Setting Index:\s+0x([0-9a-fA-F]+)' { $curDC = [int]("0x" + $Matches[1]) }
}
if ($null -eq $curAC -and $null -eq $curDC) {
    Write-Host "[FAIL] could not read System unattended sleep timeout (powercfg /q)" -ForegroundColor Red
} else {
    Write-Host ("[INFO] unattended sleep timeout: AC {0}s, DC {1}s" -f $curAC, $curDC)
    $changed = $false
    if ($curAC -lt $targetAC) {
        & powercfg /setacvalueindex SCHEME_CURRENT $sleepGroup $unattendSleep $targetAC
        Write-Host "[ OK ] AC unattended sleep: $curAC s -> $targetAC s" -ForegroundColor Green
        $changed = $true
    }
    if ($curDC -lt $targetDC) {
        & powercfg /setdcvalueindex SCHEME_CURRENT $sleepGroup $unattendSleep $targetDC
        Write-Host "[ OK ] DC unattended sleep: $curDC s -> $targetDC s" -ForegroundColor Green
        $changed = $true
    }
    if ($changed) {
        & powercfg /setactive SCHEME_CURRENT
        Write-Host "[ OK ] scheme reapplied" -ForegroundColor Green
    } else {
        Write-Host "[ OK ] unattended sleep timeouts already >= targets" -ForegroundColor Green
    }
}

# --- 3. 'DevOptimizer' event source ------------------------------------------
$source = 'DevOptimizer'
if ([System.Diagnostics.EventLog]::SourceExists($source)) {
    Write-Host "[ OK ] event source '$source' already exists" -ForegroundColor Green
} else {
    New-EventLog -LogName Application -Source $source
    Write-Host "[ OK ] event source '$source' created (Application log)" -ForegroundColor Green
}
try {
    Write-EventLog -LogName Application -Source $source -EventId 1 -EntryType Information `
        -Message 'DevOptimizer event source test entry (Tune-Windows-For-Devin.ps1).'
    Write-Host "[ OK ] test event written and source writable" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] event source not writable: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "=== Tuning complete ===" -ForegroundColor Magenta
try { Stop-Transcript | Out-Null } catch { }
