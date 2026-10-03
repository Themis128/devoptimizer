:: SYNOPSIS: DevOptimizer automation script: UNIFIED-LAUNCHER-NoAdmin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title  - Standard Mode- Unified Central Launcher
color 0B

:: Set script directory
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:MAIN_MENU
cls
echo.
echo ================================================================


:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo
echo     DEVOPTIMIZER - UNIFIED CENTRAL LAUNCHER v4.0
echo
echo ================================================================
echo.
echo  SYSTEM STATUS: Ready | Tools: 66+ | Scripts: 26+ | Success Rate: 87.2%
echo.
echo 
echo                     QUICK ACTIONS                            
echo 
echo.
echo   [1]  QUICK OPTIMIZATION    - Balanced system settings
echo   [2]  ULTRA PERFORMANCE     - Maximum performance mode
echo   [3]  SYSTEM HEALTH CHECK   - Performance analysis
echo   [4]  SYSTEM CLEANUP        - Comprehensive cleanup
echo.
echo 
echo                   DEVELOPMENT TOOLS                         
echo 
echo.
echo   [5]   INSTALL DEV TOOLS     - Essential development software
echo   [6]  CURSOR AI OPTIMIZATION - AI development setup
echo   [7]  VS CODE OPTIMIZATION   - Code editor optimization
echo   [8]  DOCKER OPTIMIZATION    - Container management
echo   [9]  NUXT3 OPTIMIZATION     - Nuxt.js development setup
echo.
echo 
echo                   SYSTEM MANAGEMENT                         
echo 
echo.
echo   [10]  NETWORK OPTIMIZATION  - Network tuning
echo   [11]  SECURITY HARDENING    - Security enhancements
echo   [12]  POWER MANAGEMENT      - Power optimization
echo   [13]  STARTUP MANAGEMENT    - Boot optimization
echo   [14]   SCREEN SETTINGS      - Display management
echo.
echo 
echo                   SPECIALIZED TOOLS                        
echo 
echo.
echo   [15]  FIX WSL UBUNTU        - WSL configuration
echo   [16]  DUAL GPU OPTIMIZATION - GPU and streaming setup
echo   [17]  CACHE CLEANER         - Development cache management
echo   [18]  PREREQUISITES CHECK   - Check required tools
echo.
echo 
echo                   ADVANCED SUITES                          
echo 
echo.
echo   [19]  ADVANCED AI SUITE     - Complete AI/ML environment
echo   [20]  SYSTEM DIAGNOSTICS    - Advanced system analysis
echo   [21]  PERFORMANCE MONITOR   - Real-time monitoring
echo   [22]  SYSTEM VALIDATION     - Comprehensive testing
echo.
echo 
echo                     UTILITY MENUS                          
echo 
echo.
echo   [23]  TOOL LIST            - Show all available tools
echo   [24]  SYSTEM STATUS        - Detailed system information
echo   [25]   CONFIGURATION        - System settings and config
echo   [26]  HELP & DOCUMENTATION - Usage guides and help
echo.
echo 
echo                     SYSTEM ACTIONS                         
echo 
echo.
echo   [27]  REFRESH SYSTEM       - Reload and refresh
echo   [28]  TEST ALL TOOLS       - Run comprehensive tests
echo   [29]  OPEN FOLDER          - Open DevOptimizer folder
echo   [30]  REPAIR SYSTEM        - Fix common issues
echo.
echo   [0]   EXIT                 - Close launcher
echo.
echo ================================================================
echo   Most tools require Administrator privileges
echo    Right-click and "Run as administrator" for full functionality
echo ================================================================
echo.

set /p choice="Enter your choice (0-30): "

