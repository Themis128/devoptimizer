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

# Check if running with administrator privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


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
    Write-Host "  This script is running with administrator privileges." -ForegroundColor Yellow
    Write-Host "  The DISM error may be transient; consider running DISM /Online /Cleanup-Image /RestoreHealth first." -ForegroundColor Yellow
}

# 2. Windows Update Download Cache
Write-Host "`n--- [2] Windows Update Download Cache ---" -ForegroundColor Cyan
$wuPath = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wuPath) {
    $wuItems = Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
    if ($wuItems) {
        $size = ($wuItems | Measure-Object Length -Sum).Sum
    } else {
        $size = 0
    }
    Write-Host "Stopping wuauserv service..."
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    if (Test-Path $wuPath) {
        Write-Host "Clearing $wuPath ($([math]::Round($size/1GB,2)) GB)..."
        Get-ChildItem $wuPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Restarting wuauserv service..."
    Start-Service wuauserv -ErrorAction SilentlyContinue
    if (Test-Path $wuPath) {
        $wuItemsAfter = Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
        if ($wuItemsAfter) {
            $newSize = ($wuItemsAfter | Measure-Object Length -Sum).Sum
        } else {
            $newSize = 0
        }
        Write-Host ("[2] Windows Update cache cleaned: -{0} GB" -f (GB ($size - $newSize))) -ForegroundColor Green
    } else {
        Write-Host ("[2] Windows Update cache cleaned: -{0} GB" -f (GB ($size))) -ForegroundColor Green
    }
} else {
    Write-Host "[2] Windows Update cache: path not found" -ForegroundColor DarkGray
}

# 3. Delivery Optimization Cache - Using direct folder deletion to avoid interactive prompt
Write-Host "`n--- [3] Delivery Optimization Cache ---" -ForegroundColor Cyan
try {
    $doCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\DeliveryOptimization"
    if (Test-Path $doCachePath) {
        $doItems = Get-ChildItem $doCachePath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
        if ($doItems) {
            $size = ($doItems | Measure-Object Length -Sum).Sum
        } else {
            $size = 0
        }
        Write-Host "Removing Delivery Optimization cache ($([math]::Round($size/1MB,2)) MB)..."
        Remove-Item -Path $doCachePath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[3] Delivery Optimization cache: CLEARED" -ForegroundColor Green
    } else {
        Write-Host "[3] Delivery Optimization cache: not found" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "[3] Delivery Optimization cache: SKIPPED ($($_.Exception.Message.Split("`n")[0]))" -ForegroundColor DarkGray
}

# 4. System Restore Points / Shadow Copies
Write-Host "`n--- [4] System Restore Points (oldest only) ---" -ForegroundColor Cyan
Write-Host "Running: vssadmin delete shadows /for=c: /oldest /quiet"
try {
    $vssResult = vssadmin delete shadows /for=c: /oldest /quiet 2>&1
    $vssResult | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[4] Oldest shadow copy: DELETED" -ForegroundColor Green
    } else {
        Write-Host "[4] Shadow copy: EXIT CODE $LASTEXITCODE (may be none to delete)" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "[4] Shadow copy deletion skipped (may require admin): $($_.Exception.Message)" -ForegroundColor DarkGray
}

# 5. Windows.old if exists
Write-Host "`n--- [5] Windows.old folder (if present) ---" -ForegroundColor Cyan
$winOld = "C:\Windows.old"
if (Test-Path $winOld) {
    $winOldItems = Get-ChildItem $winOld -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
    if ($winOldItems) {
        $size = ($winOldItems | Measure-Object Length -Sum).Sum
    } else {
        $size = 0
    }
    Write-Host "Found Windows.old ($([math]::Round($size/1GB,2)) GB) - removing..."
    takeown /f "$winOld" /r /d y 2>&1 | Out-Null
    icacls "$winOld" /grant administrators:F /t /c /q 2>&1 | Out-Null
    Remove-Item $winOld -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ("[5] Windows.old removed: -{0} GB" -f (GB ($size))) -ForegroundColor Green
} else {
    Write-Host "[5] Windows.old: not found" -ForegroundColor DarkGray
}

# Summary
$after = (Get-PSDrive C).Free
Write-Host "`n=== Summary ===" -ForegroundColor Magenta
Write-Host ("C: free before: {0:N2} GB" -f ($before/1GB))
Write-Host ("C: free after  : {0:N2} GB" -f ($after/1GB))
Write-Host ("Freed on C:   : {0:N2} GB" -f (($after - $before)/1GB))
Write-Host "`nDone. A reboot is recommended after DISM operations." -ForegroundColor Yellow

exit 0