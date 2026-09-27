@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\logs\self-healing.log"
set "ERROR_COUNT=0"
set "RECOVERY_COUNT=0"
set "MAX_RECOVERY_ATTEMPTS=3"
set "START_TIME=%time%"

:: Create logs directory if it doesn't exist
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" 2>nul

:: Function to log with timestamp
:log_message
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: Function to log recovery attempts
:log_recovery
echo [%date% %time%] RECOVERY #%RECOVERY_COUNT%: %~1 >> "%LOG_FILE%"
goto :eof

:: Function to check system health
:check_system_health
set "HEALTH_SCORE=100"
call :log_message "Checking system health..."

:: Check disk space
for /f "tokens=3" %%a in ('dir /-c %SystemDrive%\ ^| find "bytes free"') do set "FREE_SPACE=%%a"
if %FREE_SPACE% lss 1073741824 (
set /a HEALTH_SCORE-=20
call :log_message "WARNING: Low disk space detected"
)

:: Check memory
for /f "skip=1" %%p in ('wmic OS get TotalVisibleMemorySize /value') do if not "%%p"=="" set "TOTAL_MEM=%%p"
set "TOTAL_MEM=%TOTAL_MEM:TotalVisibleMemorySize=%"
if %TOTAL_MEM% lss 2147483648 (
set /a HEALTH_SCORE-=15
call :log_message "WARNING: Low memory detected"
)

:: Check critical processes
tasklist | findstr /I "explorer.exe" 2>NUL | findstr /I "explorer.exe">nul
if errorlevel 1 (
set /a HEALTH_SCORE-=30
call :log_message "CRITICAL: Explorer process not running"
)

:: Check network connectivity
ping google.com -n 1 >nul 2>&1
if errorlevel 1 (
set /a HEALTH_SCORE-=10
call :log_message "WARNING: Network connectivity issues"
)

call :log_message "System health score: %HEALTH_SCORE%"
goto :eof

:: Function to perform automatic recovery
:auto_recovery
set "RECOVERY_TYPE=%~1"
set /a RECOVERY_COUNT+=1

call :log_recovery "Starting recovery for: %RECOVERY_TYPE%"

if "%RECOVERY_TYPE%"=="disk_cleanup" (
echo Performing disk cleanup...
del /q /f /s "%TEMP%\*" >nul 2>&1
del /q /f /s "%WINDIR%\Temp\*" >nul 2>&1
call :log_recovery "Disk cleanup completed"
) else if "%RECOVERY_TYPE%"=="restart_explorer" (
echo Restarting Explorer process...
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
call :log_recovery "Explorer restarted"
) else if "%RECOVERY_TYPE%"=="clear_memory" (
echo Clearing memory cache...
echo off | clip
call :log_recovery "Memory cache cleared"
) else if "%RECOVERY_TYPE%"=="repair_registry" (
echo Repairing registry issues...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListviewAlphaSelect" /t REG_DWORD /d 0 /f >nul 2>&1
call :log_recovery "Registry repair completed"
) else if "%RECOVERY_TYPE%"=="network_reset" (
echo Resetting network configuration...
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
call :log_recovery "Network reset completed"
)

goto :eof

:: Function to self-heal on error
:self_heal
set "ERROR_TYPE=%~1"
set "ERROR_DESCRIPTION=%~2"

call :log_message "Self-healing triggered for: %ERROR_TYPE% - %ERROR_DESCRIPTION%"

if "%ERROR_TYPE%"=="file_not_found" (
call :auto_recovery "disk_cleanup"
call :auto_recovery "repair_registry"
) else if "%ERROR_TYPE%"=="access_denied" (
call :auto_recovery "restart_explorer"
call :auto_recovery "clear_memory"
) else if "%ERROR_TYPE%"=="network_error" (
call :auto_recovery "network_reset"
) else if "%ERROR_TYPE%"=="memory_error" (
call :auto_recovery "clear_memory"
call :auto_recovery "disk_cleanup"
) else (
call :auto_recovery "disk_cleanup"
call :auto_recovery "repair_registry"
call :auto_recovery "clear_memory"
)

