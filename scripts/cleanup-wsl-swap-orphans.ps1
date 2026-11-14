<#
.SYNOPSIS
    Reaps orphaned WSL swap.vhdx files left in %TEMP%\<GUID>\ by crashed or
    terminated WSL VMs. Each VM boot creates a fresh swap.vhdx (sized by
    .wslconfig swap=, currently 24GB sparse); clean shutdowns delete it, but
    wsl --terminate / guardian T2 / crashes leave it behind. On 2026-11-11
    five orphans held ~63GB and helped fill C: to 0.7GB free, which crashed
    Docker Desktop and fed the vsock flap loop.
.DESCRIPTION
    Safe-by-construction:
      - files older than -MinAgeHours (default 2) are candidates; younger
        files are reaped only when an exclusive-open probe proves they are
        NOT locked by the hypervisor (dead-VM orphans), so a boot in
        progress is never touched;
      - the LIVE VM's swap.vhdx is held open by the hypervisor, so the
        delete simply fails and the file is skipped;
      - the GUID dir is removed only if empty afterwards.
    Logs to logs\wsl-swap-reaper.log. Called every 30 min by the
    WSL-Memory-Watchdog task via check-wsl-memory-pressure.ps1.
#>
#requires -Version 5.1
# CATEGORY: system
param(
    [int]$MinAgeHours = 2,
    [switch]$DryRun
)

$ErrorActionPreference = 'SilentlyContinue'
$logFile = 'D:\DevOptimizer\logs\wsl-swap-reaper.log'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

function Log([string]$msg) { Add-Content -Path $logFile -Value "$stamp $msg" }

$cutoff = (Get-Date).AddHours(-$MinAgeHours)
$reclaimed = 0L
$reaped = 0
$skipped = 0

# Swap disks live in the interactive user's temp; an elevated task's TEMP
# can resolve to C:\Windows\TEMP, so scan both.
$roots = @($env:TEMP, 'C:\Users\tbaltzakis\AppData\Local\Temp') |
    Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$dirs = foreach ($root in $roots) {
    Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$' }
}

foreach ($d in $dirs) {
    $swap = Join-Path $d.FullName 'swap.vhdx'
    if (-not (Test-Path $swap)) { continue }
    $item = Get-Item $swap
    # Fresh files belong to a boot in progress or the live VM. The live
    # VM's swap is locked by the hypervisor, so an UNLOCKED fresh file is
    # an orphan from a VM that died mid-boot (vsock flaps churn these) —
    # reclaim it now instead of waiting out MinAgeHours while C: drains.
    $freshOrphan = $false
    if ($item.LastWriteTime -gt $cutoff) {
        try {
            $fs = [System.IO.File]::Open($swap, 'Open', 'ReadWrite', 'None')
            $fs.Close()
            $freshOrphan = $true
        } catch { $freshOrphan = $false }
        if (-not $freshOrphan) { $skipped++; continue }
    }
    $mb = [math]::Round($item.Length / 1MB)
    if ($DryRun) {
        Log "DRYRUN would reap $($d.Name) swap.vhdx ${mb} MB (last write $($item.LastWriteTime))"
        $reclaimed += $item.Length; $reaped++
        continue
    }
    try {
        Remove-Item $swap -Force -ErrorAction Stop
        $reclaimed += $item.Length; $reaped++
        $how = if ($freshOrphan) { 'fresh-orphan (unlocked)' } else { 'aged' }
        Log "reaped $($d.Name) swap.vhdx ${mb} MB ($how, last write $($item.LastWriteTime))"
    } catch {
        # Locked = live VM's swap disk; anything else is unexpected - keep it.
        $skipped++
        Log "skip $($d.Name) swap.vhdx ${mb} MB - $($_.Exception.Message)"
    }
    # Remove the GUID dir only if the reaper emptied it.
    if (-not $DryRun -and -not (Get-ChildItem $d.FullName -Force -ErrorAction SilentlyContinue)) {
        Remove-Item $d.FullName -Force -ErrorAction SilentlyContinue
    }
}

if ($reaped -gt 0) {
    Log ("done: reaped {0} file(s), reclaimed {1:N1} GB, skipped {2}" -f $reaped, ($reclaimed/1GB), $skipped)
} else {
    Log "done: no orphans (skipped $skipped fresh/locked)"
}
exit 0
