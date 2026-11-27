# vmcompute-unstick.ps1 - emergency repair for vmcompute StopPending wedge.
# Fired on-demand via elevated scheduled task. Kills zombie VM worker procs,
# lets vmcompute finish stopping, restarts vmcompute + WSLService,
# re-enables quiesced probe tasks, restarts Docker Desktop service.
# If vmmemWSL/vmwp survive Stop-Process (kernel-wait), logs NEEDS-REBOOT.
$ErrorActionPreference = 'Continue'
$log = 'D:\DevOptimizer\logs\vmcompute-unstick.log'
function W($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $log -Append -Encoding ascii }
W '=== vmcompute-unstick start ==='

# 1. Kill the stuck compactor script (holds quiesce state; its finally is unreachable)
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' or Name='pwsh.exe'" |
  Where-Object { $_.CommandLine -match 'nightly-wsl-vhdx-compact' } |
  ForEach-Object {
    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop; W "killed compactor ps pid=$($_.ProcessId)" }
    catch { W "compactor ps kill failed pid=$($_.ProcessId): $($_.Exception.Message)" }
  }

# 2. Kill hung wsl.exe client procs (piled-up probes)
Get-Process wsl -ErrorAction SilentlyContinue | ForEach-Object {
  try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {}
}
W 'wsl client procs cleared'

# 3. Kill zombie VM worker procs
foreach ($name in 'vmwp','vmmemWSL','vmmem') {
  Get-Process $name -ErrorAction SilentlyContinue | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force -ErrorAction Stop; W "killed $name pid=$($_.Id)" }
    catch { W "kill $name pid=$($_.Id) failed: $($_.Exception.Message)" }
  }
}
Start-Sleep -Seconds 10

# 4. Verify workers are gone; survivors mean kernel-wait -> reboot needed
$survivors = @(Get-Process vmwp,vmmemWSL,vmmem -ErrorAction SilentlyContinue)
if ($survivors.Count -gt 0) {
  W ("NEEDS-REBOOT: VM worker procs survived elevated kill: " + ($survivors | ForEach-Object { "$($_.Name)#$($_.Id)" }) -join ', ')
} else {
  W 'no VM worker procs remain'
}

# 5. vmcompute: wait for stop to complete, then start
$deadline = (Get-Date).AddSeconds(60)
while ((Get-Service vmcompute).Status -ne 'Stopped' -and (Get-Date) -lt $deadline) { Start-Sleep 3 }
$st = (Get-Service vmcompute).Status
W "vmcompute status after wait: $st"
try { Start-Service vmcompute -ErrorAction Stop; W 'vmcompute started' }
catch { W "vmcompute start failed: $($_.Exception.Message)" }

# 6. WSLService restart (drops stale ext4.vhdx file handle - the lock holder seen at 05:11)
try { Restart-Service WSLService -Force -ErrorAction Stop; W 'WSLService restarted' }
catch { W "WSLService restart failed: $($_.Exception.Message)" }

# 7. Re-enable quiesced probe tasks (compactor was killed before its finally)
$qfile = 'D:\DevOptimizer\logs\.quiesced-probe-tasks'
if (Test-Path $qfile) {
  $n = 0
  Get-Content $qfile | ForEach-Object {
    $line = $_.Trim(); if (-not $line) { return }
    $path, $name = $line -split '\|', 2
    $tn = if ($path -eq '\') { $name } else { "$path\$name" }
    try { Enable-ScheduledTask -TaskName $tn -ErrorAction Stop | Out-Null; $n++ }
    catch { W "re-enable failed ${tn}: $($_.Exception.Message)" }
  }
  Remove-Item $qfile -Force -ErrorAction SilentlyContinue
  W "re-enabled $n quiesced task(s)"
}

# 8. Docker Desktop service back up (compactor had stopped it)
try { Start-Service com.docker.service -ErrorAction Stop; W 'com.docker.service started' }
catch { W "com.docker.service start failed: $($_.Exception.Message)" }

# 9. Relaunch Docker Desktop UI/backend
$dd = @("$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe",
        'C:\Program Files\Docker\Docker\Docker Desktop.exe') |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($dd) { Start-Process $dd; W 'Docker Desktop relaunched' } else { W 'Docker Desktop.exe not found - relaunch skipped' }

# 10. Final state
$svc = Get-Service vmcompute,WSLService,com.docker.service | ForEach-Object { "$($_.Name)=$($_.Status)" }
W ('final: ' + ($svc -join ' '))
W '=== vmcompute-unstick done ==='
