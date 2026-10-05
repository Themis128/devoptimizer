<#
.SYNOPSIS
    WSL Ubuntu garbage sweep (daily 03:00 scheduled): apt cache, journal, uv cache, gh cache.
.DESCRIPTION
    Cleans inside Ubuntu-26.04 as root: apt archive cache, systemd journal vacuum to 100 MB,
    tbaltzakis uv package cache, gh cache files older than 30 days. Never touches Docker
    images/containers/volumes (own lineage is not garbage) or any user data outside caches.
    Host-side guard: if the WSL VM is not running, log and exit WITHOUT invoking wsl.exe
    (same pattern as check-wsl-memory-pressure.ps1 - do not wake the VM for cleanup).
#>
#requires -Version 5.1
# CATEGORY: cleanup

$ErrorActionPreference = 'SilentlyContinue'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$logFile = 'D:\DevOptimizer\logs\wsl-ubuntu-cleanup.log'

$vm = Get-Process vmmemWSL -ErrorAction SilentlyContinue
if (-not $vm) {
    Add-Content -Path $logFile -Value "$stamp WSL not running (skipped)"
    exit 0
}

$before = (wsl.exe -d Ubuntu-26.04 -u root -- sh -c "df -B1 / | tail -1 | awk '{print `$4}'") -replace "`r", ""

$steps = @(
    @{ Name = 'apt-get clean';          Cmd = 'apt-get clean -y' },
    @{ Name = 'journal vacuum 100M';    Cmd = 'journalctl --vacuum-size=100M | tail -1' },
    @{ Name = 'uv cache clean';         Cmd = 'sudo -u tbaltzakis -H bash -c "command -v uv >/dev/null && uv cache clean || rm -rf /home/tbaltzakis/.cache/uv/archive-v0"' },
    @{ Name = 'gh cache prune >30d';    Cmd = 'find /home/tbaltzakis/.cache/gh -type f -mtime +30 -delete' }
)

$results = @()
foreach ($s in $steps) {
    $out = (wsl.exe -d Ubuntu-26.04 -u root -- bash -c $s.Cmd) -replace "`r", "" | Select-Object -Last 1
    $results += ("  [{0}] {1}" -f $s.Name, $out)
}

$after = (wsl.exe -d Ubuntu-26.04 -u root -- sh -c "df -B1 / | tail -1 | awk '{print `$4}'") -replace "`r", ""
$freedMB = 0
try { $freedMB = [math]::Round(([long]$after - [long]$before) / 1MB, 1) } catch { }

Add-Content -Path $logFile -Value "$stamp WSL Ubuntu cleanup: freed $freedMB MB inside root fs"
$results | ForEach-Object { Add-Content -Path $logFile -Value "$stamp$_" }
Write-Host "WSL Ubuntu cleanup done: freed $freedMB MB"
exit 0
