# Elevated Windows 11 repair - run via UAC (Start-Process -Verb RunAs)
# Fixes: orphaned PRI-Driver service (13x boot failures), system file
# integrity (DISM RestoreHealth + SFC), read-only chkdsk scan of C:.
$ErrorActionPreference = 'Continue'
$log = 'D:\DevOptimizer\logs\win11-repair-20260906.log'
$done = 'D:\DevOptimizer\logs\win11-repair-20260906.done'
Start-Transcript -Path $log -Force

function Log([string]$m) { Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }

Log '=== Windows 11 repair started ==='

# --- 1. Disable orphaned PRI-Driver service (binary missing) ---
Log 'Disabling orphaned PRI-Driver service (driver file missing)...'
sc.exe config PRI-Driver start= disabled
Log ("PRI-Driver config exit: {0}" -f $LASTEXITCODE)

# --- 2. DISM RestoreHealth (repairs the component store) ---
Log 'Running DISM /RestoreHealth (5-20 minutes)...'
dism /Online /Cleanup-Image /RestoreHealth
Log ("DISM RestoreHealth exit: {0}" -f $LASTEXITCODE)

# --- 3. SFC system file check/repair ---
Log 'Running sfc /scannow (5-15 minutes)...'
sfc /scannow
Log ("SFC exit: {0}" -f $LASTEXITCODE)

# --- 4. Read-only chkdsk scan of C: ---
Log 'Running chkdsk C: /scan (read-only)...'
chkdsk C: /scan
Log ("chkdsk exit: {0}" -f $LASTEXITCODE)

# --- 5. Re-check the service state ---
Log 'PRI-Driver state after fix:'
sc.exe query PRI-Driver

Log '=== Windows 11 repair complete ==='
Stop-Transcript
Set-Content -Path $done -Value (Get-Date -Format o)
