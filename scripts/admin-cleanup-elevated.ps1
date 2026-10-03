<#
.SYNOPSIS
    Admin cleanup suite run elevated: DISM, update caches, shadow-copy pruning.
.DESCRIPTION
    Admin cleanup suite run elevated: DISM, update caches, shadow-copy pruning.
#>

# Windows 11 Admin Cleanup - Run Elevated
$ErrorActionPreference = 'Continue'

function MB { param($b) [math]::Round($b/1MB, 1) }
function GB { param($b) [math]::Round($b/1GB, 2) }

$before = (Get-PSDrive C).Free
Write-Host "=== Windows 11 Admin Cleanup ===" -ForegroundColor Magenta
Write-Host ("C: free before: {0:N2} GB`n" -f ($before/1GB))

# 1. DISM Component Store Cleanup
Write-Host "--- [1] DISM Component Store Cleanup ---" -ForegroundColor Cyan
Write-Host "Running: Dism /Online /Cleanup-Image /StartComponentCleanup"
Write-Host "This may take several minutes..." -ForegroundColor Yellow
$dismResult = Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart 2>&1
$dismResult | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -eq 0) {
    Write-Host "[1] DISM component cleanup: COMPLETED" -ForegroundColor Green
} else {
    Write-Host "[1] DISM component cleanup: EXIT CODE $LASTEXITCODE" -ForegroundColor Red
}

# 2. Windows Update Download Cache
Write-Host "`n--- [2] Windows Update Download Cache ---" -ForegroundColor Cyan
$wuPath = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wuPath) {
    $size = (Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Host "Stopping wuauserv service..."
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    Write-Host "Clearing $wuPath ($([math]::Round($size/1GB,2)) GB)..."
    Get-ChildItem $wuPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Restarting wuauserv service..."
    Start-Service wuauserv -ErrorAction SilentlyContinue
    Write-Host ("[2] Windows Update cache cleaned: -{0} GB" -f (GB $size)) -ForegroundColor Green
} else {
    Write-Host "[2] Windows Update cache: path not found" -ForegroundColor DarkGray
}

# 3. Delivery Optimization Cache
Write-Host "`n--- [3] Delivery Optimization Cache ---" -ForegroundColor Cyan
try {
    Write-Host "Running: Delete-DeliveryOptimizationCache"
    Delete-DeliveryOptimizationCache -ErrorAction Stop
    Write-Host "[3] Delivery Optimization cache: CLEARED" -ForegroundColor Green
} catch {
    Write-Host "[3] Delivery Optimization cache: SKIPPED ($($_.Exception.Message.Split("`n")[0]))" -ForegroundColor DarkGray
}

# 4. System Restore Points / Shadow Copies
Write-Host "`n--- [4] System Restore Points (oldest only) ---" -ForegroundColor Cyan
Write-Host "Running: vssadmin delete shadows /for=c: /oldest"
$vssResult = vssadmin delete shadows /for=c: /oldest 2>&1
$vssResult | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -eq 0) {
    Write-Host "[4] Oldest shadow copy: DELETED" -ForegroundColor Green
} else {
    Write-Host "[4] Shadow copy: EXIT CODE $LASTEXITCODE (may be none to delete)" -ForegroundColor DarkGray
}

# 5. Windows.old if exists
Write-Host "`n--- [5] Windows.old folder (if present) ---" -ForegroundColor Cyan
$winOld = "C:\Windows.old"
if (Test-Path $winOld) {
    $size = (Get-ChildItem $winOld -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Host "Found Windows.old ($([math]::Round($size/1GB,2)) GB) - removing..."
    takeown /f "$winOld" /r /d y 2>&1 | Out-Null
    icacls "$winOld" /grant administrators:F /t /c /q 2>&1 | Out-Null
    Remove-Item $winOld -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ("[5] Windows.old removed: -{0} GB" -f (GB $size)) -ForegroundColor Green
} else {
    Write-Host "[5] Windows.old: not found" -ForegroundColor DarkGray
}

# Summary
$after = (Get-PSDrive C).Free
Write-Host "`n=== Summary ===" -ForegroundColor Magenta
Write-Host ("C: free before: {0:N2} GB" -f ($before/1GB))
Write-Host ("C: free after : {0:N2} GB" -f ($after/1GB))
Write-Host ("Freed on C:   : {0:N2} GB" -f (($after - $before)/1GB))
Write-Host "`nDone. A reboot is recommended after DISM operations." -ForegroundColor Yellow
Read-Host "Press Enter to exit"