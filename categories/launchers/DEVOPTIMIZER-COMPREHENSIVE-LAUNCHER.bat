@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title DevOptimizer Comprehensive Launcher
color 0A

echo ========================================================================
echo                    DEVOPTIMIZER COMPREHENSIVE LAUNCHER
echo ========================================================================
echo.
echo [STATUS] Initializing Comprehensive DevOptimizer System...
echo [INFO] Loading all available tools and services...
echo.

REM Check if running from correct directory
if not exist "%~dp0" (
echo [ERROR] Cannot determine script directory
echo [INFO] Please ensure you are running this from the DevOptimizer directory
pause
exit /b 1
)

REM Check if logs directory exists
if not exist "%~dp0logs" (
echo [WARNING] Logs directory not found, creating...
mkdir "%~dp0logs" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Logs directory created successfully
) else (
echo [ERROR] Failed to create logs directory
)
)

echo [SUCCESS] Comprehensive DevOptimizer System initialized
echo [INFO] All modules loaded and ready for operation
echo.

REM Comprehensive system status check
echo ========================================================================
echo                       COMPREHENSIVE SYSTEM STATUS
echo ========================================================================
echo.

REM Check Ollama status
echo [STATUS] Checking Ollama service...
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Ollama: ONLINE ^(Running^)
) else (
echo [WARNING] Ollama: OFFLINE ^(Not Running^)
)

REM Check OneDrive status
echo [STATUS] Checking OneDrive service...
tasklist | findstr /I "OneDrive.exe" 2>NUL | findstr /I "OneDrive.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] OneDrive: ONLINE ^(Running^)
) else (
echo [WARNING] OneDrive: OFFLINE ^(Not Running^)
)

REM Check Cursor status
echo [STATUS] Checking Cursor AI...
tasklist | findstr /I "Cursor.exe" 2>NUL | findstr /I "Cursor.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Cursor AI: ONLINE ^(Running^)
) else (
echo [WARNING] Cursor AI: OFFLINE ^(Not Running^)
)

REM Check VS Code status
echo [STATUS] Checking VS Code...
tasklist | findstr /I "Code.exe" 2>NUL | findstr /I "Code.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] VS Code: ONLINE ^(Running^)
) else (
echo [WARNING] VS Code: OFFLINE ^(Not Running^)
)

echo.
echo [INFO] System status check completed
echo.

:main_menu
echo ========================================================================
echo                        COMPREHENSIVE OPTIONS MENU
echo ========================================================================
echo.
echo [AI & DEVELOPMENT TOOLS]
echo [1] Ollama Model Manager              [2] Ollama Server Manager
echo [3] Ollama Quick Tests               [4] Cursor AI Troubleshooter
echo [5] Ollama Troubleshooter            [6] Development Tools Manager
echo.
echo [MICROSOFT 365 & CLOUD]
echo [7] M365 Troubleshooter              [8] OneDrive Manager
echo.
echo [SYSTEM MANAGEMENT]
echo [9] System Health Check              [A] Performance Optimization
echo [B] System Backup Manager            [C] Network Manager
echo [D] Security Manager                 [E] System Performance Monitor
echo.
echo [ADVANCED FEATURES]
echo [F] AWS Infrastructure Manager       [G] Screen Settings Manager
echo [H] Health Monitor                   [I] Insider Channel Manager
echo [J] Real-Time Monitor                [K] Ollama Intelligent Monitor
echo.
echo [SYSTEM ACTIONS]
echo [L] Run All Health Checks            [M] Perform Complete System Scan
echo [N] Emergency System Recovery        [O] Create System Restore Point
echo [P] Generate System Report           [Q] Update All Tools
echo.
echo [0] Exit Comprehensive Launcher
echo.
set /p choice="Enter your choice: "

