:: SYNOPSIS: DevOptimizer automation script: UNIFIED-LAUNCHER.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\logs\unified-launcher.log"
set "ERROR_COUNT=0"

:: Create logs directory if it doesn't exist
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" 2>nul

:: Function to log messages
:log_message
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: Function to log errors
:log_error
echo [%date% %time%] ERROR: %~1 >> "%LOG_FILE%"
set /a ERROR_COUNT+=1
echo [ERROR] %~1
goto :eof

:: Function to check command success
:check_error
if errorlevel 1 (
call :log_error "Command failed: %~1"
goto :eof
)
goto :eof

:: Check if running as administrator
:check_admin
net session >nul 2>&1
if %errorlevel%==0 (
set "ADMIN_MODE=1"
set "MODE_TEXT=Administrator Mode"
call :log_message "Running in Administrator Mode"
) else (
set "ADMIN_MODE=0"
set "MODE_TEXT=Standard Mode"
call :log_message "Running in Standard Mode"
)
goto :eof

:: Function to display enhanced menu
:display_menu
cls
echo.
echo ========================================================================
echo                    DEVOPTIMIZER UNIFIED LAUNCHER
echo ========================================================================
echo.
echo [STATUS] Mode: %MODE_TEXT%
echo [STATUS] Script Directory: %SCRIPT_DIR%
echo [INFO] System ready for operation
echo.
call :check_admin
echo.
echo ========================================================================
echo                          QUICK SYSTEM STATUS
echo ========================================================================
echo.

:: Check Ollama status
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [STATUS] Ollama: ONLINE
) else (
echo [STATUS] Ollama: OFFLINE
)

:: Check OneDrive status
tasklist | findstr /I "OneDrive.exe" 2>NUL | findstr /I "OneDrive.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [STATUS] OneDrive: ONLINE
) else (
echo [STATUS] OneDrive: OFFLINE
)

:: Check Cursor status
tasklist | findstr /I "Cursor.exe" 2>NUL | findstr /I "Cursor.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [STATUS] Cursor AI: ONLINE
) else (
echo [STATUS] Cursor AI: OFFLINE
)

echo.
echo ========================================================================
echo                          AVAILABLE OPTIONS
echo ========================================================================
echo.
echo [1] Ollama Model Manager
echo [2] Ollama Server Manager
echo [3] Ollama Quick Tests
echo [4] M365 Troubleshooter
echo [5] Cursor AI Troubleshooter
echo [6] Ollama Troubleshooter
echo [7] OneDrive Manager
echo [8] System Health Check
echo [9] Performance Optimization
echo [A] Development Tools Manager
echo [B] System Backup Manager
echo [C] Network Manager
echo [D] Security Manager
echo [E] System Performance Monitor
echo [F] DevOptimizer Comprehensive Launcher
echo [G] Admin Tools (Admin Mode Only)
echo [H] System Optimization Suite
echo [I] Emergency Recovery Tools
echo [J] Advanced Diagnostics
echo [0] Exit
echo.
goto :eof

:: Function to execute with admin check
:execute_with_admin_check
set "SCRIPT_NAME=%~1"
set "ADMIN_REQUIRED=%~2"

if "%ADMIN_REQUIRED%"=="1" (
if "%ADMIN_MODE%"=="0" (
echo [WARNING] This operation requires administrator privileges
echo [INFO] Attempting to restart with administrator privileges...
powershell -Command "Start-Process '%~f0' -ArgumentList 'admin_%SCRIPT_NAME%' -Verb RunAs"
goto :menu
)
)

echo [INFO] Executing %SCRIPT_NAME%...
if exist "%SCRIPT_DIR%\%SCRIPT_NAME%.bat" (
echo [SUCCESS] Script found, launching...
call "%SCRIPT_DIR%\%SCRIPT_NAME%.bat"
if %errorlevel%==0 (
echo [SUCCESS] %SCRIPT_NAME% completed successfully
) else (
echo [ERROR] %SCRIPT_NAME% encountered an error (Exit Code: %errorlevel%)
)
) else (
echo [ERROR] Script not found: %SCRIPT_DIR%\%SCRIPT_NAME%.bat
echo [INFO] Please ensure the file exists and try again
)
echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:: Function to execute admin-specific operations
:execute_admin_operation
set "OPERATION=%~1"
echo [INFO] Executing admin operation: %OPERATION%

if "%OPERATION%"=="system_cleanup" (
echo [STEP 1/3] Running system cleanup...
if exist "%SCRIPT_DIR%\09-System-Deep-Clean-NoAdmin.bat" (
call "%SCRIPT_DIR%\09-System-Deep-Clean-NoAdmin.bat"
)
echo [STEP 2/3] Optimizing system performance...
if exist "%SCRIPT_DIR%\02-Ultra-Performance-NoAdmin.bat" (
call "%SCRIPT_DIR%\02-Ultra-Performance-NoAdmin.bat"
)
echo [STEP 3/3] Finalizing optimizations...
echo [SUCCESS] Admin system cleanup completed
)

