# daily-full-cleanup.ps1 - one-shot daily cleanup covering everything the
# 2026-11-13 manual session did: WSL swap orphans, user temp/caches, Docker
# builder+dangling+unused images+stopped containers, Recycle Bin, E: shader
# cache. Runs as scheduled task \DevOptimizer\Daily-Full-Cleanup (06:30,
# after the 05:00 VHDX compaction window so Docker is back up).
# Safe to re-run; everything inside is idempotent. Log: logs\daily-full-cleanup.log
# CATEGORY: cleanup
$ErrorActionPreference = 'Continue'
$log = 'D:\DevOptimizer\logs\daily-full-cleanup.log'
function Log($m) { $l = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"; Add-Content $log $l; Write-Host $l }

Log '=== daily-full-cleanup start ==='
$before = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
Log "C: free before: ${before} GB"

# 1. Orphaned WSL swap.vhdx in %TEMP%\<GUID>\ (live VM's swap is locked -> skipped)
& "$PSScriptRoot\cleanup-wsl-swap-orphans.ps1" 2>&1 | ForEach-Object { Log "swap-reaper: $_" }

# 2. User temp + package caches + safe docker subset + recycle bin attempt
& "$PSScriptRoot\win11-safe-cleanup.ps1" 2>&1 | ForEach-Object { Log "safe-cleanup: $_" }

# 3. Recycle Bin (all drives) - safe-cleanup skips it when the path lookup fails
try { Clear-RecycleBin -Force -ErrorAction Stop; Log 'recycle bin: emptied' }
catch { Log "recycle bin: $($_.Exception.Message)" }

# 4. Docker deep prune: build cache, dangling images, stopped containers.
#    Named-but-unused images are KEPT (dangling-only) so compose
#    recreations reuse them locally instead of re-pulling ~50GB/day
#    into docker_data.vhdx between compactions. Volumes are
#    intentionally NOT pruned (named data volumes).
if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker builder prune -af 2>&1 | Select-Object -Last 1 | ForEach-Object { Log "docker builder: $_" }
    docker container prune -f 2>&1 | Select-Object -Last 1 | ForEach-Object { Log "docker containers: $_" }
    docker image prune -f 2>&1 | Select-Object -Last 1 | ForEach-Object { Log "docker dangling imgs: $_" }
} else { Log 'docker: CLI not available - skipped' }

# 5. E: NVIDIA/AMD shader cache (regenerates) - keeps the small data drive clean
$shader = 'E:\AdaptivaCache'
if (Test-Path $shader) {
    Remove-Item "$shader\*" -Recurse -Force -ErrorAction SilentlyContinue
    Log 'E: AdaptivaCache cleared'
}

$after = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
Log "C: free after: ${after} GB (delta $([math]::Round($after-$before,1)) GB)"
Log '=== daily-full-cleanup done ==='
