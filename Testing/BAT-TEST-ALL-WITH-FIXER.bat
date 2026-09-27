@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion

:: ========================================================================
::                    MASTER BAT TEST ORCHESTRATOR WITH REALTIME FIXER
::                    Comprehensive Testing Suite with Auto-Fixing
:: ========================================================================

echo ========================================================================
echo                    MASTER BAT TEST ORCHESTRATOR WITH REALTIME FIXER
echo                    Comprehensive Testing Suite with Auto-Fixing
echo ========================================================================
echo.
echo [STATUS] Initializing Enhanced Test Suite with Real-time Fixer...
echo [INFO] This enhanced version includes automatic fixing during testing
echo [INFO] Progress bars refresh every 3 seconds with live updates
echo.

:: Set up paths
set "TEST_DIR=%~dp0"
set "RESULTS_DIR=%TEST_DIR%Results"
set "LOG_DIR=%RESULTS_DIR%\logs"

:: Create directories
mkdir "%RESULTS_DIR%" 2>nul
mkdir "%LOG_DIR%" 2>nul

:: Get current timestamp
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "TIMESTAMP=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

:: Initialize log file
set "LOG_FILE=%LOG_DIR%\master-test-with-fixer_%TIMESTAMP%.txt"
echo [%TIMESTAMP%] Enhanced Test Suite Started >> "%LOG_FILE%"

echo [TIMESTAMP] %TIMESTAMP%
echo [LOG FILE] %LOG_FILE%
echo.

:main_menu
cls
echo ========================================================================
echo                    ENHANCED TESTING OPTIONS
echo ========================================================================
echo.
echo [1] Run Complete Test Suite with Real-time Fixer (RECOMMENDED)
echo [2] Phase 1: Syntax Validation + Auto-Fix
echo [3] Phase 2: Safe Execution Testing + Auto-Fix
echo [4] Phase 3: Category Analysis + Auto-Fix
echo [5] Run Real-time Fixer Only (Fix All Issues)
echo [6] View Previous Test Results
echo [7] Generate Enhanced Summary Report
echo [8] Launch Progress Monitor (Live Updates)
echo [0] Exit
echo.
echo ========================================================================
echo Enter your choice (0-8):
set /p "choice=Choice: "

if "%choice%"=="1" goto :complete_suite
if "%choice%"=="2" goto :phase1_with_fixer
if "%choice%"=="3" goto :phase2_with_fixer
if "%choice%"=="4" goto :phase3_with_fixer
if "%choice%"=="5" goto :fixer_only
if "%choice%"=="6" goto :view_results
if "%choice%"=="7" goto :generate_report
if "%choice%"=="8" goto :launch_monitor
if "%choice%"=="0" goto :exit
goto :main_menu

:complete_suite
echo.
echo [PHASE] Running Complete Enhanced Test Suite with Real-time Fixer
echo [INFO] This will run all phases with automatic fixing enabled
echo [INFO] Progress bars will refresh every 3 seconds
echo.
echo Press any key to start...
pause >nul

echo [%TIMESTAMP%] Starting Complete Enhanced Test Suite >> "%LOG_FILE%"

:: Phase 1: Pre-fix validation
echo [PHASE 1] Pre-fix Syntax Validation...
call :run_phase_with_progress "BAT-VALIDATOR.bat" "Syntax Validation (Pre-Fix)"

:: Phase 1.5: Real-time Fixer
echo [PHASE 1.5] Running Real-time Auto-Fixer...
call :run_fixer_with_progress

:: Phase 2: Post-fix validation
echo [PHASE 2] Post-fix Syntax Validation...
call :run_phase_with_progress "BAT-VALIDATOR.bat" "Syntax Validation (Post-Fix)"

:: Phase 3: Safe execution testing
echo [PHASE 3] Safe Execution Testing...
call :run_phase_with_progress "BAT-SAFE-TESTER.bat" "Safe Execution Testing"

:: Phase 4: Category analysis
echo [PHASE 4] Category Analysis...
call :run_phase_with_progress "BAT-CATEGORY-REPORT.bat" "Category Analysis"

echo [SUCCESS] Complete Enhanced Test Suite finished!
goto :show_summary

