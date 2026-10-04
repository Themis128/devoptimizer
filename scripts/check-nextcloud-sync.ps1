<#
.SYNOPSIS
    NextCloud sync health check -- read-only status of the desktop client and its sync root.

.DESCRIPTION
    One-shot health view of the NextCloud desktop client on this host (pair with
    fine-tune-nextcloud.ps1, which applies tunings; this one only observes):
      1. Client version, running state, server URL, sync folder, VFS mode
      2. Sync journal size (db + wal) -- trend indicator for tree growth
      3. Recent client logs: decompress newest .gz/.log and count ERROR/WARNING lines
      4. Bounded conflict-file audit over the sync root (time-capped, safe on huge trees)
      5. Defender exclusion presence (best effort) and cldflt driver state
      6. Latest client release from GitHub API (graceful fallback when offline)
    Safe to run any time; makes no changes by default. Fully non-elevated.

.PARAMETER BackupConfig
    Additionally back up the client configuration (%APPDATA%\NextCloud minus rotating
    logs) to backups\nextcloud-config\<timestamp> under the DevOptimizer root, keeping
    the newest 5 backups. Enables full account/sync-state restore after a reinstall
    without re-downloading the whole tree.

.PARAMETER KeepBackups
    Number of config backups to retain. Default: 5.

.EXAMPLE
    .\check-nextcloud-sync.ps1
    .\check-nextcloud-sync.ps1 -BackupConfig
#>
[CmdletBinding()]
param(
    [switch]$BackupConfig,
    [int]$KeepBackups = 5
)

$ErrorActionPreference = 'SilentlyContinue'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$root = 'D:\DevOptimizer'
Write-Host "=== NextCloud Sync Health -- $stamp ==="

# --- 1. Client, server, sync folder ------------------------------------------
$clientExe = Join-Path $env:ProgramFiles 'Nextcloud\nextcloud.exe'
$cfgPath = Join-Path $env:APPDATA 'NextCloud\nextcloud.cfg'
$ver = if (Test-Path $clientExe) { (Get-Item $clientExe).VersionInfo.FileVersion } else { 'NOT FOUND' }
$proc = Get-Process nextcloud -ErrorAction SilentlyContinue | Select-Object -First 1
Write-Host ("[1] Client          : v{0} ({1})" -f $ver, $(if ($proc) { "running pid $($proc.Id)" } else { 'not running' }))
$serverUrl = $null; $syncRoot = $null; $vfsMode = $null
if (Test-Path $cfgPath) {
    $cfg = Get-Content $cfgPath
    $serverUrl = ($cfg | Where-Object { $_ -match '0\\url=' }) -replace '^.*?0\\url=', '' | Select-Object -First 1
    $syncRoot = ($cfg | Where-Object { $_ -match 'localPath=' }) -replace '^.*?localPath=', '' | Select-Object -First 1
    $vfsMode = ($cfg | Where-Object { $_ -match 'virtualFilesMode=' }) -replace '^.*?virtualFilesMode=', '' | Select-Object -First 1
    Write-Host ("    Server          : {0}" -f $serverUrl)
    Write-Host ("    Sync folder     : {0} (vfs mode: {1})" -f $syncRoot, $vfsMode)
} else {
    Write-Host "    Config          : nextcloud.cfg not found"
}
if (-not $syncRoot) { $syncRoot = Join-Path $env:USERPROFILE 'Nextcloud' }
$syncRoot = $syncRoot.TrimEnd('/')

# --- 2. Journal size -----------------------------------------------------------
$jdb = Get-ChildItem $syncRoot -Force -File -Filter '.sync_*.db' | Select-Object -First 1
if ($jdb) {
    $wal = Get-Item ($jdb.FullName + '-wal') -ErrorAction SilentlyContinue
    Write-Host ("[2] Journal         : {0} MB db + {1} MB wal (large = large tree; trend across runs)" -f ([math]::Round($jdb.Length/1MB,2)), ([math]::Round($wal.Length/1MB,2)))
} else {
    Write-Host "[2] Journal         : not found"
}

# --- 3. Recent client logs (gunzip newest, count errors/warnings) ---------------
$logDir = Join-Path $env:APPDATA 'NextCloud\logs'
$errTotal = 0; $warnTotal = 0; $scanned = 0
if (Test-Path $logDir) {
    $logs = Get-ChildItem $logDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    foreach ($l in $logs) {
        $text = $null
        try {
            if ($l.Name -match '\.gz$') {
                $fs = [IO.File]::OpenRead($l.FullName)
                $gz = New-Object IO.Compression.GzipStream($fs, [IO.Compression.CompressionMode]::Decompress)
                $sr = New-Object IO.StreamReader($gz)
                $text = $sr.ReadToEnd()
                $sr.Close(); $gz.Close(); $fs.Close()
            } else { $text = Get-Content $l.FullName -Raw }
        } catch { $text = $null }
        if ($text) {
            $scanned++
            $errTotal += ([regex]::Matches($text, '\] \[error\]')).Count
            $warnTotal += ([regex]::Matches($text, '\] \[warning\]')).Count
        }
    }
}
Write-Host ("[3] Client logs     : scanned {0} recent file(s) -> {1} error, {2} warning lines" -f $scanned, $errTotal, $warnTotal)
if ($errTotal -gt 0) { Write-Host "    (run 'nextcloud --logwindow' or check the log dir for details)" }

