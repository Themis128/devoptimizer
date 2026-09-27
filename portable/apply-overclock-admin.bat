@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal EnableExtensions
if defined DEVOPT_HOME goto rootReady
set "DEVOPT_HOME=D:\DevOptimizer"
:rootReady
set "TARGET_PS1=%DEVOPT_HOME%\config\overclocking\apply-overclock-admin.ps1"
if not exist "%TARGET_PS1%" (
echo [ERROR] PowerShell script not found: %TARGET_PS1%
exit /b 1
)
where pwsh >nul 2>nul
if %errorlevel% EQU 0 (
set "PS_CMD=pwsh"
) else (
set "PS_CMD=powershell"
)
%PS_CMD% -NoProfile -ExecutionPolicy Bypass -File "%TARGET_PS1%" %*
endlocal
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
