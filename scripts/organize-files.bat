@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
echo ========================================================================
echo                    ORGANIZING DEVOPTIMIZER HUB
echo ========================================================================

REM Create subfolders
echo [STEP 1] Creating subfolders...
if not exist "Backups" mkdir "Backups"
if not exist "Documentation" mkdir "Documentation"
if not exist "Logs" mkdir "Logs"
if not exist "Scripts" mkdir "Scripts"
if not exist "Tools" mkdir "Tools"
if not exist "tools\Variants" mkdir "tools\Variants"
if not exist "tools\Old-Launchers" mkdir "tools\Old-Launchers"

REM Move backup folders
echo [STEP 2] Moving backup folders...
for /d %%i in (backup-*) do (
if exist "%%i" (
move "%%i" "Backups\" 2>nul
echo   Moved: %%i
)
)

REM Move documentation files
echo [STEP 3] Moving documentation files...
for %%i in (*.md) do (
if exist "%%i" (
move "%%i" "Documentation\" 2>nul
echo   Moved: %%i
)
)

REM Move log files
echo [STEP 4] Moving log files...
for %%i in (*.log) do (
if exist "%%i" (
move "%%i" "Logs\" 2>nul
echo   Moved: %%i
)
)

REM Move PowerShell scripts (except this one and organize-hub.ps1)
echo [STEP 5] Moving PowerShell scripts...
for %%i in (*.ps1) do (
if exist "%%i" (
if not "%%i"=="organize-files.bat" (
if not "%%i"=="organize-hub.ps1" (
if not "%%i"=="organize-simple.ps1" (
move "%%i" "Scripts\" 2>nul
echo   Moved: %%i
)
)
)
)
)

REM Move Admin/NoAdmin variants
echo [STEP 6] Moving Admin/NoAdmin variants...
for %%i in (*-Admin.bat) do (
if exist "%%i" (
move "%%i" "tools\Variants\" 2>nul
echo   Moved: %%i
)
)

for %%i in (*-NoAdmin.bat) do (
if exist "%%i" (
move "%%i" "tools\Variants\" 2>nul
echo   Moved: %%i
)
)

REM Move duplicate launcher files (keep main ones)
echo [STEP 7] Moving duplicate launcher files...
for %%i in (*LAUNCHER*.bat) do (
if exist "%%i" (
if not "%%i"=="DEVOPTIMIZER-HUB.bat" (
if not "%%i"=="DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat" (
move "%%i" "tools\Old-Launchers\" 2>nul
echo   Moved: %%i
)
)
)
)

REM Move emoji launchers
for %%i in (-*.bat) do (
if exist "%%i" (
move "%%i" "tools\Old-Launchers\" 2>nul
echo   Moved: %%i
)
)

for %%i in (-*.bat) do (
if exist "%%i" (
move "%%i" "tools\Old-Launchers\" 2>nul
echo   Moved: %%i
)
)

for %%i in (-*.bat) do (
if exist "%%i" (
move "%%i" "tools\Old-Launchers\" 2>nul
echo   Moved: %%i
)
)

for %%i in (-*.bat) do (
if exist "%%i" (
move "%%i" "tools\Old-Launchers\" 2>nul
echo   Moved: %%i
)
)

REM Count remaining files
echo [STEP 8] Checking remaining files...
set /a count=0
for %%i in (*.bat) do set /a count+=1

echo.
echo ========================================================================
echo                    ORGANIZATION COMPLETE!
echo ========================================================================
echo Remaining BAT files in root: %count%
echo Main launcher: DEVOPTIMIZER-HUB.bat
echo Alternative launcher: DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat
echo.
echo Hub is now organized with clean root directory!
pause
exit /b %ERRORLEVEL%
