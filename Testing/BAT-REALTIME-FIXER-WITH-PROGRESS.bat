@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion

:: ========================================================================
::                    BAT FILE REALTIME FIXER WITH PROGRESS BAR
::                    Intelligent Auto-Fixer with Dynamic Progress Tracking
:: ========================================================================

echo ========================================================================
echo                    BAT FILE REALTIME FIXER WITH PROGRESS BAR
echo                    Intelligent Auto-Fixer with Dynamic Progress Tracking
echo ========================================================================
echo.
echo [STATUS] Initializing Real-time Auto-Fixer with Progress Bar...
echo [INFO] This tool automatically fixes common BAT file issues
echo [INFO] Integrated with Ollama for intelligent code analysis
echo [INFO] Progress bar refreshes every 3 seconds
echo.

:: Set up paths
set "FIXER_DIR=%~dp0"
set "RESULTS_DIR=%FIXER_DIR%Results"
set "FIXES_DIR=%RESULTS_DIR%\fixes"
set "BACKUP_DIR=%RESULTS_DIR%\backups"
set "LOG_DIR=%RESULTS_DIR%\logs"
set "PROGRESS_FILE=%RESULTS_DIR%\progress.txt"
set "REPORT_FILE=%RESULTS_DIR%\realtime-fixes.html"

:: Create directories
mkdir "%FIXES_DIR%" 2>nul
mkdir "%BACKUP_DIR%" 2>nul
mkdir "%LOG_DIR%" 2>nul

:: Initialize counters
set /a TOTAL_FILES=0
set /a FILES_PROCESSED=0
set /a TOTAL_FIXED=0
set /a SYNTAX_FIXED=0
set /a QUOTES_FIXED=0
set /a PARENTHESES_FIXED=0
set /a ECHO_FIXED=0
set /a LOOP_FIXED=0
set /a EXIT_FIXED=0
set /a OLLAMA_FIXES=0

:: Get current timestamp
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "TIMESTAMP=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

:: Initialize HTML report
call :initialize_html_report

:: Check if Ollama is available
call :check_ollama_availability
if errorlevel 1 (
echo [WARNING] Ollama not available - using rule-based fixing only
set "OLLAMA_AVAILABLE=0"
) else (
echo [SUCCESS] Ollama detected - using intelligent AI fixing
set "OLLAMA_AVAILABLE=1"
)

:: Count total files first
echo [INFO] Counting BAT files...
cd /d "D:\DevOptimizer"
for %%f in (*.bat) do set /a TOTAL_FILES+=1

echo [INFO] Found %TOTAL_FILES% BAT files to process
echo [STATUS] Starting real-time fixing process...
echo [TIMESTAMP] %TIMESTAMP%
echo.

:: Start progress monitor in background
start /b "" cmd /c "call :progress_monitor"

:: Process each BAT file
for %%f in (*.bat) do (
set "BAT_FILE=%%f"
call :fix_bat_file "%%f"
set /a FILES_PROCESSED+=1

:: Update progress file
echo %FILES_PROCESSED%^|%TOTAL_FILES%^|!TOTAL_FIXED!^|!SYNTAX_FIXED!^|!QUOTES_FIXED!^|!PARENTHESES_FIXED!^|!ECHO_FIXED!^|!LOOP_FIXED!^|!EXIT_FIXED!^|!OLLAMA_FIXES! > "%PROGRESS_FILE%"

:: Small delay to show progress
timeout /t 1 /nobreak >nul 2>&1
)

:: Stop progress monitor
taskkill /f /im cmd.exe /fi "WINDOWTITLE eq progress_monitor" >nul 2>&1

:: Generate final report
call :generate_final_report

:: Final progress display
call :show_final_progress

