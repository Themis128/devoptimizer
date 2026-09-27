@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion

:: ========================================================================
::                        BAT FILE VALIDATOR
::                    Syntax Checker for All BAT Files
:: ========================================================================

echo ========================================================================
echo                        BAT FILE VALIDATOR
echo                    Syntax Checker for All BAT Files
echo ========================================================================
echo.
echo [STATUS] Initializing BAT File Validator...
echo [INFO] This tool performs READ-ONLY syntax validation
echo [INFO] No system changes will be made during validation
echo.

:: Set up paths
set "VALIDATOR_DIR=%~dp0"
set "RESULTS_DIR=%VALIDATOR_DIR%Results"
set "LOG_DIR=%RESULTS_DIR%\logs"
set "REPORT_FILE=%RESULTS_DIR%\validation-report.html"
set "TEMP_DIR=%TEMP%\BAT_VALIDATOR_%RANDOM%"

:: Create temp directory
mkdir "%TEMP_DIR%" 2>nul

:: Initialize counters
set /a TOTAL_FILES=0
set /a VALID_FILES=0
set /a INVALID_FILES=0
set /a WARNING_FILES=0
set /a SKIPPED_FILES=0

:: Get current timestamp
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "TIMESTAMP=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

echo [STATUS] Starting validation scan...
echo [TIMESTAMP] %TIMESTAMP%
echo.