if "%choice%"=="1" goto QUICK_OPT
if "%choice%"=="2" goto ULTRA_PERF
if "%choice%"=="3" goto HEALTH_CHECK
if "%choice%"=="4" goto SYSTEM_CLEANUP
if "%choice%"=="5" goto INSTALL_DEV
if "%choice%"=="6" goto CURSOR_AI
if "%choice%"=="7" goto VSCODE_OPT
if "%choice%"=="8" goto DOCKER_OPT
if "%choice%"=="9" goto NUXT3_OPT
if "%choice%"=="10" goto NETWORK_OPT
if "%choice%"=="11" goto SECURITY_HARD
if "%choice%"=="12" goto POWER_MGMT
if "%choice%"=="13" goto STARTUP_MGMT
if "%choice%"=="14" goto SCREEN_MGMT
if "%choice%"=="15" goto WSL_FIX
if "%choice%"=="16" goto DUAL_GPU
if "%choice%"=="17" goto CACHE_CLEAN
if "%choice%"=="18" goto PREREQ_CHECK
if "%choice%"=="19" goto ADV_AI_SUITE
if "%choice%"=="20" goto SYS_DIAG
if "%choice%"=="21" goto PERF_MONITOR
if "%choice%"=="22" goto SYS_VALIDATE
if "%choice%"=="23" goto TOOL_LIST
if "%choice%"=="24" goto SYS_STATUS
if "%choice%"=="25" goto CONFIG_MENU
if "%choice%"=="26" goto HELP_MENU
if "%choice%"=="27" goto REFRESH_SYS
if "%choice%"=="28" goto TEST_TOOLS
if "%choice%"=="29" goto OPEN_FOLDER
if "%choice%"=="30" goto REPAIR_SYS
if "%choice%"=="0" goto EXIT
goto INVALID_CHOICE

:: Quick Actions
:QUICK_OPT
echo.
echo  Launching Quick Optimization...
call "%SCRIPT_DIR%\01-Quick-Optimization.bat"
goto RETURN_MENU

:ULTRA_PERF
echo.
echo  Launching Ultra Performance...
call "%SCRIPT_DIR%\02-Ultra-Performance.bat"
goto RETURN_MENU

:HEALTH_CHECK
echo.
echo  Launching System Health Check...
call "%SCRIPT_DIR%\06-System-Health-Check.bat"
goto RETURN_MENU

:SYSTEM_CLEANUP
echo.
echo  Launching System Cleanup...
call "%SCRIPT_DIR%\09-System-Deep-Clean.bat"
goto RETURN_MENU

:: Development Tools
:INSTALL_DEV
echo.
echo  Launching Install Dev Tools...
call "%SCRIPT_DIR%\03-Install-Dev-Tools.bat"
goto RETURN_MENU

:CURSOR_AI
echo.
echo  Launching Cursor AI Optimization...
call "%SCRIPT_DIR%\014-Cursor-AI-Optimization.bat"
goto RETURN_MENU

:VSCODE_OPT
echo.
echo  Launching VS Code Optimization...
call "%SCRIPT_DIR%\015-VSCode-Optimization.bat"
goto RETURN_MENU

:DOCKER_OPT
echo.
echo  Launching Docker Optimization...
call "%SCRIPT_DIR%\08-Docker-Optimization.bat"
goto RETURN_MENU

:NUXT3_OPT
echo.
echo  Launching Nuxt3 Optimization...
call "%SCRIPT_DIR%\16-Nuxt3-Windows-Optimization.bat"
goto RETURN_MENU

:: System Management
:NETWORK_OPT
echo.
echo  Launching Network Optimization...
call "%SCRIPT_DIR%\10-Network-Optimization.bat"
goto RETURN_MENU

:SECURITY_HARD
echo.
echo  Launching Security Hardening...
call "%SCRIPT_DIR%\11-Security-Hardening.bat"
goto RETURN_MENU

:POWER_MGMT
echo.
echo  Launching Power Management...
call "%SCRIPT_DIR%\12-Power-Management.bat"
goto RETURN_MENU

:STARTUP_MGMT
echo.
echo  Launching Startup Management...
call "%SCRIPT_DIR%\13-Startup-Management.bat"
goto RETURN_MENU

:SCREEN_MGMT
echo.
echo  Launching Screen Settings Manager...
call "%SCRIPT_DIR%\18-Screen-Settings-Manager.bat"
goto RETURN_MENU

:: Specialized Tools
:WSL_FIX
echo.
echo  Launching WSL Ubuntu Fix...
call "%SCRIPT_DIR%\07-Fix-WSL-Ubuntu.bat"
goto RETURN_MENU

