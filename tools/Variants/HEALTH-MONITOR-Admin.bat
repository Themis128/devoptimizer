@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%\logs\health-monitor.log"
set "ALERT_COUNT=0"
set "HEALTH_SCORE=100"

:: Create logs directory if it doesn't exist
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" 2>nul

title  - Admin Mode- DevOptimizer Hub
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

echo                    HEALTH MONITOR
echo              Real-time System Health Monitoring
echo ================================================================
echo.

:: Function to log with timestamp
:log_message
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: Function to log alert
:log_alert
echo [%date% %time%] ALERT: %~1 >> "%LOG_FILE%"
set /a ALERT_COUNT+=1
goto :eof

:: Function to check disk health
:check_disk_health
call :log_message "Checking disk health..."

for /f "tokens=3" %%a in ('dir /-c %SystemDrive%\ ^| find "bytes free"') do set "FREE_SPACE=%%a"
set "FREE_SPACE_GB=%FREE_SPACE%"
set /a FREE_SPACE_GB/=1073741824

if %FREE_SPACE_GB% lss 1 (
call :log_alert "CRITICAL: Disk space below 1GB (%FREE_SPACE_GB% GB free)"
set /a HEALTH_SCORE-=30
) else if %FREE_SPACE_GB% lss 5 (
call :log_alert "WARNING: Disk space below 5GB (%FREE_SPACE_GB% GB free)"
set /a HEALTH_SCORE-=15
) else (
call :log_message "Disk health: OK (%FREE_SPACE_GB% GB free)"
)

goto :eof

:: Function to check memory health
:check_memory_health
call :log_message "Checking memory health..."

for /f "skip=1" %%p in ('wmic OS get TotalVisibleMemorySize /value') do if not "%%p"=="" set "TOTAL_MEM=%%p"
set "TOTAL_MEM=%TOTAL_MEM:TotalVisibleMemorySize=%"
set /a TOTAL_MEM_GB=%TOTAL_MEM%/1073741824

if %TOTAL_MEM_GB% lss 2 (
call :log_alert "WARNING: Low memory detected (%TOTAL_MEM_GB% GB total)"
set /a HEALTH_SCORE-=20
) else (
call :log_message "Memory health: OK (%TOTAL_MEM_GB% GB total)"
)

goto :eof

:: Function to check process health
:check_process_health
call :log_message "Checking process health..."

:: Check for critical processes
tasklist | findstr /I "explorer.exe" 2>NUL | findstr /I "explorer.exe">nul
if errorlevel 1 (
call :log_alert "CRITICAL: Explorer process not running"
set /a HEALTH_SCORE-=40
) else (
call :log_message "Explorer process: OK"
)

:: Check for high CPU usage processes
for /f "tokens=2" %%a in ('wmic process get processid,percentprocessortime /format:csv ^| findstr /v "Node" ^| sort /r') do (
if %%a gtr 80 (
call :log_alert "WARNING: High CPU usage detected (%%a%%)"
set /a HEALTH_SCORE-=10
)
)

goto :eof

:: Function to check network health
:check_network_health
call :log_message "Checking network health..."

ping google.com -n 1 >nul 2>&1
if errorlevel 1 (
call :log_alert "WARNING: Network connectivity issues"
set /a HEALTH_SCORE-=15
) else (
call :log_message "Network health: OK"
)

goto :eof

:: Function to check file system health
:check_filesystem_health
call :log_message "Checking file system health..."

:: Check if critical directories exist
if not exist "%SCRIPT_DIR%\logs" (
call :log_alert "WARNING: Logs directory missing"
set /a HEALTH_SCORE-=10
)

:: Check if we can write to log file
echo test > "%LOG_FILE%.test" 2>nul
if errorlevel 1 (
call :log_alert "WARNING: Cannot write to log file"
set /a HEALTH_SCORE-=15
) else (
del "%LOG_FILE%.test" >nul 2>&1
)

goto :eof

:: Function to check PowerShell health
:check_powershell_health
call :log_message "Checking PowerShell health..."

powershell -Command "Write-Host 'Test'" >nul 2>&1
if errorlevel 1 (
call :log_alert "WARNING: PowerShell execution issues"
set /a HEALTH_SCORE-=20
) else (
call :log_message "PowerShell health: OK"
)

goto :eof

:: Function to display health status
:display_health_status
echo.
echo ================================================================
echo                    HEALTH STATUS REPORT
echo ================================================================
echo.

if %HEALTH_SCORE% gtr 90 (
echo Overall Health: EXCELLENT (%HEALTH_SCORE%%)
echo Status: All systems operating normally
color 0A
) else if %HEALTH_SCORE% gtr 70 (
echo Overall Health: GOOD (%HEALTH_SCORE%%)
echo Status: Minor issues detected
color 0E
) else if %HEALTH_SCORE% gtr 50 (
echo Overall Health: FAIR (%HEALTH_SCORE%%)
echo Status: Some issues require attention
color 0C
) else (
echo Overall Health: POOR (%HEALTH_SCORE%%)
echo Status: Critical issues detected
color 04
)

echo.
echo Alerts generated: %ALERT_COUNT%
echo Log file: %LOG_FILE%
echo.

goto :eof

:: Function to auto-repair if needed
:auto_repair_if_needed
if %HEALTH_SCORE% lss 70 (
echo.
echo Initiating automatic repair...
call :log_message "Initiating automatic repair due to low health score"

:: Run auto-recovery system
if exist "%SCRIPT_DIR%\AUTO-RECOVERY-SYSTEM.bat" (
call "%SCRIPT_DIR%\AUTO-RECOVERY-SYSTEM.bat"
call :log_message "Auto-recovery system executed"
) else (
call :log_alert "Auto-recovery system not found"
)
)

goto :eof

:: Main monitoring loop
:main_monitor
call :log_message "Health monitoring cycle started"

:: Reset health score
set "HEALTH_SCORE=100"
set "ALERT_COUNT=0"

:: Run all health checks
call :check_disk_health
call :check_memory_health
call :check_process_health
call :check_network_health
call :check_filesystem_health
call :check_powershell_health

:: Display health status
call :display_health_status

:: Auto-repair if needed
call :auto_repair_if_needed

:: Log final health score
call :log_message "Health monitoring cycle completed - Score: %HEALTH_SCORE%%"

goto :eof

:: Continuous monitoring mode
:continuous_monitor
echo.
echo Starting continuous monitoring...
echo Press Ctrl+C to stop
echo.

:monitor_loop
call :main_monitor
echo.
echo Next check in 30 seconds...
timeout /t 30 /nobreak >nul
goto :monitor_loop

:: Single check mode
:single_check
call :main_monitor
echo.
echo Health check completed
echo.
pause
exit /b 0

:: Main execution
echo Select monitoring mode:
echo.
echo [1] Single health check
echo [2] Continuous monitoring
echo [3] Exit
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" (
goto :single_check
) else if "%choice%"=="2" (
goto :continuous_monitor
) else if "%choice%"=="3" (
echo Goodbye!
exit /b 0
) else (
echo Invalid choice!
goto :single_check
)


:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
