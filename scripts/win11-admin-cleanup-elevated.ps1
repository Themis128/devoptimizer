<#
.SYNOPSIS
    Windows 11 admin cleanup (elevated): component store, update cache, Delivery Optimization, oldest shadow copy.
.DESCRIPTION
    Windows 11 admin cleanup (elevated): component store, update cache, Delivery Optimization, oldest shadow copy.
#>

# Windows 11 Admin Cleanup - MUST RUN AS ADMINISTRATOR

# Verify admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Must run as Administrator!"
    exit 1
}

function GB { param($b) [math]::Round($b/1GB, 2) }

$before = (Get-PSDrive C).Free
Write-Host "=== Windows 11 Admin Cleanup ===" -ForegroundColor Cyan
Write-Host "C: free before: $(GB $before) GB" -ForegroundColor Yellow

# 1. DISM Component Store Cleanup
Write-Host "`n--- [1] DISM Component Store Cleanup ---" -ForegroundColor Cyan
Write-Host "Running: Dism /Online /Cleanup-Image /StartComponentCleanup" -ForegroundColor Yellow
$dismResult = Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart 2>&1
$dismResult | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -eq 0) { Write-Host "[1] DISM component cleanup: COMPLETED" -ForegroundColor Green }
else { Write-Host "[1] DISM component cleanup: EXIT CODE $LASTEXITCODE" -ForegroundColor Red }

# 2. DISM RestoreHealth
Write-Host "`n--- [2] DISM RestoreHealth (Repair) ---" -ForegroundColor Cyan
Write-Host "Running: Dism /Online /Cleanup-Image /RestoreHealth" -ForegroundColor Yellow
Write-Host "This may take 10-30 minutes..." -ForegroundColor Yellow
$dismResult2 = Dism /Online /Cleanup-Image /RestoreHealth 2>&1
$dismResult2 | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -eq 0) { Write-Host "[2] DISM RestoreHealth: COMPLETED" -ForegroundColor Green }
else { Write-Host "[2] DISM RestoreHealth: EXIT CODE $LASTEXITCODE" -ForegroundColor Red }

# 3. SFC /scannow
Write-Host "`n--- [3] SFC /scannow ---" -ForegroundColor Cyan
Write-Host "Running: sfc /scannow" -ForegroundColor Yellow
$sfcResult = sfc /scannow 2>&1
$sfcResult | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -eq 0) { Write-Host "[3] SFC: COMPLETED" -ForegroundColor Green }
else { Write-Host "[3] SFC: EXIT CODE $LASTEXITCODE" -ForegroundColor Red }

# 4. Windows Update Download Cache
Write-Host "`n--- [4] Windows Update Download Cache ---" -ForegroundColor Cyan
$wuPath = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wuPath) {
    $size = (Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Host "Stopping wuauserv..." -ForegroundColor Yellow
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    Write-Host "Clearing $wuPath ($(GB $size) GB)..." -ForegroundColor Yellow
    Get-ChildItem $wuPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    Write-Host "[4] Windows Update cache cleaned: -$(GB $size) GB" -ForegroundColor Green
} else {
    Write-Host "[4] Windows Update cache: not found" -ForegroundColor DarkGray
}

# 5. Delivery Optimization Cache - Direct folder deletion to avoid interactive prompt
Write-Host "`n--- [5] Delivery Optimization Cache ---" -ForegroundColor Cyan
try {
    $doCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\DeliveryOptimization"
    if (Test-Path $doCachePath) {
        $size = (Get-ChildItem $doCachePath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Write-Host "Removing Delivery Optimization cache ($([math]::Round($size/1MB,2)) MB)..."
        Remove-Item -Path $doCachePath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[5] Delivery Optimization cache: CLEARED" -ForegroundColor Green
    } else {
        Write-Host "[5] Delivery Optimization cache: not found" -ForegroundColor DarkGray
    }
} catch {
    $msg = $_.Exception.Message.Split("`n")[0]
    Write-Host("[5] Delivery Optimization cache: SKIPPED ($msg)" -ForegroundColor DarkGray
}

# 6. Shadow Copies (oldest)
Write-Host "`n--- [6] Shadow Copies (oldest) ---" -ForegroundColor Cyan
Write-Host "Running: vssadmin delete shadows /for=c: /oldest /quiet" -ForegroundColor Yellow
$vssResult = vssadmin delete shadows /for=c: /oldest /quiet 2>&1
$vssResult | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -eq 0) { Write-Host "[6] Oldest shadow copy: DELETED" -ForegroundColor Green }
else { Write-Host "[6] Shadow copy: EXIT CODE $LASTEXITCODE (may be none)" -ForegroundColor DarkGray }

# 7. Windows.old
Write-Host "`n--- [7] Windows.old (if present) ---" -ForegroundColor Cyan
$winOld = "C:\Windows.old"
if (Test-Path $winOld) {
    $size = (Get-ChildItem $winOld -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Host "Found Windows.old ($(GB $size) GB) - removing..." -ForegroundColor Yellow
    takeown /f "$winOld" /r /d y 2>&1 | Out-Null
    icacls "$winOld" /grant administrators:F /t /c /q 2>&1 | Out-Null
    Remove-Item $winOld -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[7] Windows.old removed: -$(GB $size) GB" -ForegroundColor Green
} else {
    Write-Host "[7] Windows.old: not found" -ForegroundColor DarkGray
}

# Summary
$after = (Get-PSDrive C).Free
Write-Host "`n=== Summary ===" -ForegroundColor Magenta
Write-Host "C: free before: $(GB $before) GB"
Write-Host "C: free after : $(GB $after) GB"
Write-Host "Freed on C:   : $(GB ($after - $before)) GB"
Write-Host "`nDone. Reboot recommended after DISM/SFC." -ForegroundColor Yellow

exit 0