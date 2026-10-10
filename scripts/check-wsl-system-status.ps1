<#
.SYNOPSIS
    WSL & system fine-tune status -- one-shot health view of the WSL stack and this host.

.DESCRIPTION
    Read-only consolidation of the 2026-10-02 fine-tune work:
      1. WSL memory limits in effect (RAM / swap inside the VM) -- the 20GB/16GB wedge fix
      2. Swap pressure + vmmemWSL working set (the wedge precondition that killed Devin sessions)
      3. On-demand container set state (containers converted from always-restart to restart=no)
      4. Host RAM and Docker disk usage summary
      5. Optional: -ApplySafeCleanup runs scripts\win11-safe-cleanup.ps1 (user-level safe set)
    Safe to run any time; never starts the WSL VM if it is shut down.

.PARAMETER ApplySafeCleanup
    Also run the user-level safe cleanup (win11-safe-cleanup.ps1) after the status report.

.EXAMPLE
    .\check-wsl-system-status.ps1
    .\check-wsl-system-status.ps1 -ApplySafeCleanup
#>
[CmdletBinding()]
param(
    [switch]$ApplySafeCleanup
)

function Show-Progress {
    param([string]$Activity, [string]$Status, [int]$PercentComplete)
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $Status
}

function Write-VerboseStep {
    param([string]$Message)
    Write-Host "[VERBOSE] $Message" -ForegroundColor Cyan
}

$ErrorActionPreference = 'SilentlyContinue'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host "=== WSL & System Fine-Tune Status -- $stamp ==="

Show-Progress -Activity "WSL System Status" -Status "Initializing..." -PercentComplete 0

Show-Progress -Activity "WSL System Status" -Status "Checking host RAM..." -PercentComplete 10
Write-VerboseStep "Checking host RAM and vmmemWSL process"

# --- Host side -------------------------------------------------------------
$os = Get-CimInstance Win32_OperatingSystem
$hostFreeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$vmmem = Get-Process vmmemWSL -ErrorAction SilentlyContinue | Select-Object -First 1
$vmmemGB = if ($vmmem) { [math]::Round($vmmem.WS / 1GB, 2) } else { $null }
Write-Host ("Host RAM free : {0} GB of 31.7 GB" -f $hostFreeGB)
Write-Host ("vmmemWSL      : " + $(if ($vmmemGB) { "{0} GB working set (WSL running)" -f $vmmemGB } else { "not running (skipping in-VM checks)" }))

Show-Progress -Activity "WSL System Status" -Status "Checking WSL memory limits and swap pressure..." -PercentComplete 30
Write-VerboseStep "Checking WSL memory limits and swap pressure"

# --- In-VM limits & swap pressure ------------------------------------------
if ($vmmem) {
    $memLines = (wsl -e bash -c "free -m") -replace "`r", ""
    $memLine = $memLines | Where-Object { $_ -match '^Mem:' } | Select-Object -First 1
    $swapLine = $memLines | Where-Object { $_ -match '^Swap:' } | Select-Object -First 1
    if ($memLine -match '^Mem:\s+(\d+)\s+(\d+)') {
        Write-Host ("WSL RAM limit : {0} MB total, {1} MB used (cap from .wslconfig memory=)" -f $matches[1], $matches[2])
    }
    if ($swapLine -match '^Swap:\s+(\d+)\s+(\d+)') {
        $swapTotal = [int]$matches[1]
        $swapUsed = [int]$matches[2]
        $pct = 0
        if ($swapTotal -gt 0) { $pct = [math]::Round(100 * $swapUsed / $swapTotal) }
        $flag = ""
        if ($pct -ge 80) { $flag = "  [WEDGE RISK - event 1003 threshold]" }
        elseif ($pct -ge 60) { $flag = "  [elevated]" }
        Write-Host ("WSL swap      : {0}/{1} MB ({2}%){3}" -f $swapUsed, $swapTotal, $pct, $flag)
        Write-Host ("WSL swap cap  : 16384 MB expected from .wslconfig swap= (16GB fix live 2026-10-02)")
    }
} else {
    Write-Host "WSL limits    : n/a (VM down; .wslconfig memory=20GB swap=16GB applies at next start)"
}

Show-Progress -Activity "WSL System Status" -Status "Checking on-demand containers..." -PercentComplete 50
Write-VerboseStep "Checking on-demand container status"

# --- On-demand container set ------------------------------------------------
$onDemand = @('local-diffusers', 'browser-novnc', 'facebook-browser-sidecar', 'languagetool', 'metabase', 'social-media-comfyui-gpu')
$upNames = @(docker ps --format "{{.Names}}" 2>$null) -replace "`r", ""
$totalUp = ($upNames | Where-Object { $_ }).Count
Write-Host ""
Write-Host ("Docker        : {0} containers running" -f $totalUp)
foreach ($name in $onDemand) {
    $state = if ($upNames -contains $name) { "RUNNING (on-demand, started manually)" } else { "down (restart=no)" }
    Write-Host ("  on-demand   : {0,-28} {1}" -f $name, $state)
}

Show-Progress -Activity "WSL System Status" -Status "Checking Docker disk usage..." -PercentComplete 70
Write-VerboseStep "Checking Docker disk usage"

# --- Docker disk usage -------------------------------------------------------
$df = docker system df --format "{{.Type}}|{{.Size}}|{{.Reclaimable}}" 2>$null
if ($df) {
    Write-Host ""
    Write-Host "Docker disk usage:"
    foreach ($line in $df) {
        $p = $line -replace "`r", "" -split '\|'
        if ($p.Count -ge 3) { Write-Host ("  {0,-12} {1,-12} reclaimable {2}" -f $p[0], $p[1], $p[2]) }
    }
}

Show-Progress -Activity "WSL System Status" -Status "Running optional safe cleanup..." -PercentComplete 85
Write-VerboseStep "Running optional safe cleanup (if requested)"

# --- Optional safe cleanup ---------------------------------------------------
if ($ApplySafeCleanup) {
    Write-Host ""
    Write-Host "=== Running user-level safe cleanup ==="
    & (Join-Path $PSScriptRoot 'win11-safe-cleanup.ps1')
}

Show-Progress -Activity "WSL System Status" -Status "Complete" -PercentComplete 100
Write-VerboseStep "WSL system status check complete"

Write-Host ""
Write-Host "Done. Watchdog history: logs\wsl-memory-pressure.log (task \DevOptimizer\WSL-Memory-Watchdog, every 30 min)"
