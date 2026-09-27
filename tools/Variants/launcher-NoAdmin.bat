@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

:: Always use the full path to ensure it works from anywhere
call "D:\DevOptimizer\00-LAUNCHER.bat"
exit /b %ERRORLEVEL%