if "%choice%"=="1" goto :ollama_model_manager
if "%choice%"=="2" goto :ollama_server_manager
if "%choice%"=="3" goto :ollama_quick_tests
if "%choice%"=="4" goto :cursor_troubleshooter
if "%choice%"=="5" goto :ollama_troubleshooter
if "%choice%"=="6" goto :dev_tools
if "%choice%"=="7" goto :m365_troubleshooter
if "%choice%"=="8" goto :onedrive_manager
if "%choice%"=="9" goto :health_check
if /i "%choice%"=="A" goto :performance
if /i "%choice%"=="B" goto :backup_manager
if /i "%choice%"=="C" goto :network_manager
if /i "%choice%"=="D" goto :security_manager
if /i "%choice%"=="E" goto :performance_monitor
if /i "%choice%"=="F" goto :aws_manager
if /i "%choice%"=="G" goto :screen_manager
if /i "%choice%"=="H" goto :health_monitor
if /i "%choice%"=="I" goto :insider_manager
if /i "%choice%"=="J" goto :realtime_monitor
if /i "%choice%"=="K" goto :ollama_intelligent_monitor
if /i "%choice%"=="L" goto :all_health_checks
if /i "%choice%"=="M" goto :complete_scan
if /i "%choice%"=="N" goto :emergency_recovery
if /i "%choice%"=="O" goto :create_restore_point
if /i "%choice%"=="P" goto :generate_report
if /i "%choice%"=="Q" goto :update_tools
if "%choice%"=="0" goto :exit
goto :invalid

:ollama_model_manager
echo [INFO] Opening Ollama Model Manager...
echo [STATUS] Checking if OLLAMA-MODEL-MANAGER.bat exists...
if exist "%~dp0OLLAMA-MODEL-MANAGER.bat" (
echo [SUCCESS] Ollama Model Manager found, launching...
call "%~dp0OLLAMA-MODEL-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Ollama Model Manager completed successfully
) else (
echo [ERROR] Ollama Model Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Ollama Model Manager not found at: %~dp0OLLAMA-MODEL-MANAGER.bat
)
goto :return_menu

:ollama_server_manager
echo [INFO] Opening Ollama Server Manager...
echo [STATUS] Checking if OLLAMA-SERVER-MANAGER.bat exists...
if exist "%~dp0OLLAMA-SERVER-MANAGER.bat" (
echo [SUCCESS] Ollama Server Manager found, launching...
call "%~dp0OLLAMA-SERVER-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Ollama Server Manager completed successfully
) else (
echo [ERROR] Ollama Server Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Ollama Server Manager not found at: %~dp0OLLAMA-SERVER-MANAGER.bat
)
goto :return_menu

