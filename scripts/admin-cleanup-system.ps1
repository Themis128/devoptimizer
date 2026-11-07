<#
.SYNOPSIS
    Admin cleanup suite run as SYSTEM - DISM, update caches, shadow-copy pruning, DO cache
.DESCRIPTION
    Runs as SYSTEM scheduled task (weekly Sunday 03:00). No UAC prompts needed.
    Handles: DISM component cleanup, Windows Update cache, Delivery Optimization cache,
    vssadmin shadow copies, Windows.old, WER reports, temp files.
.NOTES
    Uses shared Notify.ps1 for alerts on failures.
    Log: logs\admin-cleanup-system.log
#>
#requires -Version 5.1
# CATEGORY: cleanup

$ErrorActionPreference = 'Continue'

# Import shared modules
. "$PSScriptRoot\lib\Notify.ps1"

function MB { param($b) [math]::Round($b/1MB, 1) }
function GB { param($b) [math]::Round($b/1GB, 2) }

$logFile = 'D:\DevOptimizer\logs\admin-cleanup-system.log'
function Log { param($msg)
    Add-Content -Path $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
}

$before = (Get-PSDrive C).Free
Log "=== Windows 11 Admin Cleanup (SYSTEM) ==="
Log ("C: free before: {0:N2} GB" -f ($before/1GB))

# 1. DISM Component Store Cleanup
Log "--- [1] DISM Component Store Cleanup ---"
Log "Running: Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart"
$dismResult = Dism /Online /Cleanup-Image /StartComponentCleanup /NoRestart 2>&1
$dismResult | ForEach-Object { Log "  $_" }
if ($LASTEXITCODE -eq 0) {
    Log "[1] DISM component cleanup: COMPLETED"
} else {
    Log "[1] DISM component cleanup: EXIT CODE $LASTEXITCODE"
    Send-DevOptAlert -Severity Warning -Title "Admin Cleanup (SYSTEM): DISM Failed" -Message "DISM /StartComponentCleanup exited with code $LASTEXITCODE. Output: $($dismResult -join '; ')" -Tags 'cleanup', 'dism', 'system' -EventId 1005
}

# 2. DISM ResetBase (free up space from superseded components)
Log "`n--- [1b] DISM ResetBase ---"
Log "Running: Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase /NoRestart"
$dismResult2 = Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase /NoRestart 2>&1
$dismResult2 | ForEach-Object { Log "  $_" }
if ($LASTEXITCODE -eq 0) {
    Log "[1b] DISM ResetBase: COMPLETED"
} else {
    Log "[1b] DISM ResetBase: EXIT CODE $LASTEXITCODE (may be expected if no superseded components)"
}