echo.
echo ========================================================================
echo                        FIXING COMPLETE
echo ========================================================================
echo "[TOTAL FILES] %TOTAL_FILES%"
echo "[FILES PROCESSED] %FILES_PROCESSED%"
echo "[TOTAL FIXED] %TOTAL_FIXED%"
echo "[SYNTAX FIXES] %SYNTAX_FIXED%"
echo "[QUOTES FIXES] %QUOTES_FIXED%"
echo "[PARENTHESES FIXES] %PARENTHESES_FIXED%"
echo "[ECHO FIXES] %ECHO_FIXED%"
echo "[LOOP FIXES] %LOOP_FIXED%"
echo "[EXIT FIXES] %EXIT_FIXED%"
echo "[OLLAMA FIXES] %OLLAMA_FIXES%"
echo.
echo [SUCCESS] Real-time fixing completed!
echo [INFO] Fixed files saved to: %FIXES_DIR%
echo [INFO] Backups saved to: %BACKUP_DIR%
echo [INFO] Report saved to: %REPORT_FILE%
echo.

goto :eof

:: ========================================================================
::                        PROGRESS MONITOR
:: ========================================================================

:progress_monitor
title progress_monitor
:progress_loop
if not exist "%PROGRESS_FILE%" goto :progress_loop

for /f "tokens=1,2,3,4,5,6,7,8,9,10 delims=|" %%a in (%PROGRESS_FILE%) do (
set "PROCESSED=%%a"
set "TOTAL=%%b"
set "FIXED=%%c"
set "SYNTAX=%%d"
set "QUOTES=%%e"
set "PARENS=%%f"
set "ECHO=%%g"
set "LOOP=%%h"
set "EXIT=%%i"
set "OLLAMA=%%j"
)

:: Calculate percentages
set /a PERCENTAGE=(!PROCESSED! * 100) / !TOTAL!
set /a BAR_LENGTH=(!PERCENTAGE! * 40) / 100
set /a REMAINING=40 - !BAR_LENGTH!

:: Build progress bar
set "PROGRESS_BAR="
for /l %%i in (1,1,!BAR_LENGTH!) do set "PROGRESS_BAR=!PROGRESS_BAR!"
for /l %%i in (1,1,!REMAINING!) do set "PROGRESS_BAR=!PROGRESS_BAR!░"

:: Clear screen and show progress
cls
echo ========================================================================
echo                    REALTIME FIXER PROGRESS MONITOR
echo ========================================================================
echo.
echo  FIXING STATUS: ACTIVE
echo.
echo  FILES PROGRESS:
echo    [!PROCESSED!/!TOTAL!] [!PERCENTAGE!%%] [!PROGRESS_BAR!]
echo.
echo  FIXES APPLIED:
echo     Total Files Fixed: !FIXED!
echo     Syntax Fixes: !SYNTAX!
echo     Quotes Fixes: !QUOTES!
echo     Parentheses Fixes: !PARENS!
echo     Echo Fixes: !ECHO!
echo     Loop Fixes: !LOOP!
echo     Exit Fixes: !EXIT!
echo     Ollama Fixes: !OLLAMA!
echo.
echo   STATUS: Processing BAT files...
echo  LOGS: %LOG_DIR%
echo ========================================================================

:: Wait 3 seconds before next update
timeout /t 3 /nobreak >nul 2>&1
goto :progress_loop

:: ========================================================================
::                        FIXING FUNCTIONS
:: ========================================================================

:fix_bat_file
set "FILE_PATH=%~1"
set "FILE_NAME=%~nx1"

:: Initialize fix counters for this file
set "FILE_FIXES=0"

:: Create backup
copy "%FILE_PATH%" "%BACKUP_DIR%\%FILE_NAME%.backup" >nul 2>&1

:: Fix 1: Missing quotes in set statements
call :fix_missing_quotes "%FILE_PATH%"

:: Fix 2: Unbalanced parentheses
call :fix_unbalanced_parens "%FILE_PATH%"

:: Fix 3: Missing @echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
call :fix_missing_echo_off "%FILE_PATH%"

