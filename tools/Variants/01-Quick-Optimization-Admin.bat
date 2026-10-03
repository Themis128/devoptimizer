:: SYNOPSIS: DevOptimizer automation script: 01-Quick-Optimization-Admin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\logs\quick-optimization.log"
set "ERROR_COUNT=0"

:: Create logs directory if it doesn't exist
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" 2>nul

:: Function to log errors
:log_error
echo [%date% %time%] ERROR: %~1 >> "%LOG_FILE%"
set /a ERROR_COUNT+=1
goto :eof

:: Function to check command success
:check_error
if errorlevel 1 (
call :log_error "Command failed: %~1"
echo ERROR: %~1
goto :eof
)
goto :eof

title  - Admin Mode-Quick-Optimization.bat - Enhanced Error Handling
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

echo                    01-Quick-Optimization.bat
echo ================================================================
echo Error handling: ENABLED
echo Log file: %LOG_FILE%
echo.

:: Check if PowerShell script exists
if not exist "%SCRIPT_DIR%\dev-optimizer-fixed.ps1" (
call :log_error "PowerShell script not found: dev-optimizer-fixed.ps1"
echo ERROR: Required PowerShell script not found!
echo Please ensure dev-optimizer-fixed.ps1 is in the same directory.
pause >nul
exit /b 1
)

:: Run PowerShell optimization script
echo Running PowerShell optimization script...
powershell -ExecutionPolicy Bypass -Command "& {Set-ExecutionPolicy Bypass -Scope Process -Force; & '%SCRIPT_DIR%\dev-optimizer-fixed.ps1' -Mode 'Basic' -NoPause}"
call :check_error "PowerShell optimization script"

:: Check for errors at the end
if %ERROR_COUNT% gtr 0 (
echo.
echo WARNING: %ERROR_COUNT% error(s) occurred. Check log: %LOG_FILE%
echo.
pause >nul
exit /b %ERROR_COUNT%
) else (
echo.
echo SUCCESS: Quick optimization completed without errors.
echo.
pause >nul
exit /b 0
)


:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
