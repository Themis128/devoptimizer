<#
.SYNOPSIS
    Phone-tailnet watchdog - detects galaxy-s22 dropping off the tailnet
    and relaunches its Tailscale app over ADB.
.DESCRIPTION
    Layer 2 of the phone-tailnet watch (layer 1: omv tailnet-phone-watch.py,
    every 2 min). Covers the case omv's ADB paths are blind: this host can
    reach the phone over USB serial, current-DHCP LAN endpoints, and the
    tailnet endpoint once it's back.

    Flow (every 10 min via \DevOptimizer\Phone-Tailnet-Watch):
      1. tailscale status --json -> galaxy-s22 peer Online? -> done.
      2. Offline > ~5 min: resolve an adb endpoint (USB serial -> connected
         sessions -> adb connect to known LAN/tailnet :5555 endpoints).
      3. pidof com.tailscale.ipn empty -> monkey relaunch + pin
         always_on_vpn_app (Android restarts the tunnel on kill).
      4. Re-check peer online; ntfy on remediation or when adb is
         unreachable (needs manual).
#>
#requires -Version 5.1
# CATEGORY: maintenance
param([switch]$DryRun)

$ErrorActionPreference = 'Continue'
$logFile  = 'D:\DevOptimizer\logs\phone-tailnet-watch.log'
$fixStamp = 'D:\DevOptimizer\logs\.phone-ts-lastfix'
$Adb      = 'C:\Users\tbaltzakis\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$Pkg      = 'com.tailscale.ipn'
$Peer     = 'galaxy-s22'
$KnownEndpoints = @('RFCTA0AEKZP', '192.168.1.235:5555', '192.168.1.77:5555', '100.84.31.85:5555')

function Log([string]$m) { Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" }

# Spawn a console-subsystem exe with CREATE_NO_WINDOW - bare '& exe' allocates
# a visible console (popup flash). Returns stdout; $null on spawn/timeout.
function Invoke-Hidden([string]$Exe, [string[]]$CmdArgs, [int]$TimeoutMs = 30000) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new($Exe)
    foreach ($a in $CmdArgs) { [void]$psi.ArgumentList.Add($a) }
    $psi.CreateNoWindow = $true; $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTxt = $p.StandardOutput.ReadToEnd()
    $null = $p.StandardError.ReadToEnd()
    if (-not $p.WaitForExit($TimeoutMs)) { try { $p.Kill() } catch {}; return $null }
    return $outTxt
}

# adb devices with a 20s cap - a dead/restarting adb server hangs the call
# otherwise, and this task would sit wedged until reboot.
function Get-AdbDevices {
    $out = Invoke-Hidden $Adb @('devices') -TimeoutMs 20000
    if (-not $out) { return @() }
    return ($out -split "`n" | Where-Object { $_ -match '\tdevice$' } | ForEach-Object { ($_ -split "`t")[0] })
}

# --- 1. peer state ---
$status = Invoke-Hidden 'tailscale.exe' @('status','--json') | ConvertFrom-Json
if (-not $status -or $status.BackendState -ne 'Running' -or -not $status.Peer) {
    # tailscaled itself is (re)starting - Peer is null in that window.
    # Transient, retry next pass; do not treat as phone-offline.
    exit 0
}
$node = $status.Peer.PSObject.Properties.Value | Where-Object { $_.HostName -match 'galaxy|s22' -or $_.DNSName -like 'galaxy-s22.*' } | Select-Object -First 1
if (-not $node) { Log "$Peer not in tailnet peer list - node removed? alert"; exit 1 }
if ($node.Online) { exit 0 }

$offlineMin = [math]::Round(((Get-Date) - [datetime]$node.LastSeen).TotalMinutes)
Log "$Peer offline ${offlineMin}m - attempting adb remediation"

