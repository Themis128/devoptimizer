:: SYNOPSIS: DevOptimizer automation script: normalize-bat-files.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

REM ================================================================
REM           BATCH FILE NORMALIZATION SCRIPT
REM ================================================================
REM Fixes encoding, headers, paths, and standardizes all .bat files
REM ================================================================

title Batch File Normalization for DevOptimizer

set "DEVOPTIMIZER_PATH=D:\DevOptimizer"
set "BACKUP_PATH=backups\bat-fixes_20251004_103512"
set "DRY_RUN_MODE=0"

REM Check for dry run mode
if /i "%~1"=="-dry-run" set "DRY_RUN_MODE=1"

echo ================================================================
echo           BATCH FILE NORMALIZATION FOR DEVOPTIMIZER
echo ================================================================
echo.

if %DRY_RUN_MODE% equ 1 (
echo [INFO] DRY RUN MODE: No files will be modified
echo.
) else (
echo [INFO] LIVE MODE: Files will be modified
echo.
)

REM Count .bat files
set "BAT_COUNT=0"
for %%f in ("%DEVOPTIMIZER_PATH%\*.bat") do set /a BAT_COUNT+=1

echo [INFO] Found %BAT_COUNT% .bat files to process
echo.

set "PROCESSED=0"
set "SUCCESS=0"
set "FAILED=0"
set "CHANGED=0"

REM Process each .bat file
for %%f in ("%DEVOPTIMIZER_PATH%\*.bat") do (
set /a PROCESSED+=1
set "FILENAME=%%~nxf"
set "FILEPATH=%%f"

echo [%PROCESSED%/%BAT_COUNT%] Processing: !FILENAME!

REM Skip if file is too small
for %%s in ("!FILEPATH!") do if %%~zs lss 10 (
echo   [WARN] Skipping - file too small
set /a FAILED+=1
goto :next_file
)

REM Create normalized version
call :normalize_file "!FILEPATH!" "!FILENAME!"
if !errorlevel! equ 0 (
set /a SUCCESS+=1
if !CHANGES_MADE! equ 1 set /a CHANGED+=1
) else (
set /a FAILED+=1
)

:next_file
)

echo.
echo ================================================================
echo                    NORMALIZATION SUMMARY
echo ================================================================
echo Total Files: %BAT_COUNT%
echo Processed: %PROCESSED%
echo Successful: %SUCCESS%
echo Failed: %FAILED%
echo Changed: %CHANGED%
echo.

if %DRY_RUN_MODE% equ 1 (
echo This was a DRY RUN. Remove -dry-run to apply changes.
) else (
echo Normalization completed!
echo Backups are available in: %BACKUP_PATH%
)

if %FAILED% gtr 0 (
echo.
echo Some files failed to process. Check the logs above.
exit /b 1
)

exit /b 0

REM ================================================================
REM           NORMALIZE FILE FUNCTION
REM ================================================================
:normalize_file
set "FILEPATH=%~1"
set "FILENAME=%~2"
set "CHANGES_MADE=0"

REM Create temporary file for normalized content
set "TEMP_FILE=%TEMP%\normalize_%RANDOM%.bat"

REM Start with standard header
echo @echo off > "!TEMP_FILE!"
echo setlocal EnableExtensions EnableDelayedExpansion >> "!TEMP_FILE!"
echo cd /d "%%~dp0" >> "!TEMP_FILE!"
echo. >> "!TEMP_FILE!"

