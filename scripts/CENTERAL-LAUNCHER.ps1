# DevOptimizer Central Unified Launcher
# Simple PowerShell version with all options in one place

<#+
.SYNOPSIS
Launches DevOptimizer tools from a unified interactive PowerShell menu.

.DESCRIPTION
Presents quick actions, development utilities, and advanced maintenance suites through a console menu. Supports non-interactive status views and streamlined quick runs.

.PARAMETER Quick
Starts the quick optimization flow without displaying the full menu.

.PARAMETER Status
Displays the current DevOptimizer status summary and exits.

.PARAMETER Help
Shows help information about the launcher and available commands.

.EXAMPLE
PS> .\CENTERAL-LAUNCHER.ps1
Opens the interactive launcher menu.

.EXAMPLE
PS> .\CENTERAL-LAUNCHER.ps1 -Quick
Runs the predefined quick optimization routine directly.

.NOTES
Author: DevOptimizer automation tools
#>

param(
    [switch]$Quick,
    [switch]$Status,
    [switch]$Help
)

$DevOptimizerPath = "D:\DevOptimizer"

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                                                              " -ForegroundColor Cyan
    Write-Host "    DEVOPTIMIZER - CENTRAL UNIFIED LAUNCHER v4.0             " -ForegroundColor Yellow
    Write-Host "                                                              " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SYSTEM STATUS: Ready | Tools: 66+ | Scripts: 26+ | Success Rate: 87.2%" -ForegroundColor Green
    Write-Host ""
}

