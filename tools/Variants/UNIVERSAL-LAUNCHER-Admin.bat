@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR%:~0,-1%"

:start
title  - Admin Mode- DevOptimizer
color 0B
echo.
echo ================================================================


:: Check for admin privileges
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
echo.
echo [ERROR] This script requires Administrator privileges.
echo Please run this script as Administrator.
echo.
pause
exit /b 1
) else (
echo [INFO] Running with Administrator privileges
)

echo                     UNIVERSAL LAUNCHER
echo ================================================================
echo.
:start
echo Choose an option:
echo 1. System Health Check (No Admin)
echo 2. Quick Optimization (No Admin)
echo 3. Run as Administrator (Full Features)
echo 4. Exit
echo.
set /p choice="Enter your choice (1-4): "

if "%choice%"=="1" goto :health_check
if "%choice%"=="2" goto :quick_opt
if "%choice%"=="3" goto :run_admin
if "%choice%"=="4" goto :exit
goto :invalid

:health_check
call "D:\DevOptimizer\06-System-Health-Check-NoAdmin.bat"
goto :menu

:quick_opt
call "D:\DevOptimizer\01-Quick-Optimization-NoAdmin.bat"
goto :menu

:run_admin
echo Starting PowerShell as Administrator...
powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"D:\DevOptimizer\RUN-AS-ADMIN.bat\"' -Verb RunAs"
goto :menu

:invalid
echo Invalid choice. Please try again.
goto :menu

:menu
echo.
echo Press any key to return to menu...
pause >nul
goto :start

:exit
exit /b 0


:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
