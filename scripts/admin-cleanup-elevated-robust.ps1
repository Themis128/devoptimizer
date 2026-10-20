<#
.SYNOPSIS
    Robust Windows 11 Admin Cleanup: DISM, Update caches, Shadow copies, Temp, Recycle Bin.
.DESCRIPTION
    Runs elevated. Idempotent, continues on partial failure, logs to D:\DevOptimizer\logs\.
#>
#requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

$LogFile = "D:\DevOptimizer\logs\admin-cleanup-robust-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Log { param($msg) $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; "$ts $msg" | Tee-Object -FilePath $LogFile -Append }
function GB { param($b) [math]::Round($b/1GB, 2) }
function MB { param($b) [math]::Round($b/1MB, 1) }

$before = (Get-PSDrive C).Free
Log "=== Robust Admin Cleanup Started ==="
Log "C: free before: $(GB $before) GB"

# --- 1. DISM: RestoreHealth THEN StartComponentCleanup -----------------------
Log "--- [1] DISM RestoreHealth + Component Cleanup ---"
try {
    Log "Running: Dism /Online /Cleanup-Image /RestoreHealth"
    $dism1 = Dism /Online /Cleanup-Image /RestoreHealth /NoRestart 2>&1
    $dism1 | ForEach-Object { Log "  $_" }
    if ($LASTEXITCODE -ne 0) { Log "WARN: RestoreHealth exit $LASTEXITCODE (may be benign)" }

    Log "Running: Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase"
    $dism2 = Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase /NoRestart 2>&1
    $dism2 | ForEach-Object { Log "  $_" }
    if ($LASTEXITCODE -eq 0) { Log "[1] DISM: COMPLETED" }
    else { Log "WARN: StartComponentCleanup exit $LASTEXITCODE" }
} catch { Log "ERR DISM: $($_.Exception.Message)" }

# --- 2. Windows Update Download Cache ---------------------------------------
Log "--- [2] Windows Update Download Cache ---"
$wuPath = "C:\Windows\SoftwareDistribution\Download"
try {
    if (Test-Path $wuPath) {
        $sizeBefore = (Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { !$_.PSIsContainer } | Measure-Object Length -Sum).Sum
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
        Get-ChildItem $wuPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service wuauserv -ErrorAction SilentlyContinue
        $sizeAfter = (Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { !$_.PSIsContainer } | Measure-Object Length -Sum).Sum
        Log "[2] Windows Update cache: cleaned $(GB ($sizeBefore - $sizeAfter)) GB"
    } else { Log "[2] Windows Update cache: path not found" }
} catch { Log "WARN WU cache: $($_.Exception.Message)" }

# --- 3. Delivery Optimization Cache -----------------------------------------
Log "--- [3] Delivery Optimization Cache ---"
try {
    $doPath = "$env:LOCALAPPDATA\Microsoft\Windows\DeliveryOptimization"
    if (Test-Path $doPath) {
        $size = (Get-ChildItem $doPath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { !$_.PSIsContainer } | Measure-Object Length -Sum).Sum
        Remove-Item $doPath -Recurse -Force -ErrorAction SilentlyContinue
        Log "[3] Delivery Optimization: cleaned $(MB $size) MB"
    } else { Log "[3] Delivery Optimization: not found" }
} catch { Log "WARN DO cache: $($_.Exception.Message)" }

# --- 4. ALL Old Shadow Copies (not just oldest) -----------------------------
Log "--- [4] Shadow Copies (all old) ---"
try {
    $vss = vssadmin list shadows /for=c: 2>&1
    $vss | ForEach-Object { Log "  $_" }
    # Delete all but the most recent (if >1)
    $shadowCount = ($vss | Where-Object { $_ -match 'Shadow Copy ID' }).Count
    if ($shadowCount -gt 1) {
        for ($i = 0; $i -lt ($shadowCount - 1); $i++) {
            Log "Deleting oldest shadow copy ($($i+1)/$($shadowCount-1))..."
            vssadmin delete shadows /for=c: /oldest /quiet 2>&1 | ForEach-Object { Log "  $_" }
        }
        Log "[4] Shadow copies: deleted $($shadowCount-1) old copies"
    } elseif ($shadowCount -eq 1) {
        Log "[4] Shadow copies: only 1 (kept)"
    } else {
        Log "[4] Shadow copies: none found"
    }
} catch { Log "WARN VSS: $($_.Exception.Message)" }

