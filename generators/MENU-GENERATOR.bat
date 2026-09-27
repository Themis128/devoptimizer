@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title DevOptimizer Menu Generator v4.0
color 0D

echo.
echo 
echo                                                               
echo       DEVOPTIMIZER MENU GENERATOR v4.0                     
echo          Automatic Dynamic Menu Creation System              
echo                                                               
echo 
echo.

echo  SCANNING SYSTEM FOR SCRIPTS...
echo =================================
echo.

:: Initialize counters
set "TOTAL_SCRIPTS=0"
set "TOTAL_CATEGORIES=0"

:: Scan categories directory
if exist "..\categories" (
echo  Categories directory found

for /d %%d in (..\categories\*) do (
set "CATEGORY_NAME=%%~nd"
set "SCRIPT_COUNT=0"

echo    Scanning category: !CATEGORY_NAME!

for %%f in ("%%d\*.bat" "%%d\*.ps1") do (
set /a SCRIPT_COUNT+=1
set /a TOTAL_SCRIPTS+=1
)

if !SCRIPT_COUNT! GTR 0 (
set /a TOTAL_CATEGORIES+=1
echo      Found !SCRIPT_COUNT! scripts
) else (
echo      No scripts found
)
)
) else (
echo  Categories directory not found!
echo Please run the system setup first.
pause
exit /b 1
)

echo.
echo  SCAN RESULTS:
echo   Total Categories: %TOTAL_CATEGORIES%
echo   Total Scripts: %TOTAL_SCRIPTS%
echo.

if %TOTAL_SCRIPTS% EQU 0 (
echo   No scripts found to generate menus for!
echo Use the Script Generator to create some scripts first.
pause
exit /b 1
)

echo   GENERATING DYNAMIC MENU SYSTEM...
echo ====================================
echo.

:: Generate main launcher menu
set "MAIN_MENU=..\00-DYNAMIC-LAUNCHER.bat"
echo Creating main launcher: %MAIN_MENU%

> "%MAIN_MENU%" (
echo @echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
echo setlocal enabledelayedexpansion
echo title DevOptimizer Dynamic Launcher v4.0
echo color 0B
echo.
echo echo.
echo echo 
echo echo                                                               
echo echo      DEVOPTIMIZER DYNAMIC LAUNCHER v4.0                    
echo echo          Auto-Generated Menu System                          
echo echo                                                               
echo echo 
echo echo.
echo echo Generated on: %date% %time%
echo echo Total Scripts Available: %TOTAL_SCRIPTS%
echo echo.
echo echo Select a category to explore:
echo echo.
)

:: Add category options to main menu
set "OPTION_NUM=1"
for /d %%d in (..\categories\*) do (
set "CATEGORY_NAME=%%~nd"
set "SCRIPT_COUNT=0"

:: Count scripts in this category
for %%f in ("%%d\*.bat" "%%d\*.ps1") do (
set /a SCRIPT_COUNT+=1
)

if !SCRIPT_COUNT! GTR 0 (
:: Add category to main menu
>> "%MAIN_MENU%" (
echo echo   !OPTION_NUM!^) !CATEGORY_NAME! ^(!SCRIPT_COUNT! scripts^)
)

:: Generate category-specific menu
call :GenerateCategoryMenu "!CATEGORY_NAME!" "%%d"

set /a OPTION_NUM+=1
)
)

:: Complete main menu
>> "%MAIN_MENU%" (
echo echo.
echo echo   0^) Exit
echo echo.
echo echo   NOTE: Some tools may require Administrator privileges!
echo echo    Right-click and "Run as administrator" if needed.
echo echo.
echo.
echo set /p choice="Enter your choice (0-%TOTAL_CATEGORIES%): "
echo.
)

:: Add menu logic
set "OPTION_NUM=1"
for /d %%d in (..\categories\*) do (
set "CATEGORY_NAME=%%~nd"
set "SCRIPT_COUNT=0"

for %%f in ("%%d\*.bat" "%%d\*.ps1") do (
set /a SCRIPT_COUNT+=1
)

if !SCRIPT_COUNT! GTR 0 (
>> "%MAIN_MENU%" (
echo if "%%choice%%"=="!OPTION_NUM!" ^(
echo     echo.
echo     echo Launching !CATEGORY_NAME! menu...
echo     call "%%~dp0!CATEGORY_NAME!-menu.bat"
echo ^)
)
set /a OPTION_NUM+=1
)
)

