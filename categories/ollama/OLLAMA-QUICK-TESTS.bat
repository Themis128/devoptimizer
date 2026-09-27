@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title Ollama Quick Health Tests - DevOptimizer System
color 0B

echo.
echo ========================================================================
echo                     OLLAMA QUICK HEALTH TESTS - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.
echo This script runs quick health tests for the Ollama system
echo.

cd /d "%~dp0"

REM Check if PowerShell is available
where pwsh >nul 2>&1
if %errorlevel% neq 0 (
where powershell >nul 2>&1
if %errorlevel% neq 0 (
echo ERROR: Neither pwsh nor powershell found in PATH
exit /b 1
)
set "PS_CMD=powershell -NoProfile -ExecutionPolicy Bypass"
) else (
set "PS_CMD=pwsh -NoProfile"
)

echo [INFO] Running Ollama quick health tests...
echo.

REM Check for test type parameter
set "TEST_TYPE=all"
if not "%~1"=="" (
set "TEST_TYPE=%~1"
)

REM Check for verbose parameter
set "VERBOSE_PARAM="
if /i "%~2"=="verbose" (
set "VERBOSE_PARAM=-Verbose"
)

echo [INFO] Test type: %TEST_TYPE%
echo [INFO] Verbose: %~2
echo.

REM Execute the health tests
%PS_CMD% -ExecutionPolicy Bypass -File "tests\ollama-quick-health.ps1" -TestType "%TEST_TYPE%" %VERBOSE_PARAM%
set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% equ 0 (
echo [SUCCESS] All Ollama health tests passed!
) else (
echo [ERROR] Some Ollama health tests failed. Check the output above for details.
)

echo.
echo [INFO] Test execution completed
pause
exit /b %EXIT_CODE%
