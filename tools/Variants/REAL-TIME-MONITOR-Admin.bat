@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\logs\real-time-monitor.log"
set "MONITOR_INTERVAL=5"
set "ERROR_COUNT=0"

:: Create logs directory if it doesn't exist
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" 2>nul

:: Function to log with timestamp
:log_message
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: Function to check system health
:check_system_health
set "HEALTH_STATUS=HEALTHY"
set "ISSUES=0"

:: Check if critical files exist
if not exist "%SCRIPT_DIR%\01-Quick-Optimization.bat" (
set "HEALTH_STATUS=DEGRADED"
set /a ISSUES+=1
call :log_message "WARNING: Critical file missing - 01-Quick-Optimization.bat"
)

if not exist "%SCRIPT_DIR%\06-System-Health-Check.bat" (
set "HEALTH_STATUS=DEGRADED"
set /a ISSUES+=1
call :log_message "WARNING: Critical file missing - 06-System-Health-Check.bat"
)

if not exist "%SCRIPT_DIR%\00-LAUNCHER.bat" (
set "HEALTH_STATUS=DEGRADED"
set /a ISSUES+=1
call :log_message "WARNING: Critical file missing - 00-LAUNCHER.bat"
)

:: Check PowerShell execution policy
powershell -Command "Get-ExecutionPolicy" | findstr /i "Bypass" >nul
if errorlevel 1 (
set "HEALTH_STATUS=DEGRADED"
set /a ISSUES+=1
call :log_message "WARNING: PowerShell execution policy may block scripts"
)

:: Check admin privileges
net session >nul 2>&1
if errorlevel 1 (
set "HEALTH_STATUS=DEGRADED"
set /a ISSUES+=1
call :log_message "WARNING: Not running with administrator privileges"
)

goto :eof

:: Function to display status
:display_status
cls
title  - Admin Mode-Time Monitor - DevOptimizer Hub
color 0A

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

echo                REAL-TIME MONITOR - DEVOPTIMIZER HUB
echo ================================================================
echo.
echo Current Time: %date% %time%
echo Monitor Interval: %MONITOR_INTERVAL% seconds
echo Log File: %LOG_FILE%
echo.
echo ================================================================
echo                        SYSTEM STATUS
echo ================================================================
echo.
echo Health Status: %HEALTH_STATUS%
echo Issues Detected: %ISSUES%
echo.

if "%HEALTH_STATUS%"=="HEALTHY" (
echo  All systems operational
echo  All critical files present
echo  PowerShell execution policy: Bypass
echo  Administrator privileges: Available
echo.
echo  DEVOPTIMIZER HUB: 100%% FUNCTIONAL
) else (
echo   System issues detected:
if %ISSUES% gtr 0 (
echo   - %ISSUES% issue(s) found
echo   - Check log file for details
echo   - Run AUTO-RECOVERY-SYSTEM.bat to fix
)
echo.
echo  Status: Requires attention
)

echo.
echo ================================================================
echo                        QUICK ACTIONS
echo ================================================================
echo.
echo [R] Run Health Check
echo [A] Run Auto-Recovery
echo [T] Run Test Suite
echo [L] View Log File
echo [Q] Quit Monitor
echo.
echo Press any key to continue monitoring...
echo.

goto :eof

:: Function to handle user input
:handle_input
choice /c RATLQ /n /m "Select action (R/A/T/L/Q): "
if errorlevel 5 goto :quit
if errorlevel 4 goto :view_log
if errorlevel 3 goto :run_test
if errorlevel 2 goto :run_recovery
if errorlevel 1 goto :run_health_check
goto :monitor_loop

:run_health_check
echo.
echo Running System Health Check...
call "%SCRIPT_DIR%\06-System-Health-Check.bat"
call :log_message "User initiated health check"
goto :monitor_loop

:run_recovery
echo.
echo Running Auto-Recovery System...
call "%SCRIPT_DIR%\AUTO-RECOVERY-SYSTEM.bat"
call :log_message "User initiated auto-recovery"
goto :monitor_loop

:run_test
echo.
echo Running Comprehensive Test Suite...
call "%SCRIPT_DIR%\COMPREHENSIVE-TEST-SUITE.bat"
call :log_message "User initiated test suite"
goto :monitor_loop

:view_log
echo.
echo Opening log file...
type "%LOG_FILE%"
echo.
pause >nul
goto :monitor_loop

:quit
echo.
echo Stopping real-time monitor...
call :log_message "Real-time monitor stopped by user"
exit /b 0

:: Main monitor loop
:monitor_loop
call :check_system_health
call :display_status

:: Wait for user input or timeout
choice /c RATLQ /t %MONITOR_INTERVAL% /d Q /m "Auto-refresh in %MONITOR_INTERVAL%s or select action: "
if errorlevel 5 goto :quit
if errorlevel 4 goto :view_log
if errorlevel 3 goto :run_test
if errorlevel 2 goto :run_recovery
if errorlevel 1 goto :run_health_check

goto :monitor_loop


:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
