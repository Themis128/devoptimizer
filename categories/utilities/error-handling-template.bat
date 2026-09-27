@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\logs\error.log"
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

:: Main script execution
title %~nx0 - Error Handling Enabled
echo.
echo ================================================================
echo                    %~nx0
echo ================================================================
echo Error handling: ENABLED
echo Log file: %LOG_FILE%
echo.

:: Your main commands here
:: Example:
:: your_command_here
:: call :check_error "your_command_here failed"

:: Check for errors at the end
if %ERROR_COUNT% gtr 0 (
echo.
echo WARNING: %ERROR_COUNT% error(s) occurred. Check log: %LOG_FILE%
echo.
) else (
echo.
echo SUCCESS: No errors occurred.
echo.
)

pause >nul
exit /b %ERROR_COUNT%
