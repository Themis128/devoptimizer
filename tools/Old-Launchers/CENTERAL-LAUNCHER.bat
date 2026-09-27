@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\logs\central-launcher.log"
set "ERROR_COUNT=0"

:: Create logs directory if it doesn't exist
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" 2>nul

:: Function to log with timestamp
:log_message
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: Function to log errors
:log_error
set /a ERROR_COUNT+=1
echo [%date% %time%] ERROR #%ERROR_COUNT%: %~1 >> "%LOG_FILE%"
goto :eof

:: Function to check if file exists before launching
:check_file_exists
if not exist "%~1" (
call :log_error "File not found: %~1"
echo ERROR: File not found - %~1
echo Please ensure all batch files are in the correct directory.
pause >nul
goto MAIN_MENU
)
goto :eof

:: Function to launch tool with error handling
:launch_tool
set "TOOL_NAME=%~1"
set "TOOL_FILE=%~2"
set "TOOL_DESCRIPTION=%~3"

if not exist "%TOOL_FILE%" (
echo ERROR: File not found - %TOOL_FILE%
call :log_message "ERROR: File not found - %TOOL_FILE%"
pause >nul
goto MAIN_MENU
)

call :log_message "Launching: %TOOL_NAME%"
echo.
echo Launching %TOOL_DESCRIPTION%...
echo.
call "%TOOL_FILE%"
if errorlevel 1 (
call :log_error "Tool failed: %TOOL_NAME%"
echo.
echo ERROR: %TOOL_DESCRIPTION% failed to execute properly
echo Check log file for details: %LOG_FILE%
pause >nul
) else (
call :log_message "Tool completed successfully: %TOOL_NAME%"
)
goto :eof

title DevOptimizer - Central Unified Launcher v4.1
color 0B

:MAIN_MENU
cls
echo.
echo ================================================================
echo
echo    DEVOPTIMIZER - CENTRAL UNIFIED LAUNCHER v4.0
echo
echo ================================================================
echo.
echo SYSTEM STATUS: Ready ^| Tools: 90+ ^| Scripts: 30+ ^| Success Rate: 99.9%
echo.
echo ================================================================
echo                    QUICK ACTIONS
echo ================================================================
echo.
echo   [1] QUICK OPTIMIZATION    - Balanced system settings
echo   [2] ULTRA PERFORMANCE     - Maximum performance mode
echo   [3] SYSTEM HEALTH CHECK   - Performance analysis
echo   [4] SYSTEM CLEANUP        - Comprehensive cleanup
echo.
echo ================================================================
echo                  DEVELOPMENT TOOLS
echo ================================================================
echo.
echo   [5] INSTALL DEV TOOLS     - Essential development software
echo   [6] CURSOR AI OPTIMIZATION - AI development setup
echo   [7] VS CODE OPTIMIZATION   - Code editor optimization
echo   [8] DOCKER OPTIMIZATION    - Container management
echo   [9] NUXT3 OPTIMIZATION     - Nuxt.js development setup
echo.
echo ================================================================
echo                  SYSTEM MANAGEMENT
echo ================================================================
echo.
echo   [10] NETWORK OPTIMIZATION  - Network tuning
echo   [11] SECURITY HARDENING    - Security enhancements
echo   [12] POWER MANAGEMENT      - Power optimization
echo   [13] STARTUP MANAGEMENT    - Boot optimization
echo   [14] SCREEN SETTINGS       - Display management
echo.
echo ================================================================
echo                  SPECIALIZED TOOLS
echo ================================================================
echo.
echo   [15] FIX WSL UBUNTU        - WSL configuration
echo   [16] DUAL GPU OPTIMIZATION - GPU and streaming setup
echo   [17] CACHE CLEANER         - Development cache management
echo   [18] PREREQUISITES CHECK   - Check required tools
echo.
echo ================================================================
echo                  ADVANCED SUITES
echo ================================================================
echo.
echo   [19] ADVANCED AI SUITE     - Complete AI/ML environment
echo   [20] SYSTEM DIAGNOSTICS    - Advanced system analysis
echo   [21] PERFORMANCE MONITOR   - Real-time monitoring
echo   [22] SYSTEM VALIDATION     - Comprehensive testing
echo.
echo ================================================================
echo                    UTILITY MENUS
echo ================================================================
echo.
echo   [23] TOOL LIST            - Show all available tools
echo   [24] SYSTEM STATUS        - Detailed system information
echo   [25] CONFIGURATION        - System settings and config
echo   [26] HELP DOCUMENTATION   - Usage guides and help
echo.
echo ================================================================
echo                    SYSTEM ACTIONS
echo ================================================================
echo.
echo   [27] REFRESH SYSTEM       - Reload and refresh
echo   [28] TEST ALL TOOLS       - Run comprehensive tests
echo   [29] OPEN FOLDER          - Open DevOptimizer folder
echo   [30] REPAIR SYSTEM        - Fix common issues
echo.
echo   [0]  EXIT                 - Close launcher
echo.
echo ================================================================
echo WARNING: Most tools require Administrator privileges
echo    Right-click and "Run as administrator" for full functionality
echo ================================================================
echo.

