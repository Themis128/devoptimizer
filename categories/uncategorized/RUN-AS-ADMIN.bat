@echo off 
setlocal EnableExtensions EnableDelayedExpansion 
set "SCRIPT_DIR=%~dp0" 
set "SCRIPT_DIR=%SCRIPT_DIR%:~0,-1%" 

title DevOptimizer - Administrator Mode 
color 0C 
echo. 
echo ================================================================ 
echo                DEVOPTIMIZER - ADMINISTRATOR MODE 
echo ================================================================ 
echo. 
echo All batch files are now available with full functionality 
echo. 
echo Available commands: 
echo - 01-Quick-Optimization.bat 
echo - 02-Ultra-Performance.bat 
echo - 03-Install-Dev-Tools.bat 
echo - 06-System-Health-Check.bat 
echo - And many more... 
echo. 
echo Press any key to continue... 
pause >nul
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
