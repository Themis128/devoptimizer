#Requires -Version 5.1
<#
.SYNOPSIS
    Runner for the DevOptimizer application test suite (Pester 5+).

.DESCRIPTION
    Runs tests\app\*.Tests.ps1. Installs Pester 5+ to the CurrentUser module
    path if missing (no elevation). Prefers Windows PowerShell 5.1 - the app's
    host - but works under pwsh 7 as well.

.EXAMPLE
    pwsh  -NoProfile -File scripts\Test-App.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Test-App.ps1 -CI
#>

param(
    [switch]$CI,        # CI mode: minimal output, exit code only
    [string]$Tag        # optional Pester -Tag filter
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$env:DEVOPT_ROOT = $root
$testDir = Join-Path $root 'tests\app'

# Prefer the app's real host (Windows PowerShell 5.1) when invoked from pwsh
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $env:DEVOPT_ALLOW_PWSH) {
    $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path $ps51) {
        $fwd = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path)
        if ($CI) { $fwd += '-CI' }
        if ($Tag) { $fwd += @('-Tag', $Tag) }
        & $ps51 @fwd
        exit $LASTEXITCODE
    }
}

function Ensure-Pester {
    $p = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Sort-Object Version -Descending | Select-Object -First 1
    if ($p) { return $p }
    Write-Host 'Pester 5+ not found - installing to CurrentUser (no elevation)...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try { $null = Get-PackageProvider -Name NuGet -ErrorAction Stop } catch {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }
    Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
    return (Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } |
        Sort-Object Version -Descending | Select-Object -First 1)
}

$pester = Ensure-Pester
if (-not $pester) { throw 'Pester 5+ could not be installed or found.' }
Write-Host ("DevOptimizer app tests - Pester {0} on PowerShell {1}" -f $pester.Version, $PSVersionTable.PSVersion)

Import-Module Pester -MinimumVersion 5.0 -Force

$pesterArgs = @{
    Path        = $testDir
    Output      = if ($CI) { 'Normal' } else { 'Detailed' }
    PassThru    = $true
}
if ($Tag) { $pesterArgs.Tag = $Tag }

$result = Invoke-Pester @pesterArgs
$failed = $result.FailedCount
$total  = $result.TotalCount
$skipped = if ($result.Skipped -is [int]) { $result.Skipped } else { @($result.Skipped).Count }
Write-Host ''
Write-Host ("App tests: {0} total, {1} passed, {2} failed, {3} skipped" -f $total, $result.PassedCount, $failed, $skipped)
if ($failed -gt 0) { exit 1 }
exit 0
