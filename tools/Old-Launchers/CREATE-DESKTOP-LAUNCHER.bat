@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title Create Desktop Launcher - DevOptimizer System
color 0A

echo.
echo ========================================================================
echo                    CREATE DESKTOP LAUNCHER - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.

cd /d "%~dp0"

REM Check if PowerShell is available
where pwsh >nul 2>&1
if %errorlevel% neq 0 (
where powershell >nul 2>&1
if %errorlevel% neq 0 (
echo ERROR: Neither pwsh nor powershell found in PATH
exit /b 1
)
set "PS_CMD=powershell -NoProfile -ExecutionPolicy Bypass"
) else (
set "PS_CMD=pwsh -NoProfile"
)

echo [INFO] Creating desktop launcher for DevOptimizer System...
echo [INFO] Target: DEVOPTIMIZER-WORKING-LAUNCHER.bat
echo.

REM Execute the PowerShell script
%PS_CMD% -ExecutionPolicy Bypass -File "tools\create-desktop-shortcut.ps1"
set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% equ 0 (
echo [SUCCESS] Desktop launcher created successfully!
echo [INFO] Check your desktop for the new shortcut
echo [INFO] The launcher works both with and without admin privileges
) else (
echo [ERROR] Failed to create desktop launcher. Check the output above for details.
)

echo.
pause
exit /b %EXIT_CODE%
