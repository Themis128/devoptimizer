@echo off
echo ================================================================
echo  DevOptimizer Elevated Cleanup - Scheduled Task Creator
echo ================================================================
echo.
echo This will create a scheduled task that runs every 15 days as SYSTEM
echo (highest privileges) to perform admin-level cleanup:
echo   - DISM Component Store Cleanup
echo   - Windows Update cache
echo   - Delivery Optimization cache
echo   - System Restore Points (oldest)
echo   - WSL VHDX Compaction
echo.
echo REQUIRES: Administrator privileges
echo.
pause

:: Check if running as admin
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running as Administrator
) else (
    echo [ERROR] Not running as Administrator!
    echo Please right-click this file and select "Run as Administrator"
    pause
    exit /b 1
)

:: Create the scheduled task
schtasks /create /tn "DevOptimizer-Elevated-Cleanup" `
    /tr "powershell.exe -ExecutionPolicy Bypass -File \"D:\DevOptimizer\scripts\elevated-complete-cleanup.ps1\"" `
    /sc daily /mo 15 /st 03:00 /ru SYSTEM /rl HIGHEST /f

if %errorLevel% == 0 (
    echo.
    echo [SUCCESS] Scheduled task created!
    echo.
    echo Task Details:
    schtasks /query /tn "DevOptimizer-Elevated-Cleanup" /v /fo list
) else (
    echo.
    echo [ERROR] Failed to create scheduled task
)
pause
