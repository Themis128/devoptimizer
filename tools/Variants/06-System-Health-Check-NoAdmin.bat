@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\logs\system-health-check.log"
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

:: Function to log errors
:log_error
set /a ERROR_COUNT+=1
echo [%date% %time%] ERROR #%ERROR_COUNT%: %~1 >> "%LOG_FILE%"
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

title  - Standard Mode- Advanced Error Handling v2.0
echo.
echo ================================================================


:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo                System Health Check - Advanced Error Handling
echo ================================================================
echo Version: 2.0
echo Log file: %LOG_FILE%
echo Max retries: %MAX_RETRIES%
echo.

call :log_message "Starting system health check"

:: Show initial progress
call :show_progress 0

echo This will display:
echo - CPU and Memory usage
echo - Disk space information
echo - Running processes
echo - Network adapters
echo - Windows version info
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul

call :show_progress 10
echo.
echo Running system health check...

:: Enhanced PowerShell command with error handling
call :show_progress 25
powershell -ExecutionPolicy Bypass -Command "try { Write-Host '=== SYSTEM HEALTH CHECK ===' -ForegroundColor Green; # CPU Information; $cpu = Get-CimInstance Win32_Processor; Write-Host \"`nCPU: $($cpu.Name)\" -ForegroundColor Yellow; Write-Host \"Cores: $($cpu.NumberOfCores) | Logical Processors: $($cpu.NumberOfLogicalProcessors)\" -ForegroundColor White; # Memory Information; $memory = Get-CimInstance Win32_ComputerSystem; $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2); $availableMemoryGB = [math]::Round((Get-Counter \"\Memory\Available MBytes\").CounterSamples.CookedValue / 1024, 2); $usedMemoryGB = $totalMemoryGB - $availableMemoryGB; $memoryPercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2); Write-Host \"`nMemory: $totalMemoryGB GB Total\" -ForegroundColor Yellow; Write-Host \"Used: $usedMemoryGB GB ($memoryPercent%%) | Available: $availableMemoryGB GB\" -ForegroundColor White; # Disk Information; $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }; Write-Host \"`nDisk Usage:\" -ForegroundColor Yellow; foreach ($disk in $disks) { $usedSpace = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2); $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2); $totalSpace = [math]::Round($disk.Size / 1GB, 2); $usedPercent = [math]::Round(($usedSpace / $totalSpace) * 100, 2); Write-Host \"Drive $($disk.DeviceID) - Used: $usedSpace GB ($usedPercent%%) | Free: $freeSpace GB | Total: $totalSpace GB\" -ForegroundColor White }; # Network Adapters; $adapters = Get-NetAdapter | Where-Object { $_.Status -eq \"Up\" }; Write-Host \"`nActive Network Adapters:\" -ForegroundColor Yellow; foreach ($adapter in $adapters) { Write-Host \"$($adapter.Name) - $($adapter.LinkSpeed)\" -ForegroundColor White }; # Top Processes; Write-Host \"`nTop 10 Processes by CPU Usage:\" -ForegroundColor Yellow; Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | ForEach-Object { Write-Host \"$($_.ProcessName): $([math]::Round($_.CPU, 2))s CPU\" -ForegroundColor White }; # Windows Version; $osVersion = Get-CimInstance Win32_OperatingSystem; Write-Host \"`nWindows Version: $($osVersion.Caption) $($osVersion.Version)\" -ForegroundColor Yellow; Write-Host \"Build: $($osVersion.BuildNumber)\" -ForegroundColor White; Write-Host \"`n=== HEALTH CHECK COMPLETE ===\" -ForegroundColor Green } catch { Write-Host \"ERROR: $($_.Exception.Message)\" -ForegroundColor Red; exit 1 }"
call :check_error_with_retry "PowerShell health check script"

call :show_progress 100

:: Final validation
if %ERROR_COUNT% gtr 0 (
echo.
echo WARNING: %ERROR_COUNT% error(s) occurred during health check
echo Check log file for details: %LOG_FILE%
echo.
call :log_message "Health check completed with %ERROR_COUNT% error(s)"
pause >nul
exit /b %ERROR_COUNT%
) else (
echo.
echo SUCCESS: System health check completed without errors
echo Execution time: %START_TIME% to %time%
echo.
call :log_message "Health check completed successfully"
pause >nul
exit /b 0
)