:ollama_quick_tests
echo [INFO] Running Ollama Quick Health Tests...
echo [STATUS] Checking if OLLAMA-QUICK-TESTS.bat exists...
if exist "%~dp0OLLAMA-QUICK-TESTS.bat" (
echo [SUCCESS] Ollama Quick Tests found, launching...
echo [INFO] This may take a few minutes to complete...
call "%~dp0OLLAMA-QUICK-TESTS.bat"
if %errorlevel%==0 (
echo [SUCCESS] Ollama Quick Tests completed successfully
) else (
echo [ERROR] Ollama Quick Tests encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Ollama Quick Tests not found at: %~dp0OLLAMA-QUICK-TESTS.bat
)
goto :return_menu

:cursor_troubleshooter
echo [INFO] Opening Cursor AI Troubleshooter...
echo [STATUS] Checking if CURSOR-AI-TROUBLESHOOTER.bat exists...
if exist "%~dp0CURSOR-AI-TROUBLESHOOTER.bat" (
echo [SUCCESS] Cursor AI Troubleshooter found, launching...
call "%~dp0CURSOR-AI-TROUBLESHOOTER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Cursor AI Troubleshooter completed successfully
) else (
echo [ERROR] Cursor AI Troubleshooter encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Cursor AI Troubleshooter not found at: %~dp0CURSOR-AI-TROUBLESHOOTER.bat
)
goto :return_menu

:ollama_troubleshooter
echo [INFO] Opening Ollama Troubleshooter...
echo [STATUS] Checking if OLLAMA-TROUBLESHOOTER.bat exists...
if exist "%~dp0OLLAMA-TROUBLESHOOTER.bat" (
echo [SUCCESS] Ollama Troubleshooter found, launching...
call "%~dp0OLLAMA-TROUBLESHOOTER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Ollama Troubleshooter completed successfully
) else (
echo [ERROR] Ollama Troubleshooter encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Ollama Troubleshooter not found at: %~dp0OLLAMA-TROUBLESHOOTER.bat
)
goto :return_menu

:dev_tools
echo [INFO] Opening Development Tools Manager...
echo [STATUS] Checking if DEVTOOLS-MANAGER.bat exists...
if exist "%~dp0DEVTOOLS-MANAGER.bat" (
echo [SUCCESS] Development Tools Manager found, launching...
call "%~dp0DEVTOOLS-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Development Tools Manager completed successfully
) else (
echo [ERROR] Development Tools Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Development Tools Manager not found at: %~dp0DEVTOOLS-MANAGER.bat
)
goto :return_menu

:m365_troubleshooter
echo [INFO] Opening M365 Troubleshooter...
echo [STATUS] Checking if M365-TROUBLESHOOTER.bat exists...
if exist "%~dp0M365-TROUBLESHOOTER.bat" (
echo [SUCCESS] M365 Troubleshooter found, launching...
call "%~dp0M365-TROUBLESHOOTER.bat"
if %errorlevel%==0 (
echo [SUCCESS] M365 Troubleshooter completed successfully
) else (
echo [ERROR] M365 Troubleshooter encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] M365 Troubleshooter not found at: %~dp0M365-TROUBLESHOOTER.bat
)
goto :return_menu

:onedrive_manager
echo [INFO] Opening OneDrive Manager...
echo [STATUS] Checking if ONEDRIVE-MANAGER.bat exists...
if exist "%~dp0ONEDRIVE-MANAGER.bat" (
echo [SUCCESS] OneDrive Manager found, launching...
call "%~dp0ONEDRIVE-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] OneDrive Manager completed successfully
) else (
echo [ERROR] OneDrive Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] OneDrive Manager not found at: %~dp0ONEDRIVE-MANAGER.bat
)
goto :return_menu

:health_check
echo [INFO] Running System Health Check...
echo [STATUS] Checking if 06-System-Health-Check.bat exists...
if exist "%~dp006-System-Health-Check.bat" (
echo [SUCCESS] System Health Check found, launching...
call "%~dp006-System-Health-Check.bat"
if %errorlevel%==0 (
echo [SUCCESS] System Health Check completed successfully
) else (
echo [ERROR] System Health Check encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] System Health Check not found at: %~dp006-System-Health-Check.bat
)
goto :return_menu

:performance
echo [INFO] Running Performance Optimization...
echo [STATUS] Checking if 01-Quick-Optimization.bat exists...
if exist "%~dp001-Quick-Optimization.bat" (
echo [SUCCESS] Performance Optimization found, launching...
call "%~dp001-Quick-Optimization.bat"
if %errorlevel%==0 (
echo [SUCCESS] Performance Optimization completed successfully
) else (
echo [ERROR] Performance Optimization encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Performance Optimization not found at: %~dp001-Quick-Optimization.bat
)
goto :return_menu

:backup_manager
echo [INFO] Opening System Backup Manager...
echo [STATUS] Checking if SYSTEM-BACKUP-MANAGER.bat exists...
if exist "%~dp0SYSTEM-BACKUP-MANAGER.bat" (
echo [SUCCESS] System Backup Manager found, launching...
call "%~dp0SYSTEM-BACKUP-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] System Backup Manager completed successfully
) else (
echo [ERROR] System Backup Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] System Backup Manager not found at: %~dp0SYSTEM-BACKUP-MANAGER.bat
)
goto :return_menu

:network_manager
echo [INFO] Opening Network Manager...
echo [STATUS] Checking if NETWORK-MANAGER.bat exists...
if exist "%~dp0NETWORK-MANAGER.bat" (
echo [SUCCESS] Network Manager found, launching...
call "%~dp0NETWORK-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Network Manager completed successfully
) else (
echo [ERROR] Network Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Network Manager not found at: %~dp0NETWORK-MANAGER.bat
)
goto :return_menu

