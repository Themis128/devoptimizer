@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion

:: ========================================================================
::                        ENHANCED TESTING LAUNCHER
::                    Quick Launch for Real-time Fixer Test Suite
:: ========================================================================

echo ========================================================================
echo                        ENHANCED TESTING LAUNCHER
echo                    Quick Launch for Real-time Fixer Test Suite
echo ========================================================================
echo.
echo [STATUS] Launching Enhanced BAT Testing Suite with Real-time Fixer...
echo [INFO] This includes automatic fixing with 3-second progress updates
echo.

:: Check if we're in the right directory
if not exist "BAT-TEST-ALL-WITH-FIXER.bat" (
echo [ERROR] Enhanced test suite not found in current directory
echo [INFO] Please run this from the Testing directory
echo.
echo Current directory: %CD%
echo Expected files:
echo   - BAT-TEST-ALL-WITH-FIXER.bat
echo   - BAT-REALTIME-FIXER-WITH-PROGRESS.bat
echo.
pause
exit /b 1
)

:: Check for required files
if not exist "BAT-REALTIME-FIXER-WITH-PROGRESS.bat" (
echo [WARNING] Real-time fixer not found
echo [INFO] Some features may not be available
)

:: Launch the enhanced test suite
echo [INFO] Starting Enhanced Test Suite...
echo [INFO] Progress bars will refresh every 3 seconds
echo [INFO] Real-time fixing will be applied automatically
echo.
echo Press any key to continue...
pause >nul

:: Launch the main test orchestrator
call "BAT-TEST-ALL-WITH-FIXER.bat"

echo.
echo [INFO] Enhanced Testing Launcher completed
echo [SUCCESS] Thank you for using the Enhanced Testing Suite!
echo.
pause
