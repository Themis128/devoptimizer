@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Development Cache Cleaner - Comprehensive Development Cache Management
color 0C 
echo.
echo
echo
echo DEVELOPMENT CACHE CLEANER v1.0
echo Comprehensive Development Cache Management
echo
echo echo.
echo This tool provides comprehensive cache clearing for development: echo.
echo QUICK CLEAN:
echo 1) Quick Dev Cache Clean - Fast cleanup of common dev caches
echo 2) Node.js Cache Clean - npm, pnpm, yarn caches
echo 3) Python Cache Clean - pip, conda, pycache cleanup echo.
echo DEVELOPMENT TOOLS:
echo 4) IDE Cache Clean - VS Code, Cursor, JetBrains caches
echo 5) Git Cache Clean - Git objects and refs cleanup
echo 6) Docker Cache Clean - Docker images, containers, volumes echo.
echo PACKAGE MANAGERS:
echo 7) All Package Managers - npm, pnpm, yarn, pip, conda
echo 8) Build Tools Cache - Webpack, Vite, Rollup caches
echo 9) Framework Caches - Next.js, Nuxt, React, Vue caches echo.
echo SPECIALIZED:
echo 10) AI/ML Cache Clean - TensorFlow, PyTorch, Jupyter caches
echo 11) Database Cache Clean - PostgreSQL, MongoDB, Redis caches
echo 12) System Dev Cache Clean - Windows dev-related caches echo.
echo COMPREHENSIVE:
echo 13) Complete Dev Cache Clean - All development caches (SLOW)
echo 14) Smart Cache Clean - Intelligent cache analysis & cleanup echo.
echo CONFIGURATION:
echo 15) Configure Cache Cleaner - Set up automatic cache cleaning
echo 16) View Cache Sizes - Analyze cache usage echo.
echo SAFETY MODES:
echo 17) Dry Run Mode - Test without deleting files
echo 18) Backup Mode - Create backups before cleaning
echo 19) Force Mode - Skip safety checks (DANGEROUS) echo.
echo SYSTEM TOOLS:
echo 20) Check Prerequisites - Verify system requirements echo. set /p choice="Select cache cleaning option (1-20): " if "%choice%"=="1" ( echo.
echo Launching Quick Dev Cache Clean... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -QuickClean ) else if "%choice%"=="2" ( echo.
echo Cleaning Node.js Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -NodeJSClean ) else if "%choice%"=="3" ( echo.
echo Cleaning Python Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -PythonClean ) else if "%choice%"=="4" ( echo.
echo Cleaning IDE Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -IDEClean ) else if "%choice%"=="5" ( echo.
echo Cleaning Git Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -GitClean ) else if "%choice%"=="6" ( echo.
echo Cleaning Docker Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -DockerClean ) else if "%choice%"=="7" ( echo.
echo Cleaning All Package Managers... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -PackageManagersClean ) else if "%choice%"=="8" ( echo.
echo Cleaning Build Tools Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -BuildToolsClean ) else if "%choice%"=="9" ( echo.
echo Cleaning Framework Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -FrameworkClean ) else if "%choice%"=="10" ( echo.
echo Cleaning AI/ML Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -AIMLClean ) else if "%choice%"=="11" ( echo.
echo Cleaning Database Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -DatabaseClean ) else if "%choice%"=="12" ( echo.
echo Cleaning System Dev Caches... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -SystemDevClean ) else if "%choice%"=="13" ( echo.
echo Launching Complete Dev Cache Clean... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -CompleteClean ) else if "%choice%"=="14" ( echo.
echo Launching Smart Cache Clean... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -SmartClean ) else if "%choice%"=="15" ( echo.
echo Opening Cache Cleaner Configuration... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -Configure ) else if "%choice%"=="16" ( echo.
echo Analyzing Cache Usage... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -Analyze ) else if "%choice%"=="17" ( echo.
echo Launching Dry Run Mode... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -QuickClean -DryRun ) else if "%choice%"=="18" ( echo.
echo Launching Backup Mode... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -QuickClean -Backup ) else if "%choice%"=="19" ( echo.
echo WARNING: Force Mode is DANGEROUS!
echo This will skip all safety checks. set /p confirm="Are you sure? Type 'YES' to continue: " if "%confirm%"=="YES" ( echo.
echo Launching Force Mode... powershell -ExecutionPolicy Bypass -File "%~dp0dev-cache-cleaner.ps1" -CompleteClean -Force ) else ( echo.
echo Operation cancelled. pause exit /b 0 ) ) else if "%choice%"=="20" ( echo.
echo Checking prerequisites... powershell -ExecutionPolicy Bypass -File "%~dp0prerequisites-checker.ps1" -CheckOnly ) else ( echo.
echo Invalid choice! Please enter a number from 1-20. pause exit /b 1 ) echo.
echo Development Cache Cleaner completed! echo. pause
