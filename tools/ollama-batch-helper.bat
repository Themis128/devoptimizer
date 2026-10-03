:: SYNOPSIS: DevOptimizer automation script: ollama-batch-helper.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
REM Ollama Batch Helper for DevOptimizer
REM Provides easy integration of multi-model Ollama system into batch files

setlocal enabledelayedexpansion

REM Change to script directory
cd /d "%~dp0\.."

REM Set default values
set "OUTPUT_DIR=logs"
set "CONCURRENCY=1"
set "TIMEOUT=300"

REM Parse arguments
set "PROMPT="
set "OUTPUT_FILE="
set "APPEND_MODE=false"

:parse_args
if "%~1"=="" goto :execute
if /i "%~1"=="-prompt" (
set "PROMPT=%~2"
shift
shift
goto :parse_args
)
if /i "%~1"=="-output" (
set "OUTPUT_FILE=%~2"
shift
shift
goto :parse_args
)
if /i "%~1"=="-append" (
set "APPEND_MODE=true"
shift
goto :parse_args
)
if /i "%~1"=="-concurrency" (
set "CONCURRENCY=%~2"
shift
shift
goto :parse_args
)
if /i "%~1"=="-timeout" (
set "TIMEOUT=%~2"
shift
shift
goto :parse_args
)

REM Unknown argument
echo ERROR: Unknown argument: %~1
exit /b 1

:execute
REM Validate required parameters
if "%PROMPT%"=="" (
echo ERROR: -prompt parameter is required
exit /b 1
)

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

REM Create timestamp for unique output directory
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "TIMESTAMP=%YYYY%%MM%%DD%-%HH%%Min%%Sec%"

REM Create unique output directory
set "UNIQUE_OUTPUT_DIR=%OUTPUT_DIR%\ollama-%TIMESTAMP%"

REM Run the multi-model system
%PS_CMD% -File tools\run-ollama-all.ps1 -Prompt "%PROMPT%" -OutputDir "%UNIQUE_OUTPUT_DIR%" -Concurrency %CONCURRENCY% -TimeoutSeconds %TIMEOUT%
set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% neq 0 (
echo ERROR: Multi-model execution failed with exit code %EXIT_CODE%
exit /b %EXIT_CODE%
)

REM Process output if specific output file requested
if not "%OUTPUT_FILE%"=="" (
REM Find the aggregate file
for /f "delims=" %%f in ('dir /b /s "%UNIQUE_OUTPUT_DIR%\aggregate.md" 2^>nul') do set "AGGREGATE_FILE=%%f"

if exist "%AGGREGATE_FILE%" (
if "%APPEND_MODE%"=="true" (
type "%AGGREGATE_FILE%" >> "%OUTPUT_FILE%"
) else (
type "%AGGREGATE_FILE%" > "%OUTPUT_FILE%"
)
echo Results saved to: %OUTPUT_FILE%
) else (
echo WARNING: Aggregate file not found, using first available model output
REM Find first model output file
for /f "delims=" %%f in ('dir /b "%UNIQUE_OUTPUT_DIR%\*.txt" 2^>nul ^| findstr /v "aggregate" ^| findstr /n "^" ^| findstr "^1:"') do (
set "FIRST_FILE=%%f"
goto :found_first
)
:found_first
if exist "%UNIQUE_OUTPUT_DIR%\%FIRST_FILE%" (
if "%APPEND_MODE%"=="true" (
type "%UNIQUE_OUTPUT_DIR%\%FIRST_FILE%" >> "%OUTPUT_FILE%"
) else (
type "%UNIQUE_OUTPUT_DIR%\%FIRST_FILE%" > "%OUTPUT_FILE%"
)
echo Results saved to: %OUTPUT_FILE%
)
)
)

REM Display summary
echo.
echo Multi-model execution completed successfully!
echo Output directory: %UNIQUE_OUTPUT_DIR%
echo Models used: All available Ollama models
echo Exit code: %EXIT_CODE%

exit /b %EXIT_CODE%
