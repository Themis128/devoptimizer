@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
rem DevOptimizer App launcher (fallback - shows a brief console window)
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\DevOptimizer\DevOptimizer-App.ps1"
exit /b %ERRORLEVEL%
