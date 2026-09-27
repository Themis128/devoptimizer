@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title Ollama Server Manager - DevOptimizer System
color 0D

echo.
echo ========================================================================
echo                      OLLAMA SERVER MANAGER - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.
echo This script manages the Ollama server with laptop optimization
echo.

cd /d "%~dp0"

REM Check if PowerShell is available
where pwsh >nul 2>&1
if %errorlevel% neq 0 (
where powershell >nul 2>&1
if %errorlevel% neq 0 (
echo ERROR: Neither pwsh nor powershell found in PATH
exit /b 1
)
set "PS_CMD=powershell -NoProfile -ExecutionPolicy Bypass"
) else (
set "PS_CMD=pwsh -NoProfile"
)

echo [INFO] Ollama Server Manager options:
echo.
:start
echo [1] Check Server Status
echo [2] Start Server
echo [3] Stop Server
echo [4] Restart Server
echo [5] Install Auto-Start Task
echo [6] Remove Auto-Start Task
echo [7] Quick Health Check
echo [0] Exit
echo.

set /p choice="Enter your choice (0-7): "

if "%choice%"=="1" goto :status
if "%choice%"=="2" goto :menu
if "%choice%"=="3" goto :stop
if "%choice%"=="4" goto :restart
if "%choice%"=="5" goto :install_task
if "%choice%"=="6" goto :remove_task
if "%choice%"=="7" goto :health_check
if "%choice%"=="0" goto :exit
goto :invalid_choice

:status
echo.
echo ========================================================================
echo                        CHECKING OLLAMA SERVER STATUS
echo ========================================================================
echo.
echo [INFO] Checking Ollama server status...
echo [STATUS] Verifying PowerShell script availability...

if exist "%~dp0tools\ollama-server-manager.ps1" (
echo [SUCCESS] PowerShell script found, executing...
%PS_CMD% -ExecutionPolicy Bypass -File "tools\ollama-server-manager.ps1" -Action "status"
if %errorlevel%==0 (
echo [SUCCESS] Ollama server status check completed successfully
) else (
echo [ERROR] Ollama server status check failed (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] PowerShell script not found at: %~dp0tools\ollama-server-manager.ps1
echo [INFO] Falling back to basic status check...

REM Basic status check
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Ollama server is RUNNING
echo [INFO] Process details:
tasklist | findstr /I "ollama.exe" /FO TABLE
) else (
echo [WARNING] Ollama server is NOT RUNNING
)

REM Check API connectivity
echo [INFO] Testing Ollama API connectivity...
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:11434/api/tags' -UseBasicParsing -TimeoutSec 5; if ($response.StatusCode -eq 200) { Write-Host '[SUCCESS] Ollama API is accessible on port 11434' } else { Write-Host '[WARNING] Ollama API returned status code:' $response.StatusCode } } catch { Write-Host '[ERROR] Ollama API is not accessible - server may be offline' }"
)
echo.
goto :pause_and_menu

:start
echo.
echo ========================================================================
echo                           STARTING OLLAMA SERVER
echo ========================================================================
echo.
echo [INFO] Starting Ollama server...
echo [STATUS] Verifying PowerShell script availability...

if exist "%~dp0tools\ollama-server-manager.ps1" (
echo [SUCCESS] PowerShell script found, executing...
%PS_CMD% -ExecutionPolicy Bypass -File "tools\ollama-server-manager.ps1" -Action "start"
if %errorlevel%==0 (
echo [SUCCESS] Ollama server start command completed successfully
) else (
echo [ERROR] Ollama server start command failed (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] PowerShell script not found, attempting manual start...

REM Check if Ollama is already running
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [WARNING] Ollama server is already running
) else (
echo [INFO] Attempting to start Ollama server manually...
start "" "C:\Users\%USERNAME%\AppData\Local\Programs\Ollama\ollama.exe"
timeout /t 5 >nul

REM Verify start
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Ollama server started successfully
) else (
echo [ERROR] Failed to start Ollama server
)
)
)
echo.
goto :pause_and_menu

:stop
echo.
echo ========================================================================
echo                           STOPPING OLLAMA SERVER
echo ========================================================================
echo.
echo [INFO] Stopping Ollama server...
echo [STATUS] Verifying PowerShell script availability...

if exist "%~dp0tools\ollama-server-manager.ps1" (
echo [SUCCESS] PowerShell script found, executing...
%PS_CMD% -ExecutionPolicy Bypass -File "tools\ollama-server-manager.ps1" -Action "stop"
if %errorlevel%==0 (
echo [SUCCESS] Ollama server stop command completed successfully
) else (
echo [ERROR] Ollama server stop command failed (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] PowerShell script not found, attempting manual stop...

REM Check if Ollama is running
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [INFO] Stopping Ollama server processes...
taskkill /F /IM ollama.exe >nul 2>&1
timeout /t 3 >nul

REM Verify stop
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [WARNING] Ollama server processes still running
) else (
echo [SUCCESS] Ollama server stopped successfully
)
) else (
echo [INFO] Ollama server is not running
)
)
echo.
goto :pause_and_menu

:restart
echo.
echo ========================================================================
echo                          RESTARTING OLLAMA SERVER
echo ========================================================================
echo.
echo [INFO] Restarting Ollama server...
echo [STATUS] Verifying PowerShell script availability...