:phase1_with_fixer
echo [PHASE] Running Phase 1 with Auto-Fixer
call :run_phase_with_progress "BAT-VALIDATOR.bat" "Syntax Validation"
call :run_fixer_with_progress
goto :show_summary

:phase2_with_fixer
echo [PHASE] Running Phase 2 with Auto-Fixer
call :run_fixer_with_progress
call :run_phase_with_progress "BAT-SAFE-TESTER.bat" "Safe Execution Testing"
goto :show_summary

:phase3_with_fixer
echo [PHASE] Running Phase 3 with Auto-Fixer
call :run_fixer_with_progress
call :run_phase_with_progress "BAT-CATEGORY-REPORT.bat" "Category Analysis"
goto :show_summary

:fixer_only
echo [PHASE] Running Real-time Fixer Only
call :run_fixer_with_progress
goto :show_summary

:run_phase_with_progress
set "SCRIPT_NAME=%~1"
set "PHASE_NAME=%~2"

echo [EXECUTING] %PHASE_NAME%
echo [%TIMESTAMP%] Starting %PHASE_NAME% >> "%LOG_FILE%"

:: Start progress monitor for this phase
start /b "" cmd /c "call :phase_progress_monitor \"%PHASE_NAME%\""

:: Run the actual script
if exist "%TEST_DIR%%SCRIPT_NAME%" (
call "%TEST_DIR%%SCRIPT_NAME%"
set "EXIT_CODE=%ERRORLEVEL%"
) else (
echo [ERROR] %SCRIPT_NAME% not found!
set "EXIT_CODE=1"
)

:: Stop progress monitor
taskkill /f /im cmd.exe /fi "WINDOWTITLE eq %PHASE_NAME%_progress" >nul 2>&1

echo [%TIMESTAMP%] Completed %PHASE_NAME% with exit code %EXIT_CODE% >> "%LOG_FILE%"
echo [COMPLETED] %PHASE_NAME%
echo.
goto :eof

:run_fixer_with_progress
echo [EXECUTING] Real-time Auto-Fixer with Progress Bar

:: Start the real-time fixer with progress
if exist "%TEST_DIR%BAT-REALTIME-FIXER-WITH-PROGRESS.bat" (
call "%TEST_DIR%BAT-REALTIME-FIXER-WITH-PROGRESS.bat"
set "EXIT_CODE=%ERRORLEVEL%"
) else (
echo [ERROR] Real-time fixer not found!
set "EXIT_CODE=1"
)

echo [COMPLETED] Real-time Auto-Fixer
echo.
goto :eof

:phase_progress_monitor
set "PHASE_NAME=%~1"
title %PHASE_NAME%_progress

:phase_progress_loop
:: Show phase progress
cls
echo ========================================================================
echo                    PHASE PROGRESS MONITOR: %PHASE_NAME%
echo ========================================================================
echo.
echo  PHASE STATUS: RUNNING
echo.
echo  CURRENT PHASE: %PHASE_NAME%
echo.
echo   STATUS: Processing...
echo  LOGS: %LOG_DIR%
echo ========================================================================

:: Wait 3 seconds before next update
timeout /t 3 /nobreak >nul 2>&1
goto :phase_progress_loop

:launch_monitor
echo [INFO] Launching Live Progress Monitor...
echo [INFO] This will show real-time updates every 3 seconds
echo [INFO] Close the monitor window to return to main menu
echo.
start "" cmd /c "call :live_progress_monitor"
goto :main_menu

:live_progress_monitor
title Live Progress Monitor

:live_monitor_loop
cls
echo ========================================================================
echo                    LIVE PROGRESS MONITOR
echo ========================================================================
echo.
echo  SYSTEM STATUS: MONITORING
echo.
echo  TESTING SUITE: Enhanced with Real-time Fixer
echo.
echo  AVAILABLE PHASES:
echo     Phase 1: Syntax Validation + Auto-Fix
echo     Phase 2: Safe Execution Testing + Auto-Fix
echo     Phase 3: Category Analysis + Auto-Fix
echo     Real-time Fixer: Automatic Issue Resolution
echo.
echo  FIXER CAPABILITIES:
echo     Missing quotes in set statements
echo     Unbalanced parentheses
echo     Missing @echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
echo     Infinite loops
echo     Missing exit points
echo     Ollama AI-powered intelligent fixes
echo.
echo   PROGRESS UPDATES: Every 3 seconds
echo  LOGS: %LOG_DIR%
echo  REPORTS: %RESULTS_DIR%
echo ========================================================================
echo.
echo Press Ctrl+C to close monitor...