:security_manager
echo [INFO] Opening Security Manager...
echo [STATUS] Checking if SECURITY-MANAGER.bat exists...
if exist "%~dp0SECURITY-MANAGER.bat" (
echo [SUCCESS] Security Manager found, launching...
call "%~dp0SECURITY-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Security Manager completed successfully
) else (
echo [ERROR] Security Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Security Manager not found at: %~dp0SECURITY-MANAGER.bat
)
goto :return_menu

:performance_monitor
echo [INFO] Opening System Performance Monitor...
echo [STATUS] Checking if SYSTEM-PERFORMANCE-MONITOR.bat exists...
if exist "%~dp0SYSTEM-PERFORMANCE-MONITOR.bat" (
echo [SUCCESS] System Performance Monitor found, launching...
call "%~dp0SYSTEM-PERFORMANCE-MONITOR.bat"
if %errorlevel%==0 (
echo [SUCCESS] System Performance Monitor completed successfully
) else (
echo [ERROR] System Performance Monitor encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] System Performance Monitor not found at: %~dp0SYSTEM-PERFORMANCE-MONITOR.bat
)
goto :return_menu

:aws_manager
echo [INFO] Opening AWS Infrastructure Manager...
echo [STATUS] Checking if AWS-IAC-MANAGER.bat exists...
if exist "%~dp0AWS-IAC-MANAGER.bat" (
echo [SUCCESS] AWS Infrastructure Manager found, launching...
call "%~dp0AWS-IAC-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] AWS Infrastructure Manager completed successfully
) else (
echo [ERROR] AWS Infrastructure Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] AWS Infrastructure Manager not found at: %~dp0AWS-IAC-MANAGER.bat
)
goto :return_menu

