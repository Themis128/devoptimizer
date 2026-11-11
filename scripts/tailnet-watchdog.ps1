<#
.SYNOPSIS
    Tailnet watchdog — alerts via Telegram when watched nodes go offline/online.
.DESCRIPTION
    Runs `tailscale status --json`, compares each peer's Online state against
    config\tailnet-watch.json, and sends a Telegram message on state
    transitions only (no repeat alerts while a node stays offline).
    First run records a silent baseline — currently-offline nodes do not alert.
    State persists in logs\tailnet-watchdog-state.json; log in
    logs\tailnet-watchdog.log. Exit 0 always (watchdog must not fail tasks).
#>
#requires -Version 5.1
# CATEGORY: maintenance

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'

$root      = 'D:\DevOptimizer'
$config    = Join-Path $root 'config\tailnet-watch.json'
$stateFile = Join-Path $root 'logs\tailnet-watchdog-state.json'
$logFile   = Join-Path $root 'logs\tailnet-watchdog.log'
$tokenFile = Join-Path $env:APPDATA 'devin\secrets\tg-bot-token'
$chatId    = '7017840434'

function Write-Log([string]$msg) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

function Send-Telegram([string]$text) {
    if ($DryRun) { Write-Log "DRYRUN tg: $text"; return }
    if (-not (Test-Path $tokenFile)) { Write-Log "tg token missing: $tokenFile"; return }
    $bot = (Get-Content $tokenFile -Raw).Trim()
    try {
        $body = @{ chat_id = $chatId; text = $text } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$bot/sendMessage" `
            -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 15 | Out-Null
        Write-Log "tg sent: $($text.Substring(0, [Math]::Min(80, $text.Length)))..."
    } catch {
        Write-Log "tg failed: $($_.Exception.Message)"
    }
}

# --- tailscale status --------------------------------------------------------
$prev = @{}
if (Test-Path $stateFile) {
    try { (Get-Content $stateFile -Raw | ConvertFrom-Json).states.PSObject.Properties |
          ForEach-Object { $prev[$_.Name.ToLower()] = $_.Value } } catch {}
}

function Save-State([hashtable]$states) {
    $stateDir = Split-Path $stateFile
    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    @{ states = $states } | ConvertTo-Json -Depth 4 | Set-Content $stateFile -Encoding UTF8
}

$statusJson = & tailscale.exe status --json 2>$null
$selfKey = '_tailscale-self'
if (-not $statusJson) {
    Write-Log 'tailscale status failed'
    # count consecutive failures; after 3 (~15 min) the daemon is likely
    # wedged (e.g. stuck "starting" on the Win11 25H2 DNS contention) -
    # restart the service. Restart-Service needs elevation; if the task
    # isn't elevated this fails and we alert once for manual restart.
    $fails = 0
    if ($prev.ContainsKey('_self-fails')) { $fails = [int]$prev['_self-fails'] }
    $fails++
    $prev['_self-fails'] = $fails
    if ($fails -ge 3) {
        Write-Log "tailscale status failed ${fails}x - attempting service restart"
        try {
            Restart-Service Tailscale -Force -ErrorAction Stop
            Write-Log 'tailscale service restart ok'
            Send-Telegram "tailnet watchdog: restarted Tailscale service on office-1-win-exitnode after ${fails} failed checks"
        } catch {
            Write-Log "service restart failed: $($_.Exception.Message)"
            Send-Telegram "tailnet watchdog: tailscaled unresponsive on office-1-win-exitnode (${fails} failed checks) - needs manual service restart (non-elevated task cannot restart it)"
        }
        $prev.Remove('_self-fails')
    }
    if (-not $prev.ContainsKey($selfKey) -or $prev[$selfKey] -ne 'down') {
        Send-Telegram "tailnet watchdog: Tailscale is DOWN on office-1-win-exitnode (tailscale status failed)"
        $prev[$selfKey] = 'down'
    }
    Save-State $prev
    exit 0
}
$prev.Remove('_self-fails')
try { $status = $statusJson | ConvertFrom-Json } catch {
    Write-Log "status parse failed: $($_.Exception.Message)"
    exit 0
}
if ($prev.ContainsKey($selfKey) -and $prev[$selfKey] -eq 'down') {
    Send-Telegram "tailnet watchdog: Tailscale recovered on office-1-win-exitnode"
    $prev.Remove($selfKey)
}

