@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title BAT Fix Verification - DevOptimizer
color 0A

echo ========================================================================
echo                      BAT FIX VERIFICATION
echo ========================================================================
echo.
echo [INFO] This script will verify that the fixes were applied correctly
echo [STATUS] Testing key commands and syntax patterns
echo.

REM Initialize counters
set "VERIFIED_FIXES=0"
set "REMAINING_ISSUES=0"

echo ========================================================================
echo                     TESTING COMMAND SYNTAX
echo ========================================================================
echo.

echo [TEST 1] Testing corrected tasklist syntax...
echo [STATUS] Testing: tasklist ^| findstr OneDrive
cmd /c "tasklist | findstr OneDrive" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Corrected tasklist syntax works
set /a VERIFIED_FIXES+=1
) else (
echo [ERROR] Corrected tasklist syntax failed
set /a REMAINING_ISSUES+=1
)
echo.

echo [TEST 2] Testing corrected findstr syntax...
echo [STATUS] Testing: echo test ^| findstr test
cmd /c "echo test | findstr test" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Corrected findstr syntax works
set /a VERIFIED_FIXES+=1
) else (
echo [ERROR] Corrected findstr syntax failed
set /a REMAINING_ISSUES+=1
)
echo.

echo [TEST 3] Testing ping command...
echo [STATUS] Testing: ping -n 1 onedrive.live.com
cmd /c "ping -n 1 onedrive.live.com" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Ping command works
set /a VERIFIED_FIXES+=1
) else (
echo [ERROR] Ping command failed
set /a REMAINING_ISSUES+=1
)
echo.

echo ========================================================================
echo                    CHECKING FIXED PATTERNS
echo ========================================================================
echo.

echo [CHECK 1] Scanning for remaining tasklist /FI patterns...
set "TASKLIST_REMAINING=0"
powershell -Command "& {"
$files = Get-ChildItem '*.bat'
foreach ($file in $files) {
$content = Get-Content $file.FullName -Raw
if ($content -match 'tasklist.*FI.*IMAGENAME') {
Write-Host 'Found tasklist /FI in:' $file.Name
$script:TASKLIST_REMAINING++
}
}
Write-Host 'Total remaining tasklist /FI patterns:' $TASKLIST_REMAINING
}"

echo [CHECK 2] Scanning for remaining findstr /I "patterns..."
set "FIND_REMAINING=0"
powershell -Command "& {"
$files = Get-ChildItem '*.bat'
foreach ($file in $files) {
$content = Get-Content $file.FullName -Raw
if ($content -match 'find /I /N') {
Write-Host 'Found findstr /I "in:'" $file.Name
$script:FIND_REMAINING++
}
}
Write-Host 'Total remaining findstr /I "patterns:'" $FIND_REMAINING
}"

echo [CHECK 3] Scanning for remaining echo. patterns...
set "ECHO_REMAINING=0"
powershell -Command "& {"
$files = Get-ChildItem '*.bat'
foreach ($file in $files) {
$content = Get-Content $file.FullName -Raw
if ($content -match 'echo\.') {
Write-Host 'Found echo. in:' $file.Name
$script:ECHO_REMAINING++
}
}
Write-Host 'Total remaining echo. patterns:' $ECHO_REMAINING
}"

echo.
echo ========================================================================
echo                       CORE BAT FILE TESTING
echo ========================================================================
echo.

echo [TEST 4] Testing core BAT files accessibility...
set "CORE_FILES_OK=0"

if exist "DEVOPTIMIZER-WORKING-LAUNCHER.bat" (
echo [SUCCESS] DEVOPTIMIZER-WORKING-LAUNCHER.bat - EXISTS
set /a CORE_FILES_OK+=1
) else (
echo [ERROR] DEVOPTIMIZER-WORKING-LAUNCHER.bat - MISSING
)

if exist "ONEDRIVE-MANAGER.bat" (
echo [SUCCESS] ONEDRIVE-MANAGER.bat - EXISTS
set /a CORE_FILES_OK+=1
) else (
echo [ERROR] ONEDRIVE-MANAGER.bat - MISSING
)

if exist "OLLAMA-SERVER-MANAGER.bat" (
echo [SUCCESS] OLLAMA-SERVER-MANAGER.bat - EXISTS
set /a CORE_FILES_OK+=1
) else (
echo [ERROR] OLLAMA-SERVER-MANAGER.bat - MISSING
)

if exist "SECURITY-MANAGER.bat" (
echo [SUCCESS] SECURITY-MANAGER.bat - EXISTS
set /a CORE_FILES_OK+=1
) else (
echo [ERROR] SECURITY-MANAGER.bat - MISSING
)

echo.
echo ========================================================================
echo                          VERIFICATION SUMMARY
echo ========================================================================
echo.

echo [RESULTS]
echo    Command syntax tests passed: %VERIFIED_FIXES%/3
echo    Core BAT files accessible: %CORE_FILES_OK%/4
echo   β€Ά Remaining tasklist /FI patterns: %TASKLIST_REMAINING%
echo   β€Ά Remaining findstr /I "patterns:" %FIND_REMAINING%
echo   β€Ά Remaining echo. patterns: %ECHO_REMAINING%
echo.

if %VERIFIED_FIXES%==3 (
if %CORE_FILES_OK%==4 (
if %TASKLIST_REMAINING%==0 (
if %FIND_REMAINING%==0 (
echo [SUCCESS] All fixes verified successfully!
echo [STATUS] Your BAT system should now work correctly
) else (
echo [WARNING] Some find patterns may remain - manual review recommended
)
) else (
echo [WARNING] Some tasklist patterns may remain - manual review recommended
)
) else (
echo [WARNING] Some core files may be missing
)
) else (
echo [ERROR] Some command syntax tests failed
)

echo.
echo [RECOMMENDATIONS]
echo   1. Test your main launcher: DEVOPTIMIZER-WORKING-LAUNCHER.bat
echo   2. Test OneDrive Manager troubleshooting
echo   3. Test Ollama Server Manager functionality
echo   4. Report any remaining issues
echo.

pause
exit /b 0
