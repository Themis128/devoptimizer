@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion

:: ========================================================================
::                        MASTER BAT TEST ORCHESTRATOR
::                    Comprehensive Testing Suite Controller
:: ========================================================================

echo ========================================================================
echo                        MASTER BAT TEST ORCHESTRATOR
echo                    Comprehensive Testing Suite Controller
echo ========================================================================
echo.
echo [STATUS] Initializing Master Test Orchestrator...
echo [INFO] This tool coordinates all testing phases
echo [INFO] Phase 1: Syntax Validation
echo [INFO] Phase 2: Safe Execution Testing
echo [INFO] Phase 3: Category-Based Analysis
echo.

:: Set up paths
set "TESTING_DIR=%~dp0"
set "RESULTS_DIR=%TESTING_DIR%Results"
set "VALIDATOR=%TESTING_DIR%BAT-VALIDATOR.bat"
set "SAFE_TESTER=%TESTING_DIR%BAT-SAFE-TESTER.bat"
set "CATEGORY_REPORTER=%TESTING_DIR%BAT-CATEGORY-REPORT.bat"

:: Get current timestamp
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "TIMESTAMP=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

:: Initialize master log
set "MASTER_LOG=%RESULTS_DIR%\master-test-log_%TIMESTAMP%.txt"
echo [MASTER TEST LOG] %TIMESTAMP% > "%MASTER_LOG%"
echo [INITIATED BY] Master Test Orchestrator >> "%MASTER_LOG%"
echo ======================================================================== >> "%MASTER_LOG%"
echo. >> "%MASTER_LOG%"

:: Check if testing tools exist
call :check_testing_tools
if errorlevel 1 (
echo [ERROR] Required testing tools not found!
echo [ERROR] Please ensure all testing scripts are in the Testing directory
echo [ERROR] Logged to: %MASTER_LOG%
pause
exit /b 1
)

:: Display menu
:main_menu
cls
echo ========================================================================
echo                        MASTER BAT TEST ORCHESTRATOR
echo                    Comprehensive Testing Suite Controller
echo ========================================================================
echo.
echo [TIMESTAMP] %TIMESTAMP%
echo [LOG FILE] %MASTER_LOG%
echo.
echo ========================================================================
echo                           TESTING OPTIONS
echo ========================================================================
echo [1] Run Complete Test Suite (All Phases)
echo [2] Phase 1: Syntax Validation Only
echo [3] Phase 2: Safe Execution Testing Only
echo [4] Phase 3: Category Analysis Only
echo [5] View Previous Test Results
echo [6] Generate Summary Report
echo [0] Exit
echo.
echo ========================================================================
set /p choice="Enter your choice (0-6): "

if "%choice%"=="1" goto run_complete_suite
if "%choice%"=="2" goto run_syntax_validation
if "%choice%"=="3" goto run_safe_testing
if "%choice%"=="4" goto run_category_analysis
if "%choice%"=="5" goto view_results
if "%choice%"=="6" goto generate_summary
if "%choice%"=="0" goto exit_program
echo [ERROR] Invalid choice. Please try again.
pause
goto main_menu

:: ========================================================================
::                        TESTING PHASES
:: ========================================================================

:run_complete_suite
echo [PHASE] Running Complete Test Suite
echo [PHASE] Running Complete Test Suite >> "%MASTER_LOG%"
echo [TIMESTAMP] %TIME% >> "%MASTER_LOG%"
echo.

echo [PHASE 1] Starting Syntax Validation...
echo [PHASE 1] Starting Syntax Validation... >> "%MASTER_LOG%"
call :run_phase "%VALIDATOR%" "Syntax Validation"
if errorlevel 1 (
echo [WARNING] Syntax validation had issues, continuing...
echo [WARNING] Syntax validation had issues, continuing... >> "%MASTER_LOG%"
)

echo.
echo [PHASE 2] Starting Safe Execution Testing...
echo [PHASE 2] Starting Safe Execution Testing... >> "%MASTER_LOG%"
call :run_phase "%SAFE_TESTER%" "Safe Execution Testing"
if errorlevel 1 (
echo [WARNING] Safe execution testing had issues, continuing...
echo [WARNING] Safe execution testing had issues, continuing... >> "%MASTER_LOG%"
)

