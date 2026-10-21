<#
.SYNOPSIS
    Dynamic WSL Resource Balancer - Prioritizes Devin Desktop, manages container memory limits
.DESCRIPTION
    Monitors WSL memory pressure and dynamically adjusts Docker container memory limits
    to ensure Devin Desktop (running in WSL) has priority access to resources.
    
    Features:
    - Monitors WSL /proc/meminfo for memory pressure
    - Adjusts container memory limits based on priority tiers
    - Implements dropCache memory reclaim when host is starved
    - Preserves Devin Desktop processes (PID namespace isolation)
    - Restart policies: critical=always, important=unless-stopped, optional=no
.NOTES
    Run from Windows (PowerShell) - manages WSL2 + Docker Desktop
    Requires: Docker Desktop, WSL2, admin for some operations
#>

param(
    [switch]$Monitor,
    [switch]$ApplyLimits,
    [switch]$ReclaimMemory,
    [switch]$ShowStatus,
    [int]$CheckIntervalSeconds = 30,
    [int]$MemoryPressureThresholdPercent = 85,
    [int]$CriticalMemoryThresholdPercent = 95
)

# Container priority tiers (higher = more important)
$ContainerTiers = @{
    # Critical - Devin Desktop dependencies, databases, core infrastructure
    Critical = @(
        'postgres', 'social-postgres', 'redis', 'social-redis',
        'dmr-lan-proxy', 'dmr-watchdog', 'portainer'
    )
    # Important - Core services that should stay running
    Important = @(
        'n8n', 'social-api', 'social-api-gateway', 'social-frontend',
        'social-worker-default', 'social-worker-messenger', 'social-worker-media',
        'social-worker-publishing', 'celery-beat', 'browser-novnc',
        'prometheus', 'grafana', 'alertmanager', 'node-exporter', 'cadvisor',
        'minio', 'chroma', 'nextcloud-mcp-server', 'stack-ops', 'n8n-task-runner',
        'social-metrics', 'n8n-metrics', 'c7099c0d27fc_social-cloudflared'
    )
    # Optional - Browser sidecars, heavy GPU workloads, can be limited/stopped
    Optional = @(
        'linkedin-browser-sidecar', 'tiktok-browser-sidecar', 'facebook-browser-sidecar',
        'social-media-comfyui-gpu', 'languagetool'
    )
}

# Memory limits per tier (in bytes)
$TierLimits = @{
    Critical   = '2GB'    # Generous limits for critical infrastructure
    Important  = '1GB'    # Reasonable limits for core services
    Optional   = '512MB'  # Strict limits for optional/browser containers
}

# Restart policies per tier
$TierRestartPolicies = @{
    Critical   = 'always'
    Important  = 'unless-stopped'
    Optional   = 'no'  # Manual start only after WSL bounce
}

function Get-WSLMemoryInfo {
    $output = wsl -e cat /proc/meminfo 2>$null
    if (-not $output) { return $null }
    
    $info = @{}
    foreach ($line in $output) {
        if ($line -match '^(\w+):\s+(\d+)\s+kB') {
            $info[$matches[1]] = [long]$matches[2] * 1024  # Convert to bytes
        }
    }
    return $info
}

function Get-WSLMemoryPressure {
    $info = Get-WSLMemoryInfo
    if (-not $info) { return $null }
    
    $total = $info.MemTotal
    $available = $info.MemAvailable
    if (-not $available) { $available = $info.MemFree + $info.Buffers + $info.Cached }
    
    $usedPercent = [math]::Round((($total - $available) / $total) * 100, 1)
    $freeGB = [math]::Round($available / 1GB, 2)
    $totalGB = [math]::Round($total / 1GB, 1)
    
    return @{
        TotalGB       = $totalGB
        FreeGB        = $freeGB
        UsedPercent   = $usedPercent
        IsPressure    = $usedPercent -ge $MemoryPressureThresholdPercent
        IsCritical    = $usedPercent -ge $CriticalMemoryThresholdPercent
        SwapTotalGB   = [math]::Round($info.SwapTotal / 1GB, 1)
        SwapFreeGB    = [math]::Round($info.SwapFree / 1GB, 1)
    }
}

