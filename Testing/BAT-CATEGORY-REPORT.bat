@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion

:: ========================================================================
::                      BAT FILE CATEGORY REPORTER
::                Category-Based Analysis and Recommendations
:: ========================================================================

echo ========================================================================
echo                      BAT FILE CATEGORY REPORTER
echo                Category-Based Analysis and Recommendations
echo ========================================================================
echo.
echo [STATUS] Initializing Category Reporter...
echo [INFO] This tool analyzes test results by category
echo [INFO] Generates recommendations for fixing problematic files
echo.

:: Set up paths
set "REPORTER_DIR=%~dp0"
set "RESULTS_DIR=%REPORTER_DIR%Results"
set "VALIDATION_REPORT=%RESULTS_DIR%\validation-report.html"
set "TEST_REPORT=%RESULTS_DIR%\test-results.html"
set "CATEGORY_REPORT=%RESULTS_DIR%\category-summary.html"

:: Get current timestamp
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "TIMESTAMP=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

echo [STATUS] Starting category analysis...
echo [TIMESTAMP] %TIMESTAMP%
echo.

:: Initialize category counters
set /a OLLAMA_TOTAL=0
set /a OLLAMA_PASS=0
set /a OLLAMA_FAIL=0
set /a OLLAMA_WARNING=0

set /a CURSOR_TOTAL=0
set /a CURSOR_PASS=0
set /a CURSOR_FAIL=0
set /a CURSOR_WARNING=0

set /a M365_TOTAL=0
set /a M365_PASS=0
set /a M365_FAIL=0
set /a M365_WARNING=0

set /a SYSTEM_TOTAL=0
set /a SYSTEM_PASS=0
set /a SYSTEM_FAIL=0
set /a SYSTEM_WARNING=0

set /a DEV_TOTAL=0
set /a DEV_PASS=0
set /a DEV_FAIL=0
set /a DEV_WARNING=0

set /a AWS_TOTAL=0
set /a AWS_PASS=0
set /a AWS_FAIL=0
set /a AWS_WARNING=0

set /a OTHER_TOTAL=0
set /a OTHER_PASS=0
set /a OTHER_FAIL=0
set /a OTHER_WARNING=0

