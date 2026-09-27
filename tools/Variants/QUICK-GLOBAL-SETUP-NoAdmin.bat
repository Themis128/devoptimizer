@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title  - Standard Mode- Quick Global Setup
color 0A

echo.
echo 
echo               DEVOPTIMIZER - QUICK GLOBAL SETUP              
echo 
echo.

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo [1] Adding DevOptimizer to PATH...
echo.

:: Add to user PATH (simpler approach)
setx PATH "%PATH%;%SCRIPT_DIR%" >nul 2>&1
if !errorlevel! equ 0 (
echo    Added to user PATH successfully
) else (
echo    Failed to add to PATH
)

echo.
echo [2] Creating global shortcuts...
echo.

:: Create desktop shortcut
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\DevOptimizer.lnk'); $Shortcut.TargetPath = '%SCRIPT_DIR%\DEVOPTIMIZER-MASTER-SUITE.bat'; $Shortcut.WorkingDirectory = '%SCRIPT_DIR%'; $Shortcut.Save()" >nul 2>&1
if !errorlevel! equ 0 (
echo    Desktop shortcut created
) else (
echo    Failed to create desktop shortcut
)

echo.
echo [3] Creating global batch files...
echo.

:: Create global batch files in a more accessible location
if not exist "%USERPROFILE%\bin" mkdir "%USERPROFILE%\bin"

:: Create DevOptimizer.bat
echo @echo off > "%USERPROFILE%\bin\DevOptimizer.bat"
echo call "%SCRIPT_DIR%\DEVOPTIMIZER-MASTER-SUITE.bat" %%* >> "%USERPROFILE%\bin\DevOptimizer.bat"
echo    DevOptimizer.bat created in %USERPROFILE%\bin\

:: Create DevOpt.bat
echo @echo off > "%USERPROFILE%\bin\DevOpt.bat"
echo call "%SCRIPT_DIR%\DEVOPTIMIZER-MASTER-SUITE.bat" %%* >> "%USERPROFILE%\bin\DevOpt.bat"
echo    DevOpt.bat created in %USERPROFILE%\bin\

:: Create M365Fix.bat
echo @echo off > "%USERPROFILE%\bin\M365Fix.bat"
echo call "%SCRIPT_DIR%\m365-fix-system.bat" %%* >> "%USERPROFILE%\bin\M365Fix.bat"
echo    M365Fix.bat created in %USERPROFILE%\bin\

:: Create OneDriveFix.bat
echo @echo off > "%USERPROFILE%\bin\OneDriveFix.bat"
echo call "%SCRIPT_DIR%\onedrive-fix-system.bat" %%* >> "%USERPROFILE%\bin\OneDriveFix.bat"
echo    OneDriveFix.bat created in %USERPROFILE%\bin\

echo.
echo [4] Adding bin directory to PATH...
echo.

:: Add bin directory to PATH
setx PATH "%PATH%;%USERPROFILE%\bin" >nul 2>&1
if !errorlevel! equ 0 (
echo    Added bin directory to PATH
) else (
echo    Failed to add bin directory to PATH
)

echo.
echo 
echo                     SETUP COMPLETE!                          
echo 
echo.
echo  DevOptimizer is now accessible from anywhere!
echo.
echo  GLOBAL COMMANDS (after restart):
echo   DevOptimizer     - Launch master suite
echo   DevOpt          - Launch master suite (short)
echo   M365Fix         - Fix Microsoft 365 issues
echo   OneDriveFix     - Fix OneDrive issues
echo.
echo  FILES CREATED:
echo   Desktop: DevOptimizer.lnk
echo   %USERPROFILE%\bin\DevOptimizer.bat
echo   %USERPROFILE%\bin\DevOpt.bat
echo   %USERPROFILE%\bin\M365Fix.bat
echo   %USERPROFILE%\bin\OneDriveFix.bat
echo.
echo  TO ACTIVATE:
echo   1. Restart your command prompt or PowerShell
echo   2. Test: DevOptimizer (from any directory)
echo.
pause

endlocal
exit /b %ERRORLEVEL%