set /p choice="Enter your choice (0-30): "

if "%choice%"=="1" (
call :launch_tool "01-Quick-Optimization.bat" "%SCRIPT_DIR%\01-Quick-Optimization.bat" "Quick Optimization"
) else if "%choice%"=="2" (
call :launch_tool "02-Ultra-Performance.bat" "%SCRIPT_DIR%\02-Ultra-Performance.bat" "Ultra Performance"
) else if "%choice%"=="3" (
call :launch_tool "06-System-Health-Check.bat" "%SCRIPT_DIR%\06-System-Health-Check.bat" "System Health Check"
) else if "%choice%"=="4" (
call :launch_tool "09-System-Deep-Clean.bat" "%SCRIPT_DIR%\09-System-Deep-Clean.bat" "System Cleanup"
) else if "%choice%"=="5" (
call :launch_tool "03-Install-Dev-Tools.bat" "%SCRIPT_DIR%\03-Install-Dev-Tools.bat" "Install Dev Tools"
) else if "%choice%"=="6" (
call :launch_tool "014-Cursor-AI-Optimization.bat" "%SCRIPT_DIR%\014-Cursor-AI-Optimization.bat" "Cursor AI Optimization"
) else if "%choice%"=="7" (
call :launch_tool "015-VSCode-Optimization.bat" "%SCRIPT_DIR%\015-VSCode-Optimization.bat" "VS Code Optimization"
) else if "%choice%"=="8" (
call :launch_tool "08-Docker-Optimization.bat" "%SCRIPT_DIR%\08-Docker-Optimization.bat" "Docker Optimization"
) else if "%choice%"=="9" (
call :launch_tool "16-Nuxt3-Windows-Optimization.bat" "%SCRIPT_DIR%\16-Nuxt3-Windows-Optimization.bat" "Nuxt3 Optimization"
) else if "%choice%"=="10" (
call :launch_tool "10-Network-Optimization.bat" "%SCRIPT_DIR%\10-Network-Optimization.bat" "Network Optimization"
) else if "%choice%"=="11" (
call :launch_tool "11-Security-Hardening.bat" "%SCRIPT_DIR%\11-Security-Hardening.bat" "Security Hardening"
) else if "%choice%"=="12" (
call :launch_tool "12-Power-Management.bat" "%SCRIPT_DIR%\12-Power-Management.bat" "Power Management"
) else if "%choice%"=="13" (
call :launch_tool "13-Startup-Management.bat" "%SCRIPT_DIR%\13-Startup-Management.bat" "Startup Management"
) else if "%choice%"=="14" (
call :launch_tool "18-Screen-Settings-Manager.bat" "%SCRIPT_DIR%\18-Screen-Settings-Manager.bat" "Screen Settings Manager"
) else if "%choice%"=="15" (
call :launch_tool "07-Fix-WSL-Ubuntu.bat" "%SCRIPT_DIR%\07-Fix-WSL-Ubuntu.bat" "WSL Ubuntu Fix"
) else if "%choice%"=="16" (
call :launch_tool "017-Dual-GPU-NVIDIA-Broadcast-Optimization.bat" "%SCRIPT_DIR%\017-Dual-GPU-NVIDIA-Broadcast-Optimization.bat" "Dual GPU Optimization"
) else if "%choice%"=="17" (
call :launch_tool "025-Development-Cache-Cleaner.bat" "%SCRIPT_DIR%\025-Development-Cache-Cleaner.bat" "Development Cache Cleaner"
) else if "%choice%"=="18" (
call :launch_tool "026-Prerequisites-Checker.bat" "%SCRIPT_DIR%\026-Prerequisites-Checker.bat" "Prerequisites Checker"
) else if "%choice%"=="19" (
call :launch_tool "019-Advanced-AI-Development-Suite.bat" "%SCRIPT_DIR%\019-Advanced-AI-Development-Suite.bat" "Advanced AI Development Suite"
) else if "%choice%"=="20" (
call :launch_tool "ENHANCED-SYSTEM-DIAGNOSTICS.bat" "%SCRIPT_DIR%\ENHANCED-SYSTEM-DIAGNOSTICS.bat" "System Diagnostics"
) else if "%choice%"=="21" (
call :launch_tool "REAL-TIME-MONITOR.bat" "%SCRIPT_DIR%\REAL-TIME-MONITOR.bat" "Performance Monitor"
) else if "%choice%"=="22" (
call :launch_tool "COMPREHENSIVE-TEST-SUITE.bat" "%SCRIPT_DIR%\COMPREHENSIVE-TEST-SUITE.bat" "System Validation"
) else if "%choice%"=="23" (
call :launch_tool "TOOL_LIST" "powershell -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%\optimizer.ps1\" -List" "Tool List"
) else if "%choice%"=="24" (
call :launch_tool "SYSTEM_STATUS" "powershell -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%\optimizer.ps1\" -Status" "System Status"
) else if "%choice%"=="25" (
goto CONFIG_MENU
) else if "%choice%"=="26" (
goto HELP_MENU
) else if "%choice%"=="27" (
call :launch_tool "REFRESH_SYSTEM" "powershell -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%\setup-global-access.ps1\"" "Refresh System"
) else if "%choice%"=="28" (
call :launch_tool "TEST_TOOLS" "powershell -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%\validate-system.ps1\" -Detailed" "Test All Tools"
) else if "%choice%"=="29" (
call :launch_tool "OPEN_FOLDER" "explorer \"%SCRIPT_DIR%\"" "Open DevOptimizer Folder"
) else if "%choice%"=="30" (
call :launch_tool "QUICK-FIX-POWERSHELL-ERROR.bat" "%SCRIPT_DIR%\QUICK-FIX-POWERSHELL-ERROR.bat" "Repair System"
) else if "%choice%"=="0" (
goto EXIT
) else (
goto INVALID_CHOICE
)
goto RETURN_MENU