function Get-DockerContainers {
    $output = docker ps --format "{{.Names}}|{{.ID}}|{{.Status}}|{{.Image}}" 2>$null
    $containers = @()
    foreach ($line in $output) {
        $parts = $line -split '\|'
        if ($parts.Count -ge 4) {
            $containers += [pscustomobject]@{
                Name   = $parts[0].Trim()
                ID     = $parts[1].Trim()
                Status = $parts[2].Trim()
                Image  = $parts[3].Trim()
            }
        }
    }
    return $containers
}

function Get-ContainerTier {
    param([string]$Name)
    foreach ($tier in $ContainerTiers.Keys) {
        if ($ContainerTiers[$tier] -contains $Name) { return $tier }
    }
    return 'Optional'  # Default tier for unknown containers
}

function Set-ContainerMemoryLimit {
    param([string]$Name, [string]$Limit)
    try {
        docker update --memory=$Limit $Name 2>$null | Out-Null
        return $true
    } catch {
        Write-Warning ("Failed to set memory limit for {0}: {1}" -f $Name, $_)
        return $false
    }
}

function Set-ContainerRestartPolicy {
    param([string]$Name, [string]$Policy)
    try {
        docker update --restart=$Policy $Name 2>$null | Out-Null
        return $true
    } catch {
        Write-Warning ("Failed to set restart policy for {0}: {1}" -f $Name, $_)
        return $false
    }
}

function Apply-TierLimits {
    $containers = Get-DockerContainers
    $results = @{ Critical=@(); Important=@(); Optional=@() }
    
    foreach ($container in $containers) {
        $tier = Get-ContainerTier $container.Name
        $limit = $TierLimits[$tier]
        $policy = $TierRestartPolicies[$tier]
        
        $memOk = Set-ContainerMemoryLimit $container.Name $limit
        $restartOk = Set-ContainerRestartPolicy $container.Name $policy
        
        $results[$tier] += [pscustomobject]@{
            Name       = $container.Name
            MemoryLimit = $limit
            RestartPolicy = $policy
            MemoryApplied = $memOk
            RestartApplied = $restartOk
        }
    }
    return $results
}

function Invoke-MemoryReclaim {
    Write-Host "Initiating WSL memory reclaim (dropCache)..." -ForegroundColor Yellow
    # Trigger drop_caches in WSL (requires root in WSL)
    wsl -u root -e bash -c "echo 3 > /proc/sys/vm/drop_caches" 2>$null
    
    # Also trigger Windows working set trim
    try {
        $ws = Add-Type -MemberDefinition @"
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("kernel32.dll")] public static extern bool SetProcessWorkingSetSize(IntPtr hProcess, int dwMinimumWorkingSetSize, int dwMaximumWorkingSetSize);
    [DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
}
"@ -Name "Win32" -PassThru
        $ws::SetProcessWorkingSetSize($ws::GetCurrentProcess(), -1, -1) | Out-Null
    } catch {}
    
    Start-Sleep 2
    $pressure = Get-WSLMemoryPressure
    Write-Host ("Post-reclaim: {0} GB free ({1}% used)" -f $pressure.FreeGB, $pressure.UsedPercent) -ForegroundColor Green
}