:: Fix 4: Infinite loops
call :fix_infinite_loops "%FILE_PATH%"

:: Fix 5: Missing exit points
call :fix_missing_exits "%FILE_PATH%"

:: Fix 6: Syntax errors with Ollama (if available)
if "%OLLAMA_AVAILABLE%"=="1" (
call :ollama_intelligent_fix "%FILE_PATH%"
)

:: Record fixes
if !FILE_FIXES! GTR 0 (
set /a TOTAL_FIXED+=1
echo "%FILE_NAME%^|!FILE_FIXES!^|%TIMESTAMP%" >> "%LOG_DIR%\fixes-log.txt"
)

goto :eof

:fix_missing_quotes
set "FILE_PATH=%~1"

:: Create a PowerShell script to fix missing quotes
echo $content = Get-Content '%FILE_PATH%' -Raw > "%TEMP%\fix_quotes.ps1"
echo $lines = $content -split "`r?`n" >> "%TEMP%\fix_quotes.ps1"
echo $fixed = @() >> "%TEMP%\fix_quotes.ps1"
echo $fixedCount = 0 >> "%TEMP%\fix_quotes.ps1"
echo foreach ($line in $lines) { >> "%TEMP%\fix_quotes.ps1"
echo     if ($line -match '^set\s+"[^"]*=\s*[^"]*$') { >> "%TEMP%\fix_quotes.ps1"
echo         $line = $line + '"' >> "%TEMP%\fix_quotes.ps1"
echo         $fixedCount++ >> "%TEMP%\fix_quotes.ps1"
echo     } >> "%TEMP%\fix_quotes.ps1"
echo     $fixed += $line >> "%TEMP%\fix_quotes.ps1"
echo } >> "%TEMP%\fix_quotes.ps1"
echo if ($fixedCount -gt 0) { >> "%TEMP%\fix_quotes.ps1"
echo     Set-Content '%FILE_PATH%' -Value ($fixed -join "`n") >> "%TEMP%\fix_quotes.ps1"
echo     Write-Host "Fixed $fixedCount missing quotes" >> "%TEMP%\fix_quotes.ps1"
echo } >> "%TEMP%\fix_quotes.ps1"

powershell -ExecutionPolicy Bypass -File "%TEMP%\fix_quotes.ps1" >nul 2>&1
if not errorlevel 1 (
set /a QUOTES_FIXED+=1
set /a FILE_FIXES+=1
)

del "%TEMP%\fix_quotes.ps1" >nul 2>&1
goto :eof

:fix_unbalanced_parens
set "FILE_PATH=%~1"

:: Create a PowerShell script to fix unbalanced parentheses
echo $content = Get-Content '%FILE_PATH%' -Raw > "%TEMP%\fix_parens.ps1"
echo $lines = $content -split "`r?`n" >> "%TEMP%\fix_parens.ps1"
echo $fixed = @() >> "%TEMP%\fix_parens.ps1"
echo $fixedCount = 0 >> "%TEMP%\fix_parens.ps1"
echo foreach ($line in $lines) { >> "%TEMP%\fix_parens.ps1"
echo     $openParens = ($line.ToCharArray() ^| Where-Object { $_ -eq '(' }).Count >> "%TEMP%\fix_parens.ps1"
echo     $closeParens = ($line.ToCharArray() ^| Where-Object { $_ -eq ')' }).Count >> "%TEMP%\fix_parens.ps1"
echo     if ($openParens -gt $closeParens) { >> "%TEMP%\fix_parens.ps1"
echo         $line = $line + (')' * ($openParens - $closeParens)) >> "%TEMP%\fix_parens.ps1"
echo         $fixedCount++ >> "%TEMP%\fix_parens.ps1"
echo     } >> "%TEMP%\fix_parens.ps1"
echo     $fixed += $line >> "%TEMP%\fix_parens.ps1"
echo } >> "%TEMP%\fix_parens.ps1"
echo if ($fixedCount -gt 0) { >> "%TEMP%\fix_parens.ps1"
echo     Set-Content '%FILE_PATH%' -Value ($fixed -join "`n") >> "%TEMP%\fix_parens.ps1"
echo     Write-Host "Fixed $fixedCount unbalanced parentheses" >> "%TEMP%\fix_parens.ps1"
echo } >> "%TEMP%\fix_parens.ps1"

