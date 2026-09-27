@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal EnableExtensions

title DevOptimizer Desktop Shortcut Creator

echo ================================================================
echo           DEVOPTIMIZER DESKTOP SHORTCUT CREATOR
echo ================================================================
echo.
echo This script creates a beautiful red-colored desktop shortcut
echo for the DevOptimizer Comprehensive Launcher with access to ALL batch files.
echo.

REM Change to script directory
cd /d "%~dp0"

REM Check if PowerShell is available
where pwsh >nul 2>&1
if %errorlevel% neq 0 (
where powershell >nul 2>&1
if %errorlevel% neq 0 (
echo ERROR: PowerShell not found. Please install PowerShell to continue.
pause
exit /b 1
)
set "PS_CMD=powershell -NoProfile -ExecutionPolicy Bypass"
) else (
set "PS_CMD=pwsh -NoProfile"
)

echo [INFO] Creating desktop shortcuts with red color theme...
echo [INFO] PowerShell Command: %PS_CMD%
echo.

REM Execute PowerShell script
%PS_CMD% -File tools\create-desktop-shortcut.ps1 -TargetPath "%~dp0DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat" -ShortcutName "DevOptimizer All Batch Files"
set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% equ 0 (
echo  SUCCESS: Desktop shortcuts created successfully!
echo.
echo  WHAT WAS CREATED:
echo  DevOptimizer All Batch Files.lnk (Main shortcut)
echo  DevOptimizer-Red-Launcher.lnk (Red-themed shortcut)
echo  DevOptimizer-Red-Launcher.bat (Red wrapper script)
echo.
echo  HOTKEYS:
echo  Ctrl+Alt+D - Launch comprehensive DevOptimizer launcher
echo  Ctrl+Alt+R - Launch red-themed DevOptimizer launcher
echo.
echo  FEATURES: The comprehensive launcher provides access to ALL batch files
echo    in the DevOptimizer folder with dynamic scanning and categorization.
echo.
echo  RED THEME FEATURES:
echo  Beautiful red console color (0C)
echo  ASCII art startup animation
echo  Professional red-themed UI
echo  Proper UTF-8 encoding support
echo.
echo Your DevOptimizer desktop shortcuts are ready to use!
) else (
echo  ERROR: Desktop shortcut creation failed with exit code %EXIT_CODE%
echo Please check the output above for details.
)

echo.
pause
exit /b %EXIT_CODE%
