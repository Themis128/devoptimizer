@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title DevOptimizer System Launcher
color 0C

echo ========================================================================
echo                        DEVOPTIMIZER SYSTEM LAUNCHER
echo ========================================================================
echo.
echo [STATUS] Initializing DevOptimizer System...
echo [INFO] Checking system prerequisites...

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

echo [SUCCESS] DevOptimizer System initialized successfully
echo [INFO] System ready for operation
echo.

REM Quick system status check
echo ========================================================================
echo                          QUICK SYSTEM STATUS
echo ========================================================================
echo.

REM Check Ollama status
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [STATUS] Ollama: ONLINE
) else (
echo [STATUS] Ollama: OFFLINE
)

REM Check OneDrive status
tasklist | findstr /I "OneDrive.exe" 2>NUL | findstr /I "OneDrive.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [STATUS] OneDrive: ONLINE
) else (
echo [STATUS] OneDrive: OFFLINE
)

REM Check Cursor status
tasklist | findstr /I "Cursor.exe" 2>NUL | findstr /I "Cursor.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [STATUS] Cursor AI: ONLINE
) else (
echo [STATUS] Cursor AI: OFFLINE
)

echo.
echo ========================================================================
:start
echo                          AVAILABLE OPTIONS
echo ========================================================================
echo.
echo [1] Ollama Model Manager
echo [2] Ollama Server Manager (NEW)
echo [3] Ollama Quick Tests (NEW)
echo [4] M365 Troubleshooter
echo [5] Cursor AI Troubleshooter
echo [6] Ollama Troubleshooter
echo [7] OneDrive Manager
echo [8] System Health Check
echo [9] Performance Optimization
echo [A] Development Tools Manager
echo [B] System Backup Manager
echo [C] Network Manager
echo [D] Security Manager
echo [E] System Performance Monitor
echo [F] DevOptimizer Comprehensive Launcher
echo [0] Exit
echo.
set /p choice="Enter your choice: "

if "%choice%"=="1" goto :ollama_manager
if "%choice%"=="2" goto :ollama_server_manager
if "%choice%"=="3" goto :ollama_quick_tests
if "%choice%"=="4" goto :m365_troubleshooter
if "%choice%"=="5" goto :cursor_troubleshooter
if "%choice%"=="6" goto :ollama_troubleshooter
if "%choice%"=="7" goto :onedrive_manager
if "%choice%"=="8" goto :health_check
if "%choice%"=="9" goto :performance
if /i "%choice%"=="A" goto :dev_tools
if /i "%choice%"=="B" goto :backup_manager
if /i "%choice%"=="C" goto :network_manager
if /i "%choice%"=="D" goto :security_manager
if /i "%choice%"=="E" goto :performance_monitor
if /i "%choice%"=="F" goto :comprehensive_launcher
if "%choice%"=="0" goto :exit
goto :invalid