# --- 4. Bounded conflict-file audit --------------------------------------------
$conflicts = 0; $scannedFiles = 0; $truncated = $false
if (Test-Path $syncRoot) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $di = New-Object IO.DirectoryInfo($syncRoot)
        foreach ($f in $di.EnumerateFiles('*', [IO.SearchOption]::AllDirectories)) {
            $scannedFiles++
            if ($f.Name -match '\(conflicted copy|_conflict-') { $conflicts++ }
            if ($sw.ElapsedMilliseconds -gt 20000 -or $scannedFiles -ge 50000) { $truncated = $true; break }
        }
    } catch { }
    $capNote = if ($truncated) { 'CAPPED (20 s / 50k files) - counts are lower bounds' } else { 'full tree scanned' }
    Write-Host ("[4] Conflict audit  : {0} conflicted files among {1} scanned ({2})" -f $conflicts, $scannedFiles, $capNote)
} else {
    Write-Host "[4] Conflict audit  : sync root missing"
}

# --- 5. Defender exclusions + cldflt --------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    $mp = Get-MpPreference -ErrorAction SilentlyContinue
    $hasRoot = ($mp.ExclusionPath -contains $syncRoot)
    $hasProc = ($mp.ExclusionProcess -contains 'nextcloud.exe')
    Write-Host ("[5] Defender        : sync-root exclusion={0}; process exclusion={1}" -f $(if ($hasRoot) { 'present' } else { 'MISSING' }), $(if ($hasProc) { 'present' } else { 'MISSING' }))
} else {
    Write-Host "[5] Defender        : exclusion state needs elevation (see fine-tune-nextcloud -ApplySafeTuning)"
}
$cldflt = Get-Service cldflt -ErrorAction SilentlyContinue
if ($cldflt) { Write-Host ("    cldflt driver   : {0} / {1}" -f $cldflt.Status, $cldflt.StartType) }

# --- 6. Latest release check (graceful offline fallback) -------------------------
try {
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/nextcloud/desktop/releases/latest' -TimeoutSec 5 -ErrorAction Stop
    $latest = $rel.tag_name -replace '^[vV]', ''
    $mine = ($ver -split ' ')[0]
    Write-Host ("[6] Version check   : installed {0} vs latest tag {1} ({2})" -f $mine, $latest, $(if ($mine -ge $latest) { 'current' } else { 'UPDATE AVAILABLE' }))
} catch {
    Write-Host "[6] Version check   : offline or API unreachable (check github.com/nextcloud/desktop/releases)"
}

# --- 7. Optional config backup ----------------------------------------------------
if ($BackupConfig) {
    $src = Join-Path $env:APPDATA 'NextCloud'
    $destRoot = Join-Path $root 'backups\nextcloud-config'
    $dest = Join-Path $destRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
    if (Test-Path $src) {
        New-Item $dest -ItemType Directory -Force | Out-Null
        Copy-Item "$src\*" $dest -Recurse -Force -Exclude '*.log.*', '*.log'
        Remove-Item (Join-Path $dest 'logs') -Recurse -Force -ErrorAction SilentlyContinue
        $mb = (Get-ChildItem $dest -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
        $size = if ($mb -lt 1) { '{0:N0} KB' -f ($mb * 1024) } else { '{0:N1} MB' -f $mb }
        Write-Host ("[7] Config backup   : {0} -> {1}" -f $dest, $size)
        $old = Get-ChildItem $destRoot -Directory | Sort-Object Name -Descending | Select-Object -Skip $KeepBackups
        if ($old) { $old | Remove-Item -Recurse -Force; Write-Host ("    retention       : pruned {0} older backup(s), kept {1}" -f ($old | Measure-Object).Count, $KeepBackups) }
    } else {
        Write-Host "[7] Config backup   : source missing"
    }
}

# --- Summary ------------------------------------------------------------------------
$issues = @()
if (-not $proc) { $issues += 'client not running' }
if ($errTotal -gt 5) { $issues += "$errTotal error lines in recent logs" }
if ($conflicts -gt 0) { $issues += "$conflicts conflicted file names" }
if ($ver -eq 'NOT FOUND') { $issues += 'client not installed' }
Write-Host ("`n=== Verdict: " + $(if ($issues.Count) { "ATTENTION - " + ($issues -join '; ') } else { 'HEALTHY - no action needed' }) + " ===")
