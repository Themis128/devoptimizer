<#
.SYNOPSIS
    Runs elevated maintenance.
.DESCRIPTION
    Runs elevated maintenance.
#>

# Elevated maintenance - run via Task Scheduler with full admin token
# (schtasks /RL HIGHEST). Writes progress to D:\DevOptimizer\logs\elevated-20260906.log
# and a .done marker when finished.

$ErrorActionPreference = 'Continue'
$log = 'D:\DevOptimizer\logs\elevated-20260906.log'
$done = 'D:\DevOptimizer\logs\elevated-20260906.done'
Start-Transcript -Path $log -Force

function Log([string]$m) { Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }
$vhdx = 'C:\Users\tbaltzakis\AppData\Local\Docker\wsl\disk\docker_data.vhdx'
$drive = Get-PSDrive C

Log ("START. C: free before: {0:N2} GB. vhdx before: {1:N2} GB" -f ($drive.Free/1GB), ((Get-Item $vhdx).Length/1GB))

# --- 1. Stop Docker Desktop cleanly so nothing re-mounts the vhdx ---
Log 'Quitting Docker Desktop...'
& 'C:\Program Files\Docker\Docker\DockerCli.exe' -Quit 2>$null
Start-Sleep 5
Get-Process 'Docker Desktop','com.docker.backend' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process wsl,wslhost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Log 'Shutting down WSL...'
wsl --shutdown
Start-Sleep 5
$vm = Get-Process vmmemWSL -ErrorAction SilentlyContinue
Log ("vmmemWSL present: {0}" -f [bool]$vm)

# --- 2. Compact docker_data.vhdx via diskpart ---
Log 'Compacting docker_data.vhdx (diskpart: attach readonly -> compact -> detach)...'
$dp = @"
select vdisk file="$vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
"@
$dpFile = "$env:TEMP\compact-docker.txt"
Set-Content -Path $dpFile -Value $dp -Encoding ASCII
$dpOut = diskpart /s $dpFile 2>&1
$dpOut | ForEach-Object { Log ("diskpart: $_") }
Log ("vhdx after compaction: {0:N2} GB" -f ((Get-Item $vhdx).Length/1GB))

# --- 3. Restart Docker Desktop and confirm engine + WSL recovery ---
Log 'Restarting Docker Desktop...'
Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$deadline = (Get-Date).AddMinutes(6)
do {
    Start-Sleep 10
    $eng = docker version --format '{{.Server.Version}}' 2>$null
} while (-not $eng -and (Get-Date) -lt $deadline)
Log ("Docker engine after restart: {0}" -f $(if ($eng) { $eng } else { 'NOT UP (will check later)' }))
$wslOk = wsl -d Ubuntu-26.04 -- echo wsl-ok 2>&1
Log ("WSL exec after restart: $wslOk")

# --- 4. DISM component store cleanup (long) ---
Log 'Running DISM StartComponentCleanup (this can take 10-30 minutes)...'
dism /Online /Cleanup-Image /StartComponentCleanup | Out-Null
Log ("DISM exit code: {0}" -f $LASTEXITCODE)

# --- 5. Windows Update download cache ---
Log 'Clearing Windows Update download cache...'
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service bits -Force -ErrorAction SilentlyContinue
$wuBefore = (Get-ChildItem 'C:\Windows\SoftwareDistribution\Download' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Get-ChildItem 'C:\Windows\SoftwareDistribution\Download' -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Start-Service bits -ErrorAction SilentlyContinue
Start-Service wuauserv -ErrorAction SilentlyContinue
Log ("WU cache cleared: freed ~{0:N0} MB" -f ($wuBefore/1MB))

# --- 6. Delivery Optimization cache ---
Log 'Clearing Delivery Optimization cache...'
try { Delete-DeliveryOptimizationCache -Force; Log 'Delivery Optimization cache cleared' }
catch { Log ("Delivery Optimization: {0}" -f $_.Exception.Message) }

# --- 7. Full Git (with Credential Manager) via winget, silent ---
Log 'Installing Git.Git (full, with GCM)...'
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements --silent --override "/VERYSILENT /NORESTART /SUPPRESSMSGBOXES" 2>&1 | Select-Object -Last 3 | ForEach-Object { Log ("winget: $_") }

# --- 8. Final sizes ---
$drive = Get-PSDrive C
Log ("DONE. C: free after: {0:N2} GB. vhdx after: {1:N2} GB" -f ($drive.Free/1GB), ((Get-Item $vhdx).Length/1GB))
Stop-Transcript
Set-Content -Path $done -Value (Get-Date -Format o)
