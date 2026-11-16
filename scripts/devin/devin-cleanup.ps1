<#
.SYNOPSIS
    Devin Desktop cleanup wrapper - calls devin-doctor and DevOptimizer maintenance scripts
.DESCRIPTION
    Unified entry point for all devin-cleanup skill commands.
    Runs devin-doctor via WSL or DevOptimizer scripts via PowerShell.
#>
param(
    [ValidateSet('check', 'report', 'plan', 'prune-acp', 'cleanup-sessions', 'daily-maintenance', 'health', 'diagnostics', 'repair-bundle', 'verify-setup')]
    [string]$Command,

    [int]$Days = 14,
    [string]$OutFile,
    [switch]$Force
)

$distro = 'Ubuntu-24.04'
$scriptRoot = $PSScriptRoot

function Invoke-Wsl([string]$cmd) {
    # Use cmd /c to properly capture wsl.exe output
    $escapedCmd = $cmd -replace '"', '\"'
    $fullCmd = "wsl.exe -d $distro -- bash -c `"$escapedCmd`""
    $out = cmd /c $fullCmd 2>&1
    $joined = (@($out) -join "`n") -replace "`0", ''
    return ($joined -split "`r?`n") | Where-Object { $_ -ne '' }
}

function Run-DevinDoctor([string]$subCmd, [string[]]$extraArgs = @()) {
    # devin-doctor mcp doesn't take subcommands; we call CLI directly for check/report/plan
    $cmd = 'export PATH="$HOME/.local/bin:$PATH" && devin-doctor ' + $subCmd
    return Invoke-Wsl $cmd
}

switch ($Command) {
    'check' {
        Write-Host "=== devin-doctor check ===" -ForegroundColor Cyan
        Run-DevinDoctor 'check'
    }
    'report' {
        Write-Host "=== devin-doctor report ===" -ForegroundColor Cyan
        Run-DevinDoctor 'report'
    }
    'plan' {
        Write-Host "=== devin-doctor plan ===" -ForegroundColor Cyan
        Run-DevinDoctor 'plan'
    }
    'prune-acp' {
        Write-Host "=== Pruning ACP messages (${Days}d retention) ===" -ForegroundColor Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path $scriptRoot -Parent) 'prune-acp.ps1') -Days $Days
    }
    'cleanup-sessions' {
        Write-Host "=== Cleaning superseded commit dirs and pruning server logs ===" -ForegroundColor Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'Repair-Devin.ps1') -CleanLeftovers -PruneServerLogs -Days $Days -Force
    }
    'daily-maintenance' {
        Write-Host "=== Running daily maintenance ===" -ForegroundColor Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'Invoke-DevinDailyMaintenance.ps1')
    }
    'health' {
        Write-Host "=== Devin Health Check ===" -ForegroundColor Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'Check-DevinHealth.ps1')
    }
    'diagnostics' {
        Write-Host "=== Devin Deep Diagnostics ===" -ForegroundColor Cyan
        $args = @()
        if ($OutFile) { $args += "-OutFile", $OutFile }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'Get-DevinDiagnostics.ps1') @args
    }
    'repair-bundle' {
        Write-Host "=== Repairing Corrupt Bundle ===" -ForegroundColor Cyan
        Write-Host "NOTE: After this runs, click 'Reload Window' in Devin Desktop to download fresh bundle (~700 MB)" -ForegroundColor Yellow
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'Repair-Devin.ps1') -FixBundle -Force
    }
    'verify-setup' {
        Write-Host "=== Verifying Devin Setup ===" -ForegroundColor Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'Verify-DevinSetup.ps1')
    }
}