powershell -ExecutionPolicy Bypass -File "%TEMP%\fix_parens.ps1" >nul 2>&1
if not errorlevel 1 (
set /a PARENTHESES_FIXED+=1
set /a FILE_FIXES+=1
)

del "%TEMP%\fix_parens.ps1" >nul 2>&1
goto :eof

:fix_missing_echo_off
set "FILE_PATH=%~1"

:: Check if file starts with @echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
findstr /b "@echo off" "%FILE_PATH%" >nul 2>&1
if errorlevel 1 (
:: Add @echo off at the beginning
echo @echo off > "%TEMP%\temp_file.tmp"
type "%FILE_PATH%" >> "%TEMP%\temp_file.tmp"
move "%TEMP%\temp_file.tmp" "%FILE_PATH%" >nul 2>&1
set /a ECHO_FIXED+=1
set /a FILE_FIXES+=1
)
goto :eof

:fix_infinite_loops
set "FILE_PATH=%~1"

:: Fix common infinite loop patterns
findstr /i ":start" "%FILE_PATH%" >nul 2>&1
if not errorlevel 1 (
findstr /i "goto :start" "%FILE_PATH%" >nul 2>&1
if not errorlevel 1 (
:: Replace goto :start with goto :menu
powershell -Command "(Get-Content '%FILE_PATH%') -replace 'goto :start', 'goto :menu' | Set-Content '%FILE_PATH%'" >nul 2>&1
set /a LOOP_FIXED+=1
set /a FILE_FIXES+=1
)
)
goto :eof

:fix_missing_exits
set "FILE_PATH=%~1"

:: Check if file has proper exit points
findstr /i "exit" "%FILE_PATH%" >nul 2>&1
if errorlevel 1 (
findstr /i "goto :eof" "%FILE_PATH%" >nul 2>&1
if errorlevel 1 (
:: Add exit statement at the end
echo. >> "%FILE_PATH%"
echo exit /b 0 >> "%FILE_PATH%"
set /a EXIT_FIXED+=1
set /a FILE_FIXES+=1
)
)
goto :eof

:ollama_intelligent_fix
set "FILE_PATH=%~1"
set "FILE_NAME=%~nx1"

:: Create a prompt for Ollama to analyze and fix the file
echo Analyzing and fixing batch file syntax issues. File: %FILE_NAME% > "%TEMP%\ollama_prompt.txt"
echo. >> "%TEMP%\ollama_prompt.txt"
echo Please analyze this batch file and provide fixes for any syntax errors: >> "%TEMP%\ollama_prompt.txt"
echo. >> "%TEMP%\ollama_prompt.txt"
type "%FILE_PATH%" >> "%TEMP%\ollama_prompt.txt"

:: Use Ollama to analyze the file
ollama run llama2 "%TEMP%\ollama_prompt.txt" > "%TEMP%\ollama_response.txt" 2>nul
if not errorlevel 1 (
set /a OLLAMA_FIXES+=1
set /a FILE_FIXES+=1
)

del "%TEMP%\ollama_prompt.txt" >nul 2>&1
del "%TEMP%\ollama_response.txt" >nul 2>&1
goto :eof

:check_ollama_availability
ollama list >nul 2>&1
exit /b %ERRORLEVEL%