# 3. Windows Update Download Cache
Log "`n--- [2] Windows Update Download Cache ---"
$wuPath = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wuPath) {
    $wuItems = Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
    $size = if ($wuItems) { ($wuItems | Measure-Object Length -Sum).Sum } else { 0 }
    Log "Stopping wuauserv service..."
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    if (Test-Path $wuPath) {
        Log "Clearing $wuPath ($([math]::Round($size/1GB,2)) GB)..."
        Get-ChildItem $wuPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Log "Restarting wuauserv service..."
    Start-Service wuauserv -ErrorAction SilentlyContinue
    $wuItemsAfter = Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
    $newSize = if ($wuItemsAfter) { ($wuItemsAfter | Measure-Object Length -Sum).Sum } else { 0 }
    Log ("[2] Windows Update cache cleaned: -{0} GB" -f (GB ($size - $newSize)))
} else {
    Log "[2] Windows Update cache: path not found"
}

# 4. Delivery Optimization Cache (direct folder deletion, no interactive prompt)
Log "`n--- [3] Delivery Optimization Cache ---"
try {
    $doCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\DeliveryOptimization"
    if (Test-Path $doCachePath) {
        $doItems = Get-ChildItem $doCachePath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
        $size = if ($doItems) { ($doItems | Measure-Object Length -Sum).Sum } else { 0 }
        Log "Removing Delivery Optimization cache ($([math]::Round($size/1MB,2)) MB)..."
        Remove-Item -Path $doCachePath -Recurse -Force -ErrorAction SilentlyContinue
        Log "[3] Delivery Optimization cache: CLEARED"
    } else {
        Log "[3] Delivery Optimization cache: not found"
    }
} catch {
    Log "[3] Delivery Optimization cache: SKIPPED ($($_.Exception.Message.Split("`n")[0]))"
    Send-DevOptAlert -Severity Warning -Title "Admin Cleanup (SYSTEM): DO Cache Failed" -Message "Delivery Optimization cache cleanup failed: $($_.Exception.Message)" -Tags 'cleanup', 'delivery-optimization', 'system' -EventId 1007
}

# 5. System Restore Points / Shadow Copies (oldest)
Log "`n--- [4] System Restore Points (oldest only) ---"
Log "Running: vssadmin delete shadows /for=c: /oldest /quiet"
try {
    $vssResult = vssadmin delete shadows /for=c: /oldest /quiet 2>&1
    $vssResult | ForEach-Object { Log "  $_" }
    if ($LASTEXITCODE -eq 0) {
        Log "[4] Oldest shadow copy: DELETED"
    } else {
        $vssOutput = $vssResult -join ' '
        Log "[4] Shadow copy: EXIT CODE $LASTEXITCODE"
        if ($vssOutput -notmatch 'no items|no shadows|nothing to delete') {
            Send-DevOptAlert -Severity Warning -Title "Admin Cleanup (SYSTEM): Shadow Copy Failed" -Message "vssadmin delete shadows exited with code $LASTEXITCODE. Output: $vssOutput" -Tags 'cleanup', 'vss', 'system' -EventId 1006
        }
    }
} catch {
    Log "[4] Shadow copy deletion exception: $($_.Exception.Message)"
    Send-DevOptAlert -Severity Warning -Title "Admin Cleanup (SYSTEM): Shadow Copy Exception" -Message "vssadmin threw exception: $($_.Exception.Message)" -Tags 'cleanup', 'vss', 'system' -EventId 1006
}

# 6. Windows.old if exists
Log "`n--- [5] Windows.old folder (if present) ---"
$winOld = "C:\Windows.old"
if (Test-Path $winOld) {
    $winOldItems = Get-ChildItem $winOld -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
    $size = if ($winOldItems) { ($winOldItems | Measure-Object Length -Sum).Sum } else { 0 }
    Log "Found Windows.old ($([math]::Round($size/1GB,2)) GB) - removing..."
    takeown /f "$winOld" /r /d y 2>&1 | Out-Null
    icacls "$winOld" /grant administrators:F /t /c /q 2>&1 | Out-Null
    Remove-Item $winOld -Recurse -Force -ErrorAction SilentlyContinue
    Log ("[5] Windows.old removed: -{0} GB" -f (GB ($size)))
} else {
    Log "[5] Windows.old: not found"
}

# 7. Windows Error Reporting (WER) reports
Log "`n--- [6] Windows Error Reporting (WER) ---"
$werPaths = @(
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
    "C:\Users\*\AppData\Local\Microsoft\Windows\WER\ReportArchive",
    "C:\Users\*\AppData\Local\Microsoft\Windows\WER\ReportQueue"
)
$werTotal = 0
foreach ($werPath in $werPaths) {
    if (Test-Path $werPath) {
        $werItems = Get-ChildItem $werPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
        $size = if ($werItems) { ($werItems | Measure-Object Length -Sum).Sum } else { 0 }
        $werTotal += $size
        if ($size -gt 0) {
            Log "Clearing $werPath ($([math]::Round($size/1MB,2)) MB)..."
            Get-ChildItem $werPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
Log ("[6] WER reports cleaned: -{0} MB" -f (MB $werTotal))

# 8. System temp files
Log "`n--- [7] System temp files ---"
$tempPaths = @(
    "C:\Windows\Temp",
    "C:\Windows\Prefetch"
)
$tempTotal = 0
foreach ($tempPath in $tempPaths) {
    if (Test-Path $tempPath) {
        $tempItems = Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer }
        $size = if ($tempItems) { ($tempItems | Measure-Object Length -Sum).Sum } else { 0 }
        $tempTotal += $size
        if ($size -gt 0) {
            Log "Clearing $tempPath ($([math]::Round($size/1MB,2)) MB)..."
            Get-ChildItem $tempPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -ErrorAction SilentlyContinue
        }
    }
}
Log ("[7] System temp cleaned: -{0} MB" -f (MB $tempTotal))

# Summary
$after = (Get-PSDrive C).Free
Log "`n=== Summary ==="
Log ("C: free before: {0:N2} GB" -f ($before/1GB))
Log ("C: free after  : {0:N2} GB" -f ($after/1GB))
Log ("Freed on C:   : {0:N2} GB" -f (($after - $before)/1GB))
Log "Done. A reboot is recommended after DISM operations."

exit 0