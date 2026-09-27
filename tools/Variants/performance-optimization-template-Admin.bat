@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\logs\performance.log"
set "ERROR_COUNT=0"
set "START_TIME=%time%"
:: Create logs directory if it doesn't exist
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" 2>nul
:: Function to log with timestamp
:log_message
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof
:: Function to show progress without delays
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
:: Function to wait without timeout (non-blocking)
:smart_wait
set "WAIT_TIME=%~1"
if %WAIT_TIME% gtr 0 (
echo Waiting %WAIT_TIME% seconds...
call :show_progress 0
for /l %%i in (1,1,%WAIT_TIME%) do (
set /a PROGRESS=%%i*100/%WAIT_TIME%
call :show_progress !PROGRESS!
ping 127.0.0.1 -n 2 >nul
)
call :show_progress 100
) else (
echo No wait time specified
)
goto :eof
:: Function to check if process is running (faster than timeout)
:check_process
set "PROCESS_NAME=%~1"
tasklist | findstr /I "%PROCESS_NAME%" 2>NUL | findstr /I "%PROCESS_NAME%">nul
if "%ERRORLEVEL%"=="0" (
echo Process %PROCESS_NAME% is running
) else (
echo Process %PROCESS_NAME% is not running
)
goto :eof
:: Function to wait for file creation (faster than timeout)
:wait_for_file
set "FILE_PATH=%~1"
set "MAX_WAIT=%~2"
if "%MAX_WAIT%"=="" set "MAX_WAIT=30"
set "WAIT_COUNT=0"
:wait_loop
if exist "%FILE_PATH%" (
echo File found: %FILE_PATH%
goto :eof
)
set /a WAIT_COUNT+=1
if %WAIT_COUNT% gtr %MAX_WAIT% (
echo Timeout waiting for file: %FILE_PATH%
goto :eof
)
ping 127.0.0.1 -n 2 >nul
goto :wait_loop
:: Function to execute with progress tracking
:execute_with_progress
set "COMMAND=%~1"
set "DESCRIPTION=%~2"
if "%DESCRIPTION%"=="" set "DESCRIPTION=Executing command"
echo %DESCRIPTION%...
call :show_progress 10
:: Execute command in background if possible
start /b cmd /c "%COMMAND%" >nul 2>&1
call :show_progress 50
:: Wait for completion (non-blocking)
:wait_completion
tasklist /FI "WINDOWtitle  - Admin Mode-n 1 >nul
goto :wait_completion
call :show_progress 100
echo %DESCRIPTION% completed
goto :eof
:: Function to optimize system performance
:optimize_system
echo Optimizing system performance...
call :show_progress 0
:: Clear temporary files (fast)
echo Clearing temporary files...
del /q /f /s "%TEMP%\*" >nul 2>&1
call :show_progress 25
:: Clear Windows temp files
echo Clearing Windows temp files...
del /q /f /s "%WINDIR%\Temp\*" >nul 2>&1
call :show_progress 50
:: Clear browser cache (fast)
echo Clearing browser cache...
for /d %%i in ("%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache\*") do rd /s /q "%%i" >nul 2>&1
call :show_progress 75
:: Optimize registry (fast)
echo Optimizing registry...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListviewAlphaSelect" /t REG_DWORD /d 0 /f >nul 2>&1
call :show_progress 100
echo System optimization completed
goto :eof
:: Main execution
title  - Admin Mode
REM ================================================================
REM                    ADMIN PRIVILEGE FUNCTIONS
REM ================================================================

:checkAdmin
set "IS_ADMIN=0"
fsutil dirty query %SystemDrive% >nul 2>&1
if not errorlevel 1 (
    set "IS_ADMIN=1"
) else (
    net session >nul 2>&1
    if not errorlevel 1 set "IS_ADMIN=1"
)
exit /b

:requireAdmin
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
    echo.
    echo [ERROR] This operation requires Administrator privileges.
    echo Please run this script as Administrator.
    echo.
    pause
    exit /b 1
)
exit /b