# --- 2. resolve an adb endpoint ---
$endpoint = $null
$devs = @(Get-AdbDevices)
foreach ($ep in $KnownEndpoints) { if ($devs -contains $ep) { $endpoint = $ep; break } }
if (-not $endpoint) {
    # prefer any connected USB serial, then LAN ip:port session
    $endpoint = $devs | Where-Object { $_ -notmatch ':' -and $_ -ne 'emulator-5554' } | Select-Object -First 1
    if (-not $endpoint) { $endpoint = $devs | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+:\d+$' } | Select-Object -First 1 }
}
if (-not $endpoint) {
    foreach ($ep in ($KnownEndpoints | Where-Object { $_ -match ':' })) { Invoke-Hidden $Adb @('connect', $ep) | Out-Null }
    $devs = @(Get-AdbDevices)
    foreach ($ep in $KnownEndpoints) { if ($devs -contains $ep) { $endpoint = $ep; break } }
    if (-not $endpoint) { $endpoint = $devs | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+:\d+$' } | Select-Object -First 1 }
}

# 30-min cooldown so a dead-phone loop doesn't spam adb/ntfy every pass
if ((Test-Path $fixStamp) -and ((Get-Item $fixStamp).LastWriteTime -gt (Get-Date).AddMinutes(-30))) {
    Log 'remediation in 30-min cooldown - skip'
    exit 0
}

if (-not $endpoint) {
    Log 'adb unreachable (USB + LAN + tailnet endpoints all failed) - manual check needed'
    try { . 'D:\DevOptimizer\scripts\lib\Notify.ps1'; Send-DevOptAlert -Severity Warning -Title 'Phone tailnet watch' -Message "galaxy-s22 offline ${offlineMin}m and no adb endpoint reachable - check wireless debugging / USB." -Tags 'phone','tailscale' -ErrorAction SilentlyContinue } catch { }
    New-Item -ItemType File -Path $fixStamp -Force | Out-Null
    exit 2
}

# --- 3. app-process repair ---
$pid_ = ((Invoke-Hidden $Adb @('-s', $endpoint, 'shell', 'pidof', $Pkg)) -replace '\s','')
if ($pid_) {
    Log "app alive (pid $pid_) via $endpoint but peer offline - not an app-death; skipping relaunch"
    exit 0
}
Log "app dead via $endpoint - relaunching"
if (-not $DryRun) {
    Invoke-Hidden $Adb @('-s', $endpoint, 'shell', 'monkey', '-p', $Pkg, '-c', 'android.intent.category.LAUNCHER', '1') | Out-Null
    Start-Sleep -Seconds 8
    $aon = ((Invoke-Hidden $Adb @('-s', $endpoint, 'shell', 'settings', 'get', 'global', 'always_on_vpn_app')) -replace '\s','')
    if ($aon -ne $Pkg) {
        Invoke-Hidden $Adb @('-s', $endpoint, 'shell', 'settings', 'put', 'global', 'always_on_vpn_app', $Pkg) | Out-Null
        Log "pinned always_on_vpn_app -> $Pkg"
    }
}

# --- 4. verify ---
Start-Sleep -Seconds 10
$status2 = Invoke-Hidden 'tailscale.exe' @('status','--json') | ConvertFrom-Json
$node2 = $status2.Peer.PSObject.Properties.Value | Where-Object { $_.HostName -match 'galaxy|s22' -or $_.DNSName -like 'galaxy-s22.*' } | Select-Object -First 1
$ok = $node2 -and $node2.Online
New-Item -ItemType File -Path $fixStamp -Force | Out-Null
try {
    . 'D:\DevOptimizer\scripts\lib\Notify.ps1'
    if ($ok) {
        Send-DevOptAlert -Severity Recovery -Title 'Phone tailnet watch' -Message "galaxy-s22 tailscale app was dead - relaunched via $endpoint, node back online." -Tags 'phone','tailscale','white_check_mark' -ErrorAction SilentlyContinue
    } else {
        Send-DevOptAlert -Severity Warning -Title 'Phone tailnet watch' -Message "galaxy-s22 relaunched via $endpoint but node still offline - may need app UI check." -Tags 'phone','tailscale' -ErrorAction SilentlyContinue
    }
} catch { }
Log ("remediation done via {0} - peer online: {1}" -f $endpoint, $ok)
exit 0
