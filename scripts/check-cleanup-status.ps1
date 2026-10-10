<#
.SYNOPSIS
    Read-only Win11 cleanup status assessment: drives, temp, dev caches, browser data, VHDX sizes, Docker usage.
.DESCRIPTION
    Read-only Win11 cleanup status assessment: drives, temp, dev caches, browser data, VHDX sizes, Docker usage.
#>

#requires -Version 5.1
# CATEGORY: cleanup
# Read-only assessment: does Windows 11 need a cleanup?
# Prints sizes of known cleanable locations. Deletes nothing.

function Show-Progress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $Status
}

function Write-VerboseStep {
    param([string]$Message)
    Write-Host "[VERBOSE] $Message" -ForegroundColor Cyan
}

function GB1 { param($b) [math]::Round($b/1GB, 2) }
function MB1 { param($b) [math]::Round($b/1MB, 0) }

# Sum of all files under $Path (0 if missing/unreadable)
function DS {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    $s = (Get-ChildItem $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
          Measure-Object Length -Sum).Sum
    if (-not $s) { $s = 0 }
    return $s
}

function Row {
    param([string]$Label, [string]$Path)
    if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) { Write-Host ("{0,-44} : (not present)" -f $Label) -ForegroundColor DarkGray; return 0 }
    $s = DS $Path
    if ($s -ge 1GB) { Write-Host ("{0,-44} : {1,8} GB" -f $Label, (GB1 $s)) -ForegroundColor $(if ($s -ge 1GB) { 'Yellow' } else { 'Gray' }) }
    else { Write-Host ("{0,-44} : {1,8} MB" -f $Label, (MB1 $s)) -ForegroundColor Gray }
    return $s
}

# Chromium cache subdirs across Default + Profile N
function ChromiumCache {
    param([string]$Root)
    $sum = 0
    if (-not (Test-Path $Root)) { return 0 }
    $profs = @('Default') + @((Get-ChildItem $Root -Directory -Filter 'Profile *' -ErrorAction SilentlyContinue).Name)
    foreach ($pr in $profs) {
        foreach ($sub in 'Cache', 'Code Cache', 'GPUCache') {
            $sum += DS (Join-Path (Join-Path $Root $pr) $sub)
        }
    }
    return $sum
}

$script:cleanable = 0
function AddClean { param($bytes) $script:cleanable += $bytes }

Write-VerboseStep "Starting Win11 Cleanup Assessment"
Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Initializing..." -PercentComplete 0

