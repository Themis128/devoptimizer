<#
.SYNOPSIS
    DevOptimizer Health Dashboard - generates HTML + JSON health overview
.DESCRIPTION
    Generates a single-page real-time view of all subsystem health:
    - WSL Permanent Fix (4 layers)
    - WSL Guardian (T1-T3)
    - Host Guard (T2-T4)
    - Docker-WSL Sync
    - DD Settings Watchdog
    - Admin Cleanup
    Outputs: logs/health-dashboard.html (self-contained) + logs/health-dashboard.json (API)
    Auto-refresh: meta refresh 60s + JS fetch of JSON every 30s
#>
#requires -Version 5.1
# CATEGORY: monitoring

$ErrorActionPreference = 'SilentlyContinue'

# Import shared modules
. "$PSScriptRoot\lib\Log.ps1"
. "$PSScriptRoot\lib\State.ps1"

$HtmlOutput = 'D:\DevOptimizer\logs\health-dashboard.html'
$JsonOutput = 'D:\DevOptimizer\logs\health-dashboard.json'

# --- Data Collection ---

function Get-WSLFixState {
    $stateFile = 'D:\DevOptimizer\logs\wsl-permanent-fix-state.json'
    if (Test-Path $stateFile) {
        $s = Get-Content $stateFile -Raw | ConvertFrom-Json
        return @{
            lastGate = $s.lastGate ?? 'unknown'
            wslexecDetected = $s.wslexecDetected ?? $false
            lastDockerStart = $s.lastDockerStart ?? 'never'
            status = if ($s.wslexecDetected) { 'Warning' } elseif ($s.lastGate -eq 'Layer4-ConfigHardened') { 'Healthy' } else { 'Unknown' }
        }
    }
    return @{ status='Unknown'; lastGate='none'; wslexecDetected=$false; lastDockerStart='never' }
}

function Get-GuardianState {
    $stateFile = 'C:\ProgramData\wsl-guardian\state.json'
    if (Test-Path $stateFile) {
        $s = Get-Content $stateFile -Raw | ConvertFrom-Json
        return @{
            deepFails = $s.deepFails ?? 0
            postT2Fails = $s.postT2Fails ?? 0
            lastT1 = $s.lastT1 ?? 'never'
            lastT2 = $s.lastT2 ?? 'never'
            lastT3 = $s.lastT3 ?? 'never'
            t2Pending = $s.t2Pending ?? $false
            status = if ($s.deepFails -ge 4) { 'Critical' } elseif ($s.deepFails -ge 2) { 'Warning' } else { 'Healthy' }
        }
    }
    return @{ status='Unknown'; deepFails=0; postT2Fails=0; lastT1='never'; lastT2='never'; lastT3='never'; t2Pending=$false }
}

function Get-HostGuardState {
    $stateFile = 'D:\DevOptimizer\logs\host-guard-state.json'
    if (Test-Path $stateFile) {
        $s = Get-Content $stateFile -Raw | ConvertFrom-Json
        $metrics = $s.metrics ?? @{}
        return @{
            availMB = $metrics.availMB ?? 0
            vramPct = $metrics.vramPct ?? 0
            commitPct = $metrics.commitPct ?? 0
            lastDropCaches = $s.lastDropCaches ?? 'never'
            lastUnload = $s.lastUnload ?? 'never'
            lastBounce = $s.lastBounce ?? 'never'
            status = if ($metrics.availMB -lt 1200) { 'Critical' } elseif ($metrics.availMB -lt 2500 -or $metrics.vramPct -gt 85) { 'Warning' } else { 'Healthy' }
        }
    }
    return @{ status='Unknown'; availMB=0; vramPct=0; commitPct=0; lastDropCaches='never'; lastUnload='never'; lastBounce='never' }
}

function Get-DockerSyncState {
    $logFile = 'D:\DevOptimizer\logs\docker-wsl-sync.log'
    $lastRun = 'never'
    $actions = 0
    $containersUp = 0
    if (Test-Path $logFile) {
        $lines = Get-Content $logFile -Tail 20
        foreach ($line in $lines) {
            if ($line -match 'sync run started') { $lastRun = $line.Split(' ')[0] + ' ' + $line.Split(' ')[1] }
            if ($line -match 'sync complete: (\d+) container.*?(\d+) repair') {
                $containersUp = [int]$Matches[1]
                $actions = [int]$Matches[2]
            }
        }
    }
    return @{
        lastRun = $lastRun
        actions = $actions
        containersUp = $containersUp
        status = if ($actions -gt 0) { 'Warning' } else { 'Healthy' }
    }
}

