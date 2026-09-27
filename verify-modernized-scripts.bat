@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title Verifying Modernized Scripts
color 0B

set "PORTABLE_DIR=D:\DevOptimizer\portable"
set "TEST_LOG=D:\DevOptimizer\verification-results.txt"

set "TOTAL=0"
set "PASSED=0"
set "FAILED=0"

cd /d "D:\DevOptimizer"

echo.
echo ================================================================
echo    VERIFYING MODERNIZED SCRIPTS
echo ================================================================
echo.

> "%TEST_LOG%" (
echo Modernized Scripts Verification Report
echo ================================================================
echo Date: %date% %time%
echo.
)

for %%f in ("%PORTABLE_DIR%\*.bat") do (
set /a TOTAL+=1
set "SCRIPT_FILE=%%~nf"

echo [!TOTAL!/75] Checking: !SCRIPT_FILE!

set "HAS_FEATURES=0"

findstr /i /c:"@echo off" "%%f" >nul 2>&1
if not errorlevel 1 set /a HAS_FEATURES+=1

findstr /i /c:"setlocal enabledelayedexpansion" "%%f" >nul 2>&1
if not errorlevel 1 set /a HAS_FEATURES+=1

findstr /i /c:"SCRIPT_ERROR" /c:"ERROR_CODE" "%%f" >nul 2>&1
if not errorlevel 1 set /a HAS_FEATURES+=1

findstr /i /c:"exit /b" "%%f" >nul 2>&1
if not errorlevel 1 set /a HAS_FEATURES+=1

if !HAS_FEATURES! GEQ 3 (
echo   [PASSED] Modern features detected: !HAS_FEATURES!/4
set /a PASSED+=1
>> "%TEST_LOG%" (
echo [!TOTAL!/75] !SCRIPT_FILE! - PASSED ^(!HAS_FEATURES!/4 features^)
)
) else (
echo   [FAILED] Missing modern features: !HAS_FEATURES!/4
set /a FAILED+=1
>> "%TEST_LOG%" (
echo [!TOTAL!/75] !SCRIPT_FILE! - FAILED ^(!HAS_FEATURES!/4 features^)
)
)
)

echo.
echo ================================================================
echo    VERIFICATION SUMMARY
echo ================================================================
echo.
echo Total Scripts: %TOTAL%
echo Passed: %PASSED%
echo Failed: %FAILED%

set /a PASS_RATE=(%PASSED% * 100) / %TOTAL%
echo Pass Rate: !PASS_RATE!%%
echo.

>> "%TEST_LOG%" (
echo.
echo ================================================================
echo SUMMARY
echo ================================================================
echo Total: %TOTAL%
echo Passed: %PASSED%
echo Failed: %FAILED%
echo Pass Rate: !PASS_RATE!%%
)

if %FAILED% EQU 0 (
echo [SUCCESS] All scripts verified successfully!
color 0A
) else (
echo [WARNING] Some scripts need attention.
color 0E
)

echo.
echo Detailed results: %TEST_LOG%
echo.
pause
exit /b 0