>> "%MAIN_MENU%" (
echo if "%%choice%%"=="0" ^(
echo     echo.
echo     echo Goodbye! 
echo     exit /b 0
echo ^) else ^(
echo     echo.
echo     echo  Invalid choice! Please enter a number from 0-%TOTAL_CATEGORIES%.
echo     echo.
echo     pause
echo     goto :eof
echo ^)
echo.
echo echo.
echo echo Press any key to return to launcher or close this window...
echo pause ^>nul
echo "%%~f0"
echo.
echo endlocal
)

echo  Main launcher created: %MAIN_MENU%

echo.
echo  MENU GENERATION COMPLETED!
echo =============================
echo.
echo Generated Files:
echo    Main Launcher: 00-DYNAMIC-LAUNCHER.bat
for /d %%d in (..\categories\*) do (
set "CATEGORY_NAME=%%~nd"
if exist "..\!CATEGORY_NAME!-menu.bat" (
echo    Category Menu: !CATEGORY_NAME!-menu.bat
)
)

echo.
echo  USAGE INSTRUCTIONS:
echo   1. Run 00-DYNAMIC-LAUNCHER.bat to access all scripts
echo   2. Navigate through categories using the numbered menu
echo   3. Select individual scripts to execute them
echo   4. Re-run this generator when you add new scripts
echo.

echo  Would you like to test the generated menu system?
set /p "TEST_MENU=Test now? (y/N): "
if /i "%TEST_MENU%"=="y" (
echo.
echo Launching dynamic menu system...
call "%MAIN_MENU%"
)

echo.
echo Thank you for using DevOptimizer Menu Generator! 
pause
goto :EOF

:GenerateCategoryMenu
set "CAT_NAME=%~1"
set "CAT_PATH=%~2"
set "CAT_MENU=..\%CAT_NAME%-menu.bat"

echo   Creating category menu: %CAT_MENU%

> "%CAT_MENU%" (
echo @echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
echo setlocal enabledelayedexpansion
echo title %CAT_NAME% - DevOptimizer Category Menu
echo color 0B
echo.
echo echo.
echo echo 
echo echo                                                               
echo echo      %CAT_NAME% CATEGORY MENU                               
echo echo                                                               
echo echo 
echo echo.
echo echo Available scripts in %CAT_NAME%:
echo echo.
)

:: Add scripts to category menu
set "SCRIPT_NUM=1"
for %%f in ("%CAT_PATH%\*.bat" "%CAT_PATH%\*.ps1") do (
set "SCRIPT_FILE=%%~nf"
set "SCRIPT_EXT=%%~xf"

>> "%CAT_MENU%" (
echo echo   !SCRIPT_NUM!^) !SCRIPT_FILE!!SCRIPT_EXT!
)
set /a SCRIPT_NUM+=1
)

>> "%CAT_MENU%" (
echo echo.
echo echo   0^) Return to main menu
echo echo.
echo set /p choice="Enter your choice (0-!SCRIPT_NUM!): "
echo.
)

:: Add execution logic
set "SCRIPT_NUM=1"
for %%f in ("%CAT_PATH%\*.bat" "%CAT_PATH%\*.ps1") do (
set "SCRIPT_FILE=%%~nxf"
set "SCRIPT_EXT=%%~xf"

>> "%CAT_MENU%" (
echo if "%%choice%%"=="!SCRIPT_NUM!" ^(
echo     echo.
echo     echo Launching !SCRIPT_FILE!...
if "!SCRIPT_EXT!"==".bat" (
echo     call "%%~dp0categories\%CAT_NAME%\!SCRIPT_FILE!"
) else (
echo     powershell -ExecutionPolicy Bypass -File "%%~dp0categories\%CAT_NAME%\!SCRIPT_FILE!"
)
echo ^)
)
set /a SCRIPT_NUM+=1
)

>> "%CAT_MENU%" (
echo if "%%choice%%"=="0" ^(
echo     echo.
echo     echo Returning to main menu...
echo     call "%%~dp000-DYNAMIC-LAUNCHER.bat"
echo ^) else ^(
echo     echo.
echo     echo  Invalid choice!
echo     echo.
echo     pause
echo     goto :eof
echo ^)
echo.
echo endlocal
)

goto :EOF

endlocal
