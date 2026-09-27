@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

:: Always use the full path to ensure it works from anywhere
call "D:\DevOptimizer\00-LAUNCHER.bat"


:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
