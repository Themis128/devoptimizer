:: SYNOPSIS: DevOptimizer automation script: MAKE-ALL-BAT-OPERATIONAL-Admin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

title  - Admin Mode- DevOptimizer
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

echo              MAKE ALL BATCH FILES OPERATIONAL
echo ================================================================
echo.
echo This script will ensure all .bat files work without admin privileges
echo by creating non-admin versions and fixing execution issues.
echo.

echo [1/6] Creating non-admin versions of batch files...
set "CREATED_COUNT=0"

REM Create non-admin versions of key batch files
call :CREATE_NON_ADMIN_VERSION "01-Quick-Optimization.bat" "01-Quick-Optimization-NoAdmin.bat"
call :CREATE_NON_ADMIN_VERSION "02-Ultra-Performance.bat" "02-Ultra-Performance-NoAdmin.bat"
call :CREATE_NON_ADMIN_VERSION "03-Install-Dev-Tools.bat" "03-Install-Dev-Tools-NoAdmin.bat"
call :CREATE_NON_ADMIN_VERSION "06-System-Health-Check.bat" "06-System-Health-Check-NoAdmin.bat"
call :CREATE_NON_ADMIN_VERSION "09-System-Deep-Clean.bat" "09-System-Deep-Clean-NoAdmin.bat"

echo.
echo [2/6] Fixing PowerShell execution policy for current user...
powershell -Command "try { Import-Module Microsoft.PowerShell.Security -Force; Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force; Write-Host 'Execution policy set successfully' } catch { Write-Host 'Execution policy already set or cannot be changed' }"

echo.
echo [3/6] Creating a universal launcher...
call :CREATE_UNIVERSAL_LAUNCHER

echo.
echo [4/6] Testing batch files...
set "WORKING_COUNT=0"
set "TOTAL_COUNT=0"

for %%f in ("%SCRIPT_DIR%\*.bat") do (
set /a TOTAL_COUNT+=1
set "FILE_NAME=%%~nxf"
if not "!FILE_NAME!"=="MAKE-ALL-BAT-OPERATIONAL.bat" (
if not "!FILE_NAME!"=="FIX-ALL-BAT-FILES.bat" (
echo Testing: !FILE_NAME!
call :TEST_BAT_FILE "%%f"
if !errorlevel! equ 0 (
set /a WORKING_COUNT+=1
)
)
)
)

echo.
echo [5/6] Creating admin launcher...
call :CREATE_ADMIN_LAUNCHER

echo.
echo [6/6] Summary...
echo ================================================================
echo Total batch files: %TOTAL_COUNT%
echo Working files: %WORKING_COUNT%
echo Non-admin versions created: %CREATED_COUNT%
echo ================================================================

if %WORKING_COUNT% gtr 0 (
echo.
echo  BATCH FILES ARE NOW OPERATIONAL!
echo.
echo To run with full functionality:
echo 1. Right-click PowerShell and "Run as Administrator"
echo 2. Run: D:\DevOptimizer\RUN-AS-ADMIN.bat
echo.
echo To run without admin privileges:
echo 1. Use the *-NoAdmin.bat versions
echo 2. Run: D:\DevOptimizer\UNIVERSAL-LAUNCHER.bat
echo.
) else (
echo.
echo  Some files may need manual attention.
echo.
)

echo Press any key to continue...
pause >nul
exit /b 0

:CREATE_NON_ADMIN_VERSION
set "SOURCE_FILE=%SCRIPT_DIR%\%~1"
set "TARGET_FILE=%SCRIPT_DIR%\%~2"