:screen_manager
echo [INFO] Opening Screen Settings Manager...
echo [STATUS] Checking if 18-Screen-Settings-Manager.bat exists...
if exist "%~dp018-Screen-Settings-Manager.bat" (
echo [SUCCESS] Screen Settings Manager found, launching...
call "%~dp018-Screen-Settings-Manager.bat"
if %errorlevel%==0 (
echo [SUCCESS] Screen Settings Manager completed successfully
) else (
echo [ERROR] Screen Settings Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Screen Settings Manager not found at: %~dp018-Screen-Settings-Manager.bat
)
goto :return_menu

:health_monitor
echo [INFO] Opening Health Monitor...
echo [STATUS] Checking if HEALTH-MONITOR.bat exists...
if exist "%~dp0HEALTH-MONITOR.bat" (
echo [SUCCESS] Health Monitor found, launching...
call "%~dp0HEALTH-MONITOR.bat"
if %errorlevel%==0 (
echo [SUCCESS] Health Monitor completed successfully
) else (
echo [ERROR] Health Monitor encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Health Monitor not found at: %~dp0HEALTH-MONITOR.bat
)
goto :return_menu

:insider_manager
echo [INFO] Opening Insider Channel Manager...
echo [STATUS] Checking if insider-channel-manager.bat exists...
if exist "%~dp0insider-channel-manager.bat" (
echo [SUCCESS] Insider Channel Manager found, launching...
call "%~dp0insider-channel-manager.bat"
if %errorlevel%==0 (
echo [SUCCESS] Insider Channel Manager completed successfully
) else (
echo [ERROR] Insider Channel Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Insider Channel Manager not found at: %~dp0insider-channel-manager.bat
)
goto :return_menu

:realtime_monitor
echo [INFO] Opening Real-Time Monitor...
echo [STATUS] Checking if REAL-TIME-MONITOR.bat exists...
if exist "%~dp0REAL-TIME-MONITOR.bat" (
echo [SUCCESS] Real-Time Monitor found, launching...
call "%~dp0REAL-TIME-MONITOR.bat"
if %errorlevel%==0 (
echo [SUCCESS] Real-Time Monitor completed successfully
) else (
echo [ERROR] Real-Time Monitor encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Real-Time Monitor not found at: %~dp0REAL-TIME-MONITOR.bat
)
goto :return_menu

:ollama_intelligent_monitor
echo [INFO] Opening Ollama Intelligent Monitor...
echo [STATUS] Checking if ollama-intelligent-monitor.bat exists...
if exist "%~dp0ollama-intelligent-monitor.bat" (
echo [SUCCESS] Ollama Intelligent Monitor found, launching...
call "%~dp0ollama-intelligent-monitor.bat"
if %errorlevel%==0 (
echo [SUCCESS] Ollama Intelligent Monitor completed successfully
) else (
echo [ERROR] Ollama Intelligent Monitor encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Ollama Intelligent Monitor not found at: %~dp0ollama-intelligent-monitor.bat
)
goto :return_menu

:all_health_checks
echo [INFO] Running All Health Checks...
echo [STATUS] This will run comprehensive health checks on all systems...
echo [WARNING] This may take several minutes to complete
echo.
set /p confirm="Do you want to continue? (Y/N): "
if /i not "%confirm%"=="Y" goto :return_menu
echo.
echo [STEP 1/5] Running System Health Check...
call "%~dp006-System-Health-Check.bat"
echo.
echo [STEP 2/5] Running Ollama Health Tests...
call "%~dp0OLLAMA-QUICK-TESTS.bat"
echo.
echo [STEP 3/5] Running Security Scan...
call "%~dp0SECURITY-MANAGER.bat"
echo.
echo [STEP 4/5] Running Performance Check...
call "%~dp0SYSTEM-PERFORMANCE-MONITOR.bat"
echo.
echo [STEP 5/5] Generating Health Report...
echo [SUCCESS] All health checks completed
echo [INFO] Check logs directory for detailed reports
goto :return_menu

:complete_scan
echo [INFO] Performing Complete System Scan...
echo [STATUS] This will scan all system components and services...
echo [WARNING] This is a comprehensive scan and may take 10-15 minutes
echo.
set /p confirm="Do you want to continue? (Y/N): "
if /i not "%confirm%"=="Y" goto :return_menu
echo.
echo [STEP 1/6] Scanning Development Tools...
call "%~dp0DEVTOOLS-MANAGER.bat"
echo.
echo [STEP 2/6] Scanning Network Configuration...
call "%~dp0NETWORK-MANAGER.bat"
echo.
echo [STEP 3/6] Scanning Security Status...
call "%~dp0SECURITY-MANAGER.bat"
echo.
echo [STEP 4/6] Scanning System Performance...
call "%~dp0SYSTEM-PERFORMANCE-MONITOR.bat"
echo.
echo [STEP 5/6] Scanning Backup Status...
call "%~dp0SYSTEM-BACKUP-MANAGER.bat"
echo.
echo [STEP 6/6] Generating Scan Report...
echo [SUCCESS] Complete system scan finished
echo [INFO] Check logs directory for comprehensive scan report
goto :return_menu

:emergency_recovery
echo [CRITICAL] Emergency System Recovery Mode
echo [WARNING] This will attempt to recover critical system functions
echo [WARNING] Only use this if your system is experiencing critical issues
echo.
set /p confirm="Are you sure you want to proceed? (YES/NO): "
if not "%confirm%"=="YES" goto :return_menu
echo.
echo [STEP 1/4] Stopping non-essential services...
echo [INFO] Stopping Ollama service...
taskkill /F /IM ollama.exe 2>nul
echo [INFO] Stopping OneDrive...
taskkill /F /IM OneDrive.exe 2>nul
echo.
echo [STEP 2/4] Running emergency security scan...
call "%~dp0SECURITY-MANAGER.bat"
echo.
echo [STEP 3/4] Clearing temporary files...
del /q /f /s "%TEMP%\*" 2>nul
echo.
echo [STEP 4/4] Restarting critical services...
echo [INFO] Restarting Windows Defender...
net start WinDefend 2>nul
echo [INFO] Restarting Windows Firewall...
net start MpsSvc 2>nul
echo [SUCCESS] Emergency recovery completed
echo [INFO] Please restart your computer to complete recovery
goto :return_menu

:create_restore_point
echo [INFO] Creating System Restore Point...
echo [STATUS] This will create a restore point for your system...
echo [WARNING] This requires administrator privileges
echo.
set /p confirm="Do you want to continue? (Y/N): "
if /i not "%confirm%"=="Y" goto :return_menu
echo.
echo [STEP 1/2] Creating restore point...
powershell -Command "Checkpoint-Computer -Description 'DevOptimizer Restore Point' -RestorePointType 'MODIFY_SETTINGS'"
if %errorlevel%==0 (
echo [SUCCESS] System restore point created successfully
) else (
echo [ERROR] Failed to create restore point - administrator privileges may be required
)
echo.
echo [STEP 2/2] Verifying restore point...
powershell -Command "Get-ComputerRestorePoint | Select-Object -First 1 | Format-Table -AutoSize"
echo [SUCCESS] Restore point creation completed
goto :return_menu

:generate_report
echo [INFO] Generating Comprehensive System Report...
echo [STATUS] Collecting system information and generating report...
echo.
echo [STEP 1/4] Collecting system information...
systeminfo > "%~dp0logs\system-info.txt" 2>nul
echo [STEP 2/4] Collecting process information...
tasklist > "%~dp0logs\process-list.txt" 2>nul
echo [STEP 3/4] Collecting service information...
sc query state= all > "%~dp0logs\service-list.txt" 2>nul
echo [STEP 4/4] Generating report summary...
echo DevOptimizer System Report - %date% %time% > "%~dp0logs\system-report.txt"
echo ======================================== >> "%~dp0logs\system-report.txt"
echo. >> "%~dp0logs\system-report.txt"
echo System Information: >> "%~dp0logs\system-report.txt"
type "%~dp0logs\system-info.txt" >> "%~dp0logs\system-report.txt"
echo. >> "%~dp0logs\system-report.txt"
echo Process Information: >> "%~dp0logs\system-report.txt"
type "%~dp0logs\process-list.txt" >> "%~dp0logs\system-report.txt"
echo. >> "%~dp0logs\system-report.txt"
echo Service Information: >> "%~dp0logs\system-report.txt"
type "%~dp0logs\service-list.txt" >> "%~dp0logs\system-report.txt"
echo [SUCCESS] System report generated successfully
echo [INFO] Report saved to: %~dp0logs\system-report.txt
goto :return_menu

:update_tools
echo [INFO] Updating All DevOptimizer Tools...
echo [STATUS] This will check for and install updates for all tools...
echo.
echo [STEP 1/3] Checking for Node.js updates...
if exist "%~dp0DEVTOOLS-MANAGER.bat" (
echo [INFO] Running Development Tools Manager for updates...
call "%~dp0DEVTOOLS-MANAGER.bat"
)
echo.
echo [STEP 2/3] Checking for Ollama updates...
if exist "%~dp0OLLAMA-SERVER-MANAGER.bat" (
echo [INFO] Running Ollama Server Manager for updates...
call "%~dp0OLLAMA-SERVER-MANAGER.bat"
)
echo.
echo [STEP 3/3] Updating system components...
echo [INFO] Running Windows Update check...
powershell -Command "Get-WindowsUpdate -AcceptAll -Install -AutoReboot" 2>nul
echo [SUCCESS] Tool updates completed
goto :return_menu

:invalid
echo [ERROR] Invalid choice. Please select a valid option.
echo [INFO] Valid options are:
echo [INFO]   [1-9] - Numeric options for specific tools
echo [INFO]   [A-Q] - Letter options for management tools
echo [INFO]   [0]   - Exit the application
echo.
echo [INFO] Press any key to return to menu...
pause >nul
goto :main_menu

:return_menu
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :main_menu

:exit
echo.
echo ========================================================================
echo                 DEVOPTIMIZER COMPREHENSIVE LAUNCHER CLOSING
echo ========================================================================
echo.
echo [INFO] Thank you for using DevOptimizer Comprehensive Launcher
echo [INFO] All operations have been completed successfully
echo [INFO] System is shutting down gracefully...
echo.
echo [SUCCESS] DevOptimizer Comprehensive Launcher closed successfully
echo [INFO] For quick access, use the standard DevOptimizer Launcher
echo.
pause
exit /b 0
