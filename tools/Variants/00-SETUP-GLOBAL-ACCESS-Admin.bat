@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title  - Admin Mode- Setup Global Access
color 0A

:: Check for admin privileges
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
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

echo ADMINISTRATOR PRIVILEGES REQUIRED
echo ================================================================
echo.
echo This script requires Administrator privileges to modify the system PATH.
echo Please right-click this file and select "Run as administrator"
echo.
pause >nul
exit /b 1
)

cls
echo ================================================================
echo DEVOPTIMIZER - SETUP GLOBAL ACCESS
echo ================================================================
echo.
echo This will add D:\DevOptimizer to your system PATH so all
echo .bat files can be run from anywhere on your PC.
echo.
set /p confirm=Continue with setup? (Y/N):
if /i not "%confirm%"=="Y" (
echo Setup cancelled.
pause >nul
exit /b 0
)

echo.
echo Setting up global access...

:: Get current system PATH
for /f "usebackq tokens=2*" %%A in (`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul`) do (
set "CURRENT_PATH=%%B"
)

:: Check if DevOptimizer is already in PATH
echo %CURRENT_PATH% | findstr /i "D:\DevOptimizer" >nul
if not errorlevel 1 (
echo D:\DevOptimizer is already in system PATH
goto :success
)

:: Add DevOptimizer to PATH
echo Adding D:\DevOptimizer to system PATH...
set "NEW_PATH=%CURRENT_PATH%;D:\DevOptimizer"

:: Update system PATH
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d "%NEW_PATH%" /f >nul
if errorlevel 1 (
echo Failed to update system PATH
pause >nul
exit /b 1
)

:: Refresh environment variables
setx PATH "%NEW_PATH%" /M >nul 2>&1

:success
echo.
echo ================================================================
echo SETUP COMPLETED SUCCESSFULLY!
echo ================================================================
echo.
echo D:\DevOptimizer has been added to system PATH
echo All .bat files can now be run from anywhere
echo.
echo USAGE EXAMPLES:
echo - Open Command Prompt anywhere and type: optimizer.bat
echo - Run from any folder: insider-automation.bat
echo - Quick access: DevOptimizer.bat
echo.
echo NOTE: You may need to restart Command Prompt/PowerShell
echo for the changes to take effect.
echo.
echo Available commands:
dir /b *.bat | findstr /v "00-SETUP-GLOBAL-ACCESS.bat"
echo.
pause >nul
goto :end

:checkAdmin
set "IS_ADMIN=0"
fsutil dirty query %SystemDrive% >nul 2>&1
if errorlevel 1 (
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
) else (
set "IS_ADMIN=1"
)
exit /b

:end
endlocal


:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