# BackendState other than Running (e.g. "NoState" while stuck "starting")
# means the daemon is up but not connected - same remediation path as a
# hard failure, counted separately so brief restarts don't trigger it.
$backend = [string]$status.BackendState
if ($backend -and $backend -ne 'Running') {
    if (-not $prev.ContainsKey('_self-stuck')) { $prev['_self-stuck'] = (Get-Date).ToString('o') }
    $stuckMin = ((Get-Date) - [datetime]::Parse($prev['_self-stuck'])).TotalMinutes
    if ($stuckMin -ge 15) {
        Write-Log "BackendState=$backend for $([int]$stuckMin)m - attempting service restart"
        try {
            Restart-Service Tailscale -Force -ErrorAction Stop
            Write-Log 'tailscale service restart ok'
            Send-Telegram "tailnet watchdog: restarted Tailscale service on office-1-win-exitnode (BackendState=$backend for $([int]$stuckMin)m)"
        } catch {
            Write-Log "service restart failed: $($_.Exception.Message)"
            Send-Telegram "tailnet watchdog: tailscaled stuck (BackendState=$backend) on office-1-win-exitnode - needs manual service restart"
        }
        $prev.Remove('_self-stuck')
    } else {
        Write-Log "BackendState=$backend (stuck ${stuckMin}m, restart due at 15m)"
    }
} else {
    $prev.Remove('_self-stuck')
}

# --- self health remediation ---------------------------------------------------
# Known Win11 25H2 issue: tailscaled reports "failed to set the DNS
# configuration ... being used by another process" while DNS actually works
# (tailscale/tailscale#21035). Cycling accept-dns forces a re-apply and
# clears the health entry. Rate-limited to once per 6h; alerts only if the
# warning survives remediation.
$health = @($status.Health)
$dnsWarn = $health | Where-Object { $_ -match 'DNS configuration' }
if ($dnsWarn) {
    $remKey = '_dns-remediation'
    $lastRem = $null
    if ($prev.ContainsKey($remKey)) { $lastRem = [datetime]::Parse($prev[$remKey]) }
    $due = (-not $lastRem) -or ((Get-Date) - $lastRem).TotalHours -ge 6
    if ($due) {
        Write-Log "health: DNS config warning present - cycling accept-dns"
        if (-not $DryRun) {
            & tailscale.exe set --accept-dns=false 2>$null | Out-Null
            Start-Sleep -Seconds 2
            & tailscale.exe set --accept-dns=true 2>$null | Out-Null
        }
        Start-Sleep -Seconds 3
        $recheck = & tailscale.exe status --json 2>$null | ConvertFrom-Json
        $still = @($recheck.Health) | Where-Object { $_ -match 'DNS configuration' }
        $prev[$remKey] = (Get-Date).ToString('o')
        if ($still) {
            Write-Log "health: DNS warning persists after remediation"
            Send-Telegram "tailnet watchdog: Tailscale DNS health warning persists on office-1-win-exitnode after accept-dns cycle (Win11 25H2 known issue - DNS itself likely still works)"
        } else {
            Write-Log "health: DNS warning cleared by remediation"
            Send-Telegram "tailnet watchdog: cleared Tailscale DNS health warning on office-1-win-exitnode (accept-dns cycle)"
        }
    } else {
        Write-Log "health: DNS warning present, remediation not due yet"
    }
}

# --- load watch config -------------------------------------------------------
if (-not (Test-Path $config)) { Write-Log "config missing: $config"; exit 0 }
$watch = Get-Content $config -Raw | ConvertFrom-Json
$nodes = @{}
foreach ($n in $watch.nodes) { $nodes[$n.name.ToLower()] = $n }

