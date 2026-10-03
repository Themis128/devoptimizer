:: SYNOPSIS: DevOptimizer automation script: OPEN-UI-NEW-WINDOW-Admin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title  - Admin Mode-6): "

if "%choice%"=="1" goto :universal
if "%choice%"=="2" goto :admin
if "%choice%"=="3" goto :health
if "%choice%"=="4" goto :optimization
if "%choice%"=="5" goto :all
if "%choice%"=="6" goto :exit
goto :invalid

:universal
:start
echo Opening Universal Launcher in new window...
start "DevOptimizer Universal Launcher" cmd /k "D:\DevOptimizer\UNIVERSAL-LAUNCHER.bat"
goto :end

:admin
echo Opening Admin Mode in new window...
start "DevOptimizer Admin Mode" powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\RUN-AS-ADMIN.bat"
goto :end

:health
echo Opening System Health Check in new window...
start "System Health Check" cmd /k "D:\DevOptimizer\06-System-Health-Check.bat"
goto :end

:optimization
echo Opening Quick Optimization in new window...
start "Quick Optimization" cmd /k "D:\DevOptimizer\01-Quick-Optimization.bat"
goto :end

:all
echo Opening all UI components...
start "DevOptimizer Universal Launcher" cmd /k "D:\DevOptimizer\UNIVERSAL-LAUNCHER.bat"
timeout /t 2 /nobreak >nul
start "DevOptimizer Admin Mode" powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\RUN-AS-ADMIN.bat"
timeout /t 2 /nobreak >nul
start "System Health Check" cmd /k "D:\DevOptimizer\06-System-Health-Check.bat"
goto :end

:invalid
echo Invalid choice. Please try again.
pause
goto :start

:end
echo.
echo UI opened successfully!
echo.
pause
exit /b 0

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