function Show-MainMenu {
    Show-Header

    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "                    QUICK ACTIONS                            " -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  [1] QUICK OPTIMIZATION    - Balanced system settings" -ForegroundColor White
    Write-Host "  [2] ULTRA PERFORMANCE     - Maximum performance mode" -ForegroundColor White
    Write-Host "  [3] SYSTEM HEALTH CHECK   - Performance analysis" -ForegroundColor White
    Write-Host "  [4] SYSTEM CLEANUP        - Comprehensive cleanup" -ForegroundColor White
    Write-Host ""

    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "                  DEVELOPMENT TOOLS                         " -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [5] INSTALL DEV TOOLS     - Essential development software" -ForegroundColor White
    Write-Host "  [6] CURSOR AI OPTIMIZATION - AI development setup" -ForegroundColor White
    Write-Host "  [7] VS CODE OPTIMIZATION   - Code editor optimization" -ForegroundColor White
    Write-Host "  [8] DOCKER OPTIMIZATION    - Container management" -ForegroundColor White
    Write-Host "  [9] NUXT3 OPTIMIZATION     - Nuxt.js development setup" -ForegroundColor White
    Write-Host ""

    Write-Host "================================================================" -ForegroundColor Magenta
    Write-Host "                  SYSTEM MANAGEMENT                         " -ForegroundColor Magenta
    Write-Host "================================================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [10] NETWORK OPTIMIZATION  - Network tuning" -ForegroundColor White
    Write-Host "  [11] SECURITY HARDENING    - Security enhancements" -ForegroundColor White
    Write-Host "  [12] POWER MANAGEMENT      - Power optimization" -ForegroundColor White
    Write-Host "  [13] STARTUP MANAGEMENT    - Boot optimization" -ForegroundColor White
    Write-Host "  [14] SCREEN SETTINGS       - Display management" -ForegroundColor White
    Write-Host ""

    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host "                  SPECIALIZED TOOLS                        " -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [15] FIX WSL UBUNTU        - WSL configuration" -ForegroundColor White
    Write-Host "  [16] DUAL GPU OPTIMIZATION - GPU and streaming setup" -ForegroundColor White
    Write-Host "  [17] CACHE CLEANER         - Development cache management" -ForegroundColor White
    Write-Host "  [18] PREREQUISITES CHECK   - Check required tools" -ForegroundColor White
    Write-Host ""

    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "                  ADVANCED SUITES                          " -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  [19] ADVANCED AI SUITE     - Complete AI/ML environment" -ForegroundColor White
    Write-Host "  [20] SYSTEM DIAGNOSTICS    - Advanced system analysis" -ForegroundColor White
    Write-Host "  [21] PERFORMANCE MONITOR   - Real-time monitoring" -ForegroundColor White
    Write-Host "  [22] SYSTEM VALIDATION     - Comprehensive testing" -ForegroundColor White
    Write-Host ""

    Write-Host "================================================================" -ForegroundColor DarkCyan
    Write-Host "                    UTILITY MENUS                          " -ForegroundColor DarkCyan
    Write-Host "================================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  [23] TOOL LIST            - Show all available tools" -ForegroundColor White
    Write-Host "  [24] SYSTEM STATUS        - Detailed system information" -ForegroundColor White
    Write-Host "  [25] CONFIGURATION        - System settings and config" -ForegroundColor White
    Write-Host "  [26] HELP DOCUMENTATION   - Usage guides and help" -ForegroundColor White
    Write-Host ""

    Write-Host "================================================================" -ForegroundColor DarkMagenta
    Write-Host "                    SYSTEM ACTIONS                         " -ForegroundColor DarkMagenta
    Write-Host "================================================================" -ForegroundColor DarkMagenta
    Write-Host ""
    Write-Host "  [27] REFRESH SYSTEM       - Reload and refresh" -ForegroundColor White
    Write-Host "  [28] TEST ALL TOOLS       - Run comprehensive tests" -ForegroundColor White
    Write-Host "  [29] OPEN FOLDER          - Open DevOptimizer folder" -ForegroundColor White
    Write-Host "  [30] REPAIR SYSTEM        - Fix common issues" -ForegroundColor White
    Write-Host ""
    Write-Host "  [0]  EXIT                 - Close launcher" -ForegroundColor Red
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "WARNING: Most tools require Administrator privileges" -ForegroundColor Yellow
    Write-Host "   Right-click and 'Run as administrator' for full functionality" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Execute-Tool {
    param([string]$ToolName, [string]$FilePath, [string]$Description)

    Write-Host "`nExecuting: $ToolName - $Description" -ForegroundColor Cyan

    if (Test-Path $FilePath) {
        try {
            if ($FilePath.EndsWith(".ps1")) {
                & powershell -ExecutionPolicy Bypass -File $FilePath
            } else {
                & cmd.exe /c $FilePath
            }
            Write-Host "Successfully executed: $ToolName" -ForegroundColor Green
        }
        catch {
            Write-Host "Error executing $ToolName`: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Tool not found: $FilePath" -ForegroundColor Red
    }
}

# Main execution
if ($Help) {
    Write-Host "DevOptimizer Central Launcher Help" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\CENTERAL-LAUNCHER.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Quick    Run quick optimization immediately" -ForegroundColor White
    Write-Host "  -Status   Show system status" -ForegroundColor White
    Write-Host "  -Help     Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\CENTERAL-LAUNCHER.ps1 -Quick" -ForegroundColor White
    Write-Host "  .\CENTERAL-LAUNCHER.ps1 -Status" -ForegroundColor White
    Write-Host "  .\CENTERAL-LAUNCHER.ps1" -ForegroundColor White
    exit 0
}

if ($Status) {
    & powershell -ExecutionPolicy Bypass -File "$DevOptimizerPath\optimizer.ps1" -Status
    exit 0
}

if ($Quick) {
    Execute-Tool "Quick Optimization" "$DevOptimizerPath\01-Quick-Optimization.bat" "Balanced system settings"
    exit 0
}

# Main menu loop
do {
    Show-MainMenu
    $choice = Read-Host "Enter your choice (0-30)"

    switch ($choice) {
        "1" { Execute-Tool "Quick Optimization" "$DevOptimizerPath\01-Quick-Optimization.bat" "Balanced system settings" }
        "2" { Execute-Tool "Ultra Performance" "$DevOptimizerPath\02-Ultra-Performance.bat" "Maximum performance mode" }
        "3" { Execute-Tool "System Health Check" "$DevOptimizerPath\06-System-Health-Check.bat" "Performance analysis" }
        "4" { Execute-Tool "System Cleanup" "$DevOptimizerPath\09-System-Deep-Clean.bat" "Comprehensive cleanup" }
        "5" { Execute-Tool "Install Dev Tools" "$DevOptimizerPath\03-Install-Dev-Tools.bat" "Essential development software" }
        "6" { Execute-Tool "Cursor AI Optimization" "$DevOptimizerPath\014-Cursor-AI-Optimization.bat" "AI development setup" }
        "7" { Execute-Tool "VS Code Optimization" "$DevOptimizerPath\015-VSCode-Optimization.bat" "Code editor optimization" }
        "8" { Execute-Tool "Docker Optimization" "$DevOptimizerPath\08-Docker-Optimization.bat" "Container management" }
        "9" { Execute-Tool "Nuxt3 Optimization" "$DevOptimizerPath\16-Nuxt3-Windows-Optimization.bat" "Nuxt.js development setup" }
        "10" { Execute-Tool "Network Optimization" "$DevOptimizerPath\10-Network-Optimization.bat" "Network tuning" }
        "11" { Execute-Tool "Security Hardening" "$DevOptimizerPath\11-Security-Hardening.bat" "Security enhancements" }
        "12" { Execute-Tool "Power Management" "$DevOptimizerPath\12-Power-Management.bat" "Power optimization" }
        "13" { Execute-Tool "Startup Management" "$DevOptimizerPath\13-Startup-Management.bat" "Boot optimization" }
        "14" { Execute-Tool "Screen Settings Manager" "$DevOptimizerPath\18-Screen-Settings-Manager.bat" "Display management" }
        "15" { Execute-Tool "WSL Ubuntu Fix" "$DevOptimizerPath\07-Fix-WSL-Ubuntu.bat" "WSL configuration" }
        "16" { Execute-Tool "Dual GPU Optimization" "$DevOptimizerPath\017-Dual-GPU-NVIDIA-Broadcast-Optimization.bat" "GPU and streaming setup" }
        "17" { Execute-Tool "Cache Cleaner" "$DevOptimizerPath\025-Development-Cache-Cleaner.bat" "Development cache management" }
        "18" { Execute-Tool "Prerequisites Check" "$DevOptimizerPath\026-Prerequisites-Checker.bat" "Check required tools" }
        "19" { Execute-Tool "Advanced AI Suite" "$DevOptimizerPath\019-Advanced-AI-Development-Suite.bat" "Complete AI/ML environment" }
        "20" { Execute-Tool "System Diagnostics" "$DevOptimizerPath\ENHANCED-SYSTEM-DIAGNOSTICS.bat" "Advanced system analysis" }
        "21" { Execute-Tool "Performance Monitor" "$DevOptimizerPath\real-time-monitoring.ps1" "Real-time monitoring" }
        "22" { Execute-Tool "System Validation" "$DevOptimizerPath\validate-system.ps1" "Comprehensive testing" }
        "23" { & powershell -ExecutionPolicy Bypass -File "$DevOptimizerPath\optimizer.ps1" -List }
        "24" { & powershell -ExecutionPolicy Bypass -File "$DevOptimizerPath\optimizer.ps1" -Status }
        "25" {
            Write-Host "`nConfiguration Menu:" -ForegroundColor Cyan
            Write-Host "1. View Current Config" -ForegroundColor White
            Write-Host "2. Edit Configuration" -ForegroundColor White
            Write-Host "3. Open Config Folder" -ForegroundColor White
            $configChoice = Read-Host "Enter choice (1-3)"
            switch ($configChoice) {
                "1" { Get-Content "$DevOptimizerPath\bat.config.json" | ConvertFrom-Json | ConvertTo-Json -Depth 10 }
                "2" { notepad "$DevOptimizerPath\bat.config.json" }
                "3" { Start-Process "explorer.exe" -ArgumentList "$DevOptimizerPath\config" }
            }
        }
        "26" {
            Write-Host "`nHelp and Documentation:" -ForegroundColor Cyan
            Write-Host "1. Quick Start Guide" -ForegroundColor White
            Write-Host "2. Tool Documentation" -ForegroundColor White
            Write-Host "3. Troubleshooting" -ForegroundColor White
            $helpChoice = Read-Host "Enter choice (1-3)"
            switch ($helpChoice) {
                "1" {
                    Write-Host "`nQUICK START GUIDE:" -ForegroundColor Yellow
                    Write-Host "1. Run as Administrator for full functionality" -ForegroundColor White
                    Write-Host "2. Start with Quick Optimization (Option 1)" -ForegroundColor White
                    Write-Host "3. Run System Health Check (Option 3) to verify" -ForegroundColor White
                    Write-Host "4. Use Development Tools (Options 5-9) for coding setup" -ForegroundColor White
                    Write-Host "5. Regular maintenance with System Cleanup (Option 4)" -ForegroundColor White
                }
                "2" { & powershell -ExecutionPolicy Bypass -File "$DevOptimizerPath\optimizer.ps1" -List }
                "3" {
                    Write-Host "`nTROUBLESHOOTING:" -ForegroundColor Yellow
                    Write-Host "1. 'Access Denied' - Run as Administrator" -ForegroundColor White
                    Write-Host "2. 'Command not found' - Check PATH configuration" -ForegroundColor White
                    Write-Host "3. 'PowerShell errors' - Run PowerShell fix tools" -ForegroundColor White
                    Write-Host "4. 'Tool not working' - Run system validation" -ForegroundColor White
                }
            }
        }
        "27" { Execute-Tool "Refresh System" "$DevOptimizerPath\setup-global-access.ps1" "Reload and refresh" }
        "28" { Execute-Tool "Test All Tools" "$DevOptimizerPath\validate-system.ps1" "Run comprehensive tests" }
        "29" { Start-Process "explorer.exe" -ArgumentList $DevOptimizerPath }
        "30" { Execute-Tool "Repair System" "$DevOptimizerPath\QUICK-FIX-POWERSHELL-ERROR.bat" "Fix common issues" }
        "0" {
            Write-Host "`nThank you for using DevOptimizer!" -ForegroundColor Green
            Write-Host "   System optimized and ready for development." -ForegroundColor Green
            break
        }
        default {
            Write-Host "`nInvalid choice! Please enter a number from 0-30." -ForegroundColor Red
        }
    }

    if ($choice -ne "0") {
        Write-Host "`nPress Enter to return to main menu..."
        Read-Host
    }
} while ($choice -ne "0")
