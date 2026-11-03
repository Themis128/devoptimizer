<#
.SYNOPSIS
    Elevated complete cleanup: DISM component store, WU cache, Delivery Optimization, shadow copies, VHDX compaction. Requires admin.
.DESCRIPTION
    Elevated complete cleanup: DISM component store, WU cache, Delivery Optimization, shadow copies, VHDX compaction. Requires admin.
#>

# Elevated Complete Cleanup Script
# Runs all admin-required tasks: VHDX compaction + Windows 11 Admin Cleanup
# MUST be run as Administrator (Start-Process -Verb RunAs)

param(
    [switch]$SkipVhdx,
    [switch]$SkipAdminCleanup
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "           ELEVATED COMPLETE CLEANUP (Admin Required)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Verify admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script MUST run as Administrator. Right-click PowerShell -> Run as Administrator."
    exit 1
}

# Per-run transcript so scheduled/manual runs leave a log
try { Start-Transcript -Path ("D:\DevOptimizer\logs\elevated-complete-cleanup-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date)) -ErrorAction Stop | Out-Null } catch { }

function GB { param($b) [math]::Round($b/1GB, 2) }
function MB { param($b) [math]::Round($b/1MB, 1) }

# ================================================================
# PART 1: VHDX COMPACTION (WSL Ubuntu-24.04)
# ================================================================
if (-not $SkipVhdx) {
    Write-Host "`n=== PART 1: WSL/DOCKER VHDX COMPACTION ===" -ForegroundColor Magenta

    # Devin-safe compaction (2026-09-29): delegates to the standalone script, which
    # gates on Devin.exe/devin-server (defers instead of killing active sessions),
    # releases the disks by polling for exclusive access instead of sleep-3, and
    # restarts Docker + WSL afterward (the old inline version left them dead).
    # -ForceAll: the 15-day cadence compacts regardless of the 10 GB growth threshold.
    & (Join-Path $PSScriptRoot 'Invoke-VhdxCompaction.ps1') -AsLibrary -ForceAll
    Write-Host ("PART 1 result: {0}" -f $global:LAST_VHDX_COMPACTION.status) -ForegroundColor Cyan
}

# ================================================================
# PART 2: WINDOWS 11 ADMIN CLEANUP (DISM, Windows Update, etc.)
# ================================================================
if (-not $SkipAdminCleanup) {
    Write-Host "`n=== PART 2: WINDOWS 11 ADMIN CLEANUP ===" -ForegroundColor Magenta
    
    $before = (Get-PSDrive C).Free
    Write-Host "C: free before: $(GB $before) GB" -ForegroundColor Cyan
    
    # 1. DISM Component Store Cleanup
    Write-Host "`n--- [1] DISM Component Store Cleanup ---" -ForegroundColor Cyan
    Write-Host "Running: Dism /Online /Cleanup-Image /StartComponentCleanup" -ForegroundColor Yellow
    Write-Host "This may take several minutes..." -ForegroundColor Yellow
    $dismResult = Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart 2>&1
    $dismResult | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[1] DISM component cleanup: COMPLETED" -ForegroundColor Green
    } else {
        Write-Host "[1] DISM component cleanup: EXIT CODE $LASTEXITCODE" -ForegroundColor Red
    }
    
    # 2. DISM RestoreHealth (repair)
    Write-Host "`n--- [1b] DISM RestoreHealth (Repair) ---" -ForegroundColor Cyan
    Write-Host "Running: Dism /Online /Cleanup-Image /RestoreHealth" -ForegroundColor Yellow
    Write-Host "This may take 10-30 minutes..." -ForegroundColor Yellow
    $dismResult2 = Dism /Online /Cleanup-Image /RestoreHealth 2>&1
    $dismResult2 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[1b] DISM RestoreHealth: COMPLETED" -ForegroundColor Green
    } else {
        Write-Host "[1b] DISM RestoreHealth: EXIT CODE $LASTEXITCODE" -ForegroundColor Red
    }
    
    # 3. SFC /scannow
    Write-Host "`n--- [1c] SFC /scannow ---" -ForegroundColor Cyan
    Write-Host "Running: sfc /scannow" -ForegroundColor Yellow
    $sfcResult = sfc /scannow 2>&1
    $sfcResult | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[1c] SFC: COMPLETED" -ForegroundColor Green
    } else {
        Write-Host "[1c] SFC: EXIT CODE $LASTEXITCODE" -ForegroundColor Red
    }
    
    # 4. Windows Update Download Cache
    Write-Host "`n--- [2] Windows Update Download Cache ---" -ForegroundColor Cyan
    $wuPath = "C:\Windows\SoftwareDistribution\Download"
    if (Test-Path $wuPath) {
        $size = (Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Write-Host "Stopping wuauserv service..." -ForegroundColor Yellow
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
        Write-Host "Clearing $wuPath ($(GB $size) GB)..." -ForegroundColor Yellow
        Get-ChildItem $wuPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Restarting wuauserv service..." -ForegroundColor Yellow
        Start-Service wuauserv -ErrorAction SilentlyContinue
        Write-Host "[2] Windows Update cache cleaned: -$(GB $size) GB" -ForegroundColor Green
    } else {
        Write-Host "[2] Windows Update cache: path not found" -ForegroundColor DarkGray
    }
    
    # 5. Delivery Optimization Cache
    Write-Host "`n--- [3] Delivery Optimization Cache ---" -ForegroundColor Cyan
    try {
        Write-Host "Running: Delete-DeliveryOptimizationCache" -ForegroundColor Yellow
        Delete-DeliveryOptimizationCache -ErrorAction Stop
        Write-Host "[3] Delivery Optimization cache: CLEARED" -ForegroundColor Green
    } catch {
        Write-Host "[3] Delivery Optimization cache: SKIPPED ($($_.Exception.Message.Split("`n")[0]))" -ForegroundColor DarkGray
    }
    
    # 6. System Restore Points / Shadow Copies (oldest)
    Write-Host "`n--- [4] System Restore Points (oldest only) ---" -ForegroundColor Cyan
    Write-Host "Running: vssadmin delete shadows /for=c: /oldest /quiet" -ForegroundColor Yellow
    $vssResult = vssadmin delete shadows /for=c: /oldest /quiet 2>&1
    $vssResult | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[4] Oldest shadow copy: DELETED" -ForegroundColor Green
    } else {
        Write-Host "[4] Shadow copy: EXIT CODE $LASTEXITCODE (may be none to delete)" -ForegroundColor DarkGray
    }
    
    # 7. Windows.old if exists
    Write-Host "`n--- [5] Windows.old folder (if present) ---" -ForegroundColor Cyan
    $winOld = "C:\Windows.old"
    if (Test-Path $winOld) {
        $size = (Get-ChildItem $winOld -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Write-Host "Found Windows.old ($(GB $size) GB) - removing..." -ForegroundColor Yellow
        takeown /f "$winOld" /r /d y 2>&1 | Out-Null
        icacls "$winOld" /grant administrators:F /t /c /q 2>&1 | Out-Null
        Remove-Item $winOld -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[5] Windows.old removed: -$(GB $size) GB" -ForegroundColor Green
    } else {
        Write-Host "[5] Windows.old: not found" -ForegroundColor DarkGray
    }
    
    # 6. Windows Error Reporting archives + kernel crash dumps
    Write-Host "`n--- [6] WER archives + crash dumps ---" -ForegroundColor Cyan
    $dumpCutoff = (Get-Date).AddDays(-30)
    $dumpFreed = 0
    foreach ($dumpPath in @(
        "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
        "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
        "C:\Windows\Minidump"
    )) {
        if (Test-Path $dumpPath) {
            $old = Get-ChildItem $dumpPath -Recurse -Force -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.LastWriteTime -lt $dumpCutoff }
            $sz = ($old | Measure-Object Length -Sum).Sum
            if (-not $sz) { $sz = 0 }
            if ($old) { $old | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
            $dumpFreed += $sz
            Write-Host "[6] $dumpPath : -$(MB $sz) MB" -ForegroundColor Green
        } else {
            Write-Host "[6] $dumpPath : not present" -ForegroundColor DarkGray
        }
    }
    $memDmp = "C:\Windows\MEMORY.DMP"
    if ((Test-Path $memDmp) -and ((Get-Item $memDmp).LastWriteTime -lt $dumpCutoff)) {
        $sz = (Get-Item $memDmp).Length
        Remove-Item $memDmp -Force -ErrorAction SilentlyContinue
        $dumpFreed += $sz
        Write-Host "[6] $memDmp : -$(MB $sz) MB" -ForegroundColor Green
    }
    Write-Host "[6] WER/dumps total freed: -$(MB $dumpFreed) MB" -ForegroundColor Green

    # Summary
    $after = (Get-PSDrive C).Free
    Write-Host "`n=== Admin Cleanup Summary ===" -ForegroundColor Magenta
    Write-Host ("C: free before: {0:N2} GB" -f ($before/1GB))
    Write-Host ("C: free after : {0:N2} GB" -f ($after/1GB))
    Write-Host ("Freed on C:   : {0:N2} GB" -f (($after - $before)/1GB))
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "                    ALL ADMIN TASKS COMPLETED" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "NOTE: A reboot is recommended after DISM/SFC operations." -ForegroundColor Yellow
Write-Host "NOTE: Docker Desktop was stopped - reopen it to restart your containers." -ForegroundColor Yellow
try { Stop-Transcript | Out-Null } catch { }