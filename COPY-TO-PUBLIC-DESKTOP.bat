@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
:: Copy DevOptimizer Menu to Public Desktop
:: Run this as Administrator (Right-click > Run as administrator)

echo.
echo ================================================================
echo    Copying DevOptimizer Menu to Public Desktop
echo ================================================================
echo.

:: Check admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
echo [ERROR] This script requires Administrator privileges!
echo.
echo Please right-click this file and select "Run as administrator"
echo.
pause
exit /b 1
)

:: Copy the file
echo Copying menu file...
copy /Y "D:\DevOptimizer\DevOptimizer-Menu.bat" "C:\Users\Public\Desktop\DevOptimizer-Menu.bat" >nul 2>&1

if exist "C:\Users\Public\Desktop\DevOptimizer-Menu.bat" (
echo.
echo [SUCCESS] Menu file copied to Public Desktop!
echo.
echo Location: C:\Users\Public\Desktop\DevOptimizer-Menu.bat
echo.
echo You can now run DevOptimizer-Menu.bat from the Public Desktop!
) else (
echo.
echo [ERROR] Failed to copy file. Please check permissions.
)

echo.
pause
