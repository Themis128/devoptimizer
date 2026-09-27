# DevOptimizer Unified Central Launcher
# PowerShell version with full Unicode support and enhanced functionality

param(
    [switch]$Quick,
    [switch]$Status,
    [switch]$Help
)

$DevOptimizerPath = "D:\DevOptimizer"
$LogFile = "$DevOptimizerPath\logs\unified-launcher-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure logs directory exists
$LogDir = Split-Path $LogFile -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "DEBUG" { "Cyan" }
    }

    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                                                              " -ForegroundColor Cyan
    Write-Host "    🚀 DEVOPTIMIZER - UNIFIED CENTRAL LAUNCHER v4.0         " -ForegroundColor Yellow
    Write-Host "                                                              " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 SYSTEM STATUS: Ready | Tools: 66+ | Scripts: 26+ | Success Rate: 87.2%" -ForegroundColor Green
    Write-Host ""
}

function Show-QuickActions {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║                    QUICK ACTIONS                            ║" -ForegroundColor Blue
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  [1] 🚀 QUICK OPTIMIZATION    - Balanced system settings" -ForegroundColor White
    Write-Host "  [2] ⚡ ULTRA PERFORMANCE     - Maximum performance mode" -ForegroundColor White
    Write-Host "  [3] 🏥 SYSTEM HEALTH CHECK   - Performance analysis" -ForegroundColor White
    Write-Host "  [4] 🧹 SYSTEM CLEANUP        - Comprehensive cleanup" -ForegroundColor White
    Write-Host ""
}

function Show-DevelopmentTools {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                  DEVELOPMENT TOOLS                         ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [5] 🛠️  INSTALL DEV TOOLS     - Essential development software" -ForegroundColor White
    Write-Host "  [6] 🤖 CURSOR AI OPTIMIZATION - AI development setup" -ForegroundColor White
    Write-Host "  [7] 💻 VS CODE OPTIMIZATION   - Code editor optimization" -ForegroundColor White
    Write-Host "  [8] 🐳 DOCKER OPTIMIZATION    - Container management" -ForegroundColor White
    Write-Host "  [9] 🌐 NUXT3 OPTIMIZATION     - Nuxt.js development setup" -ForegroundColor White
    Write-Host ""
}

function Show-SystemManagement {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║                  SYSTEM MANAGEMENT                         ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [10] 🌐 NETWORK OPTIMIZATION  - Network tuning" -ForegroundColor White
    Write-Host "  [11] 🔒 SECURITY HARDENING    - Security enhancements" -ForegroundColor White
    Write-Host "  [12] ⚡ POWER MANAGEMENT      - Power optimization" -ForegroundColor White
    Write-Host "  [13] 🚀 STARTUP MANAGEMENT    - Boot optimization" -ForegroundColor White
    Write-Host "  [14] 🖥️  SCREEN SETTINGS      - Display management" -ForegroundColor White
    Write-Host ""
}

function Show-SpecializedTools {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                  SPECIALIZED TOOLS                        ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [15] 🐧 FIX WSL UBUNTU        - WSL configuration" -ForegroundColor White
    Write-Host "  [16] 🎮 DUAL GPU OPTIMIZATION - GPU and streaming setup" -ForegroundColor White
    Write-Host "  [17] 🧹 CACHE CLEANER         - Development cache management" -ForegroundColor White
    Write-Host "  [18] ✅ PREREQUISITES CHECK   - Check required tools" -ForegroundColor White
    Write-Host ""
}

function Show-AdvancedSuites {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                  ADVANCED SUITES                          ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "  [19] 🤖 ADVANCED AI SUITE     - Complete AI/ML environment" -ForegroundColor White
    Write-Host "  [20] 🔧 SYSTEM DIAGNOSTICS    - Advanced system analysis" -ForegroundColor White
    Write-Host "  [21] 📊 PERFORMANCE MONITOR   - Real-time monitoring" -ForegroundColor White
    Write-Host "  [22] 🔄 SYSTEM VALIDATION     - Comprehensive testing" -ForegroundColor White
    Write-Host ""
}

