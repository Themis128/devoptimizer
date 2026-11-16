<#
.SYNOPSIS
    Windows 11 OS-level deep cleanup (requires elevation).
.DESCRIPTION
    Removes C:\Windows.old, disables hibernation, runs DISM component-store
    cleanup, and clears stale Windows system logs. Logs everything to
    logs\os-cleanup-<timestamp>.log. Does NOT touch user profiles, DevOptimizer,
    Docker/WSL data, the pagefile, or installed programs.
#>
# CATEGORY: cleanup
#requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = 'D:\DevOptimizer\logs'
$log    = Join-Path $logDir "os-cleanup-$stamp.log"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Log([string]$msg) {
    $line = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg
    Add-Content -Path $log -Value $line
    Write-Host $line
}

function FreeGB {
    [math]::Round((Get-PSDrive C).Free / 1GB, 2)
}

Log "=== Win11 OS deep cleanup start ==="
Log ("C: free before: {0} GB" -f (FreeGB))

# --- 1. Windows.old (previous OS install) ---
# NOTE: files under WinSxS\...\r are owned by TrustedInstaller and deny even
# SYSTEM delete. takeown+icacls+rd clears ~99%; stubborn remnants need
# Disk Cleanup ("Previous Windows installations") or winold-delete-worker2.ps1
# run as SYSTEM. Remove-Item -Recurse HANGS on this tree - always use rd.
if (Test-Path 'C:\Windows.old') {
    Log "Removing C:\Windows.old (takeown /a + icacls + rd passes; slow on big trees)..."
    & takeown.exe /f 'C:\Windows.old' /r /d y /a | Out-Null
    & icacls.exe 'C:\Windows.old' /grant 'administrators:F' /t /c /q | Out-Null
    & icacls.exe 'C:\Windows.old' /grant 'SYSTEM:F' /t /c /q | Out-Null
    foreach ($pass in 1..5) {
        if (-not (Test-Path 'C:\Windows.old')) { break }
        Log "rd pass $pass on C:\Windows.old"
        & cmd.exe /c 'rd /s /q C:\Windows.old' 2>&1 | ForEach-Object { Log "  rd: $_" }
        if (Test-Path 'C:\Windows.old') {
            & takeown.exe /f 'C:\Windows.old' /r /d y /a | Out-Null
            & icacls.exe 'C:\Windows.old' /grant 'administrators:F' /t /c /q | Out-Null
        }
    }
    if (Test-Path 'C:\Windows.old') {
        Log "Windows.old: PARTIAL - TrustedInstaller files remain; run Disk Cleanup > 'Clean up system files' > 'Previous Windows installations', or scripts\winold-delete-worker2.ps1 as SYSTEM"
    } else {
        Log "Windows.old: removed"
    }
} else {
    Log "Windows.old: not present"
}
Log ("C: free after Windows.old: {0} GB" -f (FreeGB))

# --- 2. Leftover upgrade folders ---
foreach ($p in 'C:\$WINDOWS.~BT', 'C:\$WinREAgent', 'C:\Windows10Upgrade', 'C:\$GetCurrent') {
    if (Test-Path $p) {
        Log "Removing leftover upgrade folder $p"
        & takeown.exe /f $p /r /d y | Out-Null
        & icacls.exe $p /grant 'administrators:F' /t /c /q | Out-Null
        Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- 3. Hibernation off (frees hiberfil.sys ~13 GB) ---
Log "Disabling hibernation (powercfg /h off)..."
& powercfg.exe /h off
Log ("hiberfil.sys present: {0}" -f (Test-Path 'C:\hiberfil.sys'))
Log ("C: free after hibernation off: {0} GB" -f (FreeGB))

# --- 4. DISM component store analysis + cleanup ---
Log "DISM AnalyzeComponentStore..."
& dism.exe /Online /Cleanup-Image /AnalyzeComponentStore 2>&1 |
    ForEach-Object { Log "DISM-ANALYZE: $_" }
Log "DISM StartComponentCleanup (can take 10-60 min)..."
& dism.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1 |
    ForEach-Object { Log "DISM-CLEAN: $_" }
Log ("C: free after DISM cleanup: {0} GB" -f (FreeGB))

# --- 5. Stale Windows system logs (>30 days) ---
$cutoff = (Get-Date).AddDays(-30)
$logTargets = @(
    'C:\Windows\Logs',
    'C:\Windows\System32\LogFiles',
    'C:\Windows\Panther',
    'C:\Windows\inf\setupapi.dev.log'
)
$freed = 0L
foreach ($t in $logTargets) {
    if (Test-Path $t) {
        $item = Get-Item $t -Force
        if ($item.PSIsContainer) {
            Get-ChildItem $t -Recurse -Force -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoff -and $_.Length -gt 0 } |
                ForEach-Object {
                    $freed += $_.Length
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                }
        } else {
            if ($item.LastWriteTime -lt $cutoff) {
                $freed += $item.Length
                Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
Log ("System logs >30d removed: {0:N1} MB" -f ($freed/1MB))

# --- 6. Windows Update download cache (safe even if small) ---
$wu = 'C:\Windows\SoftwareDistribution\Download'
if (Test-Path $wu) {
    Get-ChildItem $wu -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Log "Windows Update download cache cleared"
}

Log ("C: free final: {0} GB" -f (FreeGB))
Log "=== Win11 OS deep cleanup done ==="
