@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion

:: ========================================================================
::                        PRODUCTION FIXER LAUNCHER
::                    Quick Launch for Real BAT File Fixing with Ollama
:: ========================================================================

echo ========================================================================
echo                        PRODUCTION FIXER LAUNCHER
echo                    Quick Launch for Real BAT File Fixing with Ollama
echo ========================================================================
echo.
echo [STATUS] Launching Production Real-time Auto-Fixer...
echo [INFO] This performs REAL analysis and fixing of all BAT files
echo [INFO] Integrated with your local Ollama server for AI-powered fixes
echo [INFO] Progress bar refreshes every 3 seconds with proper encoding
echo.

:: Check if we're in the right directory
if not exist "PRODUCTION-REALTIME-FIXER.ps1" (
echo [ERROR] Production fixer not found in current directory
echo [INFO] Please run this from the Testing directory
echo.
echo Current directory: %CD%
echo Expected file: PRODUCTION-REALTIME-FIXER.ps1
echo.
pause
exit /b 1
)

:: Check if Ollama is available
echo [CHECK] Testing Ollama server connection...
ollama list >nul 2>&1
if errorlevel 1 (
echo [WARNING] Ollama server not responding
echo [INFO] The fixer will run with rule-based fixes only
echo [INFO] Make sure Ollama is running locally
echo.
) else (
echo [SUCCESS] Ollama server detected
echo [INFO] AI-powered fixes will be available
echo.
)

:: Launch the production fixer
echo [INFO] Starting Production Real-time Auto-Fixer...
echo [INFO] This will:
echo   - Scan all BAT files in D:\DevOptimizer
echo   - Create backups before making changes
echo   - Apply real fixes based on actual issues found
echo   - Use Ollama AI for intelligent analysis
echo   - Show progress bar refreshing every 3 seconds
echo.
echo Press any key to continue...
pause >nul

:: Launch the main production fixer
powershell -ExecutionPolicy Bypass -File "PRODUCTION-REALTIME-FIXER.ps1"

echo.
echo [INFO] Production Fixer Launcher completed
echo [SUCCESS] Thank you for using the Production Real-time Auto-Fixer!
echo.
pause
