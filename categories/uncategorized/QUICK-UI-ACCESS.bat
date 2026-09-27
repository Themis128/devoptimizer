@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title  Quick UI Access - DevOptimizer
color 0E
echo.
echo ================================================================
echo                     QUICK UI ACCESS
echo ================================================================
echo.
echo Press a key to open the corresponding UI:
echo.
echo [1] Universal Launcher (Menu Interface)
echo [2] Admin Mode (Full Features)
echo [3] System Health Check
echo [4] Quick Optimization
echo [5] All UIs (Multiple Windows)
echo [ESC] Exit
echo.
echo Waiting for key press...

:wait
choice /c 12345 /n /m "Press 1-5 or ESC to exit: "
if errorlevel 5 goto :all
if errorlevel 4 goto :optimization
if errorlevel 3 goto :health
if errorlevel 2 goto :admin
if errorlevel 1 goto :universal
goto :exit

:universal
echo Opening Universal Launcher...
start "DevOptimizer Universal Launcher" cmd /k "D:\DevOptimizer\UNIVERSAL-LAUNCHER.bat"
goto :end

:admin
echo Opening Admin Mode...
start "DevOptimizer Admin Mode" powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\RUN-AS-ADMIN.bat"
goto :end

:health
echo Opening System Health Check...
start "System Health Check" cmd /k "D:\DevOptimizer\06-System-Health-Check.bat"
goto :end

:optimization
echo Opening Quick Optimization...
start "Quick Optimization" cmd /k "D:\DevOptimizer\01-Quick-Optimization.bat"
goto :end

:all
echo Opening all UI components...
start "DevOptimizer Universal Launcher" cmd /k "D:\DevOptimizer\UNIVERSAL-LAUNCHER.bat"
timeout /t 1 /nobreak >nul
start "DevOptimizer Admin Mode" powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\RUN-AS-ADMIN.bat"
timeout /t 1 /nobreak >nul
start "System Health Check" cmd /k "D:\DevOptimizer\06-System-Health-Check.bat"
timeout /t 1 /nobreak >nul
start "Quick Optimization" cmd /k "D:\DevOptimizer\01-Quick-Optimization.bat"
goto :end

:end
echo.
echo UI opened successfully!
echo.
pause
goto :wait

:exit
exit /b 0
