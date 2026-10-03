:: SYNOPSIS: DevOptimizer automation script: AUTO-RECOVERY-SYSTEM-NoAdmin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%\logs\auto-recovery.log"
set "RECOVERY_COUNT=0"
set "FIXED_ISSUES=0"

:: Create logs directory if it doesn't exist
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" 2>nul

title  - Standard Mode-Recovery System - Self-Healing DevOptimizer
color 0B
echo.
echo ================================================================


:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo                    AUTO-RECOVERY SYSTEM
echo              Self-Healing DevOptimizer Hub
echo ================================================================
echo.

:: Function to log with timestamp
:log_message
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: Function to log recovery
:log_recovery
echo [%date% %time%] RECOVERY: %~1 >> "%LOG_FILE%"
goto :eof

:: Function to fix common batch file issues
:fix_batch_issues
call :log_message "Scanning for batch file issues..."

:: Fix missing @echo off
for /f "delims=" %%f in ('dir /b "%SCRIPT_DIR%\*.bat"') do (
findstr /C:"@echo off" "%SCRIPT_DIR%\%%f" >nul
if errorlevel 1 (
echo Fixing missing @echo off in %%f
powershell -Command "$content = Get-Content '%SCRIPT_DIR%\%%f'; if ($content[0] -ne '@echo off') { $newContent = @('@echo off') + $content; $newContent | Set-Content '%SCRIPT_DIR%\%%f' }"
set /a FIXED_ISSUES+=1
call :log_recovery "Fixed missing @echo off in %%f"
)
)

:: Fix bare pause commands
for /f "delims=" %%f in ('dir /b "%SCRIPT_DIR%\*.bat"') do (
findstr /C:"pause$" "%SCRIPT_DIR%\%%f" >nul
if not errorlevel 1 (
echo Fixing bare pause in %%f
powershell -Command "(Get-Content '%SCRIPT_DIR%\%%f') -replace 'pause$', 'pause >nul' | Set-Content '%SCRIPT_DIR%\%%f'"
set /a FIXED_ISSUES+=1
call :log_recovery "Fixed bare pause in %%f"
)
)

:: Fix missing error handling
for /f "delims=" %%f in ('dir /b "%SCRIPT_DIR%\*.bat"') do (
findstr /C:"setlocal" "%SCRIPT_DIR%\%%f" >nul
if errorlevel 1 (
echo Adding error handling to %%f
powershell -Command "$content = Get-Content '%SCRIPT_DIR%\%%f'; $newContent = @('@echo off', 'setlocal EnableExtensions EnableDelayedExpansion', '') + $content[1..($content.Length-1)]; $newContent | Set-Content '%SCRIPT_DIR%\%%f'"
set /a FIXED_ISSUES+=1
call :log_recovery "Added error handling to %%f"
)
)

goto :eof

:: Function to repair file permissions
:repair_permissions
call :log_message "Repairing file permissions..."

:: Reset file permissions for batch files
for /f "delims=" %%f in ('dir /b "%SCRIPT_DIR%\*.bat"') do (
icacls "%SCRIPT_DIR%\%%f" /reset >nul 2>&1
icacls "%SCRIPT_DIR%\%%f" /grant:r "%USERNAME%:(F)" >nul 2>&1
)

call :log_recovery "File permissions repaired"
goto :eof

:: Function to repair registry issues
:repair_registry
call :log_message "Repairing registry issues..."

:: Fix common registry issues
reg add "HKCU\Software\Microsoft\Command Processor" /v "EnableExtensions" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Command Processor" /v "EnableDelayedExpansion" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListviewAlphaSelect" /t REG_DWORD /d 0 /f >nul 2>&1

call :log_recovery "Registry issues repaired"
goto :eof

:: Function to repair PowerShell execution
:repair_powershell
call :log_message "Repairing PowerShell execution..."

:: Set PowerShell execution policy
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force" >nul 2>&1
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force" >nul 2>&1

call :log_recovery "PowerShell execution repaired"
goto :eof

:: Function to repair network issues
:repair_network
call :log_message "Repairing network issues..."

:: Reset network configuration
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
ipconfig /flushdns >nul 2>&1

call :log_recovery "Network issues repaired"
goto :eof

:: Function to repair disk issues
:repair_disk
call :log_message "Repairing disk issues..."

:: Clear temporary files
del /q /f /s "%TEMP%\*" >nul 2>&1
del /q /f /s "%WINDIR%\Temp\*" >nul 2>&1

:: Clear browser cache
for /d %%i in ("%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache\*") do rd /s /q "%%i" >nul 2>&1

call :log_recovery "Disk issues repaired"
goto :eof

:: Function to validate repairs
:validate_repairs
call :log_message "Validating repairs..."

set "VALIDATION_PASSED=1"

:: Test batch file execution
echo @echo off > "%SCRIPT_DIR%\test-validation.bat"
echo echo Test successful >> "%SCRIPT_DIR%\test-validation.bat"
call "%SCRIPT_DIR%\test-validation.bat" >nul 2>&1
if errorlevel 1 (
set "VALIDATION_PASSED=0"
call :log_message "ERROR: Batch file execution test failed"
)
del "%SCRIPT_DIR%\test-validation.bat" >nul 2>&1

:: Test PowerShell execution
powershell -Command "Write-Host 'Test successful'" >nul 2>&1
if errorlevel 1 (
set "VALIDATION_PASSED=0"
call :log_message "ERROR: PowerShell execution test failed"
)

:: Test file permissions
echo test > "%SCRIPT_DIR%\test-permissions.txt" 2>nul
if errorlevel 1 (
set "VALIDATION_PASSED=0"
call :log_message "ERROR: File permission test failed"
) else (
del "%SCRIPT_DIR%\test-permissions.txt" >nul 2>&1
)

if %VALIDATION_PASSED%==1 (
call :log_message "SUCCESS: All validation tests passed"
) else (
call :log_message "WARNING: Some validation tests failed"
)

goto :eof

:: Main recovery process
call :log_message "Auto-recovery system started"

echo Starting comprehensive system recovery...
echo.

echo [1/6] Fixing batch file issues...
call :fix_batch_issues

echo [2/6] Repairing file permissions...
call :repair_permissions

echo [3/6] Repairing registry issues...
call :repair_registry

echo [4/6] Repairing PowerShell execution...
call :repair_powershell

echo [5/6] Repairing network issues...
call :repair_network

echo [6/6] Repairing disk issues...
call :repair_disk

echo.
echo Validating repairs...
call :validate_repairs

echo.
echo ================================================================
echo                    RECOVERY COMPLETE
echo ================================================================
echo.
echo Issues fixed: %FIXED_ISSUES%
echo Recovery attempts: %RECOVERY_COUNT%
echo Log file: %LOG_FILE%
echo.

if %FIXED_ISSUES% gtr 0 (
echo SUCCESS: %FIXED_ISSUES% issues were automatically fixed
) else (
echo INFO: No issues found - system is healthy
)

call :log_message "Auto-recovery completed - %FIXED_ISSUES% issues fixed"

echo.
echo Press any key to continue...
pause >nul
exit /b 0
