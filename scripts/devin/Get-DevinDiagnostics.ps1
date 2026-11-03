# Get-DevinDiagnostics.ps1 - read-only deep diagnostics for Devin Desktop's WSL remote
# CATEGORY: maintenance
<#
.SYNOPSIS
    Collects a read-only diagnostic report for Devin Desktop (app, WSL remote, server bundle, logs).

.DESCRIPTION
    Deep-dive companion to Check-DevinHealth.ps1. Gathers app version, WSL state,
    devin-server process and commit, server bundle integrity, superseded commit dirs,
    extension and log counts, host/guest memory, and scans the newest renderer log and
    the current server log for known error signatures (ERR_MODULE_NOT_FOUND, exthost
    crash loops, exited processes). Changes nothing: no files are written or deleted,
    no processes are started or stopped.

.PARAMETER OutFile
    Optional path. When set, the report is also written to this file as JSON
    (in addition to the console output).

.EXAMPLE
    .\Get-DevinDiagnostics.ps1

.EXAMPLE
    .\Get-DevinDiagnostics.ps1 -OutFile "$env:TEMP\devin-diag.json"

.NOTES
    Exit code 0 = report collected; exit 1 = WSL distro unreachable (fix WSL first).
    See memory: devin-desktop-install for the failure modes this covers.
#>
param(
    [string]$OutFile
)

$distro = 'Ubuntu-24.04'

function Invoke-Wsl([string]$cmd) {
    $out = & wsl.exe -d $distro -- bash -c $cmd 2>$null
    $joined = (@($out) -join "`n") -replace "`0", ''
    # wsl.exe can deliver multi-line output as ONE element with embedded
    # newlines; split so callers always get real lines.
    return ($joined -split "`r?`n") | Where-Object { $_ -ne '' }
}

function Add-Finding([string]$level, [string]$message) {
    $script:report.findings += [ordered]@{ level = $level; message = $message }
}

$script:report = [ordered]@{
    generated = (Get-Date).ToString('o')
    distro    = $distro
    app       = [ordered]@{}
    wsl       = [ordered]@{}
    server    = [ordered]@{}
    logs      = [ordered]@{}
    memory    = [ordered]@{}
    findings  = @()
}

Write-Host "=== Devin Diagnostics ($distro, read-only) ===" -ForegroundColor Cyan

# --- App version ---
$appExe = Join-Path $env:LOCALAPPDATA 'Programs\Devin\Devin.exe'
if (Test-Path $appExe) {
    $ver = (Get-Item $appExe).VersionInfo.ProductVersion
    $script:report.app.exePath = $appExe
    $script:report.app.version = $ver
    Write-Host "[ OK ] Devin Desktop app version: $ver" -ForegroundColor Green
} else {
    $script:report.app.version = $null
    Add-Finding 'warn' "Devin.exe not found at $appExe - app may not be installed"
    Write-Host "[WARN] Devin.exe not found at $appExe" -ForegroundColor Yellow
}

# --- WSL reachable ---
$ping = Invoke-Wsl 'echo ok'
if ($ping -notmatch 'ok') {
    Write-Host "[FAIL] WSL distro '$distro' unreachable - the disease is usually the WSL VM, not Devin." -ForegroundColor Red
    Write-Host "       Check WSL FIRST (wsl -d $distro --exec true, Docker VM state, vmmemWSL memory) before touching Devin." -ForegroundColor Red
    $script:report.wsl.reachable = $false
    if ($OutFile) {
        $script:report | ConvertTo-Json -Depth 4 | Set-Content -Path $OutFile -Encoding UTF8
        Write-Host "[ OK ] JSON report written to $OutFile" -ForegroundColor Green
    }
    exit 1
}
$script:report.wsl.reachable = $true
Write-Host "[ OK ] WSL distro reachable" -ForegroundColor Green

# --- WSL uptime ---
try {
    $up = [double](((Invoke-Wsl 'cat /proc/uptime') -split '\s+')[0])
    $script:report.wsl.uptimeSeconds = $up
    Write-Host ("[ OK ] WSL uptime: {0:h\h\ m\m\ s\s}" -f [timespan]::FromSeconds($up)) -ForegroundColor Green
    if ($up -lt 180) { Add-Finding 'warn' "WSL booted $([int]$up)s ago - Devin may race the boot; Reload Window once WSL is up" }
} catch {
    $script:report.wsl.uptimeSeconds = $null
    Add-Finding 'warn' 'could not read WSL uptime'
}

