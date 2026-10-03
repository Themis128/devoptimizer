:: SYNOPSIS: DevOptimizer automation script: admin-cleanup-run-as-admin.
@echo off
title Windows 11 Admin Cleanup - Run as Administrator
echo ============================================================
echo  Windows 11 Admin Cleanup - Requires Administrator Rights
echo ============================================================
echo.
echo This script will run:
echo   1. DISM Component Store Cleanup
echo   2. Windows Update Download Cache Cleanup
echo   3. Delivery Optimization Cache Cleanup
echo   4. Oldest Shadow Copy Removal
echo   5. Windows.old folder (if exists)
echo.
echo Press any key to continue...
pause >nul

echo.
echo [1/5] DISM Component Store Cleanup...
echo This may take several minutes...
C:\Windows\System32\Dism.exe /Online /Cleanup-Image /StartComponentCleanup /NoRestart
echo DISM Exit Code: %ERRORLEVEL%
echo.

echo [2/5] Windows Update Download Cache...
net stop wuauserv >nul 2>&1
timeout /t 2 >nul
if exist C:\Windows\SoftwareDistribution\Download (
    for /d %%i in (C:\Windows\SoftwareDistribution\Download\*) do rd /s /q "%%i" 2>nul
    for %%f in (C:\Windows\SoftwareDistribution\Download\*) do del /f /q "%%f" 2>nul
    echo Windows Update cache cleared.
) else (
    echo Windows Update cache folder not found.
)
net start wuauserv >nul 2>&1
echo.

echo [3/5] Delivery Optimization Cache...
powershell.exe -Command "Delete-DeliveryOptimizationCache" 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Delivery Optimization cache cleared.
) else (
    echo Delivery Optimization cache: skipped (may not be available)
)
echo.

echo [4/5] Oldest Shadow Copy...
vssadmin delete shadows /for=c: /oldest /quiet
if %ERRORLEVEL% EQU 0 (
    echo Oldest shadow copy deleted.
) else (
    echo No shadow copies to delete or access denied.
)
echo.

echo [5/5] Windows.old folder...
if exist C:\Windows.old (
    echo Found Windows.old - removing (this may take a while)...
    takeown /f C:\Windows.old /r /d y >nul 2>&1
    icacls C:\Windows.old /grant administrators:F /t /c /q >nul 2>&1
    rd /s /q C:\Windows.old 2>nul
    echo Windows.old removed.
) else (
    echo Windows.old not found.
)
echo.

echo ============================================================
echo  Admin Cleanup Complete
echo ============================================================
echo.
echo A reboot is recommended after DISM operations.
echo Press any key to exit...
pause >nul