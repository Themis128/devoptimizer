:: SYNOPSIS: DevOptimizer automation script: standard-admin-helpers.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
REM ================================================================
REM           STANDARD ADMIN HELPER FUNCTIONS
REM ================================================================
REM These functions provide consistent admin privilege detection
REM and handling across all DevOptimizer batch files
REM ================================================================

:checkAdmin
set "IS_ADMIN=0"
REM Try fsutil dirty query (requires admin)
fsutil dirty query %SystemDrive% >nul 2>&1
if not errorlevel 1 (
set "IS_ADMIN=1"
) else (
REM Fallback to net session
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
)
exit /b

:requireAdmin
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
echo.
echo [ERROR] This operation requires Administrator privileges.
echo Please run this script as Administrator or use the NoAdmin version.
echo.
echo To run as Administrator:
echo 1. Right-click this script and select "Run as administrator"
echo 2. Or use the Admin version: %~n0-Admin.bat
echo.
pause
exit /b 1
)
exit /b

:log
REM Simple logging function
echo [%date% %time%] %~1 >> "%LOG_FILE%" 2>nul
exit /b

:detectPowerShell
REM Detect and set PowerShell command with fallback
where pwsh >nul 2>&1
if %errorlevel% neq 0 (
where powershell >nul 2>&1
if %errorlevel% neq 0 (
echo [ERROR] Neither pwsh nor powershell found in PATH
exit /b 1
)
set "PS_CMD=powershell -NoProfile -ExecutionPolicy Bypass"
) else (
set "PS_CMD=pwsh -NoProfile"
)
exit /b

:showHelp
echo.
echo USAGE: %~nx0 [options]
echo.
echo OPTIONS:
echo   -help, -h     Show this help message
echo   -dry-run      Show actions without executing (DEVOPTIMIZER_DRY_RUN=1)
echo.
echo EXAMPLES:
echo   %~nx0
echo   %~nx0 -dry-run
echo.
exit /b 0
