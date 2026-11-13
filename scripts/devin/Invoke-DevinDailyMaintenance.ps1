<#
.SYNOPSIS
    DevOptimizer automation script: Invoke-DevinDailyMaintenance.
.DESCRIPTION
    DevOptimizer automation script: Invoke-DevinDailyMaintenance.
#>

# Invoke-DevinDailyMaintenance.ps1 - unattended daily maintenance for Devin Desktop.
# CATEGORY: maintenance
#
# Scheduled daily 04:30 by \DevOptimizer\Devin-Daily-Maintenance (see
# Register-Devin-Maintenance.ps1). Keeps Devin "in shape" per the failure history
# in memory: devoptimizer-script-hub / devin-desktop-install.
#
#   1. Sweep the regenerating Electron HTTP cache  (%APPDATA%\Devin\Cache)
#   2. Prune host session logs past retention      (%APPDATA%\Devin\logs)
#   3. Prune server-side session logs past retention (~/.devin-server/data/logs)
#   4. Remove superseded/corrupt server bundle commit dirs (~/.devin-server/bin)
#      - the recurring Sep-21/25/26 corrupt-bundle failure. Deleting a corrupt
#        commit dir is the verified repair: next app launch re-downloads fresh.
#   5. VACUUM the CLI sessions.db when Devin is closed and the SQLite freelist
#      holds >= $VacuumThresholdMB reclaimable (2026-11-04: 1.6 GiB db, 86%
#      freelist -> ~220 MiB after VACUUM). Read-only probe even while running.
#   6. Run Check-DevinHealth.ps1 for the standard verdict, captured in the log.
#   7. Write <ReportDir>\latest.json so the Hub / user can inspect the last run.
#
# Safety: bundle deletion AND sessions.db VACUUM are GATED operations - both
# are DEFERRED while Devin.exe runs. The cache sweep skips locked files
# per-item (proven safe live); log prunes are age-gated. Never touched:
# ~/.devin-server/extensions, ~/.devin-server/data, .installation_lock, the
# live intact commit dir.
#
# Exit code: 0 = completed (warnings/deferrals included), 1 = WSL unreachable,
# 2 = performed a repair (corrupt commit dir removed; ~700 MB re-download on
# next app launch).
param(
    [int]$LogRetentionDays = 14,
    [int]$ReportRetentionDays = 30,
    [int]$VacuumThresholdMB = 256,
    [string]$ReportDir = 'D:\DevOptimizer\logs\devin-maintenance'
)

$distro = 'Ubuntu-24.04'
$cliPath = "$env:LOCALAPPDATA\Programs\Devin\bin\devin-desktop.cmd"
$cacheDir = "$env:APPDATA\Devin\Cache"
$hostLogsDir = "$env:APPDATA\Devin\logs"
$healthScript = Join-Path $PSScriptRoot 'Check-DevinHealth.ps1'

function Invoke-Wsl([string]$cmd) {
    $out = & wsl.exe -d $distro -- bash -c $cmd 2>$null
    $joined = (@($out) -join "`n") -replace "`0", ''
    # wsl.exe can deliver multi-line output as ONE element with embedded
    # newlines; split so callers always get real lines.
    return ($joined -split "`r?`n") | Where-Object { $_ -ne '' }
}

$script:finalExit = 0
$script:steps = New-Object System.Collections.Generic.List[object]
function Add-Step([string]$name, [string]$status, [string]$detail) {
    $color = @{ OK = 'Green'; WARN = 'Yellow'; FAIL = 'Red'; SKIP = 'DarkGray'; DEFER = 'Yellow' }[$status]
    Write-Host ("[{0,-5}] {1}: {2}" -f $status, $name, $detail) -ForegroundColor $color
    $script:steps.Add([ordered]@{ name = $name; status = $status; detail = $detail })
}

function Write-MaintenanceEvent([int]$id, [string]$type, [string]$message) {
    # Heartbeat in the Application log (source created by Tune-Windows-For-Devin.ps1).
    # Best-effort: a missing source or ACL failure must never affect the run.
    try {
        Write-EventLog -LogName Application -Source 'DevOptimizer' -EventId $id -EntryType $type -Message $message
    } catch {
        Write-Host "[WARN] Event Log write skipped: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Send-Toast([string]$title, [string]$body) {
    # Attention toast for non-zero exits (silent success stays silent). Best-effort.
    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
        $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $texts = $xml.GetElementsByTagName('text')
        $texts.Item(0).AppendChild($xml.CreateTextNode($title)) | Out-Null
        $texts.Item(1).AppendChild($xml.CreateTextNode($body)) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    } catch { }
}