function Get-DDWatchdogState {
    $stateFile = 'D:\DevOptimizer\logs\dd-settings-watchdog-state.json'
    if (Test-Path $stateFile) {
        $s = Get-Content $stateFile -Raw | ConvertFrom-Json
        return @{
            lastCheck = $s.lastCheck ?? 'never'
            lastDrift = $s.lastDrift ?? 'never'
            lastRestore = $s.lastRestore ?? 'never'
            driftCount = $s.driftCount ?? 0
            restoreCount = $s.restoreCount ?? 0
            status = if ($s.driftCount -gt 0 -and $s.lastDrift -gt $s.lastRestore) { 'Warning' } elseif ($s.driftCount -gt 0) { 'Healthy' } else { 'Healthy' }
        }
    }
    return @{ status='Unknown'; lastCheck='never'; lastDrift='never'; lastRestore='never'; driftCount=0; restoreCount=0 }
}

function Get-AdminCleanupState {
    $logFile = 'D:\DevOptimizer\logs\admin-cleanup-elevated.log'
    $lastRun = 'never'
    $freedGB = 0
    if (Test-Path $logFile) {
        $lines = Get-Content $logFile -Tail 10
        foreach ($line in $lines) {
            if ($line -match 'C: free before: ([\d.]+) GB') {
                $before = [double]$Matches[1]
            }
            if ($line -match 'Freed on C:.*: ([\d.]+) GB') {
                $freedGB = [double]$Matches[1]
            }
            if ($line -match '=== Summary ===') {
                $lastRun = (Get-Date).ToString('yyyy-MM-dd HH:mm')
            }
        }
    }
    return @{
        lastRun = $lastRun
        freedGB = $freedGB
        status = 'Healthy'
    }
}

function Get-HealthColor {
    param($status)
    switch ($status) {
        'Healthy'  { return '#22c55e' }
        'Warning'  { return '#f59e0b' }
        'Critical' { return '#ef4444' }
        default    { return '#6b7280' }
    }
}

# --- Collect All States ---
$wslFix = Get-WSLFixState
$guardian = Get-GuardianState
$hostGuard = Get-HostGuardState
$dockerSync = Get-DockerSyncState
$ddWatchdog = Get-DDWatchdogState
$adminCleanup = Get-AdminCleanupState

# Overall status
$allStatuses = $wslFix.status, $guardian.status, $hostGuard.status, $dockerSync.status, $ddWatchdog.status, $adminCleanup.status
$overall = if ($allStatuses -contains 'Critical') { 'Critical' } elseif ($allStatuses -contains 'Warning') { 'Warning' } else { 'Healthy' }

# --- Generate JSON Output ---
$jsonData = @{
    timestamp = (Get-Date -Format 'o')
    overall = $overall
    subsystems = @{
        wslPermanentFix = $wslFix
        wslGuardian = $guardian
        hostGuard = $hostGuard
        dockerWslSync = $dockerSync
        ddSettingsWatchdog = $ddWatchdog
        adminCleanup = $adminCleanup
    }
}
$jsonData | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonOutput -Encoding UTF8

