#Requires -Version 5.1
<#
.SYNOPSIS
    VS Code Insiders Startup Optimizer
.DESCRIPTION
    Launches VS Code Insiders with pre-cleanup and optimized settings
.PARAMETER Path
    Path or workspace to open
.PARAMETER CleanFirst
    Run cleanup before launching
.PARAMETER LowMemoryMode
    Launch with memory-optimized settings
.PARAMETER Extensions
    Enable or disable extensions (Default, Disable, DisableNonEssential)
.EXAMPLE
    .\Start-VSCodeInsidersOptimized.ps1
.EXAMPLE
    .\Start-VSCodeInsidersOptimized.ps1 -Path "D:\my-portfolio-aws" -CleanFirst
.EXAMPLE
    .\Start-VSCodeInsidersOptimized.ps1 -LowMemoryMode -Extensions DisableNonEssential
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, HelpMessage = "Path or workspace to open")]
    [string]$Path,
    
    [Parameter(HelpMessage = "Cleanup before launch")]
    [switch]$CleanFirst,
    
    [Parameter(HelpMessage = "Launch in low memory mode")]
    [switch]$LowMemoryMode,
    
    [Parameter(HelpMessage = "Extension loading strategy")]
    [ValidateSet("Default", "Disable", "DisableNonEssential")]
    [string]$Extensions = "Default"
)

$vsCodeInsidersPath = "C:\Users\baltz\AppData\Local\Programs\Microsoft VS Code Insiders\Code - Insiders.exe"

Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  VS Code Insiders Startup Optimizer           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Pre-launch cleanup
if ($CleanFirst) {
    Write-Host "🧹 Running pre-launch cleanup..." -ForegroundColor Yellow
    $cleanupScript = "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1"
    
    if (Test-Path $cleanupScript) {
        & $cleanupScript -Force -Silent
        Write-Host "✓ Cleanup completed" -ForegroundColor Green
        Start-Sleep -Seconds 1
    } else {
        Write-Host "⚠ Cleanup script not found, skipping..." -ForegroundColor Yellow
    }
}

# Check if VS Code Insiders is installed
if (-not (Test-Path $vsCodeInsidersPath)) {
    Write-Host "✗ VS Code Insiders not found at: $vsCodeInsidersPath" -ForegroundColor Red
    exit 1
}

# Build launch arguments
$launchArgs = @()

if ($Path) {
    if (Test-Path $Path) {
        $launchArgs += "`"$Path`""
        Write-Host "📂 Opening: $Path" -ForegroundColor Cyan
    } else {
        Write-Host "⚠ Path not found: $Path" -ForegroundColor Yellow
        Write-Host "  Launching without specific path..." -ForegroundColor Gray
    }
}

# Low memory mode settings
if ($LowMemoryMode) {
    Write-Host "🔧 Applying low memory optimizations..." -ForegroundColor Cyan
    
    # Reduce file watcher limit
    $launchArgs += "--max-memory=2048"
    
    # Disable GPU acceleration (reduces memory)
    $launchArgs += "--disable-gpu"
    
    # Reduce concurrent file operations
    $launchArgs += "--file-watcher-polling"
    
    Write-Host "  • Memory limit: 2GB" -ForegroundColor Gray
    Write-Host "  • GPU acceleration: Disabled" -ForegroundColor Gray
    Write-Host "  • File watcher: Polling mode" -ForegroundColor Gray
}

# Extension management
switch ($Extensions) {
    "Disable" {
        Write-Host "🔌 Extensions: All disabled" -ForegroundColor Yellow
        $launchArgs += "--disable-extensions"
    }
    "DisableNonEssential" {
        Write-Host "🔌 Extensions: Non-essential disabled" -ForegroundColor Yellow
        # This would require a more complex implementation with extension IDs
        # For now, we'll just note it
        Write-Host "  Note: Manual configuration needed for selective disabling" -ForegroundColor Gray
    }
    default {
        Write-Host "🔌 Extensions: Default loading" -ForegroundColor Green
    }
}

# Launch VS Code Insiders
Write-Host "`n🚀 Launching VS Code Insiders..." -ForegroundColor Cyan

try {
    $argString = $launchArgs -join " "
    
    if ($argString) {
        Start-Process -FilePath $vsCodeInsidersPath -ArgumentList $argString
    } else {
        Start-Process -FilePath $vsCodeInsidersPath
    }
    
    Write-Host "✓ VS Code Insiders started successfully!`n" -ForegroundColor Green
    
    # Optional: Monitor initial memory usage
    Write-Host "⏱️  Waiting for startup..." -ForegroundColor Gray
    Start-Sleep -Seconds 3
    
    $processes = Get-Process -Name "Code - Insiders" -ErrorAction SilentlyContinue
    if ($processes) {
        $totalMemoryMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
        $count = ($processes | Measure-Object).Count
        
        Write-Host "📊 Initial Status:" -ForegroundColor Cyan
        Write-Host "  • Processes: $count" -ForegroundColor Gray
        Write-Host "  • Memory: $totalMemoryMB MB" -ForegroundColor Gray
        Write-Host ""
    }
    
} catch {
    Write-Host "✗ Failed to launch: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
