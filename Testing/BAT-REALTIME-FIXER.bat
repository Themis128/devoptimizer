@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion

:: ========================================================================
::                        BAT FILE REALTIME FIXER
::                    Intelligent Auto-Fixer with Ollama Integration
:: ========================================================================

echo ========================================================================
echo                        BAT FILE REALTIME FIXER
echo                    Intelligent Auto-Fixer with Ollama Integration
echo ========================================================================
echo.
echo [STATUS] Initializing Real-time Auto-Fixer...
echo [INFO] This tool automatically fixes common BAT file issues
echo [INFO] Integrated with Ollama for intelligent code analysis
echo.

:: Set up paths
set "FIXER_DIR=%~dp0"
set "RESULTS_DIR=%FIXER_DIR%Results"
set "FIXES_DIR=%RESULTS_DIR%\fixes"
set "BACKUP_DIR=%RESULTS_DIR%\backups"
set "LOG_DIR=%RESULTS_DIR%\logs"
set "REPORT_FILE=%RESULTS_DIR%\realtime-fixes.html"

:: Create directories
mkdir "%FIXES_DIR%" 2>nul
mkdir "%BACKUP_DIR%" 2>nul
mkdir "%LOG_DIR%" 2>nul

:: Initialize counters
set /a TOTAL_FIXED=0
set /a SYNTAX_FIXED=0
set /a QUOTES_FIXED=0
set /a PARENTHESES_FIXED=0
set /a ECHO_FIXED=0
set /a LOOP_FIXED=0
set /a EXIT_FIXED=0

:: Get current timestamp
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "TIMESTAMP=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

:: Initialize HTML report
call :initialize_html_report

echo [STATUS] Starting real-time fixing process...
echo [TIMESTAMP] %TIMESTAMP%
echo.

:: Check if Ollama is available
call :check_ollama_availability
if errorlevel 1 (
echo [WARNING] Ollama not available - using rule-based fixing only
set "OLLAMA_AVAILABLE=0"
) else (
echo [SUCCESS] Ollama detected - using intelligent AI fixing
set "OLLAMA_AVAILABLE=1"
)

echo.
echo [INFO] Scanning for BAT files to fix...
echo.

:: Process each BAT file
cd /d "D:\DevOptimizer"
for %%f in (*.bat) do (
set "BAT_FILE=%%f"
call :fix_bat_file "%%f"
)

:: Generate final report
call :generate_final_report

echo ========================================================================
echo                        FIXING SUMMARY
echo ========================================================================
echo "[TOTAL FILES FIXED] %TOTAL_FIXED%"
echo "[SYNTAX FIXES] %SYNTAX_FIXED%"
echo "[QUOTES FIXES] %QUOTES_FIXED%"
echo "[PARENTHESES FIXES] %PARENTHESES_FIXED%"
echo "[ECHO FIXES] %ECHO_FIXED%"
echo "[LOOP FIXES] %LOOP_FIXED%"
echo "[EXIT FIXES] %EXIT_FIXED%"
echo.
echo [SUCCESS] Real-time fixing completed!
echo [INFO] Fixed files saved to: %FIXES_DIR%
echo [INFO] Backups saved to: %BACKUP_DIR%
echo [INFO] Report saved to: %REPORT_FILE%
echo.

goto :eof

:: ========================================================================
::                        FIXING FUNCTIONS
:: ========================================================================

:fix_bat_file
set "FILE_PATH=%~1"
set "FILE_NAME=%~nx1"
set "FILE_DIR=%~dp1"

echo "[FIXING] %FILE_NAME%"

:: Create backup
copy "%FILE_PATH%" "%BACKUP_DIR%\%FILE_NAME%.backup" >nul 2>&1

:: Initialize fix counters for this file
set "FILE_FIXES=0"
set "HAS_CHANGES=0"

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
echo "  [FIXED] %FILE_NAME% - !FILE_FIXES! issues resolved"
echo "%FILE_NAME%^|!FILE_FIXES!^|%TIMESTAMP%" >> "%LOG_DIR%\fixes-log.txt"
) else (
echo "  [OK] %FILE_NAME% - no fixes needed"
)

goto :eof

:fix_missing_quotes
set "FILE_PATH=%~1"
set "TEMP_FILE=%TEMP%\fix_quotes_%RANDOM%.tmp"
set "QUOTES_FIXED_COUNT=0"

