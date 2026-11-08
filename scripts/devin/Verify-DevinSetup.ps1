<#
.SYNOPSIS
    Verify Devin Desktop and CLI setup
.DESCRIPTION
    Comprehensive verification of Devin Desktop, CLI, WSL integration, and DevOptimizer integration
#>
param(
    [switch]$FixIssues
)

$ErrorActionPreference = 'SilentlyContinue'

$script:results = @()

function Log {
    param($msg, [string]$Level = 'INFO')
    $prefix = switch ($Level) { 'OK' { '[OK]' } 'WARN' { '[!]' } 'FAIL' { '[X]' } 'FIX' { '[>]' } default { '[i]' } }
    $color = if ($Level -eq 'OK') { 'Green' } elseif ($Level -eq 'WARN') { 'Yellow' } elseif ($Level -eq 'FAIL') { 'Red' } elseif ($Level -eq 'FIX') { 'Cyan' } else { 'White' }
    Write-Host "$prefix $msg" -ForegroundColor $color
}

function Add-Result {
    param([string]$Check, [string]$Status, [string]$Detail, [string]$Fix = '')
    $script:results += [pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail; Fix = $Fix }
}

Write-Host "=== Devin Setup Verification ===" -ForegroundColor Cyan

# 1. Devin Desktop Installation
$devinExe = Join-Path $env:LOCALAPPDATA 'Programs\Devin\Devin.exe'
if (Test-Path $devinExe) {
    $version = (Get-Item $devinExe).VersionInfo.ProductVersion
    Add-Result 'Devin Desktop' 'OK' "Version $version at $devinExe"
    Log "Devin Desktop: $version" 'OK'
} else {
    Add-Result 'Devin Desktop' 'FAIL' "Not found at $devinExe" "Run Install-DevinCLI.ps1 or download from https://devin.ai"
    Log "Devin Desktop: NOT FOUND" 'FAIL'
}

# 2. Devin CLI (devin-desktop is the actual executable)
$devinCli = Get-Command devin-desktop -ErrorAction SilentlyContinue
if ($devinCli) {
    $version = & devin-desktop --version 2>&1 | Select-Object -First 1
    Add-Result 'Devin CLI' 'OK' "Version: $version at $($devinCli.Source)"
    Log "Devin CLI: $version" 'OK'
} else {
    Add-Result 'Devin CLI' 'WARN' "Not in PATH" "Run Install-DevinCLI.ps1 or restart terminal"
    Log "Devin CLI: Not in PATH" 'WARN'
}

# 3. WSL Ubuntu-24.04
$distro = 'Ubuntu-24.04'
$ping = & wsl.exe -d $distro -- bash -c 'echo ok' 2>$null
if ($ping -match 'ok') {
    $uptime = & wsl.exe -d $distro -- bash -c 'cat /proc/uptime' 2>$null
    $upSec = [double]($uptime -split '\s+')[0]
    Add-Result 'WSL Ubuntu-24.04' 'OK' "Reachable, uptime: $([timespan]::FromSeconds($upSec))"
    Log "WSL: Reachable ($([timespan]::FromSeconds($upSec)))" 'OK'
} else {
    Add-Result 'WSL Ubuntu-24.04' 'FAIL' "Unreachable" "Run: wsl -d Ubuntu-24.04 --exec true"
    Log "WSL: UNREACHABLE" 'FAIL'
}

# 4. devin-server in WSL
$procs = & wsl.exe -d $distro -- bash -c "pgrep -af 'devin acp' || true" 2>$null
if ($procs -match '\.devin-server/bin/([a-f0-9]{40})/') {
    $commit = $Matches[1]
    Add-Result 'devin-server' 'OK' "Running (commit $commit)"
    Log "devin-server: Running ($commit)" 'OK'
} else {
    Add-Result 'devin-server' 'WARN' "Not running" "Click 'Reload Window' in Devin Desktop"
    Log "devin-server: Not running" 'WARN'
}

# 5. Host Memory
$os = Get-CimInstance Win32_OperatingSystem
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
if ($freeGB -ge 2) {
    Add-Result 'Host Memory' 'OK' "${freeGB} GB free"
    Log "Host Memory: ${freeGB} GB" 'OK'
} elseif ($freeGB -ge 1) {
    Add-Result 'Host Memory' 'WARN' "${freeGB} GB free - low" "Run win11-safe-cleanup.ps1 -RunNow"
    Log "Host Memory: ${freeGB} GB (LOW)" 'WARN'
} else {
    Add-Result 'Host Memory' 'FAIL' "${freeGB} GB free - critical" "Run win11-admin-cleanup-elevated.ps1 -Force (elevated)"
    Log "Host Memory: ${freeGB} GB (CRITICAL)" 'FAIL'
}

