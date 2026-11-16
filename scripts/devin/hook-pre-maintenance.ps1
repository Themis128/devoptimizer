<#
.SYNOPSIS
    Pre-hook for Devin maintenance commands - ensures safe execution conditions
.DESCRIPTION
    Validates that maintenance operations can run safely (Devin not running for bundle repairs, etc.)
#>

param(
    [string]$ToolName,
    [string]$ToolInput
)

$ErrorActionPreference = 'SilentlyContinue'

function Log-Hook {
    param([string]$Message)
    $logFile = "D:\DevOptimizer\logs\devin-hooks.log"
    Add-Content -Path $logFile -Value ("{0} [MAINT-HOOK] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

Log-Hook "Maintenance tool: $ToolName"

# Check if Devin is running (for bundle repairs)
$appProc = Get-Process -Name 'Devin' -ErrorAction SilentlyContinue
$devinRunning = [bool]$appProc

# Parse tool input for repair flags
$isRepair = $ToolName -match 'Repair-Devin'
$isFixBundle = $ToolInput -match 'FixBundle'

if ($isRepair -and $isFixBundle -and $devinRunning) {
    Log-Hook "DEFER: -FixBundle requested but Devin is running"
    Write-Output '{"decision": "approve", "additionalContext": "Devin is running - bundle repair will be DEFERRED until Devin closes. Close Devin first for immediate repair."}'
    exit 0
}

# Check WSL
$distro = 'Ubuntu-24.04'
$ping = & wsl.exe -d $distro -- bash -c 'echo ok' 2>$null
if ($ping -notmatch 'ok') {
    Log-Hook "BLOCK: WSL unreachable for maintenance"
    Write-Output '{"decision": "block", "reason": "WSL distro unreachable. Maintenance requires WSL."}'
    exit 2
}

Log-Hook "APPROVE: Maintenance checks passed"
Write-Output '{"decision": "approve"}'
exit 0