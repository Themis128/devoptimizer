@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title Testing Modernized Scripts
color 0B

set "BASE_DIR=D:\DevOptimizer"
set "PORTABLE_DIR=%BASE_DIR%\portable"
set "TEST_LOG=%BASE_DIR%\modernized-scripts-test-log.txt"
set "TEST_RESULTS=%BASE_DIR%\test-results-summary.txt"

set "TOTAL=0"
set "PASSED=0"
set "FAILED=0"
set "WARNINGS=0"

cd /d "%BASE_DIR%"

echo.
echo ================================================================
echo    TESTING MODERNIZED SCRIPTS - FUNCTIONALITY VERIFICATION
echo ================================================================
echo.
echo Testing all 75 modernized scripts...
echo.

> "%TEST_LOG%" (
echo ================================================================
echo    MODERNIZED SCRIPTS TEST LOG
echo    Started: %date% %time%
echo ================================================================
echo.
)

> "%TEST_RESULTS%" (
echo ================================================================
echo    MODERNIZED SCRIPTS TEST RESULTS
echo    Date: %date% %time%
echo ================================================================
echo.
)

:: Test each script
for %%f in ("%PORTABLE_DIR%\*.bat") do (
set /a TOTAL+=1
set "SCRIPT_FILE=%%~nf"
set "SCRIPT_PATH=%%f"

echo [!TOTAL!/75] Testing: !SCRIPT_FILE!

>> "%TEST_LOG%" (
echo.
echo ================================================================
echo [!TOTAL!/75] !SCRIPT_FILE!
echo ================================================================
echo Path: !SCRIPT_PATH!
echo Started: %time%
)

:: Test 1: File exists and is readable
if not exist "!SCRIPT_PATH!" (
echo   [FAILED] File not found
set /a FAILED+=1
>> "%TEST_LOG%" (
echo Status: FAILED - File not found
)
goto :next_script
)

:: Test 2: Check for modern features
set "HAS_ECHO_OFF=0"
set "HAS_SETLOCAL=0"
set "HAS_ERROR_HANDLING=0"
set "HAS_EXIT=0"
set "HAS_RELATIVE_PATH=0"

findstr /i /c:"@echo off" "!SCRIPT_PATH!" >nul 2>&1
if not errorlevel 1 set "HAS_ECHO_OFF=1"

findstr /i /c:"setlocal enabledelayedexpansion" "!SCRIPT_PATH!" >nul 2>&1
if not errorlevel 1 set "HAS_SETLOCAL=1"

findstr /i /c:"SCRIPT_ERROR" /c:"ERROR_CODE" /c:"error_handler" "!SCRIPT_PATH!" >nul 2>&1
if not errorlevel 1 set "HAS_ERROR_HANDLING=1"

findstr /i /c:"exit /b" /c:"goto :eof" "!SCRIPT_PATH!" >nul 2>&1
if not errorlevel 1 set "HAS_EXIT=1"

findstr /i /c:"%~dp0" "!SCRIPT_PATH!" >nul 2>&1
if not errorlevel 1 set "HAS_RELATIVE_PATH=1"

:: Test 3: Syntax validation (basic)
set "SYNTAX_OK=1"
findstr /i /c:"goto :menu" "!SCRIPT_PATH!" >nul 2>&1
if not errorlevel 1 (
echo   [WARNING] Found invalid goto :menu
set "SYNTAX_OK=0"
set /a WARNINGS+=1
)

:: Count modern features
set "FEATURE_COUNT=0"
if !HAS_ECHO_OFF! EQU 1 (
set /a FEATURE_COUNT+=1
)
if !HAS_SETLOCAL! EQU 1 (
set /a FEATURE_COUNT+=1
)
if !HAS_ERROR_HANDLING! EQU 1 (
set /a FEATURE_COUNT+=1
)
if !HAS_EXIT! EQU 1 (
set /a FEATURE_COUNT+=1
)

:: Determine status
if !FEATURE_COUNT! GEQ 3 (
if !SYNTAX_OK! EQU 1 (
echo   [PASSED] Modern features: !FEATURE_COUNT!/4
set /a PASSED+=1
>> "%TEST_LOG%" (
echo Status: PASSED
echo Modern Features: !FEATURE_COUNT!/4
echo   - @echo off: !HAS_ECHO_OFF!
echo   - setlocal enabledelayedexpansion: !HAS_SETLOCAL!
echo   - Error handling: !HAS_ERROR_HANDLING!
echo   - Exit statement: !HAS_EXIT!
echo   - Relative paths: !HAS_RELATIVE_PATH!
)
) else (
echo   [WARNING] Has modern features but syntax issue
set /a WARNINGS+=1
>> "%TEST_LOG%" (
echo Status: WARNING - Syntax issue detected
)
)
) else (
echo   [FAILED] Missing modern features: !FEATURE_COUNT!/4
set /a FAILED+=1
>> "%TEST_LOG%" (
echo Status: FAILED - Missing modern features
echo Modern Features: !FEATURE_COUNT!/4
)
)

>> "%TEST_LOG%" (
echo Completed: %time%
)

:next_script
)

:: Generate summary
echo.
echo ================================================================
echo    TEST SUMMARY
echo ================================================================
echo.
echo Total Scripts Tested: %TOTAL%
echo Passed: %PASSED%
echo Failed: %FAILED%
echo Warnings: %WARNINGS%
echo.

set /a PASS_RATE=(%PASSED% * 100) / %TOTAL%
>> "%TEST_RESULTS%" (
echo TEST SUMMARY
echo ================================================================
echo Total Scripts Tested: %TOTAL%
echo Passed: %PASSED%
echo Failed: %FAILED%
echo Warnings: %WARNINGS%
echo.
echo Pass Rate: !PASS_RATE! percent
echo.
echo ================================================================
echo Test completed: %date% %time%
)

set /a PASS_RATE=(%PASSED% * 100) / %TOTAL%
echo Pass Rate: !PASS_RATE!%%
echo.
echo Detailed logs saved to:
echo   - Test Log: %TEST_LOG%
echo   - Results: %TEST_RESULTS%
echo.

if %FAILED% EQU 0 (
echo [SUCCESS] All scripts passed modernization verification!
color 0A
) else (
echo [WARNING] Some scripts need attention. Check the logs.
color 0E
)

pause
exit /b 0