if "%OPERATION%"=="registry_cleanup" (
echo [INFO] Running registry cleanup...
echo [WARNING] This will modify system registry
set /p confirm="Are you sure you want to continue? (Y/N): "
if /i "%confirm%"=="Y" (
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU" /f >nul 2>&1
echo [SUCCESS] Registry cleanup completed
) else (
echo [INFO] Registry cleanup cancelled
)
)

if "%OPERATION%"=="service_optimization" (
echo [INFO] Optimizing Windows services...
sc config "DiagTrack" start= disabled >nul 2>&1
sc config "dmwappushservice" start= disabled >nul 2>&1
sc config "WerSvc" start= disabled >nul 2>&1
echo [SUCCESS] Service optimization completed
)

echo.
echo [INFO] Press any key to return to main menu...
pause >nul
goto :menu

:: Main menu loop
:menu
call :display_menu
set /p choice="Enter your choice: "

if "%choice%"=="1" call :execute_with_admin_check "OLLAMA-MODEL-MANAGER" "0"
if "%choice%"=="2" call :execute_with_admin_check "OLLAMA-SERVER-MANAGER" "0"
if "%choice%"=="3" call :execute_with_admin_check "OLLAMA-QUICK-TESTS" "0"
if "%choice%"=="4" call :execute_with_admin_check "M365-TROUBLESHOOTER" "0"
if "%choice%"=="5" call :execute_with_admin_check "CURSOR-AI-TROUBLESHOOTER" "0"
if "%choice%"=="6" call :execute_with_admin_check "OLLAMA-TROUBLESHOOTER" "0"
if "%choice%"=="7" call :execute_with_admin_check "ONEDRIVE-MANAGER" "0"
if "%choice%"=="8" call :execute_with_admin_check "06-System-Health-Check" "0"
if "%choice%"=="9" call :execute_with_admin_check "01-Quick-Optimization" "0"
if /i "%choice%"=="A" call :execute_with_admin_check "DEVTOOLS-MANAGER" "0"
if /i "%choice%"=="B" call :execute_with_admin_check "SYSTEM-BACKUP-MANAGER" "0"
if /i "%choice%"=="C" call :execute_with_admin_check "NETWORK-MANAGER" "0"
if /i "%choice%"=="D" call :execute_with_admin_check "SECURITY-MANAGER" "0"
if /i "%choice%"=="E" call :execute_with_admin_check "SYSTEM-PERFORMANCE-MONITOR" "0"
if /i "%choice%"=="F" call :execute_with_admin_check "DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER" "0"

if /i "%choice%"=="G" (
if "%ADMIN_MODE%"=="1" (
echo.
echo ========================================================================
echo                          ADMIN TOOLS MENU
echo ========================================================================
echo.
echo [1] System Cleanup
echo [2] Registry Cleanup
echo [3] Service Optimization
echo [4] Advanced System Diagnostics
echo [0] Back to main menu
echo.
set /p admin_choice="Enter admin tool choice: "

if "%admin_choice%"=="1" call :execute_admin_operation "system_cleanup"
if "%admin_choice%"=="2" call :execute_admin_operation "registry_cleanup"
if "%admin_choice%"=="3" call :execute_admin_operation "service_optimization"
if "%admin_choice%"=="4" call :execute_with_admin_check "ENHANCED-SYSTEM-DIAGNOSTICS" "1"
if "%admin_choice%"=="0" goto :menu
) else (
echo [ERROR] Admin tools require administrator privileges
pause
goto :menu
)
)

if /i "%choice%"=="H" call :execute_with_admin_check "02-Ultra-Performance" "0"
if /i "%choice%"=="I" call :execute_with_admin_check "AUTO-RECOVERY-SYSTEM" "0"
if /i "%choice%"=="J" call :execute_with_admin_check "ADVANCED-DIAGNOSTICS" "1"

if "%choice%"=="0" goto :exit

echo [ERROR] Invalid choice. Please select a valid option (1-9, A-J, 0)
echo [INFO] Valid options are:
echo [INFO]   [1-9] - Numeric options for specific tools
echo [INFO]   [A-J] - Letter options for management tools
echo [INFO]   [0]   - Exit the application
echo.
echo [INFO] Press any key to return to menu...
pause >nul
goto :menu

:exit
echo.
echo ========================================================================
echo                        DEVOPTIMIZER SYSTEM CLOSING
echo ========================================================================
echo.
echo [INFO] Thank you for using DevOptimizer Unified Launcher
echo [INFO] All operations have been completed
echo [INFO] System is shutting down gracefully...
echo.
call :log_message "System shutdown - Total errors: %ERROR_COUNT%"
echo [SUCCESS] DevOptimizer System closed successfully
echo.
pause
exit /b 0
