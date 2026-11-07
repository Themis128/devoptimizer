<#
.SYNOPSIS
    SYSTEM-level Windows cleanup (runs as SYSTEM, no UAC prompt)
.DESCRIPTION
    Performs admin-only cleanup: DISM component store, Windows Update cache,
    Delivery Optimization cache, vssadmin shadow copies, Windows.old, WER reports,
    temp files. Registered as \DevOptimizer\Admin-Cleanup-System (weekly Sunday 03:00, SYSTEM).
.NOTES
    Uses shared Notify.ps1 for alerts on failures.
#>
#requires -Version 5.1
#requires -RunAsAdministrator

$ErrorActionPreference = 'SilentlyContinue'

# Import shared modules
. "$PSScriptRoot\lib\Notify.ps1"
. "$PSScriptRoot\lib\Log.ps1"
. "$PSScriptRoot\lib\State.ps1"

$LogFile = "D:\DevOptimizer\logs\admin-cleanup-system.log"
$StateFile = "D:\DevOptimizer\logs\admin-cleanup-system-state.json"

function Write-Log { param($msg, $level='INFO')
    $entry = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $level, $msg
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($level -ne 'DEBUG') { Write-Host "  [$level] $msg" }
}

function MB { param($b) if ($b) { [math]::Round($b/1MB, 1) } else { 0 } }
function GB { param($b) if ($b) { [math]::Round($b/1GB, 2) } else { 0 } }

$before = (Get-PSDrive C).Free
Write-Log "=== Admin Cleanup (SYSTEM) Started ===" -level 'INFO'
Write-Log "C: free before: $(GB $before) GB"

$totalFreed = 0

# --- 1. DISM Component Store Cleanup ---
Write-Log "--- DISM Component Store Cleanup ---" -level 'INFO'
try {
    $dismStart = Get-Date
    Write-Log "Running: Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase" -level 'INFO'
    $dismResult = Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase /NoRestart 2>&1
    $dismExit = $LASTEXITCODE
    $dismDuration = (Get-Date) - $dismStart
    Write-Log "DISM completed in $($dismDuration.TotalMinutes.ToString('F1')) min, exit code: $dismExit" -level 'INFO'
    foreach ($line in $dismResult) { if ($line.Trim()) { Write-Log "  $line" -level 'DEBUG' } }
    if ($dismExit -ne 0) {
        $msg = "DISM StartComponentCleanup/ResetBase failed with exit code $dismExit"
        Write-Log $msg -level 'ERROR'
        Send-DevOptAlert -Severity Warning -Title "Admin Cleanup: DISM Failed" -Message $msg -Tags 'cleanup','dism','admin' -EventId 1005
    }
} catch {
    $msg = "DISM exception: $($_.Exception.Message)"
    Write-Log $msg -level 'ERROR'
    Send-DevOptAlert -Severity Warning -Title "Admin Cleanup: DISM Exception" -Message $msg -Tags 'cleanup','dism','admin' -EventId 1005
}