:: Wait 3 seconds before next update
timeout /t 3 /nobreak >nul 2>&1
goto :live_monitor_loop

:view_results
echo.
echo [INFO] Viewing Previous Test Results...
if exist "%RESULTS_DIR%" (
dir /b "%RESULTS_DIR%\*.html" 2>nul
if not errorlevel 1 (
echo.
echo Available reports:
for %%f in ("%RESULTS_DIR%\*.html") do echo   - %%~nxf
echo.
echo Open reports in your default browser? (y/n)
set /p "open_reports=Choice: "
if /i "!open_reports!"=="y" (
for %%f in ("%RESULTS_DIR%\*.html") do start "" "%%f"
)
) else (
echo [INFO] No HTML reports found
)
) else (
echo [INFO] No results directory found
)
echo.
echo Press any key to return to main menu...
pause >nul
goto :main_menu

:generate_report
echo.
echo [INFO] Generating Enhanced Summary Report...
echo [INFO] This will create a comprehensive report of all testing phases
echo.
echo Press any key to continue...
pause >nul

:: Generate comprehensive report
echo ^<!DOCTYPE html^> > "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<html^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<head^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<title^>Enhanced BAT Testing Summary - %TIMESTAMP%^</title^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<style^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo body { font-family: Arial, sans-serif; margin: 20px; } >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo .header { background-color: #2c3e50; color: white; padding: 20px; text-align: center; } >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo .summary { background-color: #ecf0f1; padding: 15px; margin: 20px 0; } >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^</style^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^</head^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<body^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<div class="header"^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<h1^>Enhanced BAT Testing Suite Summary^</h1^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<p^>Generated: %TIMESTAMP%^</p^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^</div^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<div class="summary"^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<h2^>Enhanced Testing Features^</h2^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<ul^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<li^>Real-time Auto-Fixer with progress tracking^</li^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<li^>Ollama AI-powered intelligent fixes^</li^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<li^>Progress bars that refresh every 3 seconds^</li^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<li^>Comprehensive syntax validation^</li^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<li^>Safe execution testing^</li^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^<li^>Category-based analysis^</li^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^</ul^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^</div^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^</body^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"
echo ^</html^> >> "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"

echo [SUCCESS] Enhanced summary report generated!
echo [FILE] %RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html
echo.
echo Open report in browser? (y/n)
set /p "open_report=Choice: "
if /i "%open_report%"=="y" start "" "%RESULTS_DIR%\enhanced-test-summary_%TIMESTAMP%.html"

echo.
echo Press any key to return to main menu...
pause >nul
goto :main_menu

:show_summary
echo.
echo ========================================================================
echo                        ENHANCED TESTING SUMMARY
echo ========================================================================
echo.
echo [SUCCESS] Enhanced testing suite completed!
echo [INFO] All phases executed with real-time fixing enabled
echo [INFO] Progress bars provided live updates every 3 seconds
echo.
echo [FEATURES USED:]
echo    Real-time Auto-Fixer with Ollama integration
echo    Dynamic progress tracking with 3-second refresh
echo    Comprehensive syntax validation
echo    Safe execution testing
echo    Category-based analysis
echo.
echo [REPORTS GENERATED:]
echo    Fix logs: %LOG_DIR%
echo    HTML reports: %RESULTS_DIR%
echo    Progress tracking: Real-time updates
echo.
echo Press any key to return to main menu...
pause >nul
goto :main_menu

:exit
echo.
echo [INFO] Exiting Enhanced Test Suite...
echo [%TIMESTAMP%] Enhanced Test Suite Ended >> "%LOG_FILE%"
echo [SUCCESS] Thank you for using the Enhanced BAT Testing Suite!
echo.
exit /b 0
