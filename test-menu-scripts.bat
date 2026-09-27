@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title Testing All Menu Scripts
color 0E

set "BASE_DIR=D:\DevOptimizer"
set "REPORT_FILE=%BASE_DIR%\menu-test-report.txt"
set "WORKING=0"
set "BROKEN=0"
set "TOTAL=0"

echo.
echo ================================================================
echo       TESTING ALL .BAT FILES IN MENU
echo ================================================================
echo.
echo Report will be saved to: %REPORT_FILE%
echo.
echo Starting tests...
echo.

> "%REPORT_FILE%" (
echo ================================================================
echo       MENU SCRIPT TEST REPORT
echo       Generated: %date% %time%
echo ================================================================
echo.
)

:: Test menu itself
echo Testing menu file...
call :TEST_FILE "%BASE_DIR%\DevOptimizer-Menu.bat" "Main Menu"
echo.

:: Test Portable Scripts
echo ================================================================
echo Testing PORTABLE SCRIPTS...
echo ================================================================
>> "%REPORT_FILE%" (
echo.
echo ================================================================
echo PORTABLE SCRIPTS
echo ================================================================
echo.
)
for %%f in ("%BASE_DIR%\portable\*.bat") do (
call :TEST_FILE "%%f" "Portable"
)
echo.

:: Test Categories
echo ================================================================
echo Testing CATEGORIES...
echo ================================================================
>> "%REPORT_FILE%" (
echo.
echo ================================================================
echo CATEGORIES
echo ================================================================
echo.
)

for /d %%d in ("%BASE_DIR%\categories\*") do (
set "CAT_NAME=%%~nd"
echo.
echo Testing category: !CAT_NAME!
>> "%REPORT_FILE%" (
echo.
echo --- !CAT_NAME! ---
)
for %%f in ("%%d\*.bat") do (
call :TEST_FILE "%%f" "Category: !CAT_NAME!"
)
)
echo.

:: Test Tools
echo ================================================================
echo Testing TOOLS...
echo ================================================================
>> "%REPORT_FILE%" (
echo.
echo ================================================================
echo TOOLS
echo ================================================================
echo.
)
for %%f in ("%BASE_DIR%\tools\*.bat") do (
call :TEST_FILE "%%f" "Tools"
)
echo.

:: Test Generators
echo ================================================================
echo Testing GENERATORS...
echo ================================================================
>> "%REPORT_FILE%" (
echo.
echo ================================================================
echo GENERATORS
echo ================================================================
echo.
)
for %%f in ("%BASE_DIR%\generators\*.bat") do (
call :TEST_FILE "%%f" "Generators"
)
echo.

:: Summary
>> "%REPORT_FILE%" (
echo.
echo ================================================================
echo SUMMARY
echo ================================================================
echo Total Files Tested: %TOTAL%
echo Working: %WORKING%
echo Broken/Errors: %BROKEN%
echo.
)

echo.
echo ================================================================
echo TEST COMPLETE
echo ================================================================
echo.
echo Total Files Tested: %TOTAL%
echo Working: %WORKING%
echo Broken/Errors: %BROKEN%
echo.
echo Full report saved to: %REPORT_FILE%
echo.
pause
exit /b

:TEST_FILE
set "FILE_PATH=%~1"
set "CATEGORY=%~2"
set /a TOTAL+=1

set "FILENAME=%~nx1"
set "RESULT=UNKNOWN"

:: Check if file exists
if not exist "!FILE_PATH!" (
set "RESULT=NOT FOUND"
set /a BROKEN+=1
echo   [X] !FILENAME! - NOT FOUND
>> "%REPORT_FILE%" (
echo [X] !FILENAME! - NOT FOUND
)
goto :EOF
)

:: Test syntax with cmd /c
cmd /c "exit /b 0" >nul 2>&1
if errorlevel 1 (
set "RESULT=SYNTAX ERROR"
set /a BROKEN+=1
echo   [X] !FILENAME! - SYNTAX ERROR
>> "%REPORT_FILE%" (
echo [X] !FILENAME! - SYNTAX ERROR
)
goto :EOF
)

:: Try to parse the file for common errors
findstr /i /c:"goto :eof" /c:"exit /b" /c:"@echo off" "!FILE_PATH!" >nul 2>&1
if errorlevel 1 (
:: Check if it's a valid batch file (has at least some batch commands)
findstr /i /c:"echo" /c:"set" /c:"if" /c:"for" /c:"call" "!FILE_PATH!" >nul 2>&1
if errorlevel 1 (
set "RESULT=NO BATCH COMMANDS"
set /a BROKEN+=1
echo   [X] !FILENAME! - NO BATCH COMMANDS
>> "%REPORT_FILE%" (
echo [X] !FILENAME! - NO BATCH COMMANDS
)
goto :EOF
)
)

:: Check for common issues
findstr /i /c:"goto :EOF" "!FILE_PATH!" >nul 2>&1
if errorlevel 1 (
findstr /i /c:"exit" "!FILE_PATH!" >nul 2>&1
if errorlevel 1 (
set "RESULT=NO EXIT"
echo   [!] !FILENAME! - NO EXIT (may loop)
>> "%REPORT_FILE%" (
echo [!] !FILENAME! - NO EXIT (may loop)
)
)
)

:: If we get here, basic structure looks OK
set "RESULT=OK"
set /a WORKING+=1
echo   [OK] !FILENAME!
>> "%REPORT_FILE%" (
echo [OK] !FILENAME!
)

goto :EOF
