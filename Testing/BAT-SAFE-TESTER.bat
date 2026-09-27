@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion

:: ========================================================================
::                        BAT FILE SAFE TESTER
::                 Safe Execution Testing with Timeout Protection
:: ========================================================================

echo ========================================================================
echo                        BAT FILE SAFE TESTER
echo                 Safe Execution Testing with Timeout Protection
echo ========================================================================
echo.
echo [STATUS] Initializing BAT File Safe Tester...
echo [INFO] This tool safely tests BAT files with timeout protection
echo [INFO] Each file will be tested with a 30-second timeout
echo [WARNING] Files requiring user input will be skipped
echo.

:: Set up paths
set "TESTER_DIR=%~dp0"
set "RESULTS_DIR=%TESTER_DIR%Results"
set "LOG_DIR=%RESULTS_DIR%\logs"
set "REPORT_FILE=%RESULTS_DIR%\test-results.html"
set "TEMP_DIR=%TEMP%\BAT_SAFE_TESTER_%RANDOM%"

:: Create temp directory
mkdir "%TEMP_DIR%" 2>nul

:: Initialize counters
set /a TOTAL_FILES=0
set /a PASS_FILES=0
set /a FAIL_FILES=0
set /a TIMEOUT_FILES=0
set /a SKIPPED_FILES=0

:: Get current timestamp
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "TIMESTAMP=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

echo [STATUS] Starting safe execution testing...
echo [TIMESTAMP] %TIMESTAMP%
echo.