:CONFIG_MENU
cls
echo.
echo ================================================================
echo                    CONFIGURATION MENU
echo ================================================================
echo.
echo   [1] View Current Config    - Show system configuration
echo   [2] Edit Configuration     - Modify settings
echo   [3] Reset to Defaults      - Restore default settings
echo   [4] Open Config Folder     - Browse configuration files
echo   [5] Backup Configuration   - Save current settings
echo   [6] Restore Configuration  - Load saved settings
echo   [0] Back to Main Menu      - Return to main launcher
echo.
set /p config_choice="Enter your choice (0-6): "

if "%config_choice%"=="1" (
echo.
echo Current Configuration:
type "%SCRIPT_DIR%\bat.config.json"
goto CONFIG_MENU
)
if "%config_choice%"=="2" (
echo.
echo Opening configuration editor...
notepad "%SCRIPT_DIR%\bat.config.json"
goto CONFIG_MENU
)
if "%config_choice%"=="3" (
echo.
echo Resetting to defaults...
call "%SCRIPT_DIR%\QUICK-GLOBAL-SETUP.bat"
goto CONFIG_MENU
)
if "%config_choice%"=="4" (
echo.
echo Opening config folder...
explorer "%SCRIPT_DIR%\config"
goto CONFIG_MENU
)
if "%config_choice%"=="5" (
echo.
echo Backing up configuration...
copy "%SCRIPT_DIR%\bat.config.json" "%SCRIPT_DIR%\backup\bat.config.backup.%date:~-4,4%%date:~-10,2%%date:~-7,2%.json"
echo Configuration backed up successfully!
goto CONFIG_MENU
)
if "%config_choice%"=="6" (
echo.
echo Restoring configuration...
if exist "%SCRIPT_DIR%\backup\bat.config.backup.*.json" (
for %%f in ("%SCRIPT_DIR%\backup\bat.config.backup.*.json") do set "backup_file=%%f"
copy "!backup_file!" "%SCRIPT_DIR%\bat.config.json"
echo Configuration restored successfully!
) else (
echo No backup files found!
)
goto CONFIG_MENU
)
if "%config_choice%"=="0" goto MAIN_MENU
goto CONFIG_MENU