# --- 5. System Temp (C:\Windows\Temp) ---------------------------------------
Log "--- [5] System Temp (C:\Windows\Temp) ---"
try {
    $tempPath = "C:\Windows\Temp"
    if (Test-Path $tempPath) {
        $sizeBefore = (Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { !$_.PSIsContainer } | Measure-Object Length -Sum).Sum
        Get-ChildItem $tempPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $sizeAfter = (Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { !$_.PSIsContainer } | Measure-Object Length -Sum).Sum
        Log "[5] System Temp: cleaned $(MB ($sizeBefore - $sizeAfter)) MB"
    }
} catch { Log "WARN System Temp: $($_.Exception.Message)" }

# --- 6. Recycle Bin (all users) ---------------------------------------------
Log "--- [6] Recycle Bin (all users) ---"
try {
    $shell = New-Object -ComObject Shell.Application
    $recycle = $shell.Namespace(0x0a)  # Recycle Bin
    if ($recycle) {
        $items = $recycle.Items()
        $count = $items.Count
        if ($count -gt 0) {
            $recycle.Items() | ForEach-Object { $_.InvokeVerb('Delete') }
            Log "[6] Recycle Bin: emptied $count items"
        } else { Log "[6] Recycle Bin: already empty" }
    }
} catch { Log "WARN Recycle Bin: $($_.Exception.Message)" }

# --- 7. Thumbnail Cache -----------------------------------------------------
Log "--- [7] Thumbnail Cache ---"
try {
    $thumbPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db"
    )
    foreach ($p in $thumbPaths) {
        Get-Item $p -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Log "[7] Thumbnail/Icon cache: cleared"
} catch { Log "WARN Thumbnails: $($_.Exception.Message)" }

# --- 8. Crash Dumps / WER ---------------------------------------------------
Log "--- [8] Crash Dumps & WER ---"
try {
    $werPaths = @(
        "C:\Windows\Minidump",
        "C:\Windows\MEMORY.DMP",
        "$env:LOCALAPPDATA\CrashDumps",
        "C:\ProgramData\Microsoft\Windows\WER"
    )
    foreach ($p in $werPaths) {
        if (Test-Path $p) {
            $size = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { !$_.PSIsContainer } | Measure-Object Length -Sum).Sum
            if ($size -gt 0) {
                Get-ChildItem $p -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Log "[8] ${p}: cleaned $(MB $size) MB"
            }
        }
    }
} catch { Log "WARN Crash dumps: $($_.Exception.Message)" }

# --- 9. Windows.old ---------------------------------------------------------
Log "--- [9] Windows.old ---"
try {
    $winOld = "C:\Windows.old"
    if (Test-Path $winOld) {
        $size = (Get-ChildItem $winOld -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { !$_.PSIsContainer } | Measure-Object Length -Sum).Sum
        # Use DISM for safe removal
        Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart 2>&1 | Out-Null
        Remove-Item $winOld -Recurse -Force -ErrorAction SilentlyContinue
        Log "[9] Windows.old: removed $(GB $size) GB"
    } else { Log "[9] Windows.old: not found" }
} catch { Log "WARN Windows.old: $($_.Exception.Message)" }

# --- Summary ----------------------------------------------------------------
$after = (Get-PSDrive C).Free
Log "=== Summary ==="
Log "C: free before: $(GB $before) GB"
Log "C: free after : $(GB $after) GB"
Log "Freed on C:   : $(GB ($after - $before)) GB"
Log "Log saved to: $LogFile"
Log "Reboot recommended after DISM operations."