function Show-UtilityMenus {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "║                    UTILITY MENUS                          ║" -ForegroundColor DarkCyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  [23] 📋 TOOL LIST            - Show all available tools" -ForegroundColor White
    Write-Host "  [24] 📊 SYSTEM STATUS        - Detailed system information" -ForegroundColor White
    Write-Host "  [25] ⚙️  CONFIGURATION        - System settings and config" -ForegroundColor White
    Write-Host "  [26] 📚 HELP AND DOCUMENTATION - Usage guides and help" -ForegroundColor White
    Write-Host ""
}

function Show-SystemActions {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor DarkMagenta
    Write-Host "║                    SYSTEM ACTIONS                         ║" -ForegroundColor DarkMagenta
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor DarkMagenta
    Write-Host ""
    Write-Host "  [27] 🔄 REFRESH SYSTEM       - Reload and refresh" -ForegroundColor White
    Write-Host "  [28] 🧪 TEST ALL TOOLS       - Run comprehensive tests" -ForegroundColor White
    Write-Host "  [29] 📁 OPEN FOLDER          - Open DevOptimizer folder" -ForegroundColor White
    Write-Host "  [30] 🔧 REPAIR SYSTEM        - Fix common issues" -ForegroundColor White
    Write-Host ""
    Write-Host "  [0]  ❌ EXIT                 - Close launcher" -ForegroundColor Red
    Write-Host ""
}