:DUAL_GPU
echo.
echo  Launching Dual GPU Optimization...
call "%SCRIPT_DIR%\017-Dual-GPU-NVIDIA-Broadcast-Optimization.bat"
goto RETURN_MENU

:CACHE_CLEAN
echo.
echo  Launching Development Cache Cleaner...
call "%SCRIPT_DIR%\025-Development-Cache-Cleaner.bat"
goto RETURN_MENU

:PREREQ_CHECK
echo.
echo  Launching Prerequisites Checker...
call "%SCRIPT_DIR%\026-Prerequisites-Checker.bat"
goto RETURN_MENU

:: Advanced Suites
:ADV_AI_SUITE
echo.
echo  Launching Advanced AI Development Suite...
call "%SCRIPT_DIR%\019-Advanced-AI-Development-Suite.bat"
goto RETURN_MENU

:SYS_DIAG
echo.
echo  Launching System Diagnostics...
call "%SCRIPT_DIR%\ENHANCED-SYSTEM-DIAGNOSTICS.bat"
goto RETURN_MENU

:PERF_MONITOR
echo.
echo  Launching Performance Monitor...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\real-time-monitoring.ps1"
goto RETURN_MENU

:SYS_VALIDATE
echo.
echo  Launching System Validation...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\validate-system.ps1" -Report
goto RETURN_MENU

:: Utility Menus
:TOOL_LIST
echo.
echo  Showing all available tools...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\optimizer.ps1" -List
goto RETURN_MENU

:SYS_STATUS
echo.
echo  Showing system status...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\optimizer.ps1" -Status
goto RETURN_MENU

:CONFIG_MENU
goto CONFIG_SUBMENU

:HELP_MENU
goto HELP_SUBMENU

:: System Actions
:REFRESH_SYS
echo.
echo  Refreshing system...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\setup-global-access.ps1"
goto RETURN_MENU

:TEST_TOOLS
echo.
echo  Testing all tools...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\validate-system.ps1" -Detailed
goto RETURN_MENU

:OPEN_FOLDER
echo.
echo  Opening DevOptimizer folder...
explorer "%SCRIPT_DIR%"
goto RETURN_MENU

:REPAIR_SYS
echo.
echo  Running system repair...
call "%SCRIPT_DIR%\QUICK-FIX-POWERSHELL-ERROR.bat"
goto RETURN_MENU

:: Configuration Submenu
:CONFIG_SUBMENU
cls
echo.
echo ================================================================
echo                    CONFIGURATION MENU
echo ================================================================
echo.
echo   [1]  View Current Config    - Show system configuration
echo   [2]   Edit Configuration     - Modify settings
echo   [3]  Reset to Defaults      - Restore default settings
echo   [4]  Open Config Folder     - Browse configuration files
echo   [5]  Backup Configuration   - Save current settings
echo   [6]  Restore Configuration  - Load saved settings
echo   [0]   Back to Main Menu      - Return to main launcher
echo.
set /p config_choice="Enter your choice (0-6): "

if "%config_choice%"=="1" (
echo.
echo  Current Configuration:
type "%SCRIPT_DIR%\bat.config.json"
goto CONFIG_SUBMENU
)
if "%config_choice%"=="2" (
echo.
echo  Opening configuration editor...
notepad "%SCRIPT_DIR%\bat.config.json"
goto CONFIG_SUBMENU
)
if "%config_choice%"=="3" (
echo.
echo  Resetting to defaults...
call "%SCRIPT_DIR%\QUICK-GLOBAL-SETUP.bat"
goto CONFIG_SUBMENU
)
if "%config_choice%"=="4" (
echo.
echo  Opening config folder...
explorer "%SCRIPT_DIR%\config"
goto CONFIG_SUBMENU
)
if "%config_choice%"=="5" (
echo.
echo  Backing up configuration...
copy "%SCRIPT_DIR%\bat.config.json" "%SCRIPT_DIR%\backup\bat.config.backup.%date:~-4,4%%date:~-10,2%%date:~-7,2%.json"
echo Configuration backed up successfully!
goto CONFIG_SUBMENU
)
if "%config_choice%"=="6" (
echo.
echo  Restoring configuration...
if exist "%SCRIPT_DIR%\backup\bat.config.backup.*.json" (
for %%f in ("%SCRIPT_DIR%\backup\bat.config.backup.*.json") do set "backup_file=%%f"
copy "!backup_file!" "%SCRIPT_DIR%\bat.config.json"
echo Configuration restored successfully!
) else (
echo No backup files found!
)
goto CONFIG_SUBMENU
)
if "%config_choice%"=="0" goto MAIN_MENU
goto CONFIG_SUBMENU

