@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM Ollama Multi-Model Runner for DevOptimizer
REM Convenience batch wrapper for the PowerShell script

setlocal enabledelayedexpansion

REM Change to script directory
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

REM Check for help request
if /i "%~1"=="-help" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/help" goto :show_help

REM Check if we have a prompt
if "%~1"=="" goto :show_help
if /i "%~1"=="-prompt" (
if "%~2"=="" goto :show_help
set "PROMPT_TEXT=%~2"
goto :run_with_prompt
)

REM If first argument is not -prompt, treat it as the prompt text
set "PROMPT_TEXT=%~1"
goto :run_with_prompt

:run_with_prompt
echo Running Ollama Multi-Model Runner...
echo Command: %PS_CMD% -File tools\run-ollama-all.ps1 -Prompt "%PROMPT_TEXT%"
echo.

REM Execute PowerShell script with proper quoting
%PS_CMD% -File tools\run-ollama-all.ps1 -Prompt "%PROMPT_TEXT%"
set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% equ 0 (
echo SUCCESS: All models completed successfully
) else if %EXIT_CODE% equ 1 (
echo ERROR: Execution failed - check logs for details
) else if %EXIT_CODE% equ 2 (
echo WARNING: Some models failed - check individual model outputs
) else if %EXIT_CODE% equ 3 (
echo WARNING: No models succeeded - check Ollama installation and models
) else (
echo ERROR: Unexpected exit code: %EXIT_CODE%
)

exit /b %EXIT_CODE%

:show_help
echo Ollama Multi-Model Runner for DevOptimizer
echo.
echo USAGE:
echo   RUN-OLLAMA-ALL-MODELS.bat "Your prompt here"
echo   RUN-OLLAMA-ALL-MODELS.bat -prompt "Your prompt here"
echo   RUN-OLLAMA-ALL-MODELS.bat -help
echo.
echo EXAMPLES:
echo   RUN-OLLAMA-ALL-MODELS.bat "Hello, how are you?"
echo   RUN-OLLAMA-ALL-MODELS.bat "Analyze my system performance"
echo.
echo This script runs the provided prompt across all installed Ollama models
echo and saves individual outputs plus an aggregate summary.
exit /b 0
