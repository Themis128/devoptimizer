<#
.SYNOPSIS
    WSL swap-pressure watchdog (read-only) - logs VM swap usage and warns at 80% via DevOptimizer event 1003.
.DESCRIPTION
    Runs every 30 minutes via scheduled task \DevOptimizer\WSL-Memory-Watchdog. Logs to
    logs\wsl-memory-pressure.log. Host-side guard prevents waking a shut-down WSL VM.
#>
# WSL memory-pressure watchdog - read-only monitor, safe to run any time.
# Logs WSL swap usage to logs\wsl-memory-pressure.log; writes a Warning event
# (DevOptimizer log, source DevOptimizer, event 1003) when swap usage >= 80% -
# the wedge precondition that killed Devin sessions on 2026-10-02.
# Host-side guard: if the WSL VM is not running, log and exit WITHOUT invoking
# wsl.exe (invoking it would wake the VM every run).
$ErrorActionPreference = 'SilentlyContinue'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$logFile = 'D:\DevOptimizer\logs\wsl-memory-pressure.log'

$vm = Get-Process vmmemWSL -ErrorAction SilentlyContinue
if (-not $vm) {
    Add-Content -Path $logFile -Value "$stamp WSL not running (skipped)"
    exit 0
}

$swapLine = (wsl -e bash -c "free -m") -replace "`r", "" | Where-Object { $_ -match '^Swap:' } | Select-Object -First 1
if ($swapLine -match '^Swap:\s+(\d+)\s+(\d+)\s+(\d+)') {
    $total = [int]$matches[1]
    $used = [int]$matches[2]
    if ($total -gt 0) {
        $pct = [math]::Round(100 * $used / $total)
        Add-Content -Path $logFile -Value "$stamp swap ${used}/${total} MB (${pct}%), vmmemWSL $([math]::Round($vm.WS/1GB,1)) GB"
        if ($pct -ge 80) {
            Write-EventLog -LogName 'DevOptimizer' -Source 'DevOptimizer' -EventId 1003 -EntryType Warning `
                -Message "WSL swap pressure ${pct}% (${used}/${total} MB) - wedge risk. Schedule a wsl --shutdown during idle or start fewer containers." `
                -ErrorAction SilentlyContinue
            Add-Content -Path $logFile -Value "$stamp WARNING: swap pressure ${pct}% - event 1003 written"
        }
        if ($pct -ge 90) {
            # Auto-reclaim guest page cache - the same safe first-aid this
            # script previously only advised at 95%. Level 1 (pagecache only)
            # is non-destructive: dirty pages are synced first, cold cache
            # refills from disk on next touch.
            wsl -d Ubuntu-26.04 -u root -- sh -c "sync; echo 1 > /proc/sys/vm/drop_caches" | Out-Null
            Add-Content -Path $logFile -Value "$stamp ACTION: swap ${pct}% - dropped guest page cache"
        }
        if ($pct -ge 95) {
            Add-Content -Path $logFile -Value ('{0} CRITICAL: swap nearly exhausted after reclaim - next step: wsl --shutdown during idle' -f $stamp)
        }
    }
}
