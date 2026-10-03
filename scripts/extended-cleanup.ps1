<#
.SYNOPSIS
    Extended cleanup (weekly): deeper user-level sweeps beyond the daily safe cleanup.
.DESCRIPTION
    Extended cleanup (weekly): deeper user-level sweeps beyond the daily safe cleanup.
#>

#requires -Version 5.1
# CATEGORY: cleanup
# Extended Windows 11 cleanup - user-level, age-gated.
# Complements win11-safe-cleanup.ps1 (temp/dev caches/Docker) and
# elevated-complete-cleanup.ps1 (DISM/WU/DO/restore points/VHDX).
# Covers: GPU shader caches, HuggingFace model blobs, browser caches,
# VS Code stable caches, Electron app caches, user-side WER archives,
# and rotation of DevOptimizer's own logs.
# Locked files are skipped. Ollama models and everything on D: outside
# logs\ are never touched.

param(
    [int]$ShaderDays   = 30,   # GPU shader caches (regenerated on demand)
    [int]$ModelDays    = 60,   # HuggingFace blobs (re-downloaded on demand)
    [int]$BrowserDays  = 7,
    [int]$CodeDays     = 30,
    [int]$ElectronDays = 14,
    [int]$WerDays      = 30,
    [int]$LogDays      = 30,   # DevOptimizer's own logs (moved to archive\)
    [int]$ArchiveDays  = 180,  # archived logs are deleted after this
    [switch]$DryRun
)

