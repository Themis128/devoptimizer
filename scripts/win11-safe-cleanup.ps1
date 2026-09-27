<#
.SYNOPSIS
    Windows 11 safe cleanup for DevOptimizer (non-admin scope)
.DESCRIPTION
    Cleans user-level temp/caches, dev package-manager caches, Docker build
    cache and dangling images. Does NOT touch containers (running or stopped),
    volumes, models, or user data. Admin-only items are reported at the end.
#>

$before = (Get-PSDrive C).Free
function MB { param($b) [math]::Round($b/1MB, 1) }

Write-Host "=== Windows 11 Safe Cleanup ===" -ForegroundColor Magenta
Write-Host ("C: free before: {0:N2} GB`n" -f ($before/1GB))

# 1. User temp files (skip files locked/in use)
$size = (Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("[1] User temp cleaned          : -{0} MB" -f (MB $size)) -ForegroundColor Green

# 2. Windows temp (best effort without admin)
$size = (Get-ChildItem 'C:\Windows\Temp' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Get-ChildItem 'C:\Windows\Temp' -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("[2] Windows temp (best effort) : -{0} MB (locked/admin files skipped)" -f (MB $size)) -ForegroundColor Green

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

# 4. PowerShell module cache crumbs + error dumps
foreach ($dir in @("$env:LOCALAPPDATA\Microsoft\Windows\INetCache\IE", "$env:LOCALAPPDATA\CrashDumps")) {
    if (Test-Path $dir) {
        $size = (Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Get-ChildItem $dir -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ("[4] {0,-30}: -{1} MB" -f (Split-Path $dir -Leaf), (MB $size)) -ForegroundColor Green
    }
}

# 5. Recycle bin
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Host '[5] Recycle bin emptied' -ForegroundColor Green
} catch { Write-Host "[5] Recycle bin: skipped ($($_.Exception.Message))" -ForegroundColor DarkGray }

# 6. Docker: build cache + dangling images ONLY (containers, volumes, named images untouched)
Write-Host "`n--- Docker (safe subset) ---" -ForegroundColor Cyan
$beforeDocker = (docker system df --format '{{.Type}} {{.Size}}' 2>$null) -join '; '
Write-Host "Before: $beforeDocker"
docker builder prune -f 2>&1 | Select-Object -Last 1 | ForEach-Object { Write-Host "[6] Build cache : $_" -ForegroundColor Green }
docker image prune -f 2>&1 | Select-Object -Last 1 | ForEach-Object { Write-Host "[6] Dangling img: $_" -ForegroundColor Green }
Write-Host "Containers/volumes/named images: untouched" -ForegroundColor DarkGray

# --- Summary ---
$after = (Get-PSDrive C).Free
Write-Host "`n=== Summary ===" -ForegroundColor Magenta
Write-Host ("C: free after : {0:N2} GB" -f ($after/1GB))
Write-Host ("Freed on C:   : {0:N2} MB" -f (MB ($after - $before)))

# --- Admin-required items (report only) ---
Write-Host "`nRequires Administrator (run DevOptimizer cleanup elevated for these):" -ForegroundColor Yellow
Write-Host '  - DISM component store cleanup : Dism /Online /Cleanup-Image /StartComponentCleanup'
Write-Host '  - Windows Update download cache: Stop wuauserv, clear C:\Windows\SoftwareDistribution\Download'
Write-Host '  - Delivery Optimization cache  : Delete-DeliveryOptimizationCache (elevated PowerShell)'
Write-Host '  - System restore points / shadow copies: vssadmin delete shadows /for=c: /oldest'
