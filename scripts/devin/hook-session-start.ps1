<#
.SYNOPSIS
    SessionStart hook - runs when Devin CLI session starts
.DESCRIPTION
    Performs quick health check and logs session start for audit trail
#>

param(
    [string]$ToolName,
    [string]$ToolInput
)

$ErrorActionPreference = 'SilentlyContinue'

function Log-Hook {
    param([string]$Message)
    $logFile = "D:\DevOptimizer\logs\devin-hooks.log"
    Add-Content -Path $logFile -Value ("{0} [SESSION] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

Log-Hook "Devin CLI session started"

# Quick WSL check
$distro = 'Ubuntu-24.04'
$ping = & wsl.exe -d $distro -- bash -c 'echo ok' 2>$null
$wslOk = $ping -match 'ok'

# Host memory
$os = Get-CimInstance Win32_OperatingSystem
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)

# Devin version
$devinExe = Join-Path $env:LOCALAPPDATA 'Programs\Devin\Devin.exe'
$version = if (Test-Path $devinExe) { (Get-Item $devinExe).VersionInfo.ProductVersion } else { 'NOT_INSTALLED' }

$context = @{
    wslReachable = $wslOk
    hostFreeGB = $freeGB
    devinVersion = $version
    timestamp = (Get-Date).ToString('o')
} | ConvertTo-Json -Compress

Log-Hook "Session context: $context"

# Inject context for the session
Write-Output (@"
{
  "decision": "approve",
  "additionalContext": "DevOptimizer session start: WSL=$($wslOk), HostMem=${freeGB}GB, Devin=$version. Run `/devin-health` for full check."
}
"@)

exit 0