if exist "%~dp0tools\ollama-server-manager.ps1" (
echo [SUCCESS] PowerShell script found, executing...
%PS_CMD% -ExecutionPolicy Bypass -File "tools\ollama-server-manager.ps1" -Action "restart"
if %errorlevel%==0 (
echo [SUCCESS] Ollama server restart command completed successfully
) else (
echo [ERROR] Ollama server restart command failed (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] PowerShell script not found, attempting manual restart...

echo [STEP 1] Stopping Ollama server...
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
taskkill /F /IM ollama.exe >nul 2>&1
echo [SUCCESS] Ollama server stopped
timeout /t 3 >nul
) else (
echo [INFO] Ollama server was not running
)

echo [STEP 2] Starting Ollama server...
start "" "C:\Users\%USERNAME%\AppData\Local\Programs\Ollama\ollama.exe"
timeout /t 5 >nul

REM Verify restart
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Ollama server restarted successfully
) else (
echo [ERROR] Failed to restart Ollama server
)
)
echo.
goto :pause_and_menu

:install_task
echo.
echo ========================================================================
echo                     INSTALLING AUTO-START SCHEDULED TASK
echo ========================================================================
echo.
echo [INFO] Installing auto-start scheduled task for Ollama server...
echo [STATUS] Verifying PowerShell script availability...

if exist "%~dp0tools\ollama-server-manager.ps1" (
echo [SUCCESS] PowerShell script found, executing...
%PS_CMD% -ExecutionPolicy Bypass -File "tools\ollama-server-manager.ps1" -Action "install-task"
if %errorlevel%==0 (
echo [SUCCESS] Auto-start task installation completed successfully
) else (
echo [ERROR] Auto-start task installation failed (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] PowerShell script not found, cannot install scheduled task
echo [INFO] Please ensure the PowerShell script exists or install manually
)
echo.
goto :pause_and_menu

:remove_task
echo.
echo ========================================================================
echo                      REMOVING AUTO-START SCHEDULED TASK
echo ========================================================================
echo.
echo [INFO] Removing auto-start scheduled task for Ollama server...
echo [STATUS] Verifying PowerShell script availability...

if exist "%~dp0tools\ollama-server-manager.ps1" (
echo [SUCCESS] PowerShell script found, executing...
%PS_CMD% -ExecutionPolicy Bypass -File "tools\ollama-server-manager.ps1" -Action "remove-task"
if %errorlevel%==0 (
echo [SUCCESS] Auto-start task removal completed successfully
) else (
echo [ERROR] Auto-start task removal failed (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] PowerShell script not found, cannot remove scheduled task
echo [INFO] Please ensure the PowerShell script exists or remove manually
)
echo.
goto :pause_and_menu

:health_check
echo.
echo ========================================================================
echo                         RUNNING QUICK HEALTH CHECK
echo ========================================================================
echo.
echo [INFO] Running quick health check for Ollama server...
echo [STATUS] Checking if OLLAMA-QUICK-TESTS.bat exists...

if exist "%~dp0OLLAMA-QUICK-TESTS.bat" (
echo [SUCCESS] Quick tests script found, launching...
echo [INFO] This will perform basic health checks...
call "OLLAMA-QUICK-TESTS.bat" "basic"
if %errorlevel%==0 (
echo [SUCCESS] Quick health check completed successfully
) else (
echo [ERROR] Quick health check encountered issues (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] OLLAMA-QUICK-TESTS.bat not found at: %~dp0OLLAMA-QUICK-TESTS.bat
echo [INFO] Falling back to basic health check...

REM Basic health check
echo [CHECK 1] Checking Ollama process...
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Ollama process is running
) else (
echo [ERROR] Ollama process is not running
)

echo [CHECK 2] Testing API connectivity...
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:11434/api/tags' -UseBasicParsing -TimeoutSec 5; if ($response.StatusCode -eq 200) { Write-Host '[SUCCESS] Ollama API is responding' } else { Write-Host '[WARNING] Ollama API returned status code:' $response.StatusCode } } catch { Write-Host '[ERROR] Ollama API is not accessible' }"
)
echo.
goto :pause_and_menu

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please enter a number between 0-7.
echo [INFO] Valid options are:
echo [INFO]   [1] Check Server Status
echo [INFO]   [2] Start Server
echo [INFO]   [3] Stop Server
echo [INFO]   [4] Restart Server
echo [INFO]   [5] Install Auto-Start Task
echo [INFO]   [6] Remove Auto-Start Task
echo [INFO]   [7] Quick Health Check
echo [INFO]   [0] Exit
echo.
echo [INFO] Press any key to return to menu...
pause >nul
goto :menu

:pause_and_menu
echo.
pause
goto :menu

:menu
cls
goto :menu

:exit
echo.
echo ========================================================================
echo                     OLLAMA SERVER MANAGER CLOSING
echo ========================================================================
echo.
echo [INFO] Thank you for using Ollama Server Manager
echo [INFO] All server management operations completed
echo [INFO] Returning to DevOptimizer System...
echo.
echo [SUCCESS] Ollama Server Manager closed successfully
echo.
pause
exit /b 0