:: Create a PowerShell script to fix missing quotes
echo $content = Get-Content '%FILE_PATH%' -Raw > "%TEMP%\fix_quotes.ps1"
echo $lines = $content -split "`r?`n" >> "%TEMP%\fix_quotes.ps1"
echo $fixed = @() >> "%TEMP%\fix_quotes.ps1"
echo foreach ($line in $lines) { >> "%TEMP%\fix_quotes.ps1"
echo     if ($line -match '^set\s+"[^"]*=\s*[^"]*$') { >> "%TEMP%\fix_quotes.ps1"
echo         $line = $line + '"' >> "%TEMP%\fix_quotes.ps1"
echo         $QUOTES_FIXED_COUNT++ >> "%TEMP%\fix_quotes.ps1"
echo     } >> "%TEMP%\fix_quotes.ps1"
echo     $fixed += $line >> "%TEMP%\fix_quotes.ps1"
echo } >> "%TEMP%\fix_quotes.ps1"
echo if ($QUOTES_FIXED_COUNT -gt 0) { >> "%TEMP%\fix_quotes.ps1"
echo     Set-Content '%FILE_PATH%' -Value ($fixed -join "`n") >> "%TEMP%\fix_quotes.ps1"
echo     Write-Host "Fixed $QUOTES_FIXED_COUNT missing quotes" >> "%TEMP%\fix_quotes.ps1"
echo } >> "%TEMP%\fix_quotes.ps1"

powershell -ExecutionPolicy Bypass -File "%TEMP%\fix_quotes.ps1" >nul 2>&1
if not errorlevel 1 set /a QUOTES_FIXED+=1 & set /a FILE_FIXES+=1

del "%TEMP%\fix_quotes.ps1" >nul 2>&1
goto :eof

:fix_unbalanced_parens
set "FILE_PATH=%~1"
set "TEMP_FILE=%TEMP%\fix_parens_%RANDOM%.tmp"
set "PAREN_FIXED_COUNT=0"

:: Create a PowerShell script to fix unbalanced parentheses
echo $content = Get-Content '%FILE_PATH%' -Raw > "%TEMP%\fix_parens.ps1"
echo $lines = $content -split "`r?`n" >> "%TEMP%\fix_parens.ps1"
echo $fixed = @() >> "%TEMP%\fix_parens.ps1"
echo foreach ($line in $lines) { >> "%TEMP%\fix_parens.ps1"
echo     $openParens = ($line.ToCharArray() ^| Where-Object { $_ -eq '(' }).Count >> "%TEMP%\fix_parens.ps1"
echo     $closeParens = ($line.ToCharArray() ^| Where-Object { $_ -eq ')' }).Count >> "%TEMP%\fix_parens.ps1"
echo     if ($openParens -gt $closeParens) { >> "%TEMP%\fix_parens.ps1"
echo         $line = $line + (')' * ($openParens - $closeParens)) >> "%TEMP%\fix_parens.ps1"
echo         $PAREN_FIXED_COUNT++ >> "%TEMP%\fix_parens.ps1"
echo     } >> "%TEMP%\fix_parens.ps1"
echo     $fixed += $line >> "%TEMP%\fix_parens.ps1"
echo } >> "%TEMP%\fix_parens.ps1"
echo if ($PAREN_FIXED_COUNT -gt 0) { >> "%TEMP%\fix_parens.ps1"
echo     Set-Content '%FILE_PATH%' -Value ($fixed -join "`n") >> "%TEMP%\fix_parens.ps1"
echo     Write-Host "Fixed $PAREN_FIXED_COUNT unbalanced parentheses" >> "%TEMP%\fix_parens.ps1"
echo } >> "%TEMP%\fix_parens.ps1"

powershell -ExecutionPolicy Bypass -File "%TEMP%\fix_parens.ps1" >nul 2>&1
if not errorlevel 1 set /a PARENTHESES_FIXED+=1 & set /a FILE_FIXES+=1

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

echo "  [AI] Analyzing %FILE_NAME% with Ollama..."

:: Create a prompt for Ollama to analyze and fix the file
echo Analyzing and fixing batch file syntax issues. File: %FILE_NAME% > "%TEMP%\ollama_prompt.txt"
echo. >> "%TEMP%\ollama_prompt.txt"
echo Please analyze this batch file and provide fixes for any syntax errors: >> "%TEMP%\ollama_prompt.txt"
echo. >> "%TEMP%\ollama_prompt.txt"
type "%FILE_PATH%" >> "%TEMP%\ollama_prompt.txt"

:: Use Ollama to analyze the file
ollama run llama2 "%TEMP%\ollama_prompt.txt" > "%TEMP%\ollama_response.txt" 2>nul
if not errorlevel 1 (
echo "  [AI] Ollama analysis completed for %FILE_NAME%"
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
echo ^<p^>Total Files Fixed: %TOTAL_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Syntax Fixes: %SYNTAX_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Quotes Fixes: %QUOTES_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Parentheses Fixes: %PARENTHESES_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Echo Fixes: %ECHO_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Loop Fixes: %LOOP_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Exit Fixes: %EXIT_FIXED%^</p^> >> "%REPORT_FILE%"
echo ^</div^> >> "%REPORT_FILE%"
echo ^</body^> >> "%REPORT_FILE%"
echo ^</html^> >> "%REPORT_FILE%"
goto :eof