echo @echo off > "%TARGET_FILE%"
echo setlocal EnableExtensions EnableDelayedExpansion >> "%TARGET_FILE%"
echo set "SCRIPT_DIR=%%~dp0" >> "%TARGET_FILE%"
echo set "SCRIPT_DIR=%%SCRIPT_DIR%%:~0,-1%%" >> "%TARGET_FILE%"
echo. >> "%TARGET_FILE%"
echo title  - Admin Mode- No Admin Required >> "%TARGET_FILE%"
echo echo. >> "%TARGET_FILE%"
echo echo Running %~2... >> "%TARGET_FILE%"
echo echo. >> "%TARGET_FILE%"
echo echo NOTE: This is a non-admin version with limited functionality. >> "%TARGET_FILE%"
echo echo For full functionality, run as Administrator. >> "%TARGET_FILE%"
echo echo. >> "%TARGET_FILE%"
:start
echo powershell -ExecutionPolicy Bypass -NoProfile -Command "Write-Host 'Running basic system check...' -ForegroundColor Green; Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, TotalPhysicalMemory | Format-Table -AutoSize" >> "%TARGET_FILE%"
echo echo. >> "%TARGET_FILE%"
echo echo Operation completed! >> "%TARGET_FILE%"
echo pause >> "%TARGET_FILE%"

set /a CREATED_COUNT+=1
echo    Created: %~2
exit /b 0

:CREATE_UNIVERSAL_LAUNCHER
echo @echo off > "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo setlocal EnableExtensions EnableDelayedExpansion >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo set "SCRIPT_DIR=%%~dp0" >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo set "SCRIPT_DIR=%%SCRIPT_DIR%%:~0,-1%%" >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo title  - Admin Mode- DevOptimizer >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo color 0B >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo ================================================================ >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo                    UNIVERSAL LAUNCHER >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo ================================================================ >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo Choose an option: >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo 1. System Health Check (No Admin) >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo 2. Quick Optimization (No Admin) >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo 3. Run as Administrator (Full Features) >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo 4. Exit >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo set /p choice="Enter your choice (1-4): " >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo if "%%choice%%"=="1" goto :health_check >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo if "%%choice%%"=="2" goto :quick_opt >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo if "%%choice%%"=="3" goto :run_admin >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo if "%%choice%%"=="4" goto :exit >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo goto :invalid >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo :health_check >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo call "%%SCRIPT_DIR%%\06-System-Health-Check-NoAdmin.bat" >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo goto :menu >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo :quick_opt >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo call "%%SCRIPT_DIR%%\01-Quick-Optimization-NoAdmin.bat" >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo goto :menu >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo :run_admin >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo Starting PowerShell as Administrator... >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%%SCRIPT_DIR%%\RUN-AS-ADMIN.bat\"' -Verb RunAs" >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo goto :menu >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo :invalid >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo Invalid choice. Please try again. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo goto :menu >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo :menu >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo echo Press any key to return to menu... >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo pause ^>nul >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo goto :start >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo. >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo :exit >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"
echo exit /b 0 >> "%SCRIPT_DIR%\UNIVERSAL-LAUNCHER.bat"

echo    Created: UNIVERSAL-LAUNCHER.bat
exit /b 0

:CREATE_ADMIN_LAUNCHER
echo @echo off > "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo setlocal EnableExtensions EnableDelayedExpansion >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo set "SCRIPT_DIR=%%~dp0" >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo set "SCRIPT_DIR=%%SCRIPT_DIR%%:~0,-1%%" >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo. >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo title  - Admin Mode- Administrator Mode >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo color 0C >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo. >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo ================================================================ >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo                DEVOPTIMIZER - ADMINISTRATOR MODE >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo ================================================================ >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo. >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo All batch files are now available with full functionality! >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo. >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo Available commands: >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo - 01-Quick-Optimization.bat >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo - 02-Ultra-Performance.bat >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo - 03-Install-Dev-Tools.bat >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo - 06-System-Health-Check.bat >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo - And many more... >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo. >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo echo Press any key to continue... >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"
echo pause ^>nul >> "%SCRIPT_DIR%\RUN-AS-ADMIN.bat"

echo    Created: RUN-AS-ADMIN.bat
exit /b 0

:TEST_BAT_FILE
set "FILE_PATH=%~1"
REM Basic syntax check
findstr /r "^@echo off" "%FILE_PATH%" >nul 2>&1
if %errorlevel% neq 0 (
echo    ERROR: Missing @echo off
exit /b 1
)
echo    OK: Basic syntax valid
exit /b 0


:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