:ollama_manager
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
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

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
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

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
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:m365_troubleshooter
echo [INFO] Opening M365 Troubleshooter...
echo [STATUS] Checking if M365-TROUBLESHOOTER.bat exists...
if exist "%~dp0M365-TROUBLESHOOTER.bat" (
echo [SUCCESS] M365 Troubleshooter found, launching...
echo [INFO] This will diagnose Microsoft 365 issues...
call "%~dp0M365-TROUBLESHOOTER.bat"
if %errorlevel%==0 (
echo [SUCCESS] M365 Troubleshooter completed successfully
) else (
echo [ERROR] M365 Troubleshooter encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] M365 Troubleshooter not found at: %~dp0M365-TROUBLESHOOTER.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:cursor_troubleshooter
echo [INFO] Opening Cursor AI Troubleshooter...
echo [STATUS] Checking if CURSOR-AI-TROUBLESHOOTER.bat exists...
if exist "%~dp0CURSOR-AI-TROUBLESHOOTER.bat" (
echo [SUCCESS] Cursor AI Troubleshooter found, launching...
echo [INFO] This will diagnose Cursor AI issues...
call "%~dp0CURSOR-AI-TROUBLESHOOTER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Cursor AI Troubleshooter completed successfully
) else (
echo [ERROR] Cursor AI Troubleshooter encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Cursor AI Troubleshooter not found at: %~dp0CURSOR-AI-TROUBLESHOOTER.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:ollama_troubleshooter
echo [INFO] Opening Ollama Troubleshooter...
echo [STATUS] Checking if OLLAMA-TROUBLESHOOTER.bat exists...
if exist "%~dp0OLLAMA-TROUBLESHOOTER.bat" (
echo [SUCCESS] Ollama Troubleshooter found, launching...
echo [INFO] This will diagnose Ollama issues...
call "%~dp0OLLAMA-TROUBLESHOOTER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Ollama Troubleshooter completed successfully
) else (
echo [ERROR] Ollama Troubleshooter encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Ollama Troubleshooter not found at: %~dp0OLLAMA-TROUBLESHOOTER.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:onedrive_manager
echo [INFO] Opening OneDrive Manager...
echo [STATUS] Checking if ONEDRIVE-MANAGER.bat exists...
if exist "%~dp0ONEDRIVE-MANAGER.bat" (
echo [SUCCESS] OneDrive Manager found, launching...
echo [INFO] This will manage your OneDrive accounts...
call "%~dp0ONEDRIVE-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] OneDrive Manager completed successfully
) else (
echo [ERROR] OneDrive Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] OneDrive Manager not found at: %~dp0ONEDRIVE-MANAGER.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:health_check
echo [INFO] Running System Health Check...
echo [STATUS] Checking if 06-System-Health-Check.bat exists...
if exist "%~dp006-System-Health-Check.bat" (
echo [SUCCESS] System Health Check found, launching...
echo [INFO] This will perform comprehensive system diagnostics...
call "%~dp006-System-Health-Check.bat"
if %errorlevel%==0 (
echo [SUCCESS] System Health Check completed successfully
) else (
echo [ERROR] System Health Check encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] System Health Check not found at: %~dp006-System-Health-Check.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:performance
echo [INFO] Running Performance Optimization...
echo [STATUS] Checking if 01-Quick-Optimization.bat exists...
if exist "%~dp001-Quick-Optimization.bat" (
echo [SUCCESS] Performance Optimization found, launching...
echo [INFO] This will optimize system performance...
call "%~dp001-Quick-Optimization.bat"
if %errorlevel%==0 (
echo [SUCCESS] Performance Optimization completed successfully
) else (
echo [ERROR] Performance Optimization encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Performance Optimization not found at: %~dp001-Quick-Optimization.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:dev_tools
echo [INFO] Opening Development Tools Manager...
echo [STATUS] Checking if DEVTOOLS-MANAGER.bat exists...
if exist "%~dp0DEVTOOLS-MANAGER.bat" (
echo [SUCCESS] Development Tools Manager found, launching...
echo [INFO] This will manage development tools and environments...
call "%~dp0DEVTOOLS-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Development Tools Manager completed successfully
) else (
echo [ERROR] Development Tools Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Development Tools Manager not found at: %~dp0DEVTOOLS-MANAGER.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:backup_manager
echo [INFO] Opening System Backup Manager...
echo [STATUS] Checking if SYSTEM-BACKUP-MANAGER.bat exists...
if exist "%~dp0SYSTEM-BACKUP-MANAGER.bat" (
echo [SUCCESS] System Backup Manager found, launching...
echo [INFO] This will manage system backups and restore operations...
call "%~dp0SYSTEM-BACKUP-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] System Backup Manager completed successfully
) else (
echo [ERROR] System Backup Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] System Backup Manager not found at: %~dp0SYSTEM-BACKUP-MANAGER.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:network_manager
echo [INFO] Opening Network Manager...
echo [STATUS] Checking if NETWORK-MANAGER.bat exists...
if exist "%~dp0NETWORK-MANAGER.bat" (
echo [SUCCESS] Network Manager found, launching...
echo [INFO] This will manage network connectivity and diagnostics...
call "%~dp0NETWORK-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Network Manager completed successfully
) else (
echo [ERROR] Network Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Network Manager not found at: %~dp0NETWORK-MANAGER.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:security_manager
echo [INFO] Opening Security Manager...
echo [STATUS] Checking if SECURITY-MANAGER.bat exists...
if exist "%~dp0SECURITY-MANAGER.bat" (
echo [SUCCESS] Security Manager found, launching...
echo [INFO] This will manage system security and protection...
call "%~dp0SECURITY-MANAGER.bat"
if %errorlevel%==0 (
echo [SUCCESS] Security Manager completed successfully
) else (
echo [ERROR] Security Manager encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Security Manager not found at: %~dp0SECURITY-MANAGER.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:performance_monitor
echo [INFO] Opening System Performance Monitor...
echo [STATUS] Checking if SYSTEM-PERFORMANCE-MONITOR.bat exists...
if exist "%~dp0SYSTEM-PERFORMANCE-MONITOR.bat" (
echo [SUCCESS] System Performance Monitor found, launching...
echo [INFO] This will monitor system performance in real-time...
call "%~dp0SYSTEM-PERFORMANCE-MONITOR.bat"
if %errorlevel%==0 (
echo [SUCCESS] System Performance Monitor completed successfully
) else (
echo [ERROR] System Performance Monitor encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] System Performance Monitor not found at: %~dp0SYSTEM-PERFORMANCE-MONITOR.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:comprehensive_launcher
echo [INFO] Opening DevOptimizer Comprehensive Launcher...
echo [STATUS] Checking if DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat exists...
if exist "%~dp0DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat" (
echo [SUCCESS] DevOptimizer Comprehensive Launcher found, launching...
echo [INFO] This will open the comprehensive launcher with all features...
call "%~dp0DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat"
if %errorlevel%==0 (
echo [SUCCESS] DevOptimizer Comprehensive Launcher completed successfully
) else (
echo [ERROR] DevOptimizer Comprehensive Launcher encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] DevOptimizer Comprehensive Launcher not found at: %~dp0DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:invalid
echo [ERROR] Invalid choice. Please select a valid option (1-9, A-F, 0)
echo [INFO] Valid options are:
echo [INFO]   [1-9] - Numeric options for specific tools
echo [INFO]   [A-F] - Letter options for management tools
echo [INFO]   [0]   - Exit the application
echo.
echo [INFO] Press any key to return to menu...
pause >nul
goto :menu

:exit
echo.
echo ========================================================================
echo                        DEVOPTIMIZER SYSTEM CLOSING
echo ========================================================================
echo.
echo [INFO] Thank you for using DevOptimizer System
echo [INFO] All operations have been completed
echo [INFO] System is shutting down gracefully...
echo.
echo [SUCCESS] DevOptimizer System closed successfully
echo.
pause
exit /b 0

:menu
cls
goto :start