echo.
echo [PHASE 3] Starting Category Analysis...
echo [PHASE 3] Starting Category Analysis... >> "%MASTER_LOG%"
call :run_phase "%CATEGORY_REPORTER%" "Category Analysis"
if errorlevel 1 (
echo [WARNING] Category analysis had issues
echo [WARNING] Category analysis had issues >> "%MASTER_LOG%"
)

echo.
echo [SUCCESS] Complete test suite finished!
echo [SUCCESS] Complete test suite finished! >> "%MASTER_LOG%"
echo [RESULTS] Check the Results directory for detailed reports
echo [RESULTS] Check the Results directory for detailed reports >> "%MASTER_LOG%"
echo.
pause
goto main_menu

:run_syntax_validation
echo [PHASE] Running Syntax Validation Only
echo [PHASE] Running Syntax Validation Only >> "%MASTER_LOG%"
call :run_phase "%VALIDATOR%" "Syntax Validation"
echo.
pause
goto main_menu

:run_safe_testing
echo [PHASE] Running Safe Execution Testing Only
echo [PHASE] Running Safe Execution Testing Only >> "%MASTER_LOG%"
call :run_phase "%SAFE_TESTER%" "Safe Execution Testing"
echo.
pause
goto main_menu

:run_category_analysis
echo [PHASE] Running Category Analysis Only
echo [PHASE] Running Category Analysis Only >> "%MASTER_LOG%"
call :run_phase "%CATEGORY_REPORTER%" "Category Analysis"
echo.
pause
goto main_menu

:view_results
echo [ACTION] Viewing Previous Test Results
echo [ACTION] Viewing Previous Test Results >> "%MASTER_LOG%"
call :show_results_menu
goto main_menu

:generate_summary
echo [ACTION] Generating Summary Report
echo [ACTION] Generating Summary Report >> "%MASTER_LOG%"
call :generate_summary_report
echo.
pause
goto main_menu

:exit_program
echo [STATUS] Exiting Master Test Orchestrator
echo [STATUS] Exiting Master Test Orchestrator >> "%MASTER_LOG%"
echo [LOG FILE] %MASTER_LOG%
echo [LOG FILE] %MASTER_LOG% >> "%MASTER_LOG%"
echo.
echo Thank you for using the BAT Test Suite!
exit /b 0

:: ========================================================================
::                        HELPER FUNCTIONS
:: ========================================================================

:check_testing_tools
echo [CHECK] Verifying testing tools...
echo [CHECK] Verifying testing tools... >> "%MASTER_LOG%"

if not exist "%VALIDATOR%" (
echo [ERROR] BAT-VALIDATOR.bat not found!
echo [ERROR] BAT-VALIDATOR.bat not found! >> "%MASTER_LOG%"
exit /b 1
)

if not exist "%SAFE_TESTER%" (
echo [ERROR] BAT-SAFE-TESTER.bat not found!
echo [ERROR] BAT-SAFE-TESTER.bat not found! >> "%MASTER_LOG%"
exit /b 1
)

if not exist "%CATEGORY_REPORTER%" (
echo [ERROR] BAT-CATEGORY-REPORT.bat not found!
echo [ERROR] BAT-CATEGORY-REPORT.bat not found! >> "%MASTER_LOG%"
exit /b 1
)

echo [SUCCESS] All testing tools found!
echo [SUCCESS] All testing tools found! >> "%MASTER_LOG%"
exit /b 0

:run_phase
set "PHASE_SCRIPT=%~1"
set "PHASE_NAME=%~2"
set "START_TIME=%TIME%"

echo [EXECUTING] %PHASE_NAME%
echo [EXECUTING] %PHASE_NAME% >> "%MASTER_LOG%"
echo [START TIME] %START_TIME% >> "%MASTER_LOG%"

:: Run the phase script
call "%PHASE_SCRIPT%"

set "EXIT_CODE=%ERRORLEVEL%"
set "END_TIME=%TIME%"

