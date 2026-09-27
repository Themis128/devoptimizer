@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Create Desktop Shortcuts - DevOptimizer
color 0A
echo.
echo ================================================================
echo                CREATE DESKTOP SHORTCUTS
echo ================================================================
echo.
echo Creating desktop shortcuts for easy UI access...
echo.

set "DESKTOP=%USERPROFILE%\Desktop"

echo [1/5] Creating Universal Launcher shortcut...
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP%\DevOptimizer Universal Launcher.lnk'); $Shortcut.TargetPath = 'D:\DevOptimizer\UNIVERSAL-LAUNCHER.bat'; $Shortcut.WorkingDirectory = 'D:\DevOptimizer'; $Shortcut.Description = 'DevOptimizer Universal Launcher - Main UI'; $Shortcut.Save()"
if %errorlevel% equ 0 (
echo    Universal Launcher shortcut created
) else (
echo    Failed to create Universal Launcher shortcut
)

echo.
echo [2/5] Creating Admin Mode shortcut...
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP%\DevOptimizer Admin Mode.lnk'); $Shortcut.TargetPath = 'powershell.exe'; $Shortcut.Arguments = '-ExecutionPolicy Bypass -File \"D:\DevOptimizer\RUN-AS-ADMIN.bat\"'; $Shortcut.WorkingDirectory = 'D:\DevOptimizer'; $Shortcut.Description = 'DevOptimizer Admin Mode - Full Features'; $Shortcut.Save()"
if %errorlevel% equ 0 (
echo    Admin Mode shortcut created
) else (
echo    Failed to create Admin Mode shortcut
)

echo.
echo [3/5] Creating System Health Check shortcut...
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP%\DevOptimizer System Health.lnk'); $Shortcut.TargetPath = 'D:\DevOptimizer\06-System-Health-Check.bat'; $Shortcut.WorkingDirectory = 'D:\DevOptimizer'; $Shortcut.Description = 'DevOptimizer System Health Check'; $Shortcut.Save()"
if %errorlevel% equ 0 (
echo    System Health Check shortcut created
) else (
echo    Failed to create System Health Check shortcut
)

echo.
echo [4/5] Creating Quick Optimization shortcut...
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP%\DevOptimizer Quick Optimization.lnk'); $Shortcut.TargetPath = 'D:\DevOptimizer\01-Quick-Optimization.bat'; $Shortcut.WorkingDirectory = 'D:\DevOptimizer'; $Shortcut.Description = 'DevOptimizer Quick Optimization'; $Shortcut.Save()"
if %errorlevel% equ 0 (
echo    Quick Optimization shortcut created
) else (
echo    Failed to create Quick Optimization shortcut
)

echo.
echo [5/5] Creating Quick UI Access shortcut...
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP%\DevOptimizer Quick Access.lnk'); $Shortcut.TargetPath = 'D:\DevOptimizer\QUICK-UI-ACCESS.bat'; $Shortcut.WorkingDirectory = 'D:\DevOptimizer'; $Shortcut.Description = 'DevOptimizer Quick UI Access - All Options'; $Shortcut.Save()"
if %errorlevel% equ 0 (
echo    Quick UI Access shortcut created
) else (
echo    Failed to create Quick UI Access shortcut
)

echo.
echo ================================================================
echo                    SHORTCUTS CREATED!
echo ================================================================
echo.
echo Desktop shortcuts have been created for:
echo - DevOptimizer Universal Launcher
echo - DevOptimizer Admin Mode
echo - DevOptimizer System Health
echo - DevOptimizer Quick Optimization
echo - DevOptimizer Quick Access
echo.
echo You can now double-click any shortcut on your desktop
echo to access the DevOptimizer UI!
echo.
echo Press any key to continue...
pause >nul
exit /b 0