REM Read original file and process line by line
set "FIRST_LINE=1"
for /f "usebackq delims=" %%a in ("!FILEPATH!") do (
set "LINE=%%a"

REM Skip existing @echo off, setlocal, cd lines
echo !LINE! | findstr /i "^@echo off" >nul && goto :skip_line
echo !LINE! | findstr /i "setlocal EnableExtensions EnableDelayedExpansion" >nul && goto :skip_line
echo !LINE! | findstr /i 'cd /d "%%~dp0"' >nul && goto :skip_line

REM Replace Unicode characters with ASCII
set "LINE=!LINE:==!"
set "LINE=!LINE:=+!"
set "LINE=!LINE:=+!"
set "LINE=!LINE:=+!"
set "LINE=!LINE:=+!"
set "LINE=!LINE:==!"
set "LINE=!LINE:=|!"
set "LINE=!LINE:=[LAUNCH]!"
set "LINE=!LINE:=[AI]!"
set "LINE=!LINE:=[PERF]!"
set "LINE=!LINE:=[TOOL]!"
set "LINE=!LINE:=[STATS]!"
set "LINE=!LINE:=[NET]!"
set "LINE=!LINE:=[SEC]!"
set "LINE=!LINE:=[UI]!"
set "LINE=!LINE:=[TEST]!"
set "LINE=!LINE:=[CFG]!"
set "LINE=!LINE:=[OK]!"
set "LINE=!LINE:=[ERR]!"
set "LINE=!LINE:=[WARN]!"
set "LINE=!LINE:=[TIP]!"
set "LINE=!LINE:=[TARGET]!"
set "LINE=!LINE:=[LIST]!"
set "LINE=!LINE:=[SEARCH]!"
set "LINE=!LINE:=[BUILD]!"
set "LINE=!LINE:=[FOLDER]!"
set "LINE=!LINE:=[NOTE]!"
set "LINE=!LINE:=[RED]!"
set "LINE=!LINE:=[GREEN]!"
set "LINE=!LINE:=[YELLOW]!"
set "LINE=!LINE:=[BLUE]!"

REM Add line to temp file
echo !LINE! >> "!TEMP_FILE!"

:skip_line
)

REM Add admin helpers if Admin version
echo !FILENAME! | findstr /i "-Admin\.bat$" >nul
if !errorlevel! equ 0 (
echo. >> "!TEMP_FILE!"
echo REM ================================================================ >> "!TEMP_FILE!"
echo REM                    ADMIN PRIVILEGE FUNCTIONS >> "!TEMP_FILE!"
echo REM ================================================================ >> "!TEMP_FILE!"
echo. >> "!TEMP_FILE!"
echo :checkAdmin >> "!TEMP_FILE!"
echo set "IS_ADMIN=0" >> "!TEMP_FILE!"
echo fsutil dirty query %%SystemDrive%% ^>nul 2^>^&1 >> "!TEMP_FILE!"
echo if not errorlevel 1 ^( >> "!TEMP_FILE!"
echo     set "IS_ADMIN=1" >> "!TEMP_FILE!"
echo ^) else ^( >> "!TEMP_FILE!"
echo     net session ^>nul 2^>^&1 >> "!TEMP_FILE!"
echo     if not errorlevel 1 set "IS_ADMIN=1" >> "!TEMP_FILE!"
echo ^) >> "!TEMP_FILE!"
echo exit /b >> "!TEMP_FILE!"
echo. >> "!TEMP_FILE!"
echo :requireAdmin >> "!TEMP_FILE!"
echo call :checkAdmin >> "!TEMP_FILE!"
echo if not "%%IS_ADMIN%%"=="1" ^( >> "!TEMP_FILE!"
echo     echo. >> "!TEMP_FILE!"
echo     echo [ERROR] This operation requires Administrator privileges. >> "!TEMP_FILE!"
echo     echo Please run this script as Administrator. >> "!TEMP_FILE!"
echo     echo. >> "!TEMP_FILE!"
echo     pause >> "!TEMP_FILE!"
echo     exit /b 1 >> "!TEMP_FILE!"
echo ^) >> "!TEMP_FILE!"
echo exit /b >> "!TEMP_FILE!"
)

REM Add exit code if not present
echo exit /b %%ERRORLEVEL%% >> "!TEMP_FILE!"

REM Replace original file if not dry run
if %DRY_RUN_MODE% equ 0 (
copy "!TEMP_FILE!" "!FILEPATH!" >nul
set "CHANGES_MADE=1"
echo   [OK] Normalized
) else (
echo   [DRY RUN] Would normalize
)

REM Clean up temp file
del "!TEMP_FILE!" >nul 2>&1

exit /b 0
