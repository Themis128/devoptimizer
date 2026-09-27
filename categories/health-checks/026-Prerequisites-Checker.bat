@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Prerequisites Checker - System Requirements Verification
color 0E 
echo.
echo
echo
echo PREREQUISITES CHECKER v1.0
echo System Requirements Verification & Installation
echo
echo echo.
echo This tool checks and installs required dependencies for the
echo Development Cache Cleaner system. echo.
echo CHECKING OPTIONS:
echo 1) Check Prerequisites Only - Verify system requirements
echo 2) Install Missing Tools - Auto-install missing dependencies
echo 3) Fix All Issues - Comprehensive system fix
echo 4) Check & Install All - Full system preparation echo.
echo TOOLS TO VERIFY:
echo PowerShell 5.1+ Node.js & npm
echo Python 3.x Git
echo .NET Framework 4.6.2+ Package managers (pnpm, yarn)
echo Windows 10+ Development tools (VS Code, Cursor)
echo System resources Docker (optional) echo.
echo NOTE: This tool requires Administrator privileges! echo. set /p choice="Select option (1-4): " if "%choice%"=="1" ( echo.
echo Checking prerequisites only... powershell -ExecutionPolicy Bypass -File "%~dp0prerequisites-checker.ps1" -CheckOnly ) else if "%choice%"=="2" ( echo.
echo Installing missing tools... powershell -ExecutionPolicy Bypass -File "%~dp0prerequisites-checker.ps1" -InstallAll ) else if "%choice%"=="3" ( echo.
echo Fixing all issues... powershell -ExecutionPolicy Bypass -File "%~dp0prerequisites-checker.ps1" -FixIssues ) else if "%choice%"=="4" ( echo.
echo Full system preparation... powershell -ExecutionPolicy Bypass -File "%~dp0prerequisites-checker.ps1" -InstallAll -Verbose ) else ( echo.
echo Invalid choice! Please enter a number from 1-4. pause exit /b 1 ) echo.
echo Prerequisites checker completed! echo.
echo Next steps:
echo If all prerequisites are OK, you can run the cache cleaner
echo If issues remain, run this tool again with option 2 or 3
echo Check the logs for detailed information echo. pause
