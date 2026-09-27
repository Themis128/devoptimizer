@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title  UI Access Guide - DevOptimizer
color 0F
echo.
echo ================================================================
echo                     UI ACCESS GUIDE
echo ================================================================
echo.
echo  MAIN UI ACCESS SCRIPTS (Color Coded):
echo ================================================================
echo.
echo  UNIVERSAL-LAUNCHER.bat        - Main menu interface (Blue)
echo  QUICK-UI-ACCESS.bat           - Quick key-based access (Yellow)
echo  OPEN-UI-NEW-WINDOW.bat        - Open UIs in new windows (Green)
echo  CREATE-DESKTOP-SHORTCUTS.bat  - Create desktop shortcuts (Purple)
echo.
echo ================================================================
echo.
echo  ORIGINAL SCRIPTS (Standard):
echo ================================================================
echo.
echo UNIVERSAL-LAUNCHER.bat           - Original version
echo QUICK-UI-ACCESS.bat              - Original version
echo OPEN-UI-NEW-WINDOW.bat           - Original version
echo CREATE-DESKTOP-SHORTCUTS.bat     - Original version
echo.
echo ================================================================
echo.
echo  SYSTEM OPTIMIZATION SCRIPTS:
echo ================================================================
echo.
echo 01-Quick-Optimization.bat        - Quick system optimization
echo 02-Ultra-Performance.bat         - Maximum performance
echo 06-System-Health-Check.bat       - System health analysis
echo 09-System-Deep-Clean.bat         - Deep system cleanup
echo.
echo ================================================================
echo.
echo  DEVELOPMENT TOOLS:
echo ================================================================
echo.
echo 03-Install-Dev-Tools.bat         - Install development tools
echo 014-Cursor-AI-Optimization.bat   - Cursor AI optimization
echo 015-VSCode-Optimization.bat      - VS Code optimization
echo 16-Nuxt3-Windows-Optimization.bat - Nuxt3 optimization
echo.
echo ================================================================
echo.
echo Press any key to open the main UI...
pause >nul
start "DevOptimizer Universal Launcher" cmd /k "D:\DevOptimizer\-UNIVERSAL-LAUNCHER.bat"
exit /b 0