# --- diff --------------------------------------------------------------------
$now = @{}
$changed = @()
foreach ($prop in $status.Peer.PSObject.Properties) {
    $p = $prop.Value
    # DNSName first label is the stable tailnet name (HostName can differ,
    # e.g. "grokbot-box" hosts as grokbot-box-1.tail4ecae1.ts.net)
    $dnsLabel = ($p.DNSName -split '\.')[0]
    $name = if ($dnsLabel) { $dnsLabel } else { $p.HostName }
    if (-not $name) { continue }
    $key = $name.ToLower()
    $cfg = $nodes[$key]
    if (-not $cfg) { continue }                       # not watched
    if (-not $cfg.alert) { continue }                 # watched but silent
    $online = [bool]$p.Online
    $now[$key] = $online

    if ($prev.ContainsKey($key)) {
        $was = [bool]$prev[$key]
        if ($was -ne $online) {
            $changed += [pscustomobject]@{ Name = $name; Online = $online; Ip = ($p.TailscaleIPs[0]) }
        }
    }
}

# --- phone connectivity (best effort, ADB) ------------------------------------
# Detects the failure mode seen 2026-11-11: phone loses public DNS/internet
# when the Tailscale exit node drops (MagicDNS has no upstream without it).
# Repair = re-assert exit node office-1-win-exitnode via UI automation.
# Skipped silently when the phone isn't reachable over ADB; 30 min cooldown.
$phoneKey = '_phone-lastfix'
try {
    $adb = 'C:\Users\tbaltzakis\AppData\Local\Android\Sdk\platform-tools\adb.exe'
    if (-not (Test-Path $adb)) { $adb = 'adb' }
    $online = & $adb devices 2>$null | Select-String 'RFCTA0AEKZP\s+device\s*$'
    if ($online) {
        $ping = & $adb -s RFCTA0AEKZP shell 'ping -c 1 -W 3 cloudflare.com' 2>$null | Out-String
        if ($ping -notmatch '1 received') {
            $due = $true
            if ($prev.ContainsKey($phoneKey)) {
                $due = ((Get-Date) - [datetime]::Parse($prev[$phoneKey])).TotalMinutes -ge 30
            }
            if ($due) {
                Write-Log 'phone connectivity check failed - attempting exit-node repair'
                $fix = Join-Path $root 'scripts\phone-ensure-exitnode.py'
                if (Test-Path $fix) {
                    $out = & python $fix 2>&1 | Out-String
                    Write-Log ("phone fix output: " + $out.Trim())
                }
                $prev[$phoneKey] = (Get-Date).ToString('o')
                Start-Sleep -Seconds 10
                $ping2 = & $adb -s RFCTA0AEKZP shell 'ping -c 1 -W 3 cloudflare.com' 2>$null | Out-String
                if ($ping2 -match '1 received') {
                    Send-Telegram "tailnet watchdog: repaired galaxy-s22 connectivity (re-set exit node office-1-win-exitnode)"
                } else {
                    Send-Telegram "tailnet watchdog: galaxy-s22 has no internet/DNS and auto-repair failed - check Tailscale app manually"
                }
            }
        } else {
            $prev.Remove($phoneKey)
        }
    }
} catch {
    Write-Log "phone check error: $($_.Exception.Message)"
}

# --- persist + notify --------------------------------------------------------
$final = @{}
foreach ($k in $prev.Keys) { $final[$k] = $prev[$k] }
foreach ($k in $now.Keys)  { $final[$k] = $now[$k] }
Save-State $final

if ($changed.Count -gt 0) {
    $lines = foreach ($c in $changed) {
        if ($c.Online) { "UP   $($c.Name) ($($c.Ip))" } else { "DOWN $($c.Name) ($($c.Ip))" }
    }
    $ts = Get-Date -Format 'HH:mm'
    Send-Telegram ("tailnet watchdog ${ts}:`n" + ($lines -join "`n"))
}

Write-Log ("check ok; watched={0} changed={1}" -f $now.Count, $changed.Count)
exit 0