# --- Guest memory ---
$freeH = Invoke-Wsl 'free -h | sed -n 2p'
$script:report.memory.guest = ($freeH -replace '\s+', ' ').Trim()
Write-Host "[ OK ] guest memory: $($script:report.memory.guest)" -ForegroundColor Green

# --- Host memory ---
$os = Get-CimInstance Win32_OperatingSystem
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$script:report.memory.hostFreeGB = $freeGB
Write-Host "[ OK ] host free memory: $freeGB GB" -ForegroundColor Green
if ($freeGB -lt 2) { Add-Finding 'warn' "host memory low: ${freeGB} GB free - starvation can kill devin-server" }

# --- devin-server process + commit ---
$procs = Invoke-Wsl "pgrep -af 'server-mai[n]' || true"
$commit = $null
if ($procs -match '\.devin-server/bin/([a-f0-9]{40})/') {
    $commit = $Matches[1]
    $script:report.server.running = $true
    $script:report.server.commit = $commit
    Write-Host "[ OK ] devin-server running (commit $commit)" -ForegroundColor Green
} else {
    $script:report.server.running = $false
    Add-Finding 'warn' "devin-server not running - if Devin shows 'Cannot reconnect', click Reload Window"
    Write-Host "[WARN] devin-server not running in WSL" -ForegroundColor Yellow
}

# --- Bundle integrity (corrupt-bundle signature: truncated node_modules) ---
$bundleIntact = $null
if ($commit) {
    $base = "`$HOME/.devin-server/bin/$commit/node_modules"
    $check = Invoke-Wsl "test -d $base/minimist -a -d $base/@vscode && echo intact || echo broken"
    $bundleIntact = ($check -match 'intact')
    $script:report.server.bundleIntact = $bundleIntact
    if ($bundleIntact) {
        Write-Host "[ OK ] server bundle intact (minimist + @vscode present)" -ForegroundColor Green
    } else {
        Add-Finding 'fail' "server bundle CORRUPT for commit $commit - run Repair-Devin.ps1 -FixBundle (or Check-DevinHealth.ps1 -Repair), then Reload Window"
        Write-Host "[FAIL] server bundle CORRUPT - classic ERR_MODULE_NOT_FOUND crash loop incoming" -ForegroundColor Red
    }
}

# --- Commit dirs (superseded leftovers) ---
$binDirs = @(Invoke-Wsl "ls -1 `$HOME/.devin-server/bin/ 2>/dev/null || true") | Where-Object { $_ -match '^[a-f0-9]{40}$' }
$script:report.server.commitDirs = $binDirs
Write-Host "[ OK ] commit dirs in bin/: $($binDirs.Count)" -ForegroundColor Green
$superseded = @($binDirs | Where-Object { $_ -ne $commit })
if ($superseded.Count -gt 0) {
    $script:report.server.supersededDirs = $superseded
    Add-Finding 'warn' "superseded commit dirs present (safe to clean with Repair-Devin.ps1 -CleanLeftovers): $($superseded -join ', ')"
    Write-Host "[WARN] superseded commit dirs: $($superseded -join ', ')" -ForegroundColor Yellow
}

# --- Extensions / lock / logs size ---
$extCount = [int](Invoke-Wsl 'ls -1 ~/.devin-server/extensions 2>/dev/null | wc -l')
$script:report.server.extensionEntries = $extCount
Write-Host "[ OK ] extensions dir entries: $extCount" -ForegroundColor Green

$logSize = (Invoke-Wsl 'du -sh ~/.devin-server/data/logs 2>/dev/null | cut -f1').Trim()
$script:report.server.dataLogsSize = $logSize
Write-Host "[ OK ] ~/.devin-server/data/logs size: $logSize" -ForegroundColor Green

# --- Renderer log scan (newest session that actually has logs) ---
$logsRoot = Join-Path $env:APPDATA 'Devin\logs'
$sessionDirs = @(Get-ChildItem $logsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d{8}T\d{6}$' } |
    Sort-Object Name -Descending)