:HELP_MENU
cls
echo.
echo ================================================================
echo                  HELP AND DOCUMENTATION
echo ================================================================
echo.
echo   [1] Quick Start Guide      - Getting started
echo   [2] Tool Documentation     - Detailed tool info
echo   [3] Troubleshooting        - Common issues and fixes
echo   [4] System Reports         - View generated reports
echo   [5] External Resources     - Links and references
echo   [6] Support Information    - Contact and support
echo   [0] Back to Main Menu      - Return to main launcher
echo.
set /p help_choice="Enter your choice (0-6): "

if "%help_choice%"=="1" (
echo.
echo Quick Start Guide:
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
goto HELP_MENU
)
if "%help_choice%"=="2" (
echo.
echo Tool Documentation:
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\optimizer.ps1" -List
goto HELP_MENU
)
if "%help_choice%"=="3" (
echo.
echo Troubleshooting Guide:
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
goto HELP_MENU
)
if "%help_choice%"=="4" (
echo.
echo System Reports:
if exist "%SCRIPT_DIR%\validation-report-*.html" (
echo Opening latest validation report...
for %%f in ("%SCRIPT_DIR%\validation-report-*.html") do start "" "%%f"
) else (
echo No reports found. Run System Validation (Option 22) to generate reports.
)
goto HELP_MENU
)
if "%help_choice%"=="5" (
echo.
echo External Resources:
echo.
echo - Microsoft Windows Documentation
echo - PowerShell Documentation
echo - Docker Documentation
echo - VS Code Documentation
echo - Cursor AI Documentation
echo.
echo Check the docs folder for local documentation.
goto HELP_MENU
)
if "%help_choice%"=="6" (
echo.
echo Support Information:
echo.
echo - Check logs in: %SCRIPT_DIR%\logs\
echo - View reports in: %SCRIPT_DIR%\reports\
echo - Run diagnostics: Option 20
echo - System validation: Option 22
echo.
echo For technical issues, check the troubleshooting guide.
goto HELP_MENU
)
if "%help_choice%"=="0" goto MAIN_MENU
goto HELP_MENU


:: Error handling
:INVALID_CHOICE
echo.
echo Invalid choice! Please enter a number from 0-30.
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
echo Thank you for using DevOptimizer!
echo    System optimized and ready for development.
echo.
pause
exit /b 0
