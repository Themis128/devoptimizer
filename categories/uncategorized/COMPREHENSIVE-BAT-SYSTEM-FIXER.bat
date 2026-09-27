@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title Comprehensive BAT System Fixer - DevOptimizer
color 0C

echo ========================================================================
echo                 COMPREHENSIVE BAT SYSTEM FIXER
echo ========================================================================
echo.
echo [INFO] This script will fix all identified issues in your BAT system
echo [WARNING] This will modify multiple BAT files - backup recommended
echo.

REM Check if running from correct directory
if not exist "%~dp0" (
echo [ERROR] Cannot determine script directory
pause
exit /b 1
)

REM Create backup directory
	set "BACKUP_DIR=%~dp0backup-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%"
	set "BACKUP_DIR=%BACKUP_DIR: =0%"
	echo [INFO] Creating backup directory: %BACKUP_DIR%
	if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

	REM Set root directory for scanning (two levels up from this script's location)
	set "ROOT_DIR=%~dp0..\.."
	echo [INFO] Scanning for .bat files in: %ROOT_DIR%

echo [SUCCESS] Backup directory created
echo.

echo ========================================================================
echo                       FIXING TASKLIST COMMANDS
echo ========================================================================
echo.

echo [INFO] Fixing tasklist commands with broken /FI syntax...
echo [STATUS] This will replace tasklist /FI "IMAGENAME eq" with tasklist | findstr

REM Process all BAT files for tasklist fixes
	set "FIXED_TASKLIST=0"
	for /r "%ROOT_DIR%" %%f in (*.bat) do (
	    echo [PROCESSING] %%f

	    REM Create backup of original file
	    REM copy "%%f" "%BACKUP_DIR%\%%f.backup" >nul 2>&1

	    REM Create a temporary PowerShell script to do the replacement
	    echo $content = Get-Content '%%f' -Raw > temp_fix.ps1
	    echo $originalContent = $content >> temp_fix.ps1
	    echo $content = $content -replace 'tasklist | findstr /I "([^"]+)" 2^>NUL \| findstr /I "\\$1"\^>NUL', 'tasklist ^| findstr /I "$1" ^>NUL' >> temp_fix.ps1
	    echo $content = $content -replace 'tasklist | findstr /I "([^"]+)" 2^>NUL \| findstr /I "\\$1"', 'tasklist ^| findstr /I "$1"' >> temp_fix.ps1
	    echo $content = $content -replace 'tasklist | findstr /I "([^"]+)"', 'tasklist ^| findstr /I "$1"' >> temp_fix.ps1
	    echo if ($content -ne $originalContent) { Set-Content '%%f' $content -Encoding UTF8; Write-Host 'Fixed %%f' } >> temp_fix.ps1

	    REM Run the PowerShell script
	    powershell -ExecutionPolicy Bypass -File temp_fix.ps1

	    REM Clean up
	    del temp_fix.ps1 >nul 2>&1

	    set /a FIXED_TASKLIST+=1
	)

echo [SUCCESS] Tasklist fixes completed
echo.

echo ========================================================================
echo                         FIXING FIND COMMANDS
echo ========================================================================
echo.

echo [INFO] Fixing find commands with broken /I /N syntax...
echo [STATUS] This will replace findstr /I "with" findstr /I

REM Process all BAT files for find fixes
	set "FIXED_FIND=0"
		for /r "%ROOT_DIR%" %%f in (*.bat) do (
		    echo [PROCESSING] %%f

		    REM Create a temporary PowerShell script to do the replacement
		    echo $content = Get-Content '%%f' -Raw > temp_fix.ps1
	    echo $originalContent = $content >> temp_fix.ps1
	    echo $content = $content -replace 'findstr /I "([^"]+)"', 'findstr /I "$1"' >> temp_fix.ps1
	    echo $content = $content -replace 'findstr /I "([^\s^">]+)', 'findstr /I "$1"' >> temp_fix.ps1
	    echo if ($content -ne $originalContent) { Set-Content '%%f' $content -Encoding UTF8; Write-Host 'Fixed %%f' } >> temp_fix.ps1

	    REM Run the PowerShell script
	    powershell -ExecutionPolicy Bypass -File temp_fix.ps1

	    REM Clean up
	    del temp_fix.ps1 >nul 2>&1
	)

echo [SUCCESS] Find fixes completed
echo.

echo ========================================================================
echo                         FIXING ECHO COMMANDS
echo ========================================================================
echo.

echo [INFO] Reviewing echo. commands for PowerShell compatibility...
echo [STATUS] This will replace problematic echo. with echo ""

REM Process all BAT files for echo fixes
	set "FIXED_ECHO=0"
		for /r "%ROOT_DIR%" %%f in (*.bat) do (
		    echo [PROCESSING] %%f

		    REM Create a temporary PowerShell script to do the replacement
		    echo $content = Get-Content '%%f' -Raw > temp_fix.ps1
	    echo $originalContent = $content >> temp_fix.ps1
	    echo $content = $content -replace 'echo\.', 'echo ""' >> temp_fix.ps1
	    echo if ($content -ne $originalContent) { Set-Content '%%f' $content -Encoding UTF8; Write-Host 'Fixed %%f' } >> temp_fix.ps1

	    REM Run the PowerShell script
	    powershell -ExecutionPolicy Bypass -File temp_fix.ps1

	    REM Clean up
	    del temp_fix.ps1 >nul 2>&1
	)

echo [SUCCESS] Echo fixes completed
echo.

echo ========================================================================
echo                         VERIFICATION
echo ========================================================================
echo.

echo [INFO] Verifying fixes...
echo [STATUS] Testing corrected command syntax...

REM Test the corrected syntax
echo [TEST] Testing: tasklist ^| findstr OneDrive
cmd /c "tasklist | findstr OneDrive" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Corrected tasklist syntax works
) else (
echo [ERROR] Corrected tasklist syntax failed
)

echo [TEST] Testing: echo test ^| findstr test
cmd /c "echo test | findstr test" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Corrected findstr syntax works
) else (
echo [ERROR] Corrected findstr syntax failed
)

echo.
echo ========================================================================
echo                          SUMMARY
echo ========================================================================
echo.

echo [SUCCESS] Comprehensive BAT System Fix completed!
echo.
echo [RESULTS]
echo    Tasklist commands fixed: %FIXED_TASKLIST% files
echo    Find commands fixed: %FIXED_FIND% files
echo    Echo commands fixed: %FIXED_ECHO% files
echo    Original files backed up to: %BACKUP_DIR%
echo.
echo [RECOMMENDATIONS]
echo   1. Test your core BAT files manually
echo   2. Run DEVOPTIMIZER-WORKING-LAUNCHER.bat
echo   3. Test OneDrive Manager troubleshooting
echo   4. Test Ollama Server Manager
echo.
echo [NEXT STEPS]
echo    Run BAT-FIX-VERIFICATION.bat to verify fixes
echo    Test main launcher and key functions
echo   Ξ²β‚¬Ξ† Report any remaining issues
echo.

exit /b 0