function Write-Report {
    $report = [ordered]@{
        date           = (Get-Date).ToString('o')
        appRunning     = $script:appRunning
        steps          = $script:steps
        healthExitCode = $script:healthExit
        exitCode       = $script:finalExit
    }
    $json = $report | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath (Join-Path $ReportDir 'latest.json') -Value $json -Encoding UTF8
}

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
try {
    Start-Transcript -Path (Join-Path $ReportDir ("devin-maintenance-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))) -Append | Out-Null
} catch { }

Write-Host "=== Devin Daily Maintenance ($distro) ===" -ForegroundColor Cyan

$appProc = Get-Process -Name 'Devin' -ErrorAction SilentlyContinue
$script:appRunning = [bool]$appProc
$script:healthExit = $null
Write-Host ("Devin.exe running: {0} -> bundle repairs {1}" -f $script:appRunning, $(if ($script:appRunning) { 'DEFERRED' } else { 'enabled' }))

# --- 1. WSL preflight: the disease is usually the WSL VM, not Devin ---------
$ping = Invoke-Wsl 'echo ok'
if ($ping -notmatch 'ok') {
    Add-Step 'wsl-preflight' 'FAIL' "distro '$distro' unreachable - check WSL/Docker VM state (wsl --shutdown recovery) before anything else"
    Write-MaintenanceEvent 1002 'Error' "Devin daily maintenance FAILED: WSL distro '$distro' unreachable. Check WSL/Docker VM state. Report: $ReportDir\latest.json"
    Send-Toast 'Devin maintenance FAILED' "WSL distro unreachable - Devin cannot self-heal. See logs\devin-maintenance\latest.json"
    Write-Report
    try { Stop-Transcript | Out-Null } catch { }
    exit 1
}
Add-Step 'wsl-preflight' 'OK' "distro '$distro' reachable"

# --- 2. Electron HTTP cache sweep (regenerates; locked files skipped) -------
$freed = 0L; $locked = 0
if (Test-Path -LiteralPath $cacheDir) {
    Get-ChildItem -LiteralPath $cacheDir -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $size = $_.Length
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
            $freed += $size
        } catch { $locked++ }
    }
    Add-Step 'cache-sweep' 'OK' ("freed {0:N1} MB, {1} locked file(s) skipped" -f ($freed / 1MB), $locked)
} else {
    Add-Step 'cache-sweep' 'SKIP' "$cacheDir not present"
}

# --- 3. Host session log retention ------------------------------------------
$hostRemoved = 0
$cutoff = (Get-Date).AddDays(-$LogRetentionDays)
if (Test-Path -LiteralPath $hostLogsDir) {
    Get-ChildItem -LiteralPath $hostLogsDir -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
                $hostRemoved++
            } catch { }
        }
}
Add-Step 'host-log-retention' 'OK' "removed $hostRemoved session dir(s) older than $LogRetentionDays days from %APPDATA%\Devin\logs"

# --- 4. Server-side session log retention (age-gated, data/logs only) -------
$before = @(Invoke-Wsl 'ls -1 ~/.devin-server/data/logs 2>/dev/null | wc -l') |
    Where-Object { $_ -match '\d' } | Select-Object -Last 1
if (-not $before) { $before = 0 }
Invoke-Wsl "find ~/.devin-server/data/logs -mindepth 1 -maxdepth 1 -mtime +$LogRetentionDays -exec rm -rf {} + 2>/dev/null; true"
$after = @(Invoke-Wsl 'ls -1 ~/.devin-server/data/logs 2>/dev/null | wc -l') |
    Where-Object { $_ -match '\d' } | Select-Object -Last 1
if (-not $after) { $after = 0 }
Add-Step 'server-log-retention' 'OK' ("server log entries {0} -> {1} (> {2} days removed)" -f $before, $after, $LogRetentionDays)

