<#
.SYNOPSIS
    Windows 11 safe cleanup for DevOptimizer (non-admin scope)
.DESCRIPTION
    Cleans user-level temp/caches, dev package-manager caches, Docker build
    cache and dangling images. Does NOT touch containers (running or stopped),
    volumes, models, or user data. Admin-only items are reported at the end.
#>

# Progress and verbose helpers
function Show-Progress {
    param([string]$Activity, [string]$Status, [int]$PercentComplete)
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Write-VerboseStep {
    param([string]$Message)
    Write-Host "  → $Message" -ForegroundColor DarkGray
}

$before = (Get-PSDrive C).Free
function MB { param($b) [math]::Round($b/1MB, 1) }

Show-Progress -Activity "Windows 11 Safe Cleanup" -Status "Initializing..." -PercentComplete 0
Write-VerboseStep "Starting Windows 11 Safe Cleanup"
Write-Host "=== Windows 11 Safe Cleanup ===" -ForegroundColor Magenta
Write-Host ("C: free before: {0:N2} GB`n" -f ($before/1GB))

Show-Progress -Activity "Windows 11 Safe Cleanup" -Status "Cleaning user temp..." -PercentComplete 10
Write-VerboseStep "Cleaning user temp files (skip locked/in-use)"
# 1. User temp files (skip files locked/in use)
$size = (Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("[1] User temp cleaned          : -{0} MB" -f (MB $size)) -ForegroundColor Green

Show-Progress -Activity "Windows 11 Safe Cleanup" -Status "Cleaning Windows temp..." -PercentComplete 20
Write-VerboseStep "Cleaning Windows temp (best effort without admin)"
# 2. Windows temp (best effort without admin)
$size = (Get-ChildItem 'C:\Windows\Temp' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Get-ChildItem 'C:\Windows\Temp' -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("[2] Windows temp (best effort) : -{0} MB (locked/admin files skipped)" -f (MB $size)) -ForegroundColor Green

Show-Progress -Activity "Windows 11 Safe Cleanup" -Status "Cleaning dev package-manager caches..." -PercentComplete 30
Write-VerboseStep "Cleaning dev package-manager caches (npm, pip, pnpm, yarn)"
# 3. Dev package-manager caches (safe to delete; re-downloaded on demand)
$targets = @(
    @{ Name = 'npm cache';      Cmd = { npm cache clean --force 2>$null } },
    @{ Name = 'pip cache';      Cmd = { pip cache purge 2>$null } },
    @{ Name = 'pnpm store';     Cmd = { pnpm store prune 2>$null } },
    @{ Name = 'yarn cache';     Cmd = { yarn cache clean 2>$null } }
)
foreach ($t in $targets) {
    try { & $t.Cmd | Out-Null; Write-Host ("[3] {0,-22} : cleaned" -f $t.Name) -ForegroundColor Green }
    catch { Write-Host ("[3] {0,-22} : skipped ({1})" -f $t.Name, $_.Exception.Message.Split("`n")[0]) -ForegroundColor DarkGray }
}

# 3b. Language package caches (NuGet, pip file cache, npm file cache)
Write-VerboseStep "Cleaning language package file caches (NuGet, pip, npm)"
$cacheTargets = @(
    @{ Name = 'NuGet v3-cache'; Path = "$env:LOCALAPPDATA\NuGet\v3-cache" },
    @{ Name = 'NuGet packages'; Path = "$env:USERPROFILE\.nuget\packages" },
    @{ Name = 'pip cache dir';  Path = "$env:LOCALAPPDATA\pip\cache" },
    @{ Name = 'pip cache alt';  Path = "$env:USERPROFILE\.cache\pip" },
    @{ Name = 'npm cache dir';  Path = "$env:LOCALAPPDATA\npm-cache" }
)
foreach ($t in $cacheTargets) {
    if (Test-Path $t.Path) {
        $size = (Get-ChildItem $t.Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Get-ChildItem $t.Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ("[3b] {0,-22}: -{1} MB" -f $t.Name, (MB $size)) -ForegroundColor Green
    } else {
        Write-Host ("[3b] {0,-22}: not found" -f $t.Name) -ForegroundColor DarkGray
    }
}

Show-Progress -Activity "Windows 11 Safe Cleanup" -Status "Cleaning PowerShell/IE cache and CrashDumps..." -PercentComplete 40
Write-VerboseStep "Cleaning PowerShell/IE cache crumbs and error dumps"
# 4. PowerShell module cache crumbs + error dumps
foreach ($dir in @("$env:LOCALAPPDATA\Microsoft\Windows\INetCache\IE", "$env:LOCALAPPDATA\CrashDumps")) {
    if (Test-Path $dir) {
        $size = (Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Get-ChildItem $dir -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ("[4] {0,-30}: -{1} MB" -f (Split-Path $dir -Leaf), (MB $size)) -ForegroundColor Green
    }
}

Show-Progress -Activity "Windows 11 Safe Cleanup" -Status "Emptying Recycle Bin..." -PercentComplete 50
Write-VerboseStep "Emptying Recycle Bin"
# 5. Recycle bin
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Host '[5] Recycle bin emptied' -ForegroundColor Green
} catch { Write-Host "[5] Recycle bin: skipped ($($_.Exception.Message))" -ForegroundColor DarkGray }

Show-Progress -Activity "Windows 11 Safe Cleanup" -Status "Cleaning Docker build cache and dangling images..." -PercentComplete 60
Write-VerboseStep "Cleaning Docker build cache and dangling images (safe subset)"
# 6. Docker: build cache + dangling images ONLY (containers, volumes, named images untouched)
Write-Host "`n--- Docker (safe subset) ---" -ForegroundColor Cyan
$beforeDocker = (docker system df --format '{{.Type}} {{.Size}}' 2>$null) -join '; '
Write-Host "Before: $beforeDocker"
docker builder prune -f 2>&1 | Select-Object -Last 1 | ForEach-Object { Write-Host "[6] Build cache : $_" -ForegroundColor Green }
docker image prune -f 2>&1 | Select-Object -Last 1 | ForEach-Object { Write-Host "[6] Dangling img: $_" -ForegroundColor Green }
Write-Host "Containers/volumes/named images: untouched" -ForegroundColor DarkGray

Show-Progress -Activity "Windows 11 Safe Cleanup" -Status "Finalizing..." -PercentComplete 90
Write-VerboseStep "Computing cleanup summary"
# --- Summary ---
$after = (Get-PSDrive C).Free
Write-Host "`n=== Summary ===" -ForegroundColor Magenta
Write-Host ("C: free after : {0:N2} GB" -f ($after/1GB))
Write-Host ("Freed on C:   : {0:N2} MB" -f (MB ($after - $before)))

Show-Progress -Activity "Windows 11 Safe Cleanup" -Status "Complete" -PercentComplete 100
Write-VerboseStep "Safe cleanup complete"

# --- Admin-required items (report only) ---
Write-Host "`nRequires Administrator (run DevOptimizer cleanup elevated for these):" -ForegroundColor Yellow
Write-Host '  - DISM component store cleanup : Dism /Online /Cleanup-Image /StartComponentCleanup'
Write-Host '  - Windows Update download cache: Stop wuauserv, clear C:\Windows\SoftwareDistribution\Download'
Write-Host '  - Delivery Optimization cache  : Delete-DeliveryOptimizationCache (elevated PowerShell)'
Write-Host '  - System restore points / shadow copies: vssadmin delete shadows /for=c: /oldest'