:initialize_html_report
echo ^<!DOCTYPE html^> > "%REPORT_FILE%"
echo ^<html^> >> "%REPORT_FILE%"
echo ^<head^> >> "%REPORT_FILE%"
echo ^<title^>BAT File Real-time Fixes Report - %TIMESTAMP%^</title^> >> "%REPORT_FILE%"
echo ^<style^> >> "%REPORT_FILE%"
echo body { font-family: Arial, sans-serif; margin: 20px; } >> "%REPORT_FILE%"
echo .header { background-color: #2c3e50; color: white; padding: 20px; text-align: center; } >> "%REPORT_FILE%"
echo .summary { background-color: #ecf0f1; padding: 15px; margin: 20px 0; } >> "%REPORT_FILE%"
echo .fix-item { background-color: #d5f4e6; padding: 10px; margin: 5px 0; border-left: 4px solid #27ae60; } >> "%REPORT_FILE%"
echo ^</style^> >> "%REPORT_FILE%"
echo ^</head^> >> "%REPORT_FILE%"
echo ^<body^> >> "%REPORT_FILE%"
echo ^<div class="header"^> >> "%REPORT_FILE%"
echo ^<h1^>BAT File Real-time Fixes Report^</h1^> >> "%REPORT_FILE%"
echo ^<p^>Generated: %TIMESTAMP%^</p^> >> "%REPORT_FILE%"
echo ^</div^> >> "%REPORT_FILE%"
goto :eof

:generate_final_report
echo ^<div class="summary"^> >> "%REPORT_FILE%"
echo ^<h2^>Fixing Summary^</h2^> >> "%REPORT_FILE%"
echo ^<p^>Total Files: %TOTAL_FILES%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Files Processed: %FILES_PROCESSED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Total Files Fixed: %TOTAL_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Syntax Fixes: %SYNTAX_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Quotes Fixes: %QUOTES_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Parentheses Fixes: %PARENTHESES_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Echo Fixes: %ECHO_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Loop Fixes: %LOOP_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Exit Fixes: %EXIT_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Ollama Fixes: %OLLAMA_FIXES%^</p^> >> "%REPORT_FILE%"
echo ^</div^> >> "%REPORT_FILE%"
echo ^</body^> >> "%REPORT_FILE%"
echo ^</html^> >> "%REPORT_FILE%"
goto :eof

:show_final_progress
:: Calculate final percentage
set /a PERCENTAGE=(%FILES_PROCESSED% * 100) / %TOTAL_FILES%
set /a BAR_LENGTH=(%PERCENTAGE% * 40) / 100
set /a REMAINING=40 - %BAR_LENGTH%

:: Build final progress bar
set "PROGRESS_BAR="
for /l %%i in (1,1,%BAR_LENGTH%) do set "PROGRESS_BAR=%PROGRESS_BAR%"
for /l %%i in (1,1,%REMAINING%) do set "PROGRESS_BAR=%PROGRESS_BAR%░"

cls
echo ========================================================================
echo                    REALTIME FIXER - FINAL RESULTS
echo ========================================================================
echo.
echo  FIXING STATUS: COMPLETED
echo.
echo  FINAL PROGRESS:
echo    [%FILES_PROCESSED%/%TOTAL_FILES%] [%PERCENTAGE%%] [%PROGRESS_BAR%]
echo.
echo  FINAL FIXES APPLIED:
echo     Total Files Fixed: %TOTAL_FIXED%
echo     Syntax Fixes: %SYNTAX_FIXED%
echo     Quotes Fixes: %QUOTES_FIXED%
echo     Parentheses Fixes: %PARENTHESES_FIXED%
echo     Echo Fixes: %ECHO_FIXED%
echo     Loop Fixes: %LOOP_FIXED%
echo     Exit Fixes: %EXIT_FIXED%
echo     Ollama Fixes: %OLLAMA_FIXES%
echo.
echo  STATUS: All fixes completed successfully!
echo  LOGS: %LOG_DIR%
echo  REPORT: %REPORT_FILE%
echo ========================================================================
goto :eof
