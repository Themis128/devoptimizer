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
    if (-not $prev.ContainsKey($selfKey) -or $prev[$selfKey] -ne 'down') {
        Send-Telegram "tailnet watchdog: Tailscale is DOWN on office-1-win-exitnode (tailscale status failed)"
        $prev[$selfKey] = 'down'; Save-State $prev
    }
    exit 0
}
try { $status = $statusJson | ConvertFrom-Json } catch {
    Write-Log "status parse failed: $($_.Exception.Message)"
    exit 0
}
if ($prev.ContainsKey($selfKey) -and $prev[$selfKey] -eq 'down') {
    Send-Telegram "tailnet watchdog: Tailscale recovered on office-1-win-exitnode"
    $prev.Remove($selfKey)
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
