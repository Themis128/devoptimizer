<#
.SYNOPSIS
    Phone notification watchdog - keeps the Nextcloud Android app under
    Android's 50-notifications-per-package cap.
.DESCRIPTION
    Runs via the DevOptimizer-Phone-Notify-Watchdog scheduled task. Android
    silently drops new notifications once an app has posted/enqueued 50
    (seen 2026-11-10: stale "File upload conflict" notifications flooded
    com.nextcloud.client and suppressed real push notifications).

    Checks, idempotently:
      1. ADB device ($Serial) is reachable - skips quietly if the phone
         is not connected (USB or WiFi ADB)
      2. Counts posted NotificationRecords for com.nextcloud.client
      3. If count >= -Threshold (default 40, cap is 50): force-stops and
         relaunches the app, which clears the backlog; the app reposts
         only its current sync state

    All actions logged to logs\phone-notify-watchdog.log (rotates at ~1 MB).
    -DryRun reports only, never touches the phone.
#>
#requires -Version 5.1
# CATEGORY: maintenance

[CmdletBinding()]
param(
    [string]$Serial    = 'RFCTA0AEKZP',
    [string]$Package   = 'com.nextcloud.client',
    [int]$Threshold    = 40,
    [string]$Root      = 'D:\DevOptimizer',
    [string]$AdbPath   = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$logFile = Join-Path $Root 'logs\phone-notify-watchdog.log'

function Log([string]$msg) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    try {
        if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 1MB) {
            $tail = Get-Content $logFile -Tail 2000 -ErrorAction SilentlyContinue
            Set-Content -Path $logFile -Value $tail -Encoding UTF8
        }
        Add-Content -Path $logFile -Value $line -ErrorAction Stop
    } catch { }
    Write-Host $line
}

# --- locate adb ---
if (-not $AdbPath) {
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:ANDROID_HOME\platform-tools\adb.exe",
        "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe",
        'adb.exe'
    )
    $AdbPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $AdbPath -or -not (Test-Path $AdbPath)) {
    Log "[adb] not found - skipping"
    return
}

function AdbShell([string]$cmd) {
    $out = & $AdbPath -s $Serial shell $cmd 2>&1 | Out-String
    return @{ Code = $LASTEXITCODE; Out = $out }
}

Log "=== phone notify check (dryRun=$DryRun serial=$Serial pkg=$Package) ==="

# --- 1. device reachable? ---
$devices = & $AdbPath devices 2>&1 | Out-String
if ($devices -notmatch "(?m)^$([regex]::Escape($Serial))\s+device") {
    Log "[$Serial] not connected - skipping"
    return
}

# --- 2. count posted notifications for the package ---
$dump = AdbShell 'dumpsys notification --noredact'
if ($dump.Code -ne 0) {
    Log "[dumpsys] failed exit=$($dump.Code) - skipping"
    return
}
$count = ([regex]::Matches($dump.Out, "NotificationRecord\(0x[0-9a-fA-F]+: pkg=$([regex]::Escape($Package))")).Count
Log "[notify] $Package records=$count threshold=$Threshold"

if ($count -lt $Threshold) {
    Log '=== phone notify check done (healthy) ==='
    return
}

Log "[notify] OVER THRESHOLD - clearing $Package notifications"
if ($DryRun) {
    Log '[notify] dryRun - would force-stop and relaunch'
    Log '=== phone notify check done ==='
    return
}

# --- 3. force-stop + relaunch clears the app's posted notifications ---
$stop = AdbShell "am force-stop $Package"
Start-Sleep -Seconds 2
$launch = AdbShell "monkey -p $Package -c android.intent.category.LAUNCHER 1"
Start-Sleep -Seconds 5
$recount = AdbShell 'dumpsys notification --noredact'
$after = ([regex]::Matches($recount.Out, "NotificationRecord\(0x[0-9a-fA-F]+: pkg=$([regex]::Escape($Package))")).Count
Log ("[notify] cleared: forceStopExit={0} launchExit={1} records {2} -> {3}" -f $stop.Code, $launch.Code, $count, $after)
Log '=== phone notify check done ==='
