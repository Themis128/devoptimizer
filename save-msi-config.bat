@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
:: Batch file to save MSI Afterburner config with admin privileges
echo.
echo ========================================
echo   Save MSI Afterburner Configuration
echo ========================================
echo.
echo This will copy the config file from workspace to Program Files.
echo Administrator privileges are required.
echo.
pause

powershell -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', 'cd D:\DevOptimizer\config\overclocking; .\save-msi-config-to-program-files.ps1; pause'"
exit /b %ERRORLEVEL%
