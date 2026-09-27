@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
REM DevOptimizer Uninstallation Launcher
REM Run this batch file to uninstall DevOptimizer

echo.
echo ========================================
echo DevOptimizer Uninstallation
echo ========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
echo Running as administrator... OK
) else (
echo ERROR: This script must be run as administrator
echo Right-click and select "Run as administrator"
pause
exit /b 1
)

echo.
echo WARNING: This will remove DevOptimizer and its components!
echo.
echo Options:
echo - Keep data files (metrics, traces, analysis results)
echo - Keep log files
echo - Keep configuration files
echo - Unregister scheduled tasks
echo - Remove Python virtual environment
echo - Remove desktop shortcuts
echo.
set /p choice="Do you want to continue? (y/N): "
if /i not "%choice%"=="y" (
echo Uninstallation cancelled
pause
exit /b 0
)

echo.
echo Starting DevOptimizer uninstallation...
echo.

REM Check if PowerShell 7 is available
pwsh --version >nul 2>&1
if %errorLevel% == 0 (
echo PowerShell 7 found... OK
) else (
echo ERROR: PowerShell 7 is required but not found
echo Please install PowerShell 7 to complete uninstallation
pause
exit /b 1
)

REM Run uninstallation script
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Uninstall-DevOptimizer.ps1" -Force
if %errorLevel% neq 0 (
echo WARNING: Uninstallation completed with some errors
echo Check the log files for details
) else (
echo Uninstallation completed successfully
)

echo.
echo ========================================
echo Uninstallation Complete!
echo ========================================
echo.
echo DevOptimizer has been removed from your system.
echo.
echo Post-uninstallation steps:
echo 1. Restart your computer
echo 2. Check System Environment Variables for any DevOptimizer paths
echo 3. Review the uninstall log for any manual cleanup required
echo.
echo Press any key to exit...
pause >nul