:: Re-check system health after recovery
call :check_system_health
call :log_message "Recovery completed. New health score: %HEALTH_SCORE%"

goto :eof

:: Function to validate system state
:validate_system_state
call :log_message "Validating system state..."

:: Check if critical files exist
if not exist "%SCRIPT_DIR%\logs" (
call :log_message "ERROR: Logs directory missing"
call :self_heal "file_not_found" "Logs directory missing"
)

:: Check if we can write to log file
echo test > "%LOG_FILE%.test" 2>nul
if errorlevel 1 (
call :log_message "ERROR: Cannot write to log file"
call :self_heal "access_denied" "Cannot write to log file"
) else (
del "%LOG_FILE%.test" >nul 2>&1
)

:: Check PowerShell execution policy
powershell -Command "Get-ExecutionPolicy" >nul 2>&1
if errorlevel 1 (
call :log_message "ERROR: PowerShell execution issues"
call :self_heal "access_denied" "PowerShell execution policy"
)

call :log_message "System state validation completed"
goto :eof

:: Function to monitor and auto-repair
:monitor_and_repair
call :log_message "Starting monitoring and auto-repair cycle"

:monitor_loop
call :check_system_health

if %HEALTH_SCORE% lss 70 (
call :log_message "CRITICAL: System health below threshold (%HEALTH_SCORE%)"
call :self_heal "system_degraded" "Health score below 70%"

if %RECOVERY_COUNT% gtr %MAX_RECOVERY_ATTEMPTS% (
call :log_message "CRITICAL: Maximum recovery attempts reached"
echo.
echo SYSTEM RECOVERY FAILED
echo Maximum recovery attempts reached
echo Please check system manually
echo.
pause
exit /b 1
)
)

:: Wait before next check (non-blocking)
ping 127.0.0.1 -n 3 >nul
goto :monitor_loop

:: Function to create system restore point
:create_restore_point
call :log_message "Creating system restore point..."
powershell -Command "Checkpoint-Computer -Description 'DevOptimizer Self-Healing System' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
if errorlevel 1 (
call :log_message "WARNING: Could not create restore point"
) else (
call :log_message "System restore point created successfully"
)
goto :eof

:: Main execution
title Self-Healing System v3.0
echo.
echo ================================================================
echo                    SELF-HEALING SYSTEM v3.0
echo ================================================================
echo Start time: %START_TIME%
echo Log file: %LOG_FILE%
echo Max recovery attempts: %MAX_RECOVERY_ATTEMPTS%
echo.

call :log_message "Self-healing system initialized"

:: Create restore point before starting
call :create_restore_point

:: Validate system state
call :validate_system_state

:: Check initial system health
call :check_system_health

if %HEALTH_SCORE% gtr 80 (
echo System health: EXCELLENT (%HEALTH_SCORE%%)
call :log_message "System health excellent - proceeding normally"
) else if %HEALTH_SCORE% gtr 60 (
echo System health: GOOD (%HEALTH_SCORE%%)
call :log_message "System health good - monitoring enabled"
) else (
echo System health: POOR (%HEALTH_SCORE%%)
call :log_message "System health poor - initiating recovery"
call :self_heal "system_degraded" "Initial health check failed"
)

:: Your main operations here
:: Example:
:: call :execute_operation
:: if errorlevel 1 call :self_heal "operation_failed" "Main operation failed"

:: Start monitoring and auto-repair
echo.
echo Starting monitoring and auto-repair system...
echo Press Ctrl+C to stop monitoring
call :monitor_and_repair

:: Final cleanup
set "END_TIME=%time%"
call :log_message "Self-healing system shutdown"
call :log_message "Start time: %START_TIME%"
call :log_message "End time: %END_TIME%"
call :log_message "Total recovery attempts: %RECOVERY_COUNT%"

echo.
echo Self-healing system completed
echo Total recovery attempts: %RECOVERY_COUNT%
echo.
pause >nul
exit /b %ERROR_COUNT%
