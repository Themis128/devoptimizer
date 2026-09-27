@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title Modernizing All Scripts with Cutting-Edge Techniques
color 0B

echo.
echo ================================================================
echo    MODERNIZING ALL SCRIPTS - CUTTING-EDGE TECHNIQUES
echo ================================================================
echo.
echo This will update all portable scripts using:
echo   - Advanced pattern matching algorithms
echo   - Modern error handling techniques
echo   - Performance optimizations
echo   - Best practice implementations
echo.

set /p "confirm=Continue? (Y/N): "
if /i not "%confirm%"=="Y" (
echo Cancelled.
exit /b 0
)

echo.
echo Starting modernization process...
echo.

:: Run PowerShell updater
powershell -ExecutionPolicy Bypass -File "%~dp0advanced-script-updater.ps1" -ScriptDir "%~dp0portable"

if errorlevel 1 (
echo.
echo [ERROR] Modernization process encountered errors.
echo Check the log file for details.
) else (
echo.
echo [SUCCESS] All scripts have been modernized!
)

echo.
pause