Write-Host "=== Win11 Cleanup Assessment - $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===" -ForegroundColor Magenta

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking drives..." -PercentComplete 10
Write-VerboseStep "Checking drive space for C:, D:, E:"
Write-Host "`n--- Drives ---" -ForegroundColor Cyan
foreach ($d in Get-PSDrive C, D, E) {
    $pct = if ($d.Used + $d.Free -gt 0) { [math]::Round(100 * $d.Free / ($d.Used + $d.Free), 0) } else { 0 }
    Write-Host ("{0}: free {1,8:N1} GB  ({2}%)  used {3,8:N1} GB" -f $d.Name, ($d.Free/1GB), $pct, ($d.Used/1GB))
}

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking temp & crash data..." -PercentComplete 20
Write-VerboseStep "Scanning user temp, Windows temp, CrashDumps, WER archives"
Write-Host "`n--- Temp & crash data (user-level) ---" -ForegroundColor Cyan
AddClean (Row 'User temp' $env:TEMP)
AddClean (Row 'Windows temp' 'C:\Windows\Temp')
AddClean (Row 'CrashDumps' "$env:LOCALAPPDATA\CrashDumps")
AddClean (Row 'WER archives (user)' "$env:LOCALAPPDATA\Microsoft\Windows\WER")

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking dev caches..." -PercentComplete 30
Write-VerboseStep "Scanning npm, pip, pnpm, Cargo, NuGet, Go, HuggingFace caches"
Write-Host "`n--- Dev caches (user-level) ---" -ForegroundColor Cyan
AddClean (Row 'npm cache' "$env:LOCALAPPDATA\npm-cache")
AddClean (Row 'pip cache' "$env:LOCALAPPDATA\pip\cache")
AddClean (Row 'pnpm store' "$env:LOCALAPPDATA\pnpm\store")
AddClean (Row 'Cargo registry' "$env:USERPROFILE\.cargo\registry")
AddClean (Row 'NuGet packages' "$env:USERPROFILE\.nuget\packages")
AddClean (Row 'Go module cache' "$env:USERPROFILE\go\pkg")
AddClean (Row 'HuggingFace cache' "$env:USERPROFILE\.cache\huggingface")
Row 'Ollama models (report-only, not auto-cleaned)' "$env:USERPROFILE\.ollama\models" | Out-Null

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking browser caches..." -PercentComplete 40
Write-VerboseStep "Scanning Chrome and Edge cache directories"
Write-Host "`n--- Browser caches (Chrome/Edge) ---" -ForegroundColor Cyan
AddClean (Row 'Chrome cache dirs' "$env:LOCALAPPDATA\Google\Chrome\User Data")
# Row above measured whole User Data; use precise cache sums for the verdict
$chromeCache = ChromiumCache "$env:LOCALAPPDATA\Google\Chrome\User Data"
$edgeCache   = ChromiumCache "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
Write-Host ("{0,-44} : {1,8} MB (precise, cleanable subset)" -f 'Chrome cache subset', (MB1 $chromeCache)) -ForegroundColor Gray
Write-Host ("{0,-44} : {1,8} MB (precise, cleanable subset)" -f 'Edge cache subset', (MB1 $edgeCache)) -ForegroundColor Gray
$script:cleanable = $script:cleanable - (DS "$env:LOCALAPPDATA\Google\Chrome\User Data") + $chromeCache

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking VS Code/Electron apps..." -PercentComplete 50
Write-VerboseStep "Scanning VS Code, Discord, Slack, Spotify caches"
Write-Host "`n--- VS Code / Electron ---" -ForegroundColor Cyan
foreach ($pair in @(
    @{ L = 'VS Code stable caches';  P = "$env:APPDATA\Code" },
    @{ L = 'VS Code Insiders caches'; P = "$env:APPDATA\Code - Insiders" }
)) {
    $sum = 0
    if (Test-Path $pair.P) {
        foreach ($sub in 'Cache', 'CachedData', 'Code Cache', 'GPUCache', 'CachedExtensionVSIXs', 'logs', 'workspaceStorage') {
            $sum += DS (Join-Path $pair.P $sub)
        }
    }
    Write-Host ("{0,-44} : {1,8} MB" -f $pair.L, (MB1 $sum)) -ForegroundColor $(if ($sum -ge 100MB) { 'Yellow' } else { 'Gray' })
    AddClean $sum
}
Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking Electron apps..." -PercentComplete 55
Write-VerboseStep "Scanning Discord, Slack, Spotify caches"
foreach ($app in @(
    @{ N = 'Discord'; P = "$env:APPDATA\discord" },
    @{ N = 'Slack';   P = "$env:APPDATA\Slack" },
    @{ N = 'Spotify'; P = "$env:APPDATA\Spotify" }
)) {
    $sum = 0
    if (Test-Path $app.P) {
        foreach ($sub in 'Cache', 'Code Cache', 'GPUCache', 'Storage') { $sum += DS (Join-Path $app.P $sub) }
    }
    if ($sum -gt 0) { Write-Host ("{0,-44} : {1,8} MB" -f $app.N, (MB1 $sum)) -ForegroundColor Gray; AddClean $sum }
}

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking Recycle Bin..." -PercentComplete 60
Write-VerboseStep "Checking Recycle Bin size"
Write-Host "`n--- Recycle bin ---" -ForegroundColor Cyan
$rb = DS 'C:\$Recycle.Bin'
Write-Host ("{0,-44} : {1,8} MB (readable subset)" -f 'C:\$Recycle.Bin', (MB1 $rb)) -ForegroundColor Gray
AddClean $rb

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking system caches..." -PercentComplete 65
Write-VerboseStep "Checking Windows Update and Delivery Optimization caches"
Write-Host "`n--- System caches (best effort without admin) ---" -ForegroundColor Cyan
Row 'Windows Update download cache' 'C:\Windows\SoftwareDistribution\Download' | Out-Null
Row 'Delivery Optimization cache' 'C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache' | Out-Null

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking VHDX disks..." -PercentComplete 70
Write-VerboseStep "Scanning WSL and Docker VHDX files"
Write-Host "`n--- VHDX backing disks ---" -ForegroundColor Cyan
Get-ChildItem "$env:LOCALAPPDATA\wsl", "$env:LOCALAPPDATA\Docker" -Recurse -Filter *.vhdx -Force -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host ("{0,-44} : {1,8} GB" -f $_.FullName.Replace("$env:LOCALAPPDATA", '~AppData\Local'), (GB1 $_.Length)) -ForegroundColor Cyan }

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking big system files..." -PercentComplete 80
Write-VerboseStep "Checking pagefile, hiberfil, swapfile sizes"
Write-Host "`n--- Big system files ---" -ForegroundColor Cyan
foreach ($f in 'pagefile.sys', 'hiberfil.sys', 'swapfile.sys') {
    $p = "C:\$f"
    if (Test-Path $p) { Write-Host ("{0,-44} : {1,8} GB" -f $f, (GB1 (Get-Item $p -Force).Length)) -ForegroundColor DarkGray }
}

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Checking Docker..." -PercentComplete 90
Write-VerboseStep "Querying Docker system disk usage"
Write-Host "`n--- Docker (if running) ---" -ForegroundColor Cyan
try {
    $null = & docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -eq 0) { & docker system df 2>$null } else { Write-Host 'Docker daemon not running - skipped' -ForegroundColor DarkGray }
} catch { Write-Host 'Docker not installed/running - skipped' -ForegroundColor DarkGray }

Show-Progress -Activity "Win11 Cleanup Assessment" -Status "Finalizing verdict..." -PercentComplete 100
Write-VerboseStep "Computing final cleanup verdict"
Write-Host "`n=== Verdict ===" -ForegroundColor Magenta
if ($script:cleanable -ge 5GB) {
    Write-Host ("YES - ~{0:N1} GB cleanable at user level right now." -f ($script:cleanable/1GB)) -ForegroundColor Red
} elseif ($script:cleanable -ge 500MB) {
    Write-Host ("MODERATE - ~{0:N0} MB cleanable at user level right now." -f ($script:cleanable/1MB)) -ForegroundColor Yellow
} else {
    Write-Host ("NO - only ~{0:N0} MB cleanable at user level; system is tidy." -f ($script:cleanable/1MB)) -ForegroundColor Green
}
Write-Host "Run extended-cleanup.ps1 / win11-safe-cleanup.ps1 for user-level, elevated-complete-cleanup.ps1 for admin items." -ForegroundColor Gray