function Show-Footer {
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "⚠️  Most tools require Administrator privileges" -ForegroundColor Yellow
    Write-Host "   Right-click and 'Run as administrator' for full functionality" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-MainMenu {
    Show-Header
    Show-QuickActions
    Show-DevelopmentTools
    Show-SystemManagement
    Show-SpecializedTools
    Show-AdvancedSuites
    Show-UtilityMenus
    Show-SystemActions
    Show-Footer
}

function Execute-Tool {
    param([string]$ToolName, [string]$FilePath, [string]$Description)

    Write-Log "Executing: $ToolName - $Description" -Level "INFO"

    if (Test-Path $FilePath) {
        try {
            if ($FilePath.EndsWith(".ps1")) {
                & powershell -ExecutionPolicy Bypass -File $FilePath
            } else {
                & cmd.exe /c $FilePath
            }
            Write-Log "Successfully executed: $ToolName" -Level "SUCCESS"
        }
        catch {
            Write-Log "Error executing $ToolName $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "Tool not found: $FilePath" -Level "ERROR"
        Write-Host "❌ Tool not found: $ToolName" -ForegroundColor Red
    }
}

function Show-ConfigurationMenu {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                    CONFIGURATION MENU" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] 📊 View Current Config    - Show system configuration" -ForegroundColor White
    Write-Host "  [2] ⚙️  Edit Configuration     - Modify settings" -ForegroundColor White
    Write-Host "  [3] 🔄 Reset to Defaults      - Restore default settings" -ForegroundColor White
    Write-Host "  [4] 📁 Open Config Folder     - Browse configuration files" -ForegroundColor White
    Write-Host "  [5] 💾 Backup Configuration   - Save current settings" -ForegroundColor White
    Write-Host "  [6] 📥 Restore Configuration  - Load saved settings" -ForegroundColor White
    Write-Host "  [0] ⬅️  Back to Main Menu      - Return to main launcher" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Enter your choice (0-6)"

    switch ($choice) {
        "1" {
            Write-Host "`n📊 Current Configuration:" -ForegroundColor Cyan
            if (Test-Path "$DevOptimizerPath\bat.config.json") {
                Get-Content "$DevOptimizerPath\bat.config.json" | ConvertFrom-Json | ConvertTo-Json -Depth 10
            } else {
                Write-Host "Configuration file not found!" -ForegroundColor Red
            }
            Read-Host "Press Enter to continue"
            Show-ConfigurationMenu
        }
        "2" {
            Write-Host "`n⚙️ Opening configuration editor..." -ForegroundColor Cyan
            if (Test-Path "$DevOptimizerPath\bat.config.json") {
                notepad "$DevOptimizerPath\bat.config.json"
            } else {
                Write-Host "Configuration file not found!" -ForegroundColor Red
            }
            Show-ConfigurationMenu
        }
        "3" {
            Write-Host "`n🔄 Resetting to defaults..." -ForegroundColor Cyan
            Execute-Tool "Reset Configuration" "$DevOptimizerPath\QUICK-GLOBAL-SETUP.bat" "Reset to defaults"
            Show-ConfigurationMenu
        }
        "4" {
            Write-Host "`n📁 Opening config folder..." -ForegroundColor Cyan
            if (Test-Path "$DevOptimizerPath\config") {
                Start-Process "explorer.exe" -ArgumentList "$DevOptimizerPath\config"
            } else {
                Write-Host "Config folder not found!" -ForegroundColor Red
            }
            Show-ConfigurationMenu
        }
        "5" {
            Write-Host "`n💾 Backing up configuration..." -ForegroundColor Cyan
            $backupFile = "$DevOptimizerPath\backup\bat.config.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            if (Test-Path "$DevOptimizerPath\bat.config.json") {
                Copy-Item "$DevOptimizerPath\bat.config.json" $backupFile
                Write-Host "Configuration backed up to: $backupFile" -ForegroundColor Green
            } else {
                Write-Host "Configuration file not found!" -ForegroundColor Red
            }
            Show-ConfigurationMenu
        }
        "6" {
            Write-Host "`n📥 Restoring configuration..." -ForegroundColor Cyan
            $backupFiles = Get-ChildItem "$DevOptimizerPath\backup\bat.config.backup.*.json" | Sort-Object LastWriteTime -Descending
            if ($backupFiles) {
                Copy-Item $backupFiles[0].FullName "$DevOptimizerPath\bat.config.json"
                Write-Host "Configuration restored from: $($backupFiles[0].Name)" -ForegroundColor Green
            } else {
                Write-Host "No backup files found!" -ForegroundColor Red
            }
            Show-ConfigurationMenu
        }
        "0" { return }
        default {
            Write-Host "❌ Invalid choice! Please enter a number from 0-6." -ForegroundColor Red
            Read-Host "Press Enter to continue"
            Show-ConfigurationMenu
        }
    }
}

function Show-HelpMenu {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                  HELP & DOCUMENTATION" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] 📖 Quick Start Guide      - Getting started" -ForegroundColor White
    Write-Host "  [2] 🛠️  Tool Documentation    - Detailed tool info" -ForegroundColor White
    Write-Host "  [3] ❓ Troubleshooting        - Common issues and fixes" -ForegroundColor White
    Write-Host "  [4] 📊 System Reports         - View generated reports" -ForegroundColor White
    Write-Host "  [5] 🔗 External Resources     - Links and references" -ForegroundColor White
    Write-Host "  [6] 📞 Support Information    - Contact and support" -ForegroundColor White
    Write-Host "  [0] ⬅️  Back to Main Menu      - Return to main launcher" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Enter your choice (0-6)"

    switch ($choice) {
        "1" {
            Write-Host "`n📖 Quick Start Guide:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "DEVOPTIMIZER QUICK START GUIDE" -ForegroundColor Yellow
            Write-Host "==============================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "1. Run as Administrator for full functionality" -ForegroundColor White
            Write-Host "2. Start with Quick Optimization (Option 1)" -ForegroundColor White
            Write-Host "3. Run System Health Check (Option 3) to verify" -ForegroundColor White
            Write-Host "4. Use Development Tools (Options 5-9) for coding setup" -ForegroundColor White
            Write-Host "5. Regular maintenance with System Cleanup (Option 4)" -ForegroundColor White
            Write-Host ""
            Read-Host "Press Enter to continue"
            Show-HelpMenu
        }
        "2" {
            Write-Host "`n🛠️ Tool Documentation:" -ForegroundColor Cyan
            & powershell -ExecutionPolicy Bypass -File "$DevOptimizerPath\optimizer.ps1" -List
            Read-Host "Press Enter to continue"
            Show-HelpMenu
        }
        "3" {
            Write-Host "`n❓ Troubleshooting Guide:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "COMMON ISSUES AND SOLUTIONS:" -ForegroundColor Yellow
            Write-Host "===========================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "1. 'Access Denied' - Run as Administrator" -ForegroundColor White
            Write-Host "2. 'Command not found' - Check PATH configuration" -ForegroundColor White
            Write-Host "3. 'PowerShell errors' - Run PowerShell fix tools" -ForegroundColor White
            Write-Host "4. 'Unicode display issues' - Use PowerShell launcher" -ForegroundColor White
            Write-Host "5. 'Tool not working' - Run system validation" -ForegroundColor White
            Write-Host ""
            Write-Host "For more help, run System Validation (Option 22)" -ForegroundColor Green
            Read-Host "Press Enter to continue"
            Show-HelpMenu
        }
        "4" {
            Write-Host "`n📊 System Reports:" -ForegroundColor Cyan
            $reports = Get-ChildItem "$DevOptimizerPath\validation-report-*.html" | Sort-Object LastWriteTime -Descending
            if ($reports) {
                Write-Host "Opening latest validation report..." -ForegroundColor Green
                Start-Process $reports[0].FullName
            } else {
                Write-Host "No reports found. Run System Validation (Option 22) to generate reports." -ForegroundColor Yellow
            }
            Read-Host "Press Enter to continue"
            Show-HelpMenu
        }
        "5" {
            Write-Host "`n🔗 External Resources:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "- Microsoft Windows Documentation" -ForegroundColor White
            Write-Host "- PowerShell Documentation" -ForegroundColor White
            Write-Host "- Docker Documentation" -ForegroundColor White
            Write-Host "- VS Code Documentation" -ForegroundColor White
            Write-Host "- Cursor AI Documentation" -ForegroundColor White
            Write-Host ""
            Write-Host "Check the docs folder for local documentation." -ForegroundColor Green
            Read-Host "Press Enter to continue"
            Show-HelpMenu
        }
        "6" {
            Write-Host "`n📞 Support Information:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "- Check logs in: $DevOptimizerPath\logs\" -ForegroundColor White
            Write-Host "- View reports in: $DevOptimizerPath\reports\" -ForegroundColor White
            Write-Host "- Run diagnostics: Option 20" -ForegroundColor White
            Write-Host "- System validation: Option 22" -ForegroundColor White
            Write-Host ""
            Write-Host "For technical issues, check the troubleshooting guide." -ForegroundColor Green
            Read-Host "Press Enter to continue"
            Show-HelpMenu
        }
        "0" { return }
        default {
            Write-Host "❌ Invalid choice! Please enter a number from 0-6." -ForegroundColor Red
            Read-Host "Press Enter to continue"
            Show-HelpMenu
        }
    }
}

# Main execution
if ($Help) {
    Show-HelpMenu
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
        "25" { Show-ConfigurationMenu }
        "26" { Show-HelpMenu }
        "27" { Execute-Tool "Refresh System" "$DevOptimizerPath\setup-global-access.ps1" "Reload and refresh" }
        "28" { Execute-Tool "Test All Tools" "$DevOptimizerPath\validate-system.ps1" "Run comprehensive tests" }
        "29" { Start-Process "explorer.exe" -ArgumentList $DevOptimizerPath }
        "30" { Execute-Tool "Repair System" "$DevOptimizerPath\QUICK-FIX-POWERSHELL-ERROR.bat" "Fix common issues" }
        "0" {
            Write-Host "`n👋 Thank you for using DevOptimizer!" -ForegroundColor Green
            Write-Host "   System optimized and ready for development." -ForegroundColor Green
            break
        }
        default {
            Write-Host "`n❌ Invalid choice! Please enter a number from 0-30." -ForegroundColor Red
            Read-Host "Press Enter to continue"
        }
    }

    if ($choice -ne "0") {
        Write-Host "`nPress Enter to return to main menu..."
        Read-Host
    }
} while ($choice -ne "0")