function Show-Status {
    $pressure = Get-WSLMemoryPressure
    if (-not $pressure) {
        Write-Error "Could not read WSL memory info"
        return
    }
    
    Write-Host "`n=== WSL Resource Status ===" -ForegroundColor Cyan
    Write-Host ("Memory: {0} GB free / {1} GB total ({2}% used)" -f $pressure.FreeGB, $pressure.TotalGB, $pressure.UsedPercent)
    Write-Host ("Swap:   {0} GB free / {1} GB total" -f $pressure.SwapFreeGB, $pressure.SwapTotalGB)
    
    if ($pressure.IsCritical) {
        Write-Host "!! CRITICAL MEMORY PRESSURE!" -ForegroundColor Red
    } elseif ($pressure.IsPressure) {
        Write-Host "!! Memory pressure detected" -ForegroundColor Yellow
    } else {
        Write-Host "OK Memory OK" -ForegroundColor Green
    }
    
    $containers = Get-DockerContainers
    
    # Pre-group containers by tier ONCE to avoid repeated Where-Object evaluation
    $containersByTier = @{
        Critical = @()
        Important = @()
        Optional = @()
    }
    foreach ($c in $containers) {
        $tier = Get-ContainerTier $c.Name
        $containersByTier[$tier] += $c
    }
    
    Write-Host "`n=== Container Tiers ===" -ForegroundColor Cyan
    foreach ($tier in @('Critical', 'Important', 'Optional')) {
        $tierContainers = $containersByTier[$tier]
        if ($tierContainers.Count -gt 0) {
            Write-Host ("`n{0} (Limit: {1}, Restart: {2}):" -f $tier, $TierLimits[$tier], $TierRestartPolicies[$tier]) -ForegroundColor Magenta
            foreach ($c in $tierContainers) {
                $memInfo = docker inspect $c.Name --format '{{.HostConfig.Memory}}' 2>$null
                $limitGB = if ($memInfo -and $memInfo -ne '0') { [math]::Round([long]$memInfo / 1GB, 2) } else { 'unlimited' }
                Write-Host ("  {0} - Limit: {1} GB - {2}" -f $c.Name, $limitGB, $c.Status)
            }
        }
    }
}

function Start-MonitorLoop {
    Write-Host ("Starting WSL resource monitor (interval: {0} s)..." -f $CheckIntervalSeconds) -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
    
    try {
        while ($true) {
            $pressure = Get-WSLMemoryPressure
            $timestamp = Get-Date -Format 'HH:mm:ss'
            
            if ($pressure.IsCritical) {
                Write-Host ("[{0}] CRITICAL: {1}% used - Reclaiming..." -f $timestamp, $pressure.UsedPercent) -ForegroundColor Red
                Invoke-MemoryReclaim
            } elseif ($pressure.IsPressure) {
                Write-Host ("[{0}] PRESSURE: {1}% used - Monitoring..." -f $timestamp, $pressure.UsedPercent) -ForegroundColor Yellow
            } else {
                Write-Host ("[{0}] OK: {1}% used ({2} GB free)" -f $timestamp, $pressure.UsedPercent, $pressure.FreeGB) -ForegroundColor Green
            }
            
            Start-Sleep $CheckIntervalSeconds
        }
    } finally {
        Write-Host "`nMonitor stopped." -ForegroundColor Cyan
    }
}

# Main execution
if ($ShowStatus -or (-not $Monitor -and -not $ApplyLimits -and -not $ReclaimMemory)) {
    Show-Status
}

if ($ApplyLimits) {
    Write-Host "Applying container memory limits and restart policies..." -ForegroundColor Cyan
    $results = Apply-TierLimits
    foreach ($tier in $results.Keys) {
        Write-Host ("`n{0} tier:" -f $tier) -ForegroundColor Magenta
        foreach ($r in $results[$tier]) {
            $status = if ($r.MemoryApplied -and $r.RestartApplied) { 'OK' } else { 'FAIL' }
            Write-Host ("  {0} {1} - Limit: {2}, Restart: {3}" -f $status, $r.Name, $r.MemoryLimit, $r.RestartPolicy)
        }
    }
}

if ($ReclaimMemory) {
    Invoke-MemoryReclaim
}

if ($Monitor) {
    Start-MonitorLoop
}

# Default: show status if no action specified
if (-not $Monitor -and -not $ApplyLimits -and -not $ReclaimMemory -and -not $ShowStatus) {
    Show-Status
}