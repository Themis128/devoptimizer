@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title DevOptimizer System Launcher
color 0C

echo.
echo ================================================================================
echo                        DEVOPTIMIZER SYSTEM LAUNCHER
echo ================================================================================
echo.

REM Change to DevOptimizer directory
cd /d "D:\DevOptimizer"

REM Launch the main launcher
call "DEVOPTIMIZER-WORKING-LAUNCHER.bat"

REM Exit
exit /b 0
