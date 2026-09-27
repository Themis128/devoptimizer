@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title DevOptimizer Script Menu
color 0B
cls

:: Set the base directory
set "BASE_DIR=D:\DevOptimizer"
cd /d "%BASE_DIR%"

:MAIN_MENU
cls
echo.
echo ================================================================
echo              DEVOPTIMIZER SCRIPT MENU
echo ================================================================
echo.
echo Select a category:
echo.
echo   [1] Portable Scripts (Main Scripts)
echo   [2] Categories (Organized by Type)
echo   [3] Tools (Utility Scripts)
echo   [4] Scripts (PowerShell Scripts)
echo   [5] Generators (Menu/Script Generators)
echo.
echo   [0] Exit
echo.
set /p "choice=Enter your choice: "

if "%choice%"=="1" goto PORTABLE_MENU
if "%choice%"=="2" goto CATEGORIES_MENU
if "%choice%"=="3" goto TOOLS_MENU
if "%choice%"=="4" goto SCRIPTS_MENU
if "%choice%"=="5" goto GENERATORS_MENU
if "%choice%"=="0" goto END
goto MAIN_MENU

:PORTABLE_MENU
cls
echo.
echo ================================================================
echo              PORTABLE SCRIPTS
echo ================================================================
echo.
set "OPTION=1"
for %%f in ("%BASE_DIR%\portable\*.bat") do (
set "filename=%%~nf"
echo   [!OPTION!] !filename!
set /a OPTION+=1
)
echo.
echo   [0] Back to Main Menu
echo.
set /p "choice=Enter your choice: "
if "%choice%"=="0" goto MAIN_MENU

set "OPTION=1"
for %%f in ("%BASE_DIR%\portable\*.bat") do (
if "!OPTION!"=="%choice%" (
echo.
echo Running: %%~nf...
echo.
call "%%f"
echo.
pause
goto PORTABLE_MENU
)
set /a OPTION+=1
)
echo Invalid choice!
timeout /t 2 >nul
goto PORTABLE_MENU

:CATEGORIES_MENU
cls
echo.
echo ================================================================
echo              CATEGORIES
echo ================================================================
echo.
echo   [1] AWS
echo   [2] Development Tools
echo   [3] Health Checks
echo   [4] Launchers
echo   [5] Network Security
echo   [6] Office M365
echo   [7] Ollama
echo   [8] System Optimization
echo   [9] Uncategorized
echo   [10] Utilities
echo   [11] Windows Insider
echo.
echo   [0] Back to Main Menu
echo.
set /p "choice=Enter your choice: "

if "%choice%"=="1" goto CAT_AWS
if "%choice%"=="2" goto CAT_DEVTOOLS
if "%choice%"=="3" goto CAT_HEALTH
if "%choice%"=="4" goto CAT_LAUNCHERS
if "%choice%"=="5" goto CAT_NETWORK
if "%choice%"=="6" goto CAT_OFFICE
if "%choice%"=="7" goto CAT_OLLAMA
if "%choice%"=="8" goto CAT_SYSTEM
if "%choice%"=="9" goto CAT_UNCATEGORIZED
if "%choice%"=="10" goto CAT_UTILITIES
if "%choice%"=="11" goto CAT_INSIDER
if "%choice%"=="0" goto MAIN_MENU
goto CATEGORIES_MENU

:CAT_AWS
call :SHOW_CATEGORY "%BASE_DIR%\categories\aws" "AWS"
goto CATEGORIES_MENU

:CAT_DEVTOOLS
call :SHOW_CATEGORY "%BASE_DIR%\categories\development-tools" "Development Tools"
goto CATEGORIES_MENU

:CAT_HEALTH
call :SHOW_CATEGORY "%BASE_DIR%\categories\health-checks" "Health Checks"
goto CATEGORIES_MENU

:CAT_LAUNCHERS
call :SHOW_CATEGORY "%BASE_DIR%\categories\launchers" "Launchers"
goto CATEGORIES_MENU

:CAT_NETWORK
call :SHOW_CATEGORY "%BASE_DIR%\categories\network-security" "Network Security"
goto CATEGORIES_MENU

:CAT_OFFICE
call :SHOW_CATEGORY "%BASE_DIR%\categories\office-m365" "Office M365"
goto CATEGORIES_MENU

:CAT_OLLAMA
call :SHOW_CATEGORY "%BASE_DIR%\categories\ollama" "Ollama"
goto CATEGORIES_MENU

:CAT_SYSTEM
call :SHOW_CATEGORY "%BASE_DIR%\categories\system-optimization" "System Optimization"
goto CATEGORIES_MENU