# ─── Color helpers ──────────────────────────────────────────────
function Write-Header { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Magenta }
function Write-Step   { param($msg) Write-Host "> $msg" -ForegroundColor Cyan }
function Write-Done   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn   { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Info   { param($msg) Write-Host "  [INFO] $msg" -ForegroundColor Gray }
function MB { param($b) [math]::Round($b/1MB, 1) }
function GB { param($b) [math]::Round($b/1GB, 2) }

$script:totalFreed = 0
$before = (Get-PSDrive C).Free
Write-Host "=== Extended Win11 Cleanup$(if ($DryRun) { ' (DRY RUN)' }) ===" -ForegroundColor Magenta
Write-Host ("C: free before: {0:N2} GB`n" -f ($before/1GB))

# Start a transcript so scheduled runs leave a per-run log (rotated below)
$logDir = 'D:\DevOptimizer\logs'
if (Test-Path $logDir) {
    try { Start-Transcript -Path (Join-Path $logDir ("extended-cleanup-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))) -ErrorAction Stop | Out-Null } catch { }
}

# ─── Prune helpers ──────────────────────────────────────────────
# Delete files under $Path older than $Days; returns bytes freed.
function Prune-Files {
    param([string]$Path, [int]$Days)
    if (-not (Test-Path $Path)) { return 0 }
    $cutoff = (Get-Date).AddDays(-$Days)
    $old = Get-ChildItem $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
           Where-Object { $_.LastWriteTime -lt $cutoff }
    $size = ($old | Measure-Object Length -Sum).Sum
    if (-not $size) { $size = 0 }
    if (-not $DryRun -and $old) { $old | Remove-Item -Force -ErrorAction SilentlyContinue }
    return $size
}

function Test-ProcRunning { param([string[]]$Names)
    [bool](Get-Process -Name $Names -ErrorAction SilentlyContinue)
}

# Chromium-family cache dirs for Default + Profile N
function Get-ChromiumCacheDirs {
    param([string]$UserDataRoot)
    $dirs = @()
    $profiles = @('Default') + @((Get-ChildItem $UserDataRoot -Directory -Filter 'Profile *' -ErrorAction SilentlyContinue).Name)
    foreach ($profile in $profiles) {
        foreach ($sub in 'Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage', 'Service Worker\ScriptCache') {
            $p = Join-Path (Join-Path $UserDataRoot $profile) $sub
            if (Test-Path $p) { $dirs += $p }
        }
    }
    return $dirs
}

# ─── [1] GPU shader caches ──────────────────────────────────────
Write-Header '[1] GPU shader caches'
foreach ($dir in @(
    "$env:LOCALAPPDATA\NVIDIA\DXCache",
    "$env:LOCALAPPDATA\NVIDIA\GLCache",
    "$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache",
    "$env:LOCALAPPDATA\D3DSCache"
)) {
    $size = Prune-Files -Path $dir -Days $ShaderDays
    $script:totalFreed += $size
    Write-Done ("{0,-40}: -{1} MB" -f (Split-Path $dir -Leaf), (MB $size))
}

# ─── [2] HuggingFace model blobs (Ollama models: report only) ───
Write-Header '[2] AI model caches'
$hf = "$env:USERPROFILE\.cache\huggingface"
$size = Prune-Files -Path $hf -Days $ModelDays
$script:totalFreed += $size
Write-Done ("HuggingFace blobs >{0}d            : -{1} MB" -f $ModelDays, (MB $size))
$ollama = "$env:USERPROFILE\.ollama\models"
if (Test-Path $ollama) {
    $sz = (Get-ChildItem $ollama -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Info ("Ollama models: {0} GB - NOT touched (delete manually via 'ollama rm')" -f (GB $sz))
}

# ─── [3] Browser caches (skip if browser is running) ────────────
Write-Header '[3] Browser caches'
$browserRoots = @(
    @{ Name = 'Chrome'; Root = "$env:LOCALAPPDATA\Google\Chrome\User Data";  Proc = @('chrome') },
    @{ Name = 'Edge';   Root = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"; Proc = @('msedge') }
)
foreach ($b in $browserRoots) {
    if (-not (Test-Path $b.Root)) { continue }
    if (Test-ProcRunning -Names $b.Proc) {
        Write-Warn "$($b.Name): running - skipped"
        continue
    }
    $bFreed = 0
    foreach ($dir in (Get-ChromiumCacheDirs -UserDataRoot $b.Root)) {
        $bFreed += Prune-Files -Path $dir -Days $BrowserDays
    }
    $script:totalFreed += $bFreed
    Write-Done ("{0,-40}: -{1} MB" -f $b.Name, (MB $bFreed))
}

# ─── [4] VS Code stable caches (skip if running) ────────────────
Write-Header '[4] VS Code caches'
$codeRoot = "$env:APPDATA\Code"
if (Test-Path $codeRoot) {
    if (Test-ProcRunning -Names @('Code')) {
        Write-Warn 'VS Code: running - skipped'
    } else {
        $cFreed = 0
        foreach ($dir in @('Cache', 'CachedData', 'Code Cache', 'GPUCache', 'CachedExtensionVSIXs', 'logs')) {
            $cFreed += Prune-Files -Path (Join-Path $codeRoot $dir) -Days $CodeDays
        }
        # workspaceStorage: drop whole subdirs not touched in $CodeDays
        $wsRoot = Join-Path $codeRoot 'workspaceStorage'
        if (Test-Path $wsRoot) {
            $cutoff = (Get-Date).AddDays(-$CodeDays)
            $stale = Get-ChildItem $wsRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff }
            $sz = ($stale | Get-ChildItem -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            if (-not $sz) { $sz = 0 }
            if (-not $DryRun -and $stale) { $stale | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
            $cFreed += $sz
        }
        $script:totalFreed += $cFreed
        Write-Done ("VS Code (>{0}d, incl. workspaceStorage) : -{1} MB" -f $CodeDays, (MB $cFreed))
    }
} else { Write-Info 'VS Code not installed - skipped' }

# ─── [5] Electron app caches ────────────────────────────────────
Write-Header '[5] Electron app caches'
$electronApps = @(
    @{ Name = 'Discord'; Root = "$env:APPDATA\discord" },
    @{ Name = 'Slack';   Root = "$env:APPDATA\Slack" },
    @{ Name = 'Spotify'; Root = "$env:APPDATA\Spotify"; Extra = @('Storage') }
)
foreach ($app in $electronApps) {
    if (-not (Test-Path $app.Root)) { continue }
    $aFreed = 0
    $subs = @('Cache', 'Code Cache', 'GPUCache') + @($app.Extra | Where-Object { $_ })
    foreach ($sub in $subs) {
        $aFreed += Prune-Files -Path (Join-Path $app.Root $sub) -Days $ElectronDays
    }
    $script:totalFreed += $aFreed
    Write-Done ("{0,-40}: -{1} MB" -f $app.Name, (MB $aFreed))
}

# ─── [6] User-side WER archives ─────────────────────────────────
Write-Header '[6] WER archives (user)'
$wFreed = 0
foreach ($dir in @(
    "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
    "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue"
)) {
    $wFreed += Prune-Files -Path $dir -Days $WerDays
}
$script:totalFreed += $wFreed
Write-Done ("WER reports >{0}d                     : -{1} MB" -f $WerDays, (MB $wFreed))

# ─── [7] DevOptimizer log rotation ──────────────────────────────
Write-Header '[7] DevOptimizer log rotation'
if (Test-Path $logDir) {
    $archive = Join-Path $logDir 'archive'
    if (-not (Test-Path $archive)) { New-Item -ItemType Directory -Path $archive -Force | Out-Null }
    $cutoff = (Get-Date).AddDays(-$LogDays)
    $staleLogs = Get-ChildItem $logDir -Recurse -Force -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -notlike "$archive*" -and $_.LastWriteTime -lt $cutoff }
    $lFreed = ($staleLogs | Measure-Object Length -Sum).Sum
    if (-not $lFreed) { $lFreed = 0 }
    if (-not $DryRun -and $staleLogs) {
        $staleLogs | Move-Item -Destination $archive -Force -ErrorAction SilentlyContinue
    }
    Write-Done ("Logs >{0}d moved to archive\          : {1} file(s), {2} MB" -f $LogDays, $staleLogs.Count, (MB $lFreed))
    # purge old archive
    $aCutoff = (Get-Date).AddDays(-$ArchiveDays)
    $dead = Get-ChildItem $archive -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $aCutoff }
    $aSz = ($dead | Measure-Object Length -Sum).Sum; if (-not $aSz) { $aSz = 0 }
    if (-not $DryRun -and $dead) { $dead | Remove-Item -Force -ErrorAction SilentlyContinue }
    Write-Done ("Archive >{0}d purged                  : -{1} MB" -f $ArchiveDays, (MB $aSz))
    $script:totalFreed += $lFreed + $aSz
} else { Write-Info "$logDir not found - skipped" }

# ─── Summary ────────────────────────────────────────────────────
if (-not $DryRun) { try { Stop-Transcript | Out-Null } catch { } }
$after = (Get-PSDrive C).Free
Write-Header 'Summary'
Write-Host ("C: free after : {0:N2} GB" -f ($after/1GB))
Write-Host ("Freed (files) : {0:N1} MB" -f (MB $script:totalFreed))
if ($DryRun) { Write-Warn 'DRY RUN - nothing was deleted' }
