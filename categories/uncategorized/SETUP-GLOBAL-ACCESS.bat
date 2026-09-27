@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title DevOptimizer - Setup Global Access
color 0A

echo.
echo 
echo               DEVOPTIMIZER - SETUP GLOBAL ACCESS             
echo 
echo.
echo This will make DevOptimizer accessible from anywhere on your system.
echo.

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo [1] Adding DevOptimizer to system PATH...
echo.

:: Add to user PATH
setx PATH "%PATH%;%SCRIPT_DIR%" /M >nul 2>&1
if !errorlevel! equ 0 (
echo    Added to system PATH successfully
) else (
echo    Could not add to system PATH (may need admin rights)
echo   Adding to user PATH instead...
setx PATH "%PATH%;%SCRIPT_DIR%" >nul 2>&1
if !errorlevel! equ 0 (
echo    Added to user PATH successfully
) else (
echo    Failed to add to PATH
)
)

echo.
echo [2] Creating global shortcuts...
echo.

:: Create shortcuts in common locations
if exist "%USERPROFILE%\Desktop" (
echo   Creating desktop shortcut...
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\DevOptimizer Master Suite.lnk'); $Shortcut.TargetPath = '%SCRIPT_DIR%\DEVOPTIMIZER-MASTER-SUITE.bat'; $Shortcut.WorkingDirectory = '%SCRIPT_DIR%'; $Shortcut.Description = 'DevOptimizer Master Suite - All-in-One System'; $Shortcut.Save()" >nul 2>&1
if !errorlevel! equ 0 (
echo      Desktop shortcut created
) else (
echo      Failed to create desktop shortcut
)
)

if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs" (
echo   Creating start menu shortcut...
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\DevOptimizer Master Suite.lnk'); $Shortcut.TargetPath = '%SCRIPT_DIR%\DEVOPTIMIZER-MASTER-SUITE.bat'; $Shortcut.WorkingDirectory = '%SCRIPT_DIR%'; $Shortcut.Description = 'DevOptimizer Master Suite - All-in-One System'; $Shortcut.Save()" >nul 2>&1
if !errorlevel! equ 0 (
echo      Start menu shortcut created
) else (
echo      Failed to create start menu shortcut
)
)

echo.
echo [3] Creating global batch files...
echo.

:: Create global batch files in system directories
if exist "%WINDIR%\System32" (
echo   Creating global batch files...

:: Create DevOptimizer.bat
echo @echo off > "%WINDIR%\System32\DevOptimizer.bat"
echo call "%SCRIPT_DIR%\DEVOPTIMIZER-MASTER-SUITE.bat" %%* >> "%WINDIR%\System32\DevOptimizer.bat"
if exist "%WINDIR%\System32\DevOptimizer.bat" (
echo      DevOptimizer.bat created globally
) else (
echo      Failed to create DevOptimizer.bat
)

:: Create DevOpt.bat (short version)
echo @echo off > "%WINDIR%\System32\DevOpt.bat"
echo call "%SCRIPT_DIR%\DEVOPTIMIZER-MASTER-SUITE.bat" %%* >> "%WINDIR%\System32\DevOpt.bat"
if exist "%WINDIR%\System32\DevOpt.bat" (
echo      DevOpt.bat created globally
) else (
echo      Failed to create DevOpt.bat
)

:: Create M365Fix.bat
echo @echo off > "%WINDIR%\System32\M365Fix.bat"
echo call "%SCRIPT_DIR%\m365-fix-system.bat" %%* >> "%WINDIR%\System32\M365Fix.bat"
if exist "%WINDIR%\System32\M365Fix.bat" (
echo      M365Fix.bat created globally
) else (
echo      Failed to create M365Fix.bat
)

:: Create OneDriveFix.bat
echo @echo off > "%WINDIR%\System32\OneDriveFix.bat"
echo call "%SCRIPT_DIR%\onedrive-fix-system.bat" %%* >> "%WINDIR%\System32\OneDriveFix.bat"
if exist "%WINDIR%\System32\OneDriveFix.bat" (
echo      OneDriveFix.bat created globally
) else (
echo      Failed to create OneDriveFix.bat
)
)

echo.
echo [4] Testing global access...
echo.

:: Test global access
cd /d C:\
echo   Testing from C:\ drive...
DevOptimizer.bat --version >nul 2>&1
if !errorlevel! equ 0 (
echo      DevOptimizer accessible globally
) else (
echo      DevOptimizer may not be accessible globally yet
echo     (You may need to restart your command prompt)
)

cd /d "%SCRIPT_DIR%"

echo.
echo [5] Creating quick access commands...
echo.

:: Create a global command file
echo @echo off > "%SCRIPT_DIR%\global-commands.bat"
echo echo DevOptimizer Global Commands: >> "%SCRIPT_DIR%\global-commands.bat"
echo echo. >> "%SCRIPT_DIR%\global-commands.bat"
echo echo Available from anywhere: >> "%SCRIPT_DIR%\global-commands.bat"
echo echo   DevOptimizer     - Launch master suite >> "%SCRIPT_DIR%\global-commands.bat"
echo echo   DevOpt          - Launch master suite (short) >> "%SCRIPT_DIR%\global-commands.bat"
echo echo   M365Fix         - Fix Microsoft 365 issues >> "%SCRIPT_DIR%\global-commands.bat"
echo echo   OneDriveFix     - Fix OneDrive issues >> "%SCRIPT_DIR%\global-commands.bat"
echo echo. >> "%SCRIPT_DIR%\global-commands.bat"
echo echo Or run from any directory: >> "%SCRIPT_DIR%\global-commands.bat"
echo echo   "%SCRIPT_DIR%\DEVOPTIMIZER-MASTER-SUITE.bat" >> "%SCRIPT_DIR%\global-commands.bat"

echo    Global commands reference created

echo.
echo 
echo                     GLOBAL ACCESS SETUP COMPLETE             
echo 
echo.
echo  DevOptimizer is now accessible from anywhere!
echo.
echo  GLOBAL COMMANDS:
echo   DevOptimizer     - Launch master suite
echo   DevOpt          - Launch master suite (short)
echo   M365Fix         - Fix Microsoft 365 issues
echo   OneDriveFix     - Fix OneDrive issues
echo.
echo  SHORTCUTS CREATED:
echo   Desktop: DevOptimizer Master Suite.lnk
echo   Start Menu: DevOptimizer Master Suite.lnk
echo.
echo  NEXT STEPS:
echo   1. Restart your command prompt or PowerShell
echo   2. Test: DevOptimizer (from any directory)
echo   3. Or use: DevOpt (short version)
echo.
echo  NOTES:
echo   - Global access may take a few minutes to activate
echo   - Restart your terminal if commands don't work immediately
echo   - All .bat files are now accessible from anywhere
echo.
pause

endlocal


exit /b 0
