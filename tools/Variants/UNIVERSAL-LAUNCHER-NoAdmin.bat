@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR%:~0,-1%"

:start
title  - Standard Mode- DevOptimizer
color 0B
echo.
echo ================================================================


:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

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
