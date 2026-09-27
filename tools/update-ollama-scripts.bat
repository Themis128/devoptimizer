@echo off
REM Update All Ollama Scripts to Use Multi-Model System
REM Automatically converts hardcoded ollama run calls to use the new multi-model system

setlocal enabledelayedexpansion

echo ================================================================
echo            UPDATING OLLAMA SCRIPTS TO MULTI-MODEL SYSTEM
echo ================================================================
echo.

cd /d "%~dp0\.."

REM Find all ollama batch files
set "UPDATED_COUNT=0"
set "TOTAL_COUNT=0"

for %%f in (ollama-*.bat) do (
set /a TOTAL_COUNT+=1
echo Processing: %%f

REM Create backup
copy "%%f" "%%f.backup" >nul 2>&1

REM Create temporary file with updated content
set "TEMP_FILE=%TEMP%\ollama_update_%%f"

(
echo @echo off
echo setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
echo.
echo :: ================================================================
echo ::              UPDATED OLLAMA SCRIPT - MULTI-MODEL SYSTEM
echo :: ================================================================
echo :: This script has been automatically updated to use all available Ollama models
echo :: Original script: %%f
echo :: Updated: %date% %time%
echo :: ================================================================
echo.

REM Process the original file and replace ollama run calls
for /f "usebackq delims=" %%a in ("%%f") do (
set "line=%%a"

REM Check if line contains ollama run command
echo !line! | findstr /i "ollama run" >nul
if !errorlevel! equ 0 (
REM Extract the prompt from the ollama run command
set "line=!line:*ollama run *=!"
set "line=!line:*7b =!"
set "line=!line:*1.5b =!"
set "line=!line:*coder: =!"
set "line=!line:*qwen2.5 =!"
set "line=!line:*qwen =!"

REM Remove the output redirection
set "line=!line: > =!"
set "line=!line:*> =!"
set "line=!line:*"% =!"
set "line=!line:*" =!"

REM Extract output file path
for /f "tokens=2" %%b in ("!line!") do set "output_file=%%b"
set "output_file=!output_file:> =!"
set "output_file=!output_file:*"% =!"
set "output_file=!output_file:*" =!"

REM Extract the prompt (everything before the output redirection)
set "prompt_part=%%a"
set "prompt_part=!prompt_part:*ollama run *=!"
set "prompt_part=!prompt_part:*7b =!"
set "prompt_part=!prompt_part:*1.5b =!"
set "prompt_part=!prompt_part:*coder: =!"
set "prompt_part=!prompt_part:*qwen2.5 =!"
set "prompt_part=!prompt_part:*qwen =!"

REM Remove output redirection from prompt
for /f "tokens=1" %%c in ("!prompt_part!") do set "prompt=%%c"

REM Replace with multi-model call
echo call "%%~dp0tools\ollama-batch-helper.bat" -prompt "!prompt!" -output "!output_file!"
) else (
REM Keep original line but update headers
if "!line!"=="echo            OLLAMA" (
echo echo            OLLAMA MULTI-MODEL SYSTEM
) else if "!line!"=="echo         OLLAMA" (
echo echo         OLLAMA MULTI-MODEL PERFORMANCE SCORER
) else if "!line!"=="echo  OLLAMA" (
echo echo  OLLAMA MULTI-MODEL INTELLIGENT MONITOR
) else if "!line!"=="echo  OLLAMA" (
echo echo  OLLAMA MULTI-MODEL INTELLIGENT OPTIMIZER
) else if "!line!"=="echo  OLLAMA" (
echo echo  OLLAMA MULTI-MODEL PREDICTIVE MAINTENANCE
) else if "!line!"=="echo  OLLAMA" (
echo echo  OLLAMA MULTI-MODEL SCRIPT GENERATOR
) else (
echo !line!
)
)
)
) > "!TEMP_FILE!"

REM Replace original file with updated version
move "!TEMP_FILE!" "%%f" >nul 2>&1

if !errorlevel! equ 0 (
echo    Updated successfully
set /a UPDATED_COUNT+=1
) else (
echo    Update failed, restoring backup
move "%%f.backup" "%%f" >nul 2>&1
)

echo.
)

echo ================================================================
echo                    UPDATE SUMMARY
echo ================================================================
echo.
echo Total scripts found: %TOTAL_COUNT%
echo Successfully updated: %UPDATED_COUNT%
echo Failed updates: %TOTAL_COUNT% - %UPDATED_COUNT%
echo.
echo Backup files created: *.backup
echo.

if %UPDATED_COUNT% gtr 0 (
echo  Multi-model system integration completed!
echo.
echo The following scripts now use ALL available Ollama models:
for %%f in (ollama-*.bat) do (
if exist "%%f.backup" echo   - %%f
)
echo.
echo Next steps:
echo 1. Test the updated scripts
echo 2. Delete .backup files when satisfied
echo 3. Enjoy enhanced multi-model analysis!
) else (
echo  No scripts were updated. Please check for errors.
)

echo.
pause
exit /b %ERRORLEVEL%
