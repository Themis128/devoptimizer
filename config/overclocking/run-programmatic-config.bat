@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: Batch file to run programmatic overclocking configuration as Administrator

echo.
echo ========================================
echo   Programmatic Overclocking Configuration
echo ========================================
echo.
echo This will attempt to configure overclocking programmatically.
echo Administrator privileges may be required.
echo.
pause

cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', 'cd D:\DevOptimizer\config\overclocking; .\apply-overclock-programmatic.ps1; pause'"
exit /b %ERRORLEVEL%