# --- 5. Bundle orphans: superseded + corrupt commit dirs ---------------------
# Check-DevinHealth derives the commit from the RUNNING server, so it cannot
# see a corrupt bundle while the app is closed; this check is process-
# independent. Integrity = node_modules/minimist + node_modules/@vscode.
$liveCommit = $null
if (Test-Path -LiteralPath $cliPath) {
    $version = & $cliPath --version 2>$null
    if (@($version).Count -ge 2 -and @($version)[1] -match '^([a-f0-9]{40})$') { $liveCommit = $Matches[1] }
}
# Guard against OTA skew: the client version file can lag the server. Also treat
# the RUNNING server's commit and freshly-downloaded dirs (< 48 h) as live, so an
# intact dir can never be deleted as "superseded" while it (or a newer download)
# is actually in use. Corrupt dirs are still always removed (self-heal path).
$serverCommit = $null
$serverProcs = @(Invoke-Wsl "pgrep -af 'server-mai[n]' 2>/dev/null; true") |
    Where-Object { $_ -match '\.devin-server/bin/([a-f0-9]{40})/' }
if ($serverProcs.Count -gt 0 -and $serverProcs[0] -match '\.devin-server/bin/([a-f0-9]{40})/') {
    $serverCommit = $Matches[1]
}
$binDirs = @(Invoke-Wsl 'ls -1d ~/.devin-server/bin/*/ 2>/dev/null' | ForEach-Object { $_ -replace '/+$', '' })
$deleted = @(); $deferred = @(); $corruptRemoved = $false

if (-not $liveCommit -and $binDirs.Count -gt 0) {
    Add-Step 'bundle-orphans' 'SKIP' "could not parse live commit from devin-desktop.cmd --version; leaving $($binDirs.Count) commit dir(s) untouched"
} else {
    foreach ($dir in $binDirs) {
        $commit = ($dir -split '/')[-1]
        $integrity = Invoke-Wsl "test -d '$dir/node_modules/minimist' -a -d '$dir/node_modules/@vscode' && echo intact || echo broken"
        $isCorrupt = ($integrity -match 'broken')
        $isLive = ($commit -eq $liveCommit) -or ($commit -eq $serverCommit) -or
            ((Invoke-Wsl "stat -c %Y '$dir' 2>/dev/null") -gt (Get-Date).AddHours(-48).ToUnixTimeSeconds())
        if (-not $isCorrupt -and $isLive) { continue }
        $why = if ($isCorrupt) { 'CORRUPT bundle' } else { 'superseded commit dir' }
        if ($script:appRunning) {
            $deferred += "$commit ($why)"
            continue
        }
        Invoke-Wsl "rm -rf '$dir'; rm -f ~/.devin-server/bin/.$commit.log ~/.devin-server/bin/.$commit.pid ~/.devin-server/bin/.$commit.token"
        $deleted += "$commit ($why)"
        if ($isCorrupt) { $corruptRemoved = $true }
    }
    if ($deleted.Count -gt 0) {
        Add-Step 'bundle-orphans' 'OK' ("removed: {0}; next app launch re-downloads the bundle" -f ($deleted -join ', '))
        if ($corruptRemoved) {
            $script:finalExit = 2
            Write-Host "[FIX ] corrupt bundle removed - on next Devin launch a fresh ~700 MB bundle downloads automatically." -ForegroundColor Yellow
        }
    } elseif ($deferred.Count -gt 0) {
        Add-Step 'bundle-orphans' 'DEFER' ("app is running; deferred: {0}" -f ($deferred -join ', '))
    } else {
        $liveShort = if ($liveCommit) { $liveCommit.Substring(0, 7) } elseif ($serverCommit) { $serverCommit.Substring(0, 7) } else { 'unknown' }
        Add-Step 'bundle-orphans' 'OK' "all commit dirs intact and current (live: $liveShort)"
    }
}