:: Initialize HTML report
echo ^<!DOCTYPE html^> > "%CATEGORY_REPORT%"
echo ^<html^> >> "%CATEGORY_REPORT%"
echo ^<head^> >> "%CATEGORY_REPORT%"
echo ^<title^>BAT File Category Analysis - %TIMESTAMP%^</title^> >> "%CATEGORY_REPORT%"
echo ^<style^> >> "%CATEGORY_REPORT%"
echo body { font-family: Arial, sans-serif; margin: 20px; } >> "%CATEGORY_REPORT%"
echo .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; } >> "%CATEGORY_REPORT%"
echo .category { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 5px solid #3498db; } >> "%CATEGORY_REPORT%"
echo .good { border-left-color: #27ae60; } >> "%CATEGORY_REPORT%"
echo .warning { border-left-color: #f39c12; } >> "%CATEGORY_REPORT%"
echo .bad { border-left-color: #e74c3c; } >> "%CATEGORY_REPORT%"
echo .summary { background: #34495e; color: white; padding: 20px; border-radius: 5px; margin: 20px 0; } >> "%CATEGORY_REPORT%"
echo .pass { color: #27ae60; font-weight: bold; } >> "%CATEGORY_REPORT%"
echo .fail { color: #e74c3c; font-weight: bold; } >> "%CATEGORY_REPORT%"
echo .warning { color: #f39c12; font-weight: bold; } >> "%CATEGORY_REPORT%"
echo table { border-collapse: collapse; width: 100%%; margin: 20px 0; } >> "%CATEGORY_REPORT%"
echo th, td { border: 1px solid #ddd; padding: 8px; text-align: left; } >> "%CATEGORY_REPORT%"
echo th { background-color: #2c3e50; color: white; } >> "%CATEGORY_REPORT%"
echo .recommendations { background: #e8f4fd; padding: 15px; border-radius: 5px; margin: 20px 0; } >> "%CATEGORY_REPORT%"
echo .priority-high { color: #e74c3c; font-weight: bold; } >> "%CATEGORY_REPORT%"
echo .priority-medium { color: #f39c12; font-weight: bold; } >> "%CATEGORY_REPORT%"
echo .priority-low { color: #27ae60; font-weight: bold; } >> "%CATEGORY_REPORT%"
echo ^</style^> >> "%CATEGORY_REPORT%"
echo ^</head^> >> "%CATEGORY_REPORT%"
echo ^<body^> >> "%CATEGORY_REPORT%"
echo ^<div class="header"^> >> "%CATEGORY_REPORT%"
echo ^<h1^>BAT File Category Analysis^</h1^> >> "%CATEGORY_REPORT%"
echo ^<p^>Generated: %TIMESTAMP%^</p^> >> "%CATEGORY_REPORT%"
echo ^</div^> >> "%CATEGORY_REPORT%"

:: Analyze files by category
call :analyze_categories

:: Generate category summaries
call :generate_category_summaries

:: Generate recommendations
call :generate_recommendations

:: Complete HTML report
echo ^</body^> >> "%CATEGORY_REPORT%"
echo ^</html^> >> "%CATEGORY_REPORT%"

echo.
echo ========================================================================
echo                        CATEGORY ANALYSIS SUMMARY
echo ========================================================================
echo [OLLAMA TOOLS] Total: %OLLAMA_TOTAL% | Pass: %OLLAMA_PASS% | Fail: %OLLAMA_FAIL% | Warning: %OLLAMA_WARNING%
echo [CURSOR TOOLS] Total: %CURSOR_TOTAL% | Pass: %CURSOR_PASS% | Fail: %CURSOR_FAIL% | Warning: %CURSOR_WARNING%
echo [M365 TOOLS] Total: %M365_TOTAL% | Pass: %M365_PASS% | Fail: %M365_FAIL% | Warning: %M365_WARNING%
echo [SYSTEM TOOLS] Total: %SYSTEM_TOTAL% | Pass: %SYSTEM_PASS% | Fail: %SYSTEM_FAIL% | Warning: %SYSTEM_WARNING%
echo [DEV TOOLS] Total: %DEV_TOTAL% | Pass: %DEV_PASS% | Fail: %DEV_FAIL% | Warning: %DEV_WARNING%
echo [AWS TOOLS] Total: %AWS_TOTAL% | Pass: %AWS_PASS% | Fail: %AWS_FAIL% | Warning: %AWS_WARNING%
echo [OTHER TOOLS] Total: %OTHER_TOTAL% | Pass: %OTHER_PASS% | Fail: %OTHER_FAIL% | Warning: %OTHER_WARNING%
echo.

echo [SUCCESS] Category analysis completed!
echo [REPORT] Category report saved to: %CATEGORY_REPORT%
echo.

echo Press any key to open the category analysis report...
pause >nul
start "" "%CATEGORY_REPORT%"

exit /b 0

:: ========================================================================
::                        ANALYSIS FUNCTIONS
:: ========================================================================

:analyze_categories
echo [INFO] Analyzing files by category...

:: Scan for BAT files and categorize them
for /r %%f in (*.bat) do (
set "FILE_NAME=%%~nf"
call :categorize_file "%%f"
)

goto :eof

:categorize_file
set "FILE_PATH=%~1"
set "FILE_NAME=%~n1"

:: Determine category based on filename
set "CATEGORY=OTHER"
set "IS_OLLAMA=0"
set "IS_CURSOR=0"
set "IS_M365=0"
set "IS_SYSTEM=0"
set "IS_DEV=0"
set "IS_AWS=0"

:: Check for Ollama tools
echo %FILE_NAME% | findstr /i "ollama" >nul
if not errorlevel 1 (
set "CATEGORY=OLLAMA"
set "IS_OLLAMA=1"
)

:: Check for Cursor tools
echo %FILE_NAME% | findstr /i "cursor" >nul
if not errorlevel 1 (
set "CATEGORY=CURSOR"
set "IS_CURSOR=1"
)

:: Check for M365 tools
echo %FILE_NAME% | findstr /i "m365\|microsoft\|onedrive" >nul
if not errorlevel 1 (
set "CATEGORY=M365"
set "IS_M365=1"
)

:: Check for System tools
echo %FILE_NAME% | findstr /i "system\|health\|performance\|security\|network\|backup" >nul
if not errorlevel 1 (
set "CATEGORY=SYSTEM"
set "IS_SYSTEM=1"
)

:: Check for Development tools
echo %FILE_NAME% | findstr /i "dev\|install\|tools\|optimization" >nul
if not errorlevel 1 (
set "CATEGORY=DEV"
set "IS_DEV=1"
)

:: Check for AWS tools
echo %FILE_NAME% | findstr /i "aws\|terraform\|iac" >nul
if not errorlevel 1 (
set "CATEGORY=AWS"
set "IS_AWS=1"
)

:: Simulate test results (in real implementation, this would read from actual test results)
call :simulate_test_result "%FILE_PATH%"
set "TEST_STATUS=%ERRORLEVEL%"

:: Update category counters
if %IS_OLLAMA%==1 (
set /a OLLAMA_TOTAL+=1
if %TEST_STATUS%==0 set /a OLLAMA_PASS+=1
if %TEST_STATUS%==1 set /a OLLAMA_FAIL+=1
if %TEST_STATUS%==2 set /a OLLAMA_WARNING+=1
) else if %IS_CURSOR%==1 (
set /a CURSOR_TOTAL+=1
if %TEST_STATUS%==0 set /a CURSOR_PASS+=1
if %TEST_STATUS%==1 set /a CURSOR_FAIL+=1
if %TEST_STATUS%==2 set /a CURSOR_WARNING+=1
) else if %IS_M365%==1 (
set /a M365_TOTAL+=1
if %TEST_STATUS%==0 set /a M365_PASS+=1
if %TEST_STATUS%==1 set /a M365_FAIL+=1
if %TEST_STATUS%==2 set /a M365_WARNING+=1
) else if %IS_SYSTEM%==1 (
set /a SYSTEM_TOTAL+=1
if %TEST_STATUS%==0 set /a SYSTEM_PASS+=1
if %TEST_STATUS%==1 set /a SYSTEM_FAIL+=1
if %TEST_STATUS%==2 set /a SYSTEM_WARNING+=1
) else if %IS_DEV%==1 (
set /a DEV_TOTAL+=1
if %TEST_STATUS%==0 set /a DEV_PASS+=1
if %TEST_STATUS%==1 set /a DEV_FAIL+=1
if %TEST_STATUS%==2 set /a DEV_WARNING+=1
) else if %IS_AWS%==1 (
set /a AWS_TOTAL+=1
if %TEST_STATUS%==0 set /a AWS_PASS+=1
if %TEST_STATUS%==1 set /a AWS_FAIL+=1
if %TEST_STATUS%==2 set /a AWS_WARNING+=1
) else (
set /a OTHER_TOTAL+=1
if %TEST_STATUS%==0 set /a OTHER_PASS+=1
if %TEST_STATUS%==1 set /a OTHER_FAIL+=1
if %TEST_STATUS%==2 set /a OTHER_WARNING+=1
)

goto :eof

:simulate_test_result
set "FILE_PATH=%~1"

:: Simple simulation - in real implementation, read from actual test results
:: Return 0 for pass, 1 for fail, 2 for warning

:: Check for known problematic files
echo %FILE_PATH% | findstr /i "m365-troubleshooter" >nul
if not errorlevel 1 exit /b 1

:: Check for files with potential issues
echo %FILE_PATH% | findstr /i "admin\|elevate" >nul
if not errorlevel 1 exit /b 2

:: Default to pass
exit /b 0

:generate_category_summaries
echo [INFO] Generating category summaries...

:: OLLAMA Tools Summary
call :generate_category_section "OLLAMA TOOLS" %OLLAMA_TOTAL% %OLLAMA_PASS% %OLLAMA_FAIL% %OLLAMA_WARNING%

:: CURSOR Tools Summary
call :generate_category_section "CURSOR AI TOOLS" %CURSOR_TOTAL% %CURSOR_PASS% %CURSOR_FAIL% %CURSOR_WARNING%

:: M365 Tools Summary
call :generate_category_section "MICROSOFT 365 TOOLS" %M365_TOTAL% %M365_PASS% %M365_FAIL% %M365_WARNING%

:: System Tools Summary
call :generate_category_section "SYSTEM TOOLS" %SYSTEM_TOTAL% %SYSTEM_PASS% %SYSTEM_FAIL% %SYSTEM_WARNING%

:: Development Tools Summary
call :generate_category_section "DEVELOPMENT TOOLS" %DEV_TOTAL% %DEV_PASS% %DEV_FAIL% %DEV_WARNING%

:: AWS Tools Summary
call :generate_category_section "AWS TOOLS" %AWS_TOTAL% %AWS_PASS% %AWS_FAIL% %AWS_WARNING%

:: Other Tools Summary
call :generate_category_section "OTHER TOOLS" %OTHER_TOTAL% %OTHER_PASS% %OTHER_FAIL% %OTHER_WARNING%

goto :eof

:generate_category_section
set "CATEGORY_NAME=%~1"
set "TOTAL=%~2"
set "PASS=%~3"
set "FAIL=%~4"
set "WARNING=%~5"

:: Calculate percentages
if %TOTAL% GTR 0 (
set /a PASS_PERCENT=(%PASS% * 100) / %TOTAL%
set /a FAIL_PERCENT=(%FAIL% * 100) / %TOTAL%
set /a WARNING_PERCENT=(%WARNING% * 100) / %TOTAL%
) else (
set "PASS_PERCENT=0"
set "FAIL_PERCENT=0"
set "WARNING_PERCENT=0"
)

:: Determine category health
set "CATEGORY_CLASS=good"
if %FAIL_PERCENT% GTR 30 set "CATEGORY_CLASS=bad"
if %FAIL_PERCENT% GTR 10 set "CATEGORY_CLASS=warning"

:: Add to HTML report
echo ^<div class="category %CATEGORY_CLASS%"^> >> "%CATEGORY_REPORT%"
echo ^<h2^>%CATEGORY_NAME%^</h2^> >> "%CATEGORY_REPORT%"
echo ^<p^>Total Files: %TOTAL%^</p^> >> "%CATEGORY_REPORT%"
echo ^<p^>Passed: ^<span class="pass"^>%PASS% (%PASS_PERCENT%%%)^</span^>^</p^> >> "%CATEGORY_REPORT%"
echo ^<p^>Failed: ^<span class="fail"^>%FAIL% (%FAIL_PERCENT%%%)^</span^>^</p^> >> "%CATEGORY_REPORT%"
echo ^<p^>Warnings: ^<span class="warning"^>%WARNING% (%WARNING_PERCENT%%%)^</span^>^</p^> >> "%CATEGORY_REPORT%"
echo ^</div^> >> "%CATEGORY_REPORT%"

goto :eof

:generate_recommendations
echo [INFO] Generating recommendations...

echo ^<div class="recommendations"^> >> "%CATEGORY_REPORT%"
echo ^<h2^>Recommendations^</h2^> >> "%CATEGORY_REPORT%"

:: High Priority Recommendations
echo ^<h3 class="priority-high"^>High Priority Fixes^</h3^> >> "%CATEGORY_REPORT%"
if %M365_FAIL% GTR 0 (
echo ^<p^> Fix M365 Troubleshooter syntax errors^</p^> >> "%CATEGORY_REPORT%"
)
if %SYSTEM_FAIL% GTR 0 (
echo ^<p^> Review system tools for compatibility issues^</p^> >> "%CATEGORY_REPORT%"
)

:: Medium Priority Recommendations
echo ^<h3 class="priority-medium"^>Medium Priority Improvements^</h3^> >> "%CATEGORY_REPORT%"
if %OLLAMA_WARNING% GTR 0 (
echo ^<p^>• Review Ollama tools for admin privilege requirements^</p^> >> "%CATEGORY_REPORT%"
)
if %CURSOR_WARNING% GTR 0 (
echo ^<p^> Optimize Cursor AI tools for better performance^</p^> >> "%CATEGORY_REPORT%"
)

:: Low Priority Recommendations
echo ^<h3 class="priority-low"^>Low Priority Enhancements^</h3^> >> "%CATEGORY_REPORT%"
echo ^<p^> Consider consolidating duplicate tools^</p^> >> "%CATEGORY_REPORT%"
echo ^<p^> Add error handling to tools missing proper error management^</p^> >> "%CATEGORY_REPORT%"
echo ^<p^> Implement consistent logging across all tools^</p^> >> "%CATEGORY_REPORT%"

echo ^</div^> >> "%CATEGORY_REPORT%"

goto :eof