$patterns = @('ERR_MODULE_NOT_FOUND', 'terminated unexpectedly')
$renderer = [ordered]@{ file = $null; session = $null; counts = @{} }
# Window relaunches can leave zero-log "stray" session dirs; they are not a
# diagnostic signal, so scan the newest dir that contains real logs instead.
$strays = 0
$newest = $null
foreach ($dir in $sessionDirs) {
    $hasLogs = @(Get-ChildItem $dir.FullName -Recurse -File -Filter *.log -ErrorAction SilentlyContinue).Count -gt 0
    if ($hasLogs) { $newest = $dir; break }
    $strays++
}
if ($newest) {
    if ($strays -gt 0) {
        Write-Host "[ OK ] skipped $strays empty stray session dir(s) (window-relaunch artifacts)" -ForegroundColor Green
    }
    $renderer.session = $newest.Name
    $rlog = Join-Path $newest.FullName 'window1\renderer.log'
    if (Test-Path $rlog) {
        $renderer.file = $rlog
        foreach ($p in $patterns) {
            $hits = @(Select-String -Path $rlog -Pattern $p -SimpleMatch -ErrorAction SilentlyContinue)
            $renderer.counts[$p] = $hits.Count
            if ($hits.Count -gt 0) {
                Write-Host "[WARN] renderer.log: $p x$($hits.Count); last: $($hits[-1].Line.Trim())" -ForegroundColor Yellow
            }
        }
        if (($renderer.counts.Values | Measure-Object -Sum -ErrorAction SilentlyContinue).Sum -eq 0) {
            Write-Host "[ OK ] renderer.log clean (no known error signatures)" -ForegroundColor Green
        }
    } else {
        Write-Host "[WARN] renderer.log not found in newest session $($newest.Name)" -ForegroundColor Yellow
    }
} elseif ($sessionDirs.Count -gt 0) {
    Write-Host "[WARN] all $($sessionDirs.Count) Devin session dir(s) under $logsRoot are empty (strays)" -ForegroundColor Yellow
} else {
    Write-Host "[WARN] no Devin session log dirs under $logsRoot" -ForegroundColor Yellow
}
$script:report.logs['renderer'] = $renderer

# --- Server log scan (current commit) ---
$serverLog = [ordered]@{ file = $null; counts = @{} }
if ($commit) {
    $slog = Invoke-Wsl "ls ~/.devin-server/.$commit.log 2>/dev/null || true"
    if ($slog -match '\.log') {
        $serverLog.file = "~/.devin-server/.$commit.log"
        foreach ($p in @('ERR_MODULE_NOT_FOUND', 'exited with code')) {
            $esc = $p -replace "'", "''"
            $raw = Invoke-Wsl "grep -c '$esc' ~/.devin-server/.$commit.log 2>/dev/null || true"
            $last = (@($raw -split "`n") | Where-Object { $_ -match '^\d+$' } | Select-Object -Last 1)
            $cnt = if ($last) { [int]$last } else { 0 }
            $serverLog.counts[$p] = $cnt
            if ($cnt -gt 0) {
                Write-Host "[WARN] server log: $p x$cnt" -ForegroundColor Yellow
            }
        }
        if (($serverLog.counts.Values | Measure-Object -Sum).Sum -eq 0) {
            Write-Host "[ OK ] server log clean (no known error signatures)" -ForegroundColor Green
        }
    }
}
$script:report.logs['server'] = $serverLog

# --- Summary ---
if ($script:report.findings.Count -eq 0) {
    Write-Host "=== DIAGNOSTICS COMPLETE - NO FINDINGS ===" -ForegroundColor Cyan
} else {
    Write-Host "=== DIAGNOSTICS COMPLETE - $($script:report.findings.Count) finding(s) ===" -ForegroundColor Cyan
    foreach ($f in $script:report.findings) {
        $color = if ($f.level -eq 'fail') { 'Red' } else { 'Yellow' }
        Write-Host "[$($f.level.ToUpper())] $($f.message)" -ForegroundColor $color
    }
}

if ($OutFile) {
    $script:report | ConvertTo-Json -Depth 4 | Set-Content -Path $OutFile -Encoding UTF8
    Write-Host "[ OK ] JSON report written to $OutFile" -ForegroundColor Green
}

exit 0
