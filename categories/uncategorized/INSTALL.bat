@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
REM DevOptimizer Installation Launcher
REM Run this batch file to install DevOptimizer

echo.
echo ========================================
echo DevOptimizer Installation
echo ========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
echo Running as administrator... OK
) else (
echo ERROR: This script must be run as administrator
echo Right-click and select "Run as administrator"
pause
exit /b 1
)

REM Check if PowerShell 7 is available
pwsh --version >nul 2>&1
if %errorLevel% == 0 (
echo PowerShell 7 found... OK
) else (
echo ERROR: PowerShell 7 is required but not found
echo Please install PowerShell 7 from: https://github.com/PowerShell/PowerShell/releases
pause
exit /b 1
)

echo.
echo Starting DevOptimizer installation...
echo.

REM Step 1: Install PowerShell modules
echo [1/4] Installing PowerShell modules...
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Install-Modules.ps1"
if %errorLevel% neq 0 (
echo ERROR: Failed to install PowerShell modules
pause
exit /b 1
)

REM Step 2: Bootstrap development environment
echo.
echo [2/4] Setting up development environment...
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Bootstrap-DevEnvironment.ps1"
if %errorLevel% neq 0 (
echo WARNING: Development environment setup had issues
echo Continuing with installation...
)

REM Step 3: Register scheduled tasks
echo.
echo [3/4] Registering scheduled tasks...
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Register-ScheduledTasks.ps1"
if %errorLevel% neq 0 (
echo WARNING: Failed to register some scheduled tasks
echo You can register them manually later
)

REM Step 4: Initial system setup
echo.
echo [4/4] Performing initial system setup...
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Security-Hardening.ps1" -RunSecurityAudit
if %errorLevel% neq 0 (
echo WARNING: Initial security audit had issues
echo You can run it manually later
)

echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo DevOptimizer has been installed successfully.
echo.
echo Next steps:
echo 1. Install Ollama from https://ollama.ai for AI analysis
echo 2. Pull AI models: ollama pull llama3.1
echo 3. Check the README.md for usage instructions
echo 4. Review logs in D:\DevOptimizer\logs\
echo.
echo Desktop shortcuts have been created for easy access.
echo.
echo Press any key to exit...
pause >nul