# --- 2. Windows Update Download Cache ---
Write-Log "--- Windows Update Cache ---" -level 'INFO'
$wuCache = 'C:\Windows\SoftwareDistribution\Download'
if (Test-Path $wuCache) {
    try {
        $size = (Get-ChildItem $wuCache -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Write-Log "Stopping wuauserv..." -level 'INFO'
        net stop wuauserv 2>$null | Out-Null
        Start-Sleep 3
        Get-ChildItem $wuCache -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        net start wuauserv 2>$null | Out-Null
        Write-Log "Windows Update cache cleaned: -$(MB $size) MB" -level 'INFO'
        $totalFreed += $size
    } catch {
        $msg = "Windows Update cache cleanup failed: $($_.Exception.Message)"
        Write-Log $msg -level 'ERROR'
        net start wuauserv 2>$null | Out-Null
    }
}

# --- 3. Delivery Optimization Cache ---
Write-Log "--- Delivery Optimization Cache ---" -level 'INFO'
$doCache = 'C:\Windows\ServiceProfiles\NetworkService\AppData\Local\DeliveryOptimization\Cache'
if (Test-Path $doCache) {
    try {
        $size = (Get-ChildItem $doCache -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Write-Log "Stopping DoSvc..." -level 'INFO'
        net stop DoSvc 2>$null | Out-Null
        Start-Sleep 2
        Get-ChildItem $doCache -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        net start DoSvc 2>$null | Out-Null
        Write-Log "Delivery Optimization cache cleaned: -$(MB $size) MB" -level 'INFO'
        $totalFreed += $size
    } catch {
        $msg = "Delivery Optimization cache cleanup failed: $($_.Exception.Message)"
        Write-Log $msg -level 'ERROR'
        net start DoSvc 2>$null | Out-Null
    }
}

# --- 4. Shadow Copies (vssadmin) ---
Write-Log "--- Shadow Copies (vssadmin) ---" -level 'INFO'
try {
    $shadows = vssadmin list shadows /for=c: 2>&1
    $shadowCount = ($shadows | Select-String 'Shadow Copy Volume' | Measure-Object).Count
    if ($shadowCount -gt 0) {
        Write-Log "Found $shadowCount shadow copy(s), deleting oldest..." -level 'INFO'
        vssadmin delete shadows /for=c: /oldest /quiet 2>&1 | ForEach-Object { Write-Log "  $_" -level 'DEBUG' }
        Write-Log "Oldest shadow copy deleted" -level 'INFO'
    } else {
        Write-Log "No shadow copies to clean" -level 'INFO'
    }
} catch {
    $msg = "Shadow copy cleanup failed: $($_.Exception.Message)"
    Write-Log $msg -level 'ERROR'
    Send-DevOptAlert -Severity Warning -Title "Admin Cleanup: Shadow Copy Failed" -Message $msg -Tags 'cleanup','vssadmin','admin' -EventId 1006
}

# --- 5. Windows.old ---
Write-Log "--- Windows.old ---" -level 'INFO'
$winOld = 'C:\Windows.old'
if (Test-Path $winOld) {
    try {
        $size = (Get-ChildItem $winOld -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Remove-Item $winOld -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Windows.old removed: -$(GB $size) GB" -level 'INFO'
        $totalFreed += $size
    } catch {
        Write-Log "Windows.old cleanup failed: $($_.Exception.Message)" -level 'ERROR'
    }
} else {
    Write-Log "Windows.old not present" -level 'INFO'
}

# --- 6. WER Reports ---
Write-Log "--- WER Reports ---" -level 'INFO'
foreach ($dir in @('C:\ProgramData\Microsoft\Windows\WER\ReportArchive', 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue')) {
    if (Test-Path $dir) {
        $size = (Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Get-ChildItem $dir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "WER $(Split-Path $dir -Leaf) cleaned: -$(MB $size) MB" -level 'INFO'
        $totalFreed += $size
    }
}

# --- 7. System Temp ---
Write-Log "--- System Temp ---" -level 'INFO'
$size = (Get-ChildItem 'C:\Windows\Temp' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Get-ChildItem 'C:\Windows\Temp' -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Log "System temp cleaned: -$(MB $size) MB" -level 'INFO'
$totalFreed += $size

# --- Summary ---
$after = (Get-PSDrive C).Free
$actualFreed = $after - $before

Write-Log "=== Admin Cleanup Complete ===" -level 'INFO'
Write-Log "C: free after: $(GB $after) GB" -level 'INFO'
Write-Log "Reported freed: $(GB $totalFreed) GB" -level 'INFO'
Write-Log "Actual C: delta: $(GB $actualFreed) GB" -level 'INFO'

# Update state
$state = @{
    lastRun = (Get-Date).ToString('o')
    lastFreedGB = [math]::Round($totalFreed / 1GB, 2)
    lastActualDeltaGB = [math]::Round($actualFreed / 1GB, 2)
}
Save-State -StateFile $StateFile -State $state

# Alert on completion
Send-DevOptAlert -Severity Info -Title "Admin Cleanup Complete" `
    -Message "Freed ~$(GB $totalFreed) GB (C: delta $(GB $actualFreed) GB)" `
    -Tags 'cleanup','admin','system','complete' -EventId 1007

exit 0
