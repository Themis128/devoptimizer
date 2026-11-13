# vhdx-compact-on-devin-exit.ps1 - fires the elevated Nightly-Vhdx-Compact
# task once per day, and recycles WSL to heal the vsock-wedge class, but only
# when no live agent session can be hurt:
#
#   devin-server alive in Ubuntu-24.04 -> NEVER act (active agent session)
#   Devin.exe open + wedge pending + user idle >=30min + no devin-server
#     -> heal NOW (idle escalation; routine compaction still waits for a
#        real Devin exit - disk tidiness is not worth bouncing the app)
#   Devin fully closed -> wedge heal (if pending) + compaction (if due)
#
# Runs every 5 min via scheduled task \Vhdx-Compact-DevinExit (limited
# rights - it launches the elevated task / issues wsl --shutdown, never
# compacts itself).
# CATEGORY: maintenance
$ErrorActionPreference = 'Continue'
$log   = 'D:\DevOptimizer\logs\vhdx-compact-on-exit.log'
$stamp = 'D:\DevOptimizer\logs\.vhdx-compact-fired'

function Log([string]$m) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') $m" }

# Idle-time probe (GetLastInputInfo - works for the interactive session this
# task runs in). Returns minutes since last keyboard/mouse input, -1 on error.
try {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DevOptIdle {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] public static extern bool GetLastInputInfo(ref LASTINPUTINFO p);
    public static int MinutesIdle() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (!GetLastInputInfo(ref lii)) { return -1; }
        return (int)(((uint)Environment.TickCount - lii.dwTime) / 60000u);
    }
}
'@ -ErrorAction Stop
} catch { }

function Test-DevinServerAlive {
    # devin-server inside Ubuntu-24.04 is the real "live agent session" gate.
    # wsl calls flake when the vsock plane is wedged - retry before deciding.
    foreach ($i in 1..3) {
        $out = & wsl.exe -d Ubuntu-24.04 -e bash -lc "pgrep -f 'devin acp|server-mai[n]' | head -3" 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) { return $true }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Send-HealNotice([string]$msg) {
    try {
        . 'D:\DevOptimizer\scripts\lib\Notify.ps1'
        Send-DevOptAlert -Severity Warning -Title 'WSL vsock heal' -Message $msg -Tags 'wsl','vsock' -ErrorAction SilentlyContinue
    } catch { }
}

# --- State ---
$today = Get-Date -Format 'yyyy-MM-dd'
$compactedToday = (Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $today)

$repairLog = 'D:\DevOptimizer\logs\wsl-repair.log'
$wedgeFlag = 'D:\DevOptimizer\logs\.vsock-wedge-healed'
$notifiedFlag = 'D:\DevOptimizer\logs\.vsock-heal-notified'
$wedged = $false
if (Test-Path $repairLog) {
    $recent = Get-Content $repairLog -Tail 80 -ErrorAction SilentlyContinue
    $wedged = [bool]($recent | Select-String 'unreachable|WSAETIMEDOUT|Wsl/Service|BROKEN|DISTRO PROXY DEAD' | Select-Object -First 1)
}
$healedToday  = (Test-Path $wedgeFlag) -and ((Get-Content $wedgeFlag -Raw).Trim() -eq $today)
$healPending  = $wedged -and -not $healedToday

# Heal-resistant wedge: the shutdown heal already ran today but NEWER wedge
# evidence exists in the repair log - escalate to the elevated network soft
# reset (no reboot needed, ~10s blip). Next tier above that is a reboot.
$resistant = $false
if ($wedged -and $healedToday) {
    $lastWedgeLine = $recent | Select-String 'unreachable|WSAETIMEDOUT|Wsl/Service|BROKEN|DISTRO PROXY DEAD' | Select-Object -Last 1
    if ($lastWedgeLine -and $lastWedgeLine.Line -match '^(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})' `
            -and (Get-Item $wedgeFlag).LastWriteTime -lt [datetime]$matches[1]) {
        $resistant = $true
    }
}

function Invoke-NetSoftReset([string]$why) {
    Log "heal-resistant wedge ($why) - firing elevated \DevOptimizer\Net-Soft-Reset"
    $out = & schtasks.exe /run /tn '\DevOptimizer\Net-Soft-Reset' 2>&1
    $out | ForEach-Object { Log "schtasks: $_" }
    if ($LASTEXITCODE -ne 0) { Log "net-soft-reset launch failed rc=$LASTEXITCODE" }
}

function Invoke-WedgeHeal([string]$why) {
    Log "vsock wedge evidence in wsl-repair.log - recycling WSL to heal it ($why)"
    & wsl.exe --shutdown 2>&1 | Out-Null
    & wsl.exe -d Ubuntu-24.04 -e true 2>&1 | Out-Null   # warm the distro back up
    $ddExe = "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
    if (Test-Path $ddExe) { Start-Process $ddExe }
    Set-Content -Path $wedgeFlag -Value $today
    Send-HealNotice "vsock wedge healed via wsl --shutdown ($why). Docker Desktop relaunched."
    Log 'wsl recycled + Docker Desktop relaunched'
}

# --- Gate A: Devin desktop app running ---
if (Get-Process -Name 'Devin' -ErrorAction SilentlyContinue) {
    # The app being open is not itself a blocker - a live agent session is.
    # A pending wedge heal may proceed once the user has been away >= 30 min.
    if (-not ($healPending -or $resistant)) { exit 0 }
    $idle = try { [DevOptIdle]::MinutesIdle() } catch { -1 }
    if ($idle -ge 0 -and $idle -lt 30) {
        # Tell the user once per day that a heal is queued behind their session.
        $notified = (Test-Path $notifiedFlag) -and ((Get-Content $notifiedFlag -Raw).Trim() -eq $today)
        if (-not $notified) {
            Set-Content -Path $notifiedFlag -Value $today
            Send-HealNotice "vsock wedge detected; heal queued - fires when you step away >=30min or close Devin (latest: nightly WSL bounce)."
            Log "wedge heal deferred - Devin open, user active (idle ${idle}m); notice sent"
        }
        exit 0
    }
    if (Test-DevinServerAlive) { Log 'wedge heal deferred - devin-server still alive (active agent session)'; exit 0 }
    if ($healPending) { Invoke-WedgeHeal 'idle-escalation' }
    elseif ($resistant) { Invoke-NetSoftReset 'idle-escalation' }
    exit 0
}

# --- Gate B: devin-server still alive in Ubuntu-24.04 ---
if (Test-DevinServerAlive) { exit 0 }

# Devin fully closed and no agent session. Only run the standalone heal when
# compaction already fired today - otherwise firing the compact task below
# recycles WSL anyway and a separate bounce would just be a redundant stop.
if ($compactedToday) {
    if ($healPending) { Invoke-WedgeHeal 'devin-exit' }
    elseif ($resistant) { Invoke-NetSoftReset 'devin-exit' }
    exit 0
}

# Fire the elevated compaction task and stamp today. Compaction itself
# recycles WSL, so a pending wedge heals inside it as well.
# Stamp only after schtasks succeeds - a failed fire must retry next pass.
Log 'Devin closed - launching Nightly-Vhdx-Compact'
$out = & schtasks.exe /run /tn '\DevOptimizer\Nightly-Vhdx-Compact' 2>&1
$out | ForEach-Object { Log "schtasks: $_" }
if ($LASTEXITCODE -eq 0) {
    Set-Content -Path $stamp -Value $today
    if ($wedged) { Set-Content -Path $wedgeFlag -Value $today }
} else { Log "schtasks failed rc=$LASTEXITCODE - will retry" }