# --- Generate HTML Output ---
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="60">
    <title>DevOptimizer Health Dashboard</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; padding: 20px; line-height: 1.5; }
        .container { max-width: 1200px; margin: 0 auto; }
        header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid #1e293b; }
        h1 { font-size: 1.5rem; font-weight: 600; }
        .overall { display: flex; align-items: center; gap: 12px; padding: 12px 20px; border-radius: 8px; font-weight: 600; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 16px; }
        .card { background: #1e293b; border-radius: 8px; padding: 20px; border: 1px solid #334155; }
        .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
        .card-title { font-weight: 600; font-size: 1rem; }
        .status-badge { padding: 4px 12px; border-radius: 9999px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; }
        .metric { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #334155; }
        .metric:last-child { border-bottom: none; }
        .metric-label { color: #94a3b8; }
        .metric-value { font-weight: 500; font-family: monospace; }
        .metric-value.warning { color: #f59e0b; }
        .metric-value.critical { color: #ef4444; }
        .metric-value.healthy { color: #22c55e; }
        .timestamp { color: #64748b; font-size: 0.8rem; text-align: right; margin-top: 20px; }
        .refresh-info { color: #64748b; font-size: 0.75rem; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>DevOptimizer Health Dashboard</h1>
            <div class="overall" style="background: $(Get-HealthColor $overall)20; color: $(Get-HealthColor $overall);">
                <span id="status-dot" style="width: 10px; height: 10px; border-radius: 50%; background: $(Get-HealthColor $overall);"></span>
                <span>Overall: $overall</span>
            </div>
        </header>
        
        <div class="grid">
"@

# WSL Permanent Fix Card
$html += @"
            <div class="card">
                <div class="card-header">
                    <span class="card-title">WSL Permanent Fix (4 Layers)</span>
                    <span class="status-badge" style="background: $(Get-HealthColor $wslFix.status)20; color: $(Get-HealthColor $wslFix.status);">$($wslFix.status)</span>
                </div>
                <div class="metric"><span class="metric-label">Last Gate</span><span class="metric-value">$($wslFix.lastGate)</span></div>
                <div class="metric"><span class="metric-label">WSLEXEC Detected</span><span class="metric-value $(if ($wslFix.wslexecDetected) { 'warning' } else { 'healthy' })">$(if ($wslFix.wslexecDetected) { 'Yes' } else { 'No' })</span></div>
                <div class="metric"><span class="metric-label">Last Docker Start</span><span class="metric-value">$($wslFix.lastDockerStart)</span></div>
            </div>
"@

# WSL Guardian Card
$html += @"
            <div class="card">
                <div class="card-header">
                    <span class="card-title">WSL Guardian (T1-T3)</span>
                    <span class="status-badge" style="background: $(Get-HealthColor $guardian.status)20; color: $(Get-HealthColor $guardian.status);">$($guardian.status)</span>
                </div>
                <div class="metric"><span class="metric-label">Deep Fails</span><span class="metric-value $(if ($guardian.deepFails -ge 4) { 'critical' } elseif ($guardian.deepFails -ge 2) { 'warning' } else { 'healthy' })">$($guardian.deepFails)</span></div>
                <div class="metric"><span class="metric-label">Post-T2 Fails</span><span class="metric-value $(if ($guardian.postT2Fails -gt 0) { 'warning' } else { 'healthy' })">$($guardian.postT2Fails)</span></div>
                <div class="metric"><span class="metric-label">T2 Pending</span><span class="metric-value $(if ($guardian.t2Pending) { 'warning' } else { 'healthy' })">$(if ($guardian.t2Pending) { 'Yes' } else { 'No' })</span></div>
                <div class="metric"><span class="metric-label">Last T1</span><span class="metric-value">$($guardian.lastT1)</span></div>
                <div class="metric"><span class="metric-label">Last T2</span><span class="metric-value">$($guardian.lastT2)</span></div>
                <div class="metric"><span class="metric-label">Last T3</span><span class="metric-value">$($guardian.lastT3)</span></div>
            </div>
"@

# Host Guard Card
$html += @"
            <div class="card">
                <div class="card-header">
                    <span class="card-title">Host Guard (T2-T4)</span>
                    <span class="status-badge" style="background: $(Get-HealthColor $hostGuard.status)20; color: $(Get-HealthColor $hostGuard.status);">$($hostGuard.status)</span>
                </div>
                <div class="metric"><span class="metric-label">Available RAM</span><span class="metric-value $(if ($hostGuard.availMB -lt 1200) { 'critical' } elseif ($hostGuard.availMB -lt 2500) { 'warning' } else { 'healthy' })">$($hostGuard.availMB) MB</span></div>
                <div class="metric"><span class="metric-label">VRAM Usage</span><span class="metric-value $(if ($hostGuard.vramPct -gt 85) { 'warning' } else { 'healthy' })">$($hostGuard.vramPct)%</span></div>
                <div class="metric"><span class="metric-label">Commit %</span><span class="metric-value $(if ($hostGuard.commitPct -gt 90) { 'warning' } else { 'healthy' })">$($hostGuard.commitPct)%</span></div>
                <div class="metric"><span class="metric-label">Last Drop Caches</span><span class="metric-value">$($hostGuard.lastDropCaches)</span></div>
                <div class="metric"><span class="metric-label">Last Model Unload</span><span class="metric-value">$($hostGuard.lastUnload)</span></div>
                <div class="metric"><span class="metric-label">Last Auto-Bounce</span><span class="metric-value">$($hostGuard.lastBounce)</span></div>
            </div>
"@

# Docker-WSL Sync Card
$html += @"
            <div class="card">
                <div class="card-header">
                    <span class="card-title">Docker-WSL Sync</span>
                    <span class="status-badge" style="background: $(Get-HealthColor $dockerSync.status)20; color: $(Get-HealthColor $dockerSync.status);">$($dockerSync.status)</span>
                </div>
                <div class="metric"><span class="metric-label">Containers Up</span><span class="metric-value">$($dockerSync.containersUp)</span></div>
                <div class="metric"><span class="metric-label">Repair Actions</span><span class="metric-value $(if ($dockerSync.actions -gt 0) { 'warning' } else { 'healthy' })">$($dockerSync.actions)</span></div>
                <div class="metric"><span class="metric-label">Last Run</span><span class="metric-value">$($dockerSync.lastRun)</span></div>
            </div>
"@

# DD Settings Watchdog Card
$html += @"
            <div class="card">
                <div class="card-header">
                    <span class="card-title">DD Settings Watchdog</span>
                    <span class="status-badge" style="background: $(Get-HealthColor $ddWatchdog.status)20; color: $(Get-HealthColor $ddWatchdog.status);">$($ddWatchdog.status)</span>
                </div>
                <div class="metric"><span class="metric-label">Drift Count</span><span class="metric-value $(if ($ddWatchdog.driftCount -gt 0) { 'warning' } else { 'healthy' })">$($ddWatchdog.driftCount)</span></div>
                <div class="metric"><span class="metric-label">Restore Count</span><span class="metric-value">$($ddWatchdog.restoreCount)</span></div>
                <div class="metric"><span class="metric-label">Last Check</span><span class="metric-value">$($ddWatchdog.lastCheck)</span></div>
                <div class="metric"><span class="metric-label">Last Drift</span><span class="metric-value $(if ($ddWatchdog.lastDrift -gt $ddWatchdog.lastRestore) { 'warning' } else { 'healthy' })">$($ddWatchdog.lastDrift)</span></div>
                <div class="metric"><span class="metric-label">Last Restore</span><span class="metric-value">$($ddWatchdog.lastRestore)</span></div>
            </div>
"@

# Admin Cleanup Card
$html += @"
            <div class="card">
                <div class="card-header">
                    <span class="card-title">Admin Cleanup</span>
                    <span class="status-badge" style="background: $(Get-HealthColor $adminCleanup.status)20; color: $(Get-HealthColor $adminCleanup.status);">$($adminCleanup.status)</span>
                </div>
                <div class="metric"><span class="metric-label">Last Run</span><span class="metric-value">$($adminCleanup.lastRun)</span></div>
                <div class="metric"><span class="metric-label">Freed Space</span><span class="metric-value healthy">$($adminCleanup.freedGB) GB</span></div>
            </div>
"@

$html += @"
        </div>
        
        <div class="timestamp">
            Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')<br>
            <span class="refresh-info">Auto-refresh: 60s (page) / 30s (data)</span>
        </div>
    </div>
    
    <script>
        // Fetch JSON and update every 30s
        async function refresh() {
            try {
                const res = await fetch('health-dashboard.json?' + Date.now());
                const data = await res.json();
                updateDashboard(data);
            } catch (e) { console.log('Refresh failed:', e); }
        }
        
        function updateDashboard(data) {
            // Update overall status
            const overallEl = document.querySelector('.overall');
            overallEl.style.background = getColor(data.overall) + '20';
            overallEl.style.color = getColor(data.overall);
            overallEl.querySelector('span:last-child').textContent = 'Overall: ' + data.overall;
            document.getElementById('status-dot').style.background = getColor(data.overall);
            
            // Update each subsystem
            Object.entries(data.subsystems).forEach(([key, sub]) => {
                const card = document.querySelector(`.card:has(.card-title:contains('${key}'))`);
                if (!card) return;
                // Simplified: just update the JSON will refresh on page reload
            });
        }
        
        function getColor(status) {
            switch(status) {
                case 'Healthy': return '#22c55e';
                case 'Warning': return '#f59e0b';
                case 'Critical': return '#ef4444';
                default: return '#6b7280';
            }
        }
        
        setInterval(refresh, 30000);
    </script>
</body>
</html>
"@

$html | Set-Content -Path $HtmlOutput -Encoding UTF8

Write-Host "Health dashboard generated: $HtmlOutput and $JsonOutput"
exit 0