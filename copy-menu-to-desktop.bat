@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
:: Copy DevOptimizer Menu to Public Desktop
echo Copying DevOptimizer Menu to Public Desktop...
echo.

:: Try to copy the file
copy /Y "D:\DevOptimizer\DevOptimizer-Menu.bat" "C:\Users\Public\Desktop\DevOptimizer-Menu.bat" 2>nul

if exist "C:\Users\Public\Desktop\DevOptimizer-Menu.bat" (
echo Success! Menu file copied to Public Desktop.
echo.
echo You can now run DevOptimizer-Menu.bat from your desktop.
) else (
echo.
echo Failed to copy to Public Desktop (may require admin rights).
echo.
echo Please manually copy the file:
echo   From: D:\DevOptimizer\DevOptimizer-Menu.bat
echo   To:   C:\Users\Public\Desktop\DevOptimizer-Menu.bat
echo.
echo Or run this script as Administrator.
)

echo.
pause


exit /b 0
