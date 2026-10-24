<#
.SYNOPSIS
    Pre-hook for Devin CLI commands - validates environment before running Devin operations
.DESCRIPTION
    Checks WSL status, Devin installation, and memory before allowing Devin commands to proceed
#>

param(
    [string]$ToolName,
    [string]$ToolInput
)

$ErrorActionPreference = 'SilentlyContinue'

function Log-Hook {
    param([string]$Message)
    $logFile = "D:\DevOptimizer\logs\devin-hooks.log"
    Add-Content -Path $logFile -Value ("{0} [PRE-HOOK] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

Log-Hook "Tool: $ToolName"

# Check WSL is reachable
$distro = 'Ubuntu-26.04'
$ping = & wsl.exe -d $distro -- bash -c 'echo ok' 2>$null
if ($ping -notmatch 'ok') {
    Log-Hook "BLOCK: WSL distro '$distro' unreachable"
    Write-Output '{"decision": "block", "reason": "WSL distro unreachable. Run `wsl -d Ubuntu-26.04 --exec true` first."}'
    exit 2
}

# Check host memory
$os = Get-CimInstance Win32_OperatingSystem
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
if ($freeGB -lt 1.5) {
    Log-Hook "WARN: Host memory low: ${freeGB} GB"
    Write-Output '{"decision": "approve", "additionalContext": "Host memory low (' + $freeGB + ' GB). Devin operations may fail."}'
    exit 0
}

# Check Devin Desktop is installed
$devinExe = Join-Path $env:LOCALAPPDATA 'Programs\Devin\Devin.exe'
if (-not (Test-Path $devinExe)) {
    Log-Hook "BLOCK: Devin Desktop not installed"
    Write-Output '{"decision": "block", "reason": "Devin Desktop not found at ' + $devinExe + '"}'
    exit 2
}

Log-Hook "APPROVE: Environment checks passed"
Write-Output '{"decision": "approve"}'
exit 0