# --- 6. sessions.db VACUUM: reclaim SQLite freelist (Devin-closed gated) -----
# Probe is read-only (safe while Devin runs); the VACUUM itself only fires when
# the app is closed AND the freelist holds >= $VacuumThresholdMB reclaimable.
# The python helper is emitted at runtime (no repo file -> no registry churn).
$sessionsDb = "$env:APPDATA\devin\cli\sessions.db"
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
$vacuumHelper = Join-Path $ReportDir 'vacuum-sessions.py'
if (-not $py -or -not (Test-Path -LiteralPath $sessionsDb)) {
    Add-Step 'sessions-db-vacuum' 'SKIP' "python or $sessionsDb unavailable - skipped"
} else {
    @'
import os, sys, sqlite3

DB = os.path.expandvars(r"%APPDATA%\\devin\\cli\\sessions.db")

def probe():
    con = sqlite3.connect("file:{}?mode=ro".format(DB), uri=True)
    cur = con.cursor()
    page_size = cur.execute("PRAGMA page_size").fetchone()[0]
    page_count = cur.execute("PRAGMA page_count").fetchone()[0]
    freelist = cur.execute("PRAGMA freelist_count").fetchone()[0]
    con.close()
    return page_count * page_size, freelist * page_size

def vacuum():
    before = os.path.getsize(DB)
    con = sqlite3.connect(DB)
    con.execute("VACUUM")
    con.close()
    after = os.path.getsize(DB)
    return before, after

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--vacuum":
        before, after = vacuum()
        print("VACUUMED {} -> {} bytes".format(before, after))
    else:
        total, free = probe()
        print("PROBE total={} free={}".format(total, free))
'@ | Set-Content -LiteralPath $vacuumHelper -Encoding ASCII

    $probeRaw = & $py $vacuumHelper 2>&1 | Select-Object -Last 1
    if ($probeRaw -match 'PROBE total=(\d+) free=(\d+)') {
        $totalBytes = [long]$Matches[1]; $freeBytes = [long]$Matches[2]
        $freeMB = [int]($freeBytes / 1MB)
        if ($script:appRunning) {
            Add-Step 'sessions-db-vacuum' 'DEFER' ("app running; {0} MiB db, {1} MiB freelist reclaimable - VACUUM deferred until Devin is closed" -f ($totalBytes / 1MB), $freeMB)
        } elseif ($freeMB -lt $VacuumThresholdMB) {
            Add-Step 'sessions-db-vacuum' 'SKIP' ("{0} MiB freelist < {1} MiB threshold - not worth compacting" -f $freeMB, $VacuumThresholdMB)
        } else {
            $vacRaw = & $py $vacuumHelper --vacuum 2>&1 | Select-Object -Last 1
            if ($vacRaw -match 'VACUUMED (\d+) -> (\d+)') {
                $before = [long]$Matches[1]; $after = [long]$Matches[2]
                Add-Step 'sessions-db-vacuum' 'OK' ("{0:N0} -> {1:N0} bytes ({2:N0} MiB reclaimed)" -f $before, $after, (($before - $after) / 1MB))
            } else {
                Add-Step 'sessions-db-vacuum' 'WARN' "vacuum output not parseable: $vacRaw"
            }
        }
    } else {
        Add-Step 'sessions-db-vacuum' 'WARN' "probe output not parseable: $probeRaw"
    }
}

# --- 7. Standard health verdict (captured into the transcript) ---------------
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $healthScript
$script:healthExit = $LASTEXITCODE

# --- 8. Report + retention ---------------------------------------------------
$stepSummary = ($script:steps | ForEach-Object { "$($_.name)=$($_.status)" }) -join '; '
switch ($script:finalExit) {
    0 { Write-MaintenanceEvent 1000 'Information' "Devin daily maintenance OK (Devin running: $script:appRunning). Steps: $stepSummary. Health exit: $script:healthExit." }
    2 { Write-MaintenanceEvent 1001 'Warning' "Devin daily maintenance PERFORMED A REPAIR - next Devin launch re-downloads the bundle (~700 MB). Steps: $stepSummary. Report: $ReportDir\latest.json" }
    default { Write-MaintenanceEvent 1002 'Error' "Devin daily maintenance exited with code $script:finalExit. Steps: $stepSummary." }
}
if ($script:finalExit -ne 0) {
    $outcome = if ($script:finalExit -eq 2) { 'repair performed' } else { "failed (exit $script:finalExit)" }
    Send-Toast 'Devin maintenance needs attention' "Daily run $outcome. Details: logs\devin-maintenance\latest.json"
}
Get-ChildItem -LiteralPath $ReportDir -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$ReportRetentionDays) } | ForEach-Object {
        try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop } catch { }
    }
Write-Report
try { Stop-Transcript | Out-Null } catch { }
exit $script:finalExit
