@echo off 
setlocal EnableExtensions EnableDelayedExpansion 
set "SCRIPT_DIR=%~dp0" 
set "SCRIPT_DIR=%SCRIPT_DIR%:~0,-1%" 

title Universal Launcher - DevOptimizer 
color 0B 
echo. 
echo ================================================================ 
echo                    UNIVERSAL LAUNCHER 
echo ================================================================ 
echo. 
echo Choose an option: 
echo 1. System Health Check (No Admin) 
echo 2. Quick Optimization (No Admin) 
echo 3. Run as Administrator (Full Features) 
echo 4. Exit 
echo. 
set /p choice="Enter your choice (1-4): " 

if "%choice%"=="1" goto :health_check 
if "%choice%"=="2" goto :quick_opt 
if "%choice%"=="3" goto :run_admin 
if "%choice%"=="4" goto :exit 
goto :invalid 

:health_check 
call "%SCRIPT_DIR%\06-System-Health-Check-NoAdmin.bat" 
goto :menu 

:quick_opt 
call "%SCRIPT_DIR%\01-Quick-Optimization-NoAdmin.bat" 
goto :menu 

:run_admin 
echo Starting PowerShell as Administrator... 
powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%SCRIPT_DIR%\RUN-AS-ADMIN.bat\"' -Verb RunAs" 
goto :menu 

:invalid 
echo Invalid choice. Please try again. 
goto :menu 

:menu 
echo. 
echo Press any key to return to menu... 
pause >nul 
goto :menu 

:exit 
exit /b 0