echo [COMPLETED] %PHASE_NAME% - Exit Code: %EXIT_CODE%
echo [COMPLETED] %PHASE_NAME% - Exit Code: %EXIT_CODE% >> "%MASTER_LOG%"
echo [END TIME] %END_TIME% >> "%MASTER_LOG%"
echo [DURATION] %START_TIME% to %END_TIME% >> "%MASTER_LOG%"
echo. >> "%MASTER_LOG%"

exit /b %EXIT_CODE%

:show_results_menu
cls
echo ========================================================================
echo                         PREVIOUS TEST RESULTS
echo ========================================================================
echo.
echo [INFO] Available test result files:
echo.

:: List available result files
set "RESULT_COUNT=0"
for %%f in ("%RESULTS_DIR%\*.html") do (
set /a RESULT_COUNT+=1
echo [!RESULT_COUNT!] %%~nxf
)

if %RESULT_COUNT%==0 (
echo [INFO] No previous test results found.
echo [INFO] Run a test phase first to generate results.
echo.
pause
goto :eof
)

echo.
echo [0] Return to Main Menu
echo.
set /p result_choice="Select a result file to view (0-%RESULT_COUNT%): "

if "%result_choice%"=="0" goto :eof

:: Open selected result file
set "FILE_INDEX=0"
for %%f in ("%RESULTS_DIR%\*.html") do (
set /a FILE_INDEX+=1
if !FILE_INDEX!==%result_choice% (
echo [OPENING] %%~nxf
start "" "%%f"
goto :eof
)
)

echo [ERROR] Invalid selection.
pause
goto :eof

:generate_summary_report
echo [INFO] Generating comprehensive summary report...

:: Create summary report
set "SUMMARY_FILE=%RESULTS_DIR%\comprehensive-summary_%TIMESTAMP%.html"
echo ^<!DOCTYPE html^> > "%SUMMARY_FILE%"
echo ^<html^> >> "%SUMMARY_FILE%"
echo ^<head^> >> "%SUMMARY_FILE%"
echo ^<title^>Comprehensive BAT Test Summary - %TIMESTAMP%^</title^> >> "%SUMMARY_FILE%"
echo ^<style^> >> "%SUMMARY_FILE%"
echo body { font-family: Arial, sans-serif; margin: 20px; } >> "%SUMMARY_FILE%"
echo .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; } >> "%SUMMARY_FILE%"
echo .section { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; } >> "%SUMMARY_FILE%"
echo .link { color: #3498db; text-decoration: none; } >> "%SUMMARY_FILE%"
echo .link:hover { text-decoration: underline; } >> "%SUMMARY_FILE%"
echo ^</style^> >> "%SUMMARY_FILE%"
echo ^</head^> >> "%SUMMARY_FILE%"
echo ^<body^> >> "%SUMMARY_FILE%"
echo ^<div class="header"^> >> "%SUMMARY_FILE%"
echo ^<h1^>Comprehensive BAT Test Summary^</h1^> >> "%SUMMARY_FILE%"
echo ^<p^>Generated: %TIMESTAMP%^</p^> >> "%SUMMARY_FILE%"
echo ^</div^> >> "%SUMMARY_FILE%"

:: Add links to individual reports
echo ^<div class="section"^> >> "%SUMMARY_FILE%"
echo ^<h2^>Available Reports^</h2^> >> "%SUMMARY_FILE%"

for %%f in ("%RESULTS_DIR%\*.html") do (
echo ^<p^>^<a href="%%~nxf" class="link"^>%%~nxf^</a^>^</p^> >> "%SUMMARY_FILE%"
)

echo ^</div^> >> "%SUMMARY_FILE%"
echo ^</body^> >> "%SUMMARY_FILE%"
echo ^</html^> >> "%SUMMARY_FILE%"

echo [SUCCESS] Summary report created: %SUMMARY_FILE%
echo [SUCCESS] Summary report created: %SUMMARY_FILE% >> "%MASTER_LOG%"
start "" "%SUMMARY_FILE%"

goto :eof