:: Help Submenu
:HELP_SUBMENU
cls
echo.
echo ================================================================
echo                  HELP & DOCUMENTATION
echo ================================================================
echo.
echo   [1]  Quick Start Guide      - Getting started
echo   [2]   Tool Documentation    - Detailed tool info
echo   [3]  Troubleshooting        - Common issues and fixes
echo   [4]  System Reports         - View generated reports
echo   [5]  External Resources     - Links and references
echo   [6]  Support Information    - Contact and support
echo   [0]   Back to Main Menu      - Return to main launcher
echo.
set /p help_choice="Enter your choice (0-6): "

if "%help_choice%"=="1" (
echo.
echo  Opening Quick Start Guide...
if exist "%SCRIPT_DIR%\QUICK-START-GUIDE.md" (
type "%SCRIPT_DIR%\QUICK-START-GUIDE.md"
) else (
echo Quick Start Guide not found. Creating basic guide...
echo.
echo DEVOPTIMIZER QUICK START GUIDE
echo ==============================
echo.
echo 1. Run as Administrator for full functionality
echo 2. Start with Quick Optimization (Option 1)
echo 3. Run System Health Check (Option 3) to verify
echo 4. Use Development Tools (Options 5-9) for coding setup
echo 5. Regular maintenance with System Cleanup (Option 4)
echo.
)
goto HELP_SUBMENU
)
if "%help_choice%"=="2" (
echo.
echo  Tool Documentation:
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\optimizer.ps1" -List
goto HELP_SUBMENU
)
if "%help_choice%"=="3" (
echo.
echo  Troubleshooting Guide:
echo.
echo COMMON ISSUES AND SOLUTIONS:
echo ============================
echo.
echo 1. "Access Denied" - Run as Administrator
echo 2. "Command not found" - Check PATH configuration
echo 3. "PowerShell errors" - Run PowerShell fix tools
echo 4. "Unicode display issues" - Use PowerShell launcher
echo 5. "Tool not working" - Run system validation
echo.
echo For more help, run System Validation (Option 22)
goto HELP_SUBMENU
)
if "%help_choice%"=="4" (
echo.
echo  System Reports:
if exist "%SCRIPT_DIR%\validation-report-*.html" (
echo Opening latest validation report...
for %%f in ("%SCRIPT_DIR%\validation-report-*.html") do start "" "%%f"
) else (
echo No reports found. Run System Validation (Option 22) to generate reports.
)
goto HELP_SUBMENU
)
if "%help_choice%"=="5" (
echo.
echo  External Resources:
echo.
echo - Microsoft Windows Documentation
echo - PowerShell Documentation
echo - Docker Documentation
echo - VS Code Documentation
echo - Cursor AI Documentation
echo.
echo Check the docs folder for local documentation.
goto HELP_SUBMENU
)
if "%help_choice%"=="6" (
echo.
echo  Support Information:
echo.
echo - Check logs in: %SCRIPT_DIR%\logs\
echo - View reports in: %SCRIPT_DIR%\reports\
echo - Run diagnostics: Option 20
echo - System validation: Option 22
echo.
echo For technical issues, check the troubleshooting guide.
goto HELP_SUBMENU
)
if "%help_choice%"=="0" goto MAIN_MENU
goto HELP_SUBMENU

:: Error handling
:INVALID_CHOICE
echo.
echo  Invalid choice! Please enter a number from 0-30.
echo.
pause
goto MAIN_MENU

:: Return to menu
:RETURN_MENU
echo.
echo ================================================================
echo Press any key to return to main menu or close this window...
pause >nul
goto MAIN_MENU

:: Exit
:EXIT
echo.
echo  Thank you for using DevOptimizer!
echo    System optimized and ready for development.
echo.
pause
exit /b 0
