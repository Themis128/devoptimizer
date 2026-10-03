<#
.SYNOPSIS
    DevOptimizer automation script: optimizer.
.DESCRIPTION
    DevOptimizer automation script: optimizer.
#>

# DevOptimizer Global Launcher
param(
    [switch]$Help,
    [switch]$List,
    [switch]$Status
)

$DevOptimizerPath = "D:\DevOptimizer"
$LauncherPath = "$DevOptimizerPath\00-LAUNCHER.bat"

function Show-Help {
    Write-Host "DevOptimizer Global Launcher" -ForegroundColor Cyan
    Write-Host "Usage: optimizer [options]" -ForegroundColor Yellow
    Write-Host "  -Help     Show this help message" -ForegroundColor White
    Write-Host "  -List     List available tools" -ForegroundColor White
    Write-Host "  -Status   Show system status" -ForegroundColor White
}

function Show-Status {
    Write-Host "DevOptimizer System Status" -ForegroundColor Cyan

    if (Test-Path $DevOptimizerPath) {
        Write-Host "DevOptimizer directory found" -ForegroundColor Green
    } else {
        Write-Host "DevOptimizer directory not found" -ForegroundColor Red
        return
    }

    if (Test-Path $LauncherPath) {
        Write-Host "Main launcher found" -ForegroundColor Green
    } else {
        Write-Host "Main launcher not found" -ForegroundColor Red
        return
    }

    $batFiles = Get-ChildItem -Path $DevOptimizerPath -Filter "*.bat" | Where-Object { $_.Name -notlike "00-SETUP*" }
    Write-Host "Found $($batFiles.Count) batch files" -ForegroundColor Green

    $psFiles = Get-ChildItem -Path $DevOptimizerPath -Filter "*.ps1"
    Write-Host "Found $($psFiles.Count) PowerShell scripts" -ForegroundColor Green

    $pathEnv = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($pathEnv -like "*$DevOptimizerPath*") {
        Write-Host "DevOptimizer is in system PATH" -ForegroundColor Green
    } else {
        Write-Host "DevOptimizer is not in system PATH" -ForegroundColor Red
    }
}

function Show-List {
    Write-Host "DevOptimizer Available Tools" -ForegroundColor Cyan

    $batFiles = Get-ChildItem -Path $DevOptimizerPath -Filter "*.bat" | Where-Object { $_.Name -notlike "00-SETUP*" } | Sort-Object Name

    Write-Host "Batch Files:" -ForegroundColor Yellow
    foreach ($file in $batFiles) {
        Write-Host "  $($file.Name)" -ForegroundColor White
    }

    Write-Host "PowerShell Scripts:" -ForegroundColor Yellow
    $psFiles = Get-ChildItem -Path $DevOptimizerPath -Filter "*.ps1" | Sort-Object Name
    foreach ($file in $psFiles) {
        Write-Host "  $($file.Name)" -ForegroundColor White
    }
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

if ($List) {
    Show-List
    exit 0
}

if ($Status) {
    Show-Status
    exit 0
}

# Default: Launch the main launcher
if (Test-Path $LauncherPath) {
    Write-Host "Launching DevOptimizer..." -ForegroundColor Cyan
    & cmd.exe /c $LauncherPath
} else {
    Write-Host "Error: DevOptimizer launcher not found" -ForegroundColor Red
    exit 1
}
