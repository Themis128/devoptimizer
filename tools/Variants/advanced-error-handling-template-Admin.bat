:: SYNOPSIS: DevOptimizer automation script: advanced-error-handling-template-Admin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\logs\advanced-error.log"
set "ERROR_COUNT=0"
set "RETRY_COUNT=0"
set "MAX_RETRIES=3"
set "START_TIME=%time%"

:: Create logs directory if it doesn't exist
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" 2>nul

:: Function to log with timestamp
:log_message
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: Function to log errors with retry information
:log_error
set /a ERROR_COUNT+=1
echo [%date% %time%] ERROR #%ERROR_COUNT%: %~1 >> "%LOG_FILE%"
if %RETRY_COUNT% gtr 0 echo [%date% %time%] RETRY #%RETRY_COUNT%: %~1 >> "%LOG_FILE%"
goto :eof

:: Function to check command success with retry
:check_error_with_retry
if errorlevel 1 (
call :log_error "Command failed: %~1"
echo ERROR: %~1
if %RETRY_COUNT% lss %MAX_RETRIES% (
set /a RETRY_COUNT+=1
echo Retrying in 2 seconds... (Attempt %RETRY_COUNT%/%MAX_RETRIES%)
timeout /t 2 /nobreak >nul
goto :eof
) else (
echo MAX RETRIES REACHED for: %~1
call :log_error "MAX RETRIES REACHED for: %~1"
goto :eof
)
) else (
set "RETRY_COUNT=0"
)
goto :eof

:: Function to validate system requirements
:validate_system
call :log_message "Validating system requirements..."

:: Check admin privileges
net session >nul 2>&1
if errorlevel 1 (
call :log_error "Administrator privileges required"
echo ERROR: This script requires Administrator privileges
goto :system_error
)

:: Check disk space (minimum 1GB free)
for /f "tokens=3" %%a in ('dir /-c %SystemDrive%\ ^| find "bytes free"') do set "FREE_SPACE=%%a"
if %FREE_SPACE% lss 1073741824 (
call :log_error "Insufficient disk space: %FREE_SPACE% bytes"
echo ERROR: Insufficient disk space (minimum 1GB required)
goto :system_error
)

:: Check memory (minimum 2GB)
for /f "skip=1" %%p in ('wmic OS get TotalVisibleMemorySize /value') do if not "%%p"=="" set "TOTAL_MEM=%%p"
set "TOTAL_MEM=%TOTAL_MEM:TotalVisibleMemorySize=%"
if %TOTAL_MEM% lss 2147483648 (
call :log_error "Insufficient memory: %TOTAL_MEM% bytes"
echo WARNING: Low memory detected, performance may be affected
)

call :log_message "System validation passed"
goto :eof

:system_error
echo.
echo SYSTEM VALIDATION FAILED
echo Check log: %LOG_FILE%
pause >nul
exit /b 1

:: Function to show progress
:show_progress
set /a PROGRESS=%~1
set "PROGRESS_BAR="
for /l %%i in (1,1,20) do (
if %%i leq %PROGRESS% (
set "PROGRESS_BAR=!PROGRESS_BAR!"
) else (
set "PROGRESS_BAR=!PROGRESS_BAR!"
)
)
echo [%PROGRESS_BAR%] %PROGRESS%%% Complete
goto :eof

:: Function to cleanup on exit
:cleanup
set "END_TIME=%time%"
call :log_message "Script execution completed"
call :log_message "Start time: %START_TIME%"
call :log_message "End time: %END_TIME%"
call :log_message "Total errors: %ERROR_COUNT%"
if %ERROR_COUNT% gtr 0 (
call :log_message "Script completed with %ERROR_COUNT% error(s)"
) else (
call :log_message "Script completed successfully with no errors"
)
goto :eof

:: Main script execution
title  - Admin Mode- Advanced Error Handling v2.0
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

echo                    %~nx0 - Advanced Error Handling
echo ================================================================
echo Version: 2.0
echo Log file: %LOG_FILE%
echo Max retries: %MAX_RETRIES%
echo.

:: Validate system before proceeding
call :validate_system
if errorlevel 1 exit /b 1

:: Show initial progress
call :show_progress 0

:: Your main commands here with enhanced error handling
:: Example:
:: echo Running main operation...
:: call :show_progress 25
:: your_command_here
:: call :check_error_with_retry "your_command_here failed"
:: call :show_progress 50
:: another_command_here
:: call :check_error_with_retry "another_command_here failed"
:: call :show_progress 75
:: final_command_here
:: call :check_error_with_retry "final_command_here failed"
:: call :show_progress 100

:: Final validation and cleanup
if %ERROR_COUNT% gtr 0 (
echo.
echo WARNING: %ERROR_COUNT% error(s) occurred during execution
echo Check log file for details: %LOG_FILE%
echo.
call :cleanup
pause >nul
exit /b %ERROR_COUNT%
) else (
echo.
echo SUCCESS: All operations completed without errors
echo Execution time: %START_TIME% to %time%
echo.
call :cleanup
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
