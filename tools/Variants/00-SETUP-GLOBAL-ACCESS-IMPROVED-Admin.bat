:: SYNOPSIS: DevOptimizer automation script: 00-SETUP-GLOBAL-ACCESS-IMPROVED-Admin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title  - Admin Mode- Enhanced Global Access Setup
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
echo DEVOPTIMIZER - ENHANCED GLOBAL ACCESS SETUP
echo ================================================================
echo.
echo This will add D:\DevOptimizer to your system PATH so all
echo .bat files can be run from anywhere on your PC.
echo.

set /p confirm=Continue with enhanced setup? (Y/N):
if /i not "%confirm%"=="Y" (
echo Setup cancelled.
pause >nul
exit /b 0
)

echo.
echo Setting up enhanced global access...

:: Get current system PATH
for /f "usebackq tokens=2*" %%A in (`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul`) do (
set "CURRENT_PATH=%%B"
)

:: Check if DevOptimizer is already in PATH
echo %CURRENT_PATH% | findstr /i "D:\DevOptimizer" >nul
if not errorlevel 1 (
echo D:\DevOptimizer is already in system PATH
goto :refresh_env
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

:: Also update user PATH for immediate use
setx PATH "%NEW_PATH%" /M >nul 2>&1

:refresh_env
echo.
echo Refreshing environment variables...

:: Create a temporary script to refresh environment
echo @echo off > "%TEMP%\refresh_env.bat"
echo call "%SystemRoot%\System32\refresh.exe" >> "%TEMP%\refresh_env.bat"
echo if exist "%SystemRoot%\System32\refresh.exe" ( >> "%TEMP%\refresh_env.bat"
echo     "%SystemRoot%\System32\refresh.exe" >> "%TEMP%\refresh_env.bat"
echo ) else ( >> "%TEMP%\refresh_env.bat"
echo     echo Environment refresh not available >> "%TEMP%\refresh_env.bat"
echo ) >> "%TEMP%\refresh_env.bat"

:: Try to refresh environment
call "%TEMP%\refresh_env.bat" 2>nul

:: Clean up temp file
del "%TEMP%\refresh_env.bat" 2>nul

echo.
echo ================================================================
echo ENHANCED SETUP COMPLETED SUCCESSFULLY!
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
echo AVAILABLE COMMANDS:
echo.
echo System Optimization:
echo   quick-optimization.bat
echo   ultra-performance.bat
echo   system-health-check.bat
echo   system-deep-clean.bat
echo.
echo Development Tools:
echo   install-dev-tools.bat
echo   cursor-ai-optimization.bat
echo   vscode-optimization.bat
echo   docker-optimization.bat
echo.
echo Specialized Tools:
echo   fix-wsl-ubuntu.bat
echo   dual-gpu-optimization.bat
echo   development-cache-cleaner.bat
echo.
echo NOTE: You may need to restart Command Prompt/PowerShell
echo for the changes to take effect.
echo.
echo Testing global access...
echo.

:: Test if the path is working
if exist "D:\DevOptimizer\00-LAUNCHER.bat" (
echo SUCCESS: DevOptimizer launcher found
echo You can now run: launcher.bat
) else (
echo WARNING: DevOptimizer launcher not found
)

echo.
echo Available commands:
dir /b "D:\DevOptimizer\*.bat" | findstr /v "00-SETUP-GLOBAL-ACCESS" | findstr /v "00-LAUNCHER"
echo.
pause
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