:: Initialize HTML report
echo ^<!DOCTYPE html^> > "%REPORT_FILE%"
echo ^<html^> >> "%REPORT_FILE%"
echo ^<head^> >> "%REPORT_FILE%"
echo ^<title^>BAT File Validation Report - %TIMESTAMP%^</title^> >> "%REPORT_FILE%"
echo ^<style^> >> "%REPORT_FILE%"
echo body { font-family: Arial, sans-serif; margin: 20px; } >> "%REPORT_FILE%"
echo .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; } >> "%REPORT_FILE%"
echo .summary { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; } >> "%REPORT_FILE%"
echo .pass { color: #27ae60; font-weight: bold; } >> "%REPORT_FILE%"
echo .fail { color: #e74c3c; font-weight: bold; } >> "%REPORT_FILE%"
echo .warning { color: #f39c12; font-weight: bold; } >> "%REPORT_FILE%"
echo .skip { color: #95a5a6; font-weight: bold; } >> "%REPORT_FILE%"
echo table { border-collapse: collapse; width: 100%%; margin: 20px 0; } >> "%REPORT_FILE%"
echo th, td { border: 1px solid #ddd; padding: 8px; text-align: left; } >> "%REPORT_FILE%"
echo th { background-color: #34495e; color: white; } >> "%REPORT_FILE%"
echo .category { background-color: #3498db; color: white; font-weight: bold; } >> "%REPORT_FILE%"
echo ^</style^> >> "%REPORT_FILE%"
echo ^</head^> >> "%REPORT_FILE%"
echo ^<body^> >> "%REPORT_FILE%"
echo ^<div class="header"^> >> "%REPORT_FILE%"
echo ^<h1^>BAT File Validation Report^</h1^> >> "%REPORT_FILE%"
echo ^<p^>Generated: %TIMESTAMP%^</p^> >> "%REPORT_FILE%"
echo ^</div^> >> "%REPORT_FILE%"

:: Function to validate a single BAT file
call :validate_bat_file

:: Find all BAT files in the current directory and subdirectories
echo [INFO] Scanning for BAT files...
for /r %%f in (*.bat) do (
set /a TOTAL_FILES+=1
set "BAT_FILE=%%f"
call :validate_single_file "%%f"
)

:: Generate summary
echo.
echo ========================================================================
echo                         VALIDATION SUMMARY
echo ========================================================================
echo [TOTAL FILES] %TOTAL_FILES%
echo [VALID FILES] %VALID_FILES% ^(PASS^)
echo [INVALID FILES] %INVALID_FILES% ^(FAIL^)
echo [WARNING FILES] %WARNING_FILES% ^(WARNING^)
echo [SKIPPED FILES] %SKIPPED_FILES% ^(SKIP^)
echo.

:: Calculate percentages
set /a PASS_PERCENT=(%VALID_FILES% * 100) / %TOTAL_FILES%
set /a FAIL_PERCENT=(%INVALID_FILES% * 100) / %TOTAL_FILES%
set /a WARNING_PERCENT=(%WARNING_FILES% * 100) / %TOTAL_FILES%

echo [PERCENTAGES] PASS: %PASS_PERCENT%%% | FAIL: %FAIL_PERCENT%%% | WARNING: %WARNING_PERCENT%%%
echo.

:: Complete HTML report
echo ^<div class="summary"^> >> "%REPORT_FILE%"
echo ^<h2^>Validation Summary^</h2^> >> "%REPORT_FILE%"
echo ^<p^>Total Files: %TOTAL_FILES%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Valid Files: ^<span class="pass"^>%VALID_FILES% (%PASS_PERCENT%%%)^</span^>^</p^> >> "%REPORT_FILE%"
echo ^<p^>Invalid Files: ^<span class="fail"^>%INVALID_FILES% (%FAIL_PERCENT%%%)^</span^>^</p^> >> "%REPORT_FILE%"
echo ^<p^>Warning Files: ^<span class="warning"^>%WARNING_FILES% (%WARNING_PERCENT%%%)^</span^>^</p^> >> "%REPORT_FILE%"
echo ^<p^>Skipped Files: ^<span class="skip"^>%SKIPPED_FILES%^</span^>^</p^> >> "%REPORT_FILE%"
echo ^</div^> >> "%REPORT_FILE%"

echo ^<h2^>Detailed Results^</h2^> >> "%REPORT_FILE%"
echo ^<table^> >> "%REPORT_FILE%"
echo ^<tr^>^<th^>File^</th^>^<th^>Status^</th^>^<th^>Issues^</th^>^<th^>Size^</th^>^</tr^> >> "%REPORT_FILE%"

:: Add detailed results to HTML
if exist "%TEMP_DIR%\results.txt" (
for /f "tokens=1,2,3,4 delims=|" %%a in (%TEMP_DIR%\results.txt) do (
echo ^<tr^>^<td^>%%a^</td^>^<td^>%%b^</td^>^<td^>%%c^</td^>^<td^>%%d^</td^>^</tr^> >> "%REPORT_FILE%"
)
)

echo ^</table^> >> "%REPORT_FILE%"
echo ^</body^> >> "%REPORT_FILE%"
echo ^</html^> >> "%REPORT_FILE%"

echo [SUCCESS] Validation completed!
echo [REPORT] HTML report saved to: %REPORT_FILE%
echo.

:: Clean up temp directory
rmdir /s /q "%TEMP_DIR%" 2>nul

echo Press any key to open the validation report...
pause >nul
start "" "%REPORT_FILE%"

exit /b 0

:: ========================================================================
::                        VALIDATION FUNCTIONS
:: ========================================================================

:validate_bat_file
echo [INFO] BAT File Validator initialized
echo [INFO] Validation criteria:
echo        - File exists and is readable
echo        - Proper batch file structure
echo        - No obvious syntax errors
echo        - Valid labels and goto statements
echo        - No infinite loops detected
echo.
goto :eof

:validate_single_file
set "FILE_PATH=%~1"
set "FILE_NAME=%~nx1"
set "FILE_DIR=%~dp1"

echo [CHECK] Validating: %FILE_NAME%

:: Initialize variables
set "STATUS=PASS"
set "ISSUES="
set "FILE_SIZE=0"

:: Check if file exists and is readable
if not exist "%FILE_PATH%" (
set "STATUS=FAIL"
set "ISSUES=File not found"
goto :record_result
)

:: Get file size
for %%s in ("%FILE_PATH%") do set "FILE_SIZE=%%~zs"

:: Check if file is empty
if %FILE_SIZE%==0 (
set "STATUS=FAIL"
set "ISSUES=Empty file"
goto :record_result
)

:: Check for common syntax issues
call :check_syntax "%FILE_PATH%"
if errorlevel 1 (
set "STATUS=FAIL"
set "ISSUES=!ISSUES!Syntax error detected"
)

:: Check for infinite loops
call :check_infinite_loops "%FILE_PATH%"
if errorlevel 1 (
set "STATUS=WARNING"
set "ISSUES=!ISSUES!Possible infinite loop"
)

:: Check for missing exit points
call :check_exit_points "%FILE_PATH%"
if errorlevel 1 (
if "!STATUS!"=="PASS" set "STATUS=WARNING"
set "ISSUES=!ISSUES!No clear exit point"
)

:: Skip certain problematic files
call :should_skip_file "%FILE_NAME%"
if errorlevel 1 (
set "STATUS=SKIP"
set "ISSUES=Intentionally skipped"
)

:record_result
:: Update counters
if "!STATUS!"=="PASS" set /a VALID_FILES+=1
if "!STATUS!"=="FAIL" set /a INVALID_FILES+=1
if "!STATUS!"=="WARNING" set /a WARNING_FILES+=1
if "!STATUS!"=="SKIP" set /a SKIPPED_FILES+=1

:: Record result
echo !FILE_NAME!^|!STATUS!^|!ISSUES!^|!FILE_SIZE! >> "%TEMP_DIR%\results.txt"

:: Display result
echo [RESULT] !STATUS!: %FILE_NAME% - !ISSUES!

goto :eof

:check_syntax
set "FILE_PATH=%~1"
set "SYNTAX_ERROR=0"

:: Check for basic batch file structure
findstr /i "@echo off" "%FILE_PATH%" >nul 2>&1
if errorlevel 1 (
set "ISSUES=!ISSUES!Missing @echo off; "
set "SYNTAX_ERROR=1"
)

:: Check for invalid characters or encoding issues
findstr /r /c:"[^\x00-\x7F]" "%FILE_PATH%" >nul 2>&1
if not errorlevel 1 (
set "ISSUES=!ISSUES!Non-ASCII characters; "
set "SYNTAX_ERROR=1"
)

:: Check for unbalanced parentheses
call :count_balanced_parens "%FILE_PATH%"
if errorlevel 1 (
set "ISSUES=!ISSUES!Unbalanced parentheses; "
set "SYNTAX_ERROR=1"
)

exit /b %SYNTAX_ERROR%

:check_infinite_loops
set "FILE_PATH=%~1"
set "LOOP_ERROR=0"

:: Check for :start followed by goto :start pattern
findstr /i ":start" "%FILE_PATH%" >nul 2>&1
if not errorlevel 1 (
findstr /i "goto :start" "%FILE_PATH%" >nul 2>&1
if not errorlevel 1 (
set "LOOP_ERROR=1"
)
)

:: Check for other common infinite loop patterns
findstr /i "goto :eof" "%FILE_PATH%" >nul 2>&1
if errorlevel 1 (
findstr /i "exit" "%FILE_PATH%" >nul 2>&1
if errorlevel 1 (
set "LOOP_ERROR=1"
)
)

exit /b %LOOP_ERROR%

:check_exit_points
set "FILE_PATH=%~1"
set "EXIT_ERROR=0"

:: Check for exit statements
findstr /i "exit" "%FILE_PATH%" >nul 2>&1
if errorlevel 1 (
findstr /i "goto :eof" "%FILE_PATH%" >nul 2>&1
if errorlevel 1 (
set "EXIT_ERROR=1"
)
)

exit /b %EXIT_ERROR%

:should_skip_file
set "FILE_NAME=%~1"

:: Skip certain types of files
echo %FILE_NAME% | findstr /i "test\|temp\|backup\|old\|copy" >nul
if not errorlevel 1 exit /b 1

:: Skip very large files (over 1MB)
if %FILE_SIZE% GTR 1048576 exit /b 1

exit /b 0

:count_balanced_parens
set "FILE_PATH=%~1"
set "PAREN_COUNT=0"

:: Simple check for balanced parentheses (not perfect but catches obvious issues)
for /f "delims=" %%i in ('findstr /r "(" "%FILE_PATH%" 2^>nul') do (
echo %%i | findstr /c:"(" >nul
if not errorlevel 1 set /a PAREN_COUNT+=1
)

for /f "delims=" %%i in ('findstr /r ")" "%FILE_PATH%" 2^>nul') do (
echo %%i | findstr /c:")" >nul
if not errorlevel 1 set /a PAREN_COUNT-=1
)

if %PAREN_COUNT% neq 0 exit /b 1
exit /b 0