# 6. Credentials
$credsFile = Join-Path $env:APPDATA 'devin\credentials.toml'
if (Test-Path $credsFile) {
    Add-Result 'Credentials' 'OK' "Found at $credsFile"
    Log "Credentials: Found" 'OK'
} else {
    Add-Result 'Credentials' 'WARN' "Not found (CLI auth not configured)" "Run: devin login  OR create $credsFile with api_key"
    Log "Credentials: Not found" 'WARN'
}

# 7. DevOptimizer Scripts
$scriptsDir = "D:\DevOptimizer\scripts\devin"
$requiredScripts = @('Check-DevinHealth.ps1', 'Get-DevinDiagnostics.ps1', 'Check-DevinDoctor.ps1', 'Invoke-DevinDailyMaintenance.ps1', 'Repair-Devin.ps1', 'Tune-Windows-For-Devin.ps1')
$missing = @()
foreach ($s in $requiredScripts) {
    if (-not (Test-Path (Join-Path $scriptsDir $s))) { $missing += $s }
}
if ($missing.Count -eq 0) {
    Add-Result 'DevOptimizer Scripts' 'OK' "All 6 scripts present"
    Log "DevOptimizer Scripts: All present" 'OK'
} else {
    Add-Result 'DevOptimizer Scripts' 'FAIL' "Missing: $($missing -join ', ')"
    Log "DevOptimizer Scripts: MISSING $($missing.Count)" 'FAIL'
}

# 8. DevOptimizer Integration (MCP, hooks, skills)
$devinConfigDir = Join-Path $env:APPDATA 'devin'
$configFiles = @('mcp_config.json', 'hooks.v1.json')
$configMissing = @()
foreach ($f in $configFiles) {
    if (-not (Test-Path (Join-Path $devinConfigDir $f))) { $configMissing += $f }
}
if (Test-Path (Join-Path $devinConfigDir 'skills\devin-integration\SKILL.md')) {
    $skillOk = $true
} else {
    $skillOk = $false
    $configMissing += 'skills/devin-integration/SKILL.md'
}
if ($configMissing.Count -eq 0 -and $skillOk) {
    Add-Result 'DevOptimizer Integration' 'OK' "MCP config, hooks, and skill configured"
    Log "DevOptimizer Integration: Configured" 'OK'
} else {
    Add-Result 'DevOptimizer Integration' 'WARN' "Missing: $($configMissing -join ', ')"
    Log "DevOptimizer Integration: Missing configs" 'WARN'
}

# 9. Scheduled Task
$task = Get-ScheduledTask -TaskName 'Devin-Daily-Maintenance' -ErrorAction SilentlyContinue
if ($task) {
    Add-Result 'Daily Maintenance Task' 'OK' "Registered: \DevOptimizer\Devin-Daily-Maintenance"
    Log "Daily Maintenance Task: Registered" 'OK'
} else {
    Add-Result 'Daily Maintenance Task' 'WARN' "Not registered" "Run Register-Devin-Maintenance.ps1"
    Log "Daily Maintenance Task: Not registered" 'WARN'
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
$ok = ($script:results | Where-Object { $_.Status -eq 'OK' }).Count
$warn = ($script:results | Where-Object { $_.Status -eq 'WARN' }).Count
$fail = ($script:results | Where-Object { $_.Status -eq 'FAIL' }).Count
$summaryColor = if ($fail -gt 0) { 'Red' } elseif ($warn -gt 0) { 'Yellow' } else { 'Green' }
Write-Host "OK: $ok  WARN: $warn  FAIL: $fail" -ForegroundColor $summaryColor

# Show failed checks
$fails = $script:results | Where-Object { $_.Status -eq 'FAIL' }
if ($fails.Count -gt 0) {
    Write-Host "`nFAILED CHECKS:" -ForegroundColor Red
    foreach ($f in $fails) {
        Write-Host "  X $($f.Check): $($f.Detail)" -ForegroundColor Red
        if ($f.Fix) { Write-Host "    Fix: $($f.Fix)" -ForegroundColor Cyan }
    }
}

# Auto-fix if requested
if ($FixIssues -and ($warn -gt 0 -or $fail -gt 0)) {
    Write-Host "`n=== AUTO-FIX ===" -ForegroundColor Cyan
    Log "Auto-fix not yet implemented - run individual fix scripts" 'WARN'
}

# Exit code
if ($fail -gt 0) { exit 1 }
if ($warn -gt 0) { exit 2 }
exit 0