:: Initialize HTML report
echo ^<!DOCTYPE html^> > "%REPORT_FILE%"
echo ^<html^> >> "%REPORT_FILE%"
echo ^<head^> >> "%REPORT_FILE%"
echo ^<title^>BAT File Safe Test Results - %TIMESTAMP%^</title^> >> "%REPORT_FILE%"
echo ^<style^> >> "%REPORT_FILE%"
echo body { font-family: Arial, sans-serif; margin: 20px; } >> "%REPORT_FILE%"
echo .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; } >> "%REPORT_FILE%"
echo .summary { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; } >> "%REPORT_FILE%"
echo .pass { color: #27ae60; font-weight: bold; } >> "%REPORT_FILE%"
echo .fail { color: #e74c3c; font-weight: bold; } >> "%REPORT_FILE%"
echo .timeout { color: #e67e22; font-weight: bold; } >> "%REPORT_FILE%"
echo .skip { color: #95a5a6; font-weight: bold; } >> "%REPORT_FILE%"
echo table { border-collapse: collapse; width: 100%%; margin: 20px 0; } >> "%REPORT_FILE%"
echo th, td { border: 1px solid #ddd; padding: 8px; text-align: left; } >> "%REPORT_FILE%"
echo th { background-color: #34495e; color: white; } >> "%REPORT_FILE%"
echo .log-link { color: #3498db; text-decoration: none; } >> "%REPORT_FILE%"
echo .log-link:hover { text-decoration: underline; } >> "%REPORT_FILE%"
echo ^</style^> >> "%REPORT_FILE%"
echo ^</head^> >> "%REPORT_FILE%"
echo ^<body^> >> "%REPORT_FILE%"
echo ^<div class="header"^> >> "%REPORT_FILE%"
echo ^<h1^>BAT File Safe Test Results^</h1^> >> "%REPORT_FILE%"
echo ^<p^>Generated: %TIMESTAMP%^</p^> >> "%REPORT_FILE%"
echo ^</div^> >> "%REPORT_FILE%"

:: Function to test a single BAT file safely
call :test_bat_file_safely

:: Find all BAT files in the current directory and subdirectories
echo [INFO] Scanning for BAT files to test...
for /r %%f in (*.bat) do (
set /a TOTAL_FILES+=1
set "BAT_FILE=%%f"
call :test_single_file "%%f"
)

:: Generate summary
echo.
echo ========================================================================
echo                        TEST EXECUTION SUMMARY
echo ========================================================================
echo [TOTAL FILES] %TOTAL_FILES%
echo [PASS FILES] %PASS_FILES% ^(SUCCESS^)
echo [FAIL FILES] %FAIL_FILES% ^(FAILED^)
echo [TIMEOUT FILES] %TIMEOUT_FILES% ^(TIMEOUT^)
echo [SKIPPED FILES] %SKIPPED_FILES% ^(SKIPPED^)
echo.

:: Calculate percentages
set /a PASS_PERCENT=(%PASS_FILES% * 100) / %TOTAL_FILES%
set /a FAIL_PERCENT=(%FAIL_FILES% * 100) / %TOTAL_FILES%
set /a TIMEOUT_PERCENT=(%TIMEOUT_FILES% * 100) / %TOTAL_FILES%

echo [PERCENTAGES] PASS: %PASS_PERCENT%%% | FAIL: %FAIL_PERCENT%%% | TIMEOUT: %TIMEOUT_PERCENT%%%
echo.

:: Complete HTML report
echo ^<div class="summary"^> >> "%REPORT_FILE%"
echo ^<h2^>Test Execution Summary^</h2^> >> "%REPORT_FILE%"
echo ^<p^>Total Files: %TOTAL_FILES%^</p^> >> "%REPORT_FILE%"
echo ^<p^>Passed: ^<span class="pass"^>%PASS_FILES% (%PASS_PERCENT%%%)^</span^>^</p^> >> "%REPORT_FILE%"
echo ^<p^>Failed: ^<span class="fail"^>%FAIL_FILES% (%FAIL_PERCENT%%%)^</span^>^</p^> >> "%REPORT_FILE%"
echo ^<p^>Timeout: ^<span class="timeout"^>%TIMEOUT_FILES% (%TIMEOUT_PERCENT%%%)^</span^>^</p^> >> "%REPORT_FILE%"
echo ^<p^>Skipped: ^<span class="skip"^>%SKIPPED_FILES%^</span^>^</p^> >> "%REPORT_FILE%"
echo ^</div^> >> "%REPORT_FILE%"

echo ^<h2^>Detailed Test Results^</h2^> >> "%REPORT_FILE%"
echo ^<table^> >> "%REPORT_FILE%"
echo ^<tr^>^<th^>File^</th^>^<th^>Status^</th^>^<th^>Exit Code^</th^>^<th^>Duration^</th^>^<th^>Log^</th^>^</tr^> >> "%REPORT_FILE%"

:: Add detailed results to HTML
if exist "%TEMP_DIR%\test_results.txt" (
for /f "tokens=1,2,3,4,5 delims=|" %%a in (%TEMP_DIR%\test_results.txt) do (
echo ^<tr^>^<td^>%%a^</td^>^<td^>%%b^</td^>^<td^>%%c^</td^>^<td^>%%d^</td^>^<td^>^<a href="logs/%%e" class="log-link"^>View Log^</a^>^</td^>^</tr^> >> "%REPORT_FILE%"
)
)

echo ^</table^> >> "%REPORT_FILE%"
echo ^</body^> >> "%REPORT_FILE%"
echo ^</html^> >> "%REPORT_FILE%"

echo [SUCCESS] Safe testing completed!
echo [REPORT] HTML report saved to: %REPORT_FILE%
echo.

:: Clean up temp directory
rmdir /s /q "%TEMP_DIR%" 2>nul

echo Press any key to open the test results report...
pause >nul
start "" "%REPORT_FILE%"

exit /b 0

:: ========================================================================
::                        TESTING FUNCTIONS
:: ========================================================================

:test_bat_file_safely
echo [INFO] Safe Tester initialized
echo [INFO] Test criteria:
echo        - 30-second timeout per file
echo        - Capture exit codes and output
echo        - Skip files requiring user input
echo        - Skip files requiring admin privileges
echo        - Generate individual log files
echo.
goto :eof

:test_single_file
set "FILE_PATH=%~1"
set "FILE_NAME=%~nx1"
set "FILE_DIR=%~dp1"
set "LOG_FILE=%LOG_DIR%\%FILE_NAME%_%TIMESTAMP%.log"

echo [TEST] Testing: %FILE_NAME%

:: Initialize variables
set "STATUS=SKIP"
set "EXIT_CODE=N/A"
set "DURATION=0"
set "START_TIME=%TIME%"

:: Check if file exists
if not exist "%FILE_PATH%" (
set "STATUS=FAIL"
set "EXIT_CODE=404"
goto :record_test_result
)

:: Check if file should be skipped
call :should_skip_test "%FILE_PATH%"
if errorlevel 1 (
set "STATUS=SKIP"
set "EXIT_CODE=SKIP"
goto :record_test_result
)

:: Create test script with timeout protection
call :create_test_script "%FILE_PATH%" "%TEMP_DIR%\test_%FILE_NAME%.bat"

:: Execute test with timeout
call :execute_with_timeout "%TEMP_DIR%\test_%FILE_NAME%.bat" "%LOG_FILE%"
set "EXIT_CODE=%ERRORLEVEL%"

:: Calculate duration
call :calculate_duration "%START_TIME%" "%TIME%"
set "DURATION=%DURATION%"

:: Determine status based on exit code
if %EXIT_CODE%==0 (
set "STATUS=PASS"
) else if %EXIT_CODE%==124 (
set "STATUS=TIMEOUT"
set "EXIT_CODE=TIMEOUT"
) else (
set "STATUS=FAIL"
)

:record_test_result
:: Update counters
if "!STATUS!"=="PASS" set /a PASS_FILES+=1
if "!STATUS!"=="FAIL" set /a FAIL_FILES+=1
if "!STATUS!"=="TIMEOUT" set /a TIMEOUT_FILES+=1
if "!STATUS!"=="SKIP" set /a SKIPPED_FILES+=1

:: Record test result
echo !FILE_NAME!^|!STATUS!^|!EXIT_CODE!^|!DURATION!^|%FILE_NAME%_%TIMESTAMP%.log >> "%TEMP_DIR%\test_results.txt"

:: Display result
echo [RESULT] !STATUS!: %FILE_NAME% - Exit Code: !EXIT_CODE! - Duration: !DURATION!

goto :eof

:should_skip_test
set "FILE_PATH=%~1"

:: Skip files that likely require user input
findstr /i "pause\|set /p\|choice\|echo.*press.*key" "%FILE_PATH%" >nul 2>&1
if not errorlevel 1 exit /b 1

:: Skip files that require admin privileges (if not running as admin)
echo %FILE_PATH% | findstr /i "admin\|elevate\|runas" >nul
if not errorlevel 1 (
net session >nul 2>&1
if errorlevel 1 exit /b 1
)

:: Skip files that are likely destructive
findstr /i "del\|rmdir\|format\|diskpart\|reg.*delete" "%FILE_PATH%" >nul 2>&1
if not errorlevel 1 exit /b 1

:: Skip test files themselves
echo %FILE_PATH% | findstr /i "test\|validator" >nul
if not errorlevel 1 exit /b 1

exit /b 0

:create_test_script
set "ORIGINAL_FILE=%~1"
set "TEST_SCRIPT=%~2"

:: Create a safe test wrapper
echo @echo off > "%TEST_SCRIPT%"
echo echo [TEST] Starting test execution... >> "%TEST_SCRIPT%"
echo echo [TEST] File: %~nx1 >> "%TEST_SCRIPT%"
echo echo [TEST] Timestamp: %TIMESTAMP% >> "%TEST_SCRIPT%"
echo echo. >> "%TEST_SCRIPT%"

:: Add dry-run parameter if the script supports it
findstr /i "dry.*run\|test.*mode\|validate" "%ORIGINAL_FILE%" >nul 2>&1
if not errorlevel 1 (
echo call "%ORIGINAL_FILE%" /dry-run /test /validate 2^>^&1 >> "%TEST_SCRIPT%"
) else (
echo call "%ORIGINAL_FILE%" 2^>^&1 >> "%TEST_SCRIPT%"
)

echo echo. >> "%TEST_SCRIPT%"
echo echo [TEST] Test execution completed with exit code: %%ERRORLEVEL%% >> "%TEST_SCRIPT%"
echo exit /b %%ERRORLEVEL%% >> "%TEST_SCRIPT%"

goto :eof

:execute_with_timeout
set "TEST_SCRIPT=%~1"
set "LOG_FILE=%~2"

:: Create log file
echo [TEST LOG] %TIMESTAMP% > "%LOG_FILE%"
echo [FILE] %TEST_SCRIPT% >> "%LOG_FILE%"
echo [COMMAND] timeout 30 "%TEST_SCRIPT%" >> "%LOG_FILE%"
echo ======================================================================== >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

:: Execute with timeout using PowerShell
powershell -Command "& { $process = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', '%TEST_SCRIPT%' -RedirectStandardOutput '%LOG_FILE%' -RedirectStandardError '%LOG_FILE%' -PassThru -WindowStyle Hidden; $timeout = 30000; $process.WaitForExit($timeout); if (!$process.HasExited) { $process.Kill(); exit 124 } else { exit $process.ExitCode } }"

set "EXIT_CODE=%ERRORLEVEL%"

echo ======================================================================== >> "%LOG_FILE%"
echo [TEST COMPLETED] Exit Code: %EXIT_CODE% >> "%LOG_FILE%"
echo [END TIME] %TIME% >> "%LOG_FILE%"

goto :eof

:calculate_duration
set "START=%~1"
set "END=%~2"

:: Simple duration calculation (not perfect but gives an estimate)
set "DURATION=~1s"

goto :eof