:CAT_UNCATEGORIZED
call :SHOW_CATEGORY "%BASE_DIR%\categories\uncategorized" "Uncategorized"
goto CATEGORIES_MENU

:CAT_UTILITIES
call :SHOW_CATEGORY "%BASE_DIR%\categories\utilities" "Utilities"
goto CATEGORIES_MENU

:CAT_INSIDER
call :SHOW_CATEGORY "%BASE_DIR%\categories\windows-insider" "Windows Insider"
goto CATEGORIES_MENU

:SHOW_CATEGORY
set "CAT_PATH=%~1"
set "CAT_NAME=%~2"
cls
echo.
echo ================================================================
echo              %CAT_NAME%
echo ================================================================
echo.
set "OPTION=1"
for %%f in ("%CAT_PATH%\*.bat") do (
set "filename=%%~nf"
echo   [!OPTION!] !filename!
set /a OPTION+=1
)
echo.
echo   [0] Back
echo.
set /p "choice=Enter your choice: "
if "%choice%"=="0" exit /b

set "OPTION=1"
for %%f in ("%CAT_PATH%\*.bat") do (
if "!OPTION!"=="%choice%" (
echo.
echo Running: %%~nf...
echo.
call "%%f"
echo.
pause
exit /b
)
set /a OPTION+=1
)
echo Invalid choice!
timeout /t 2 >nul
exit /b

:TOOLS_MENU
cls
echo.
echo ================================================================
echo              TOOLS
echo ================================================================
echo.
set "OPTION=1"
for %%f in ("%BASE_DIR%\tools\*.bat" "%BASE_DIR%\tools\*.ps1") do (
set "filename=%%~nf"
set "ext=%%~xf"
echo   [!OPTION!] !filename!!ext!
set /a OPTION+=1
)
echo.
echo   [0] Back to Main Menu
echo.
set /p "choice=Enter your choice: "
if "%choice%"=="0" goto MAIN_MENU

set "OPTION=1"
for %%f in ("%BASE_DIR%\tools\*.bat" "%BASE_DIR%\tools\*.ps1") do (
if "!OPTION!"=="%choice%" (
echo.
echo Running: %%~nf%%~xf...
echo.
if "%%~xf"==".bat" (
call "%%f"
) else (
powershell -ExecutionPolicy Bypass -File "%%f"
)
echo.
pause
goto TOOLS_MENU
)
set /a OPTION+=1
)
echo Invalid choice!
timeout /t 2 >nul
goto TOOLS_MENU

:SCRIPTS_MENU
cls
echo.
echo ================================================================
echo              SCRIPTS (PowerShell)
echo ================================================================
echo.
set "OPTION=1"
for %%f in ("%BASE_DIR%\scripts\*.ps1") do (
set "filename=%%~nf"
echo   [!OPTION!] !filename!
set /a OPTION+=1
)
echo.
echo   [0] Back to Main Menu
echo.
set /p "choice=Enter your choice: "
if "%choice%"=="0" goto MAIN_MENU

set "OPTION=1"
for %%f in ("%BASE_DIR%\scripts\*.ps1") do (
if "!OPTION!"=="%choice%" (
echo.
echo Running: %%~nf...
echo.
powershell -ExecutionPolicy Bypass -File "%%f"
echo.
pause
goto SCRIPTS_MENU
)
set /a OPTION+=1
)
echo Invalid choice!
timeout /t 2 >nul
goto SCRIPTS_MENU

:GENERATORS_MENU
cls
echo.
echo ================================================================
echo              GENERATORS
echo ================================================================
echo.
if exist "%BASE_DIR%\generators\MENU-GENERATOR.bat" (
echo   [1] Menu Generator
)
if exist "%BASE_DIR%\generators\SCRIPT-GENERATOR.bat" (
echo   [2] Script Generator
)
echo.
echo   [0] Back to Main Menu
echo.
set /p "choice=Enter your choice: "

if "%choice%"=="1" (
if exist "%BASE_DIR%\generators\MENU-GENERATOR.bat" (
call "%BASE_DIR%\generators\MENU-GENERATOR.bat"
pause
)
)
if "%choice%"=="2" (
if exist "%BASE_DIR%\generators\SCRIPT-GENERATOR.bat" (
call "%BASE_DIR%\generators\SCRIPT-GENERATOR.bat"
pause
)
)
if "%choice%"=="0" goto MAIN_MENU
goto GENERATORS_MENU

:END
cls
echo.
echo Thank you for using DevOptimizer!
echo.
timeout /t 2 >nul
exit /b
