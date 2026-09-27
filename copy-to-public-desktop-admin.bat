@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
:: This script requires Administrator privileges
:: Right-click and select "Run as administrator"

echo Copying DevOptimizer Menu to Public Desktop...
echo.

:: Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
echo ERROR: This script must be run as Administrator!
echo.
echo Please right-click this file and select "Run as administrator"
echo.
pause
exit /b 1
)

:: Copy to Public Desktop
copy /Y "D:\DevOptimizer\DevOptimizer-Menu.bat" "C:\Users\Public\Desktop\DevOptimizer-Menu.bat" >nul 2>&1

if exist "C:\Users\Public\Desktop\DevOptimizer-Menu.bat" (
echo Success! Menu file copied to Public Desktop.
echo Location: C:\Users\Public\Desktop\DevOptimizer-Menu.bat
) else (
echo Failed to copy file. Please check permissions.
)

echo.
pause
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
