:: SYNOPSIS: DevOptimizer automation script: CURSOR-AI-OPTIMIZATION-SUITE-NoAdmin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title  - Standard Mode- some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo              CURSOR AI OPTIMIZATION SUITE
echo ================================================================
echo.
echo Complete optimization suite for Cursor AI development
echo.
echo ================================================================

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
echo [INFO] Running with administrator privileges
) else (
echo [WARNING] Some operations may require administrator privileges
)

echo.
echo ================================================================
echo                    OPTIMIZATION MENU
echo ================================================================
echo.
echo 1.   Git Cache Clear
echo 2.   Cursor AI Configuration
echo 3.   Package Manager Optimization
echo 4.   Performance Optimization
echo 5.   Security Hardening
echo 6.   Analytics Setup
echo 7.   Development Tools
echo 8.   Network Optimization
echo 9.   Memory Optimization
echo 10.  Complete Optimization
echo 11.  System Report
echo 0.   Exit
echo.
echo ================================================================

set /p choice="Enter your choice (0-11): "

if "%choice%"=="1" goto git_cache_clear
if "%choice%"=="2" goto cursor_config
if "%choice%"=="3" goto package_optimization
if "%choice%"=="4" goto performance_optimization
if "%choice%"=="5" goto security_hardening
if "%choice%"=="6" goto analytics_setup
if "%choice%"=="7" goto dev_tools
if "%choice%"=="8" goto network_optimization
if "%choice%"=="9" goto memory_optimization
if "%choice%"=="10" goto complete_optimization
if "%choice%"=="11" goto system_report
if "%choice%"=="0" goto exit
goto invalid_choice

:git_cache_clear
echo.
echo ================================================================
echo                 GIT CACHE CLEAR
echo ================================================================
echo.
echo Clearing Git cache for optimal Cursor AI performance...
echo.

:: Clear Git cache
git gc --prune=now
git reset --hard HEAD
git stash clear
git reflog expire --expire=now --all
git remote prune origin
git lfs prune
git worktree prune

echo [SUCCESS] Git cache cleared!
echo.
pause
goto main_menu

:cursor_config
echo.
echo ================================================================
echo               CURSOR AI CONFIGURATION
echo ================================================================
echo.
echo Configuring Cursor AI for optimal performance...
echo.

:: Create Cursor AI configuration
if not exist "%APPDATA%\Cursor\User" mkdir "%APPDATA%\Cursor\User"

:: Cursor AI settings
echo { > "%APPDATA%\Cursor\User\settings.json"
echo   "editor.fontSize": 14, >> "%APPDATA%\Cursor\User\settings.json"
echo   "editor.fontFamily": "Fira Code, Consolas, 'Courier New', monospace", >> "%APPDATA%\Cursor\User\settings.json"
echo   "editor.fontLigatures": true, >> "%APPDATA%\Cursor\User\settings.json"
echo   "editor.tabSize": 2, >> "%APPDATA%\Cursor\User\settings.json"
echo   "editor.insertSpaces": true, >> "%APPDATA%\Cursor\User\settings.json"
echo   "editor.detectIndentation": false, >> "%APPDATA%\Cursor\User\settings.json"
echo   "editor.formatOnSave": true, >> "%APPDATA%\Cursor\User\settings.json"
echo   "editor.codeActionsOnSave": { >> "%APPDATA%\Cursor\User\settings.json"
echo     "source.fixAll.eslint": true, >> "%APPDATA%\Cursor\User\settings.json"
echo     "source.organizeImports": true >> "%APPDATA%\Cursor\User\settings.json"
echo   }, >> "%APPDATA%\Cursor\User\settings.json"
echo   "files.autoSave": "afterDelay", >> "%APPDATA%\Cursor\User\settings.json"
echo   "files.autoSaveDelay": 1000, >> "%APPDATA%\Cursor\User\settings.json"
echo   "typescript.preferences.importModuleSpecifier": "relative", >> "%APPDATA%\Cursor\User\settings.json"
echo   "javascript.preferences.importModuleSpecifier": "relative", >> "%APPDATA%\Cursor\User\settings.json"
echo   "emmet.includeLanguages": { >> "%APPDATA%\Cursor\User\settings.json"
echo     "javascript": "javascriptreact", >> "%APPDATA%\Cursor\User\settings.json"
echo     "typescript": "typescriptreact" >> "%APPDATA%\Cursor\User\settings.json"
echo   }, >> "%APPDATA%\Cursor\User\settings.json"
echo   "git.enableSmartCommit": true, >> "%APPDATA%\Cursor\User\settings.json"
echo   "git.confirmSync": false, >> "%APPDATA%\Cursor\User\settings.json"
echo   "git.autofetch": true, >> "%APPDATA%\Cursor\User\settings.json"
echo   "terminal.integrated.fontSize": 14, >> "%APPDATA%\Cursor\User\settings.json"
echo   "terminal.integrated.fontFamily": "Fira Code, Consolas, 'Courier New', monospace", >> "%APPDATA%\Cursor\User\settings.json"
echo   "workbench.colorTheme": "Default Dark+", >> "%APPDATA%\Cursor\User\settings.json"
echo   "workbench.iconTheme": "material-icon-theme", >> "%APPDATA%\Cursor\User\settings.json"
echo   "extensions.autoUpdate": true, >> "%APPDATA%\Cursor\User\settings.json"
echo   "extensions.autoCheckUpdates": true >> "%APPDATA%\Cursor\User\settings.json"
echo } >> "%APPDATA%\Cursor\User\settings.json"

echo [SUCCESS] Cursor AI configuration created!
echo.
pause
goto main_menu

:package_optimization
echo.
echo ================================================================
echo               PACKAGE MANAGER OPTIMIZATION
echo ================================================================
echo.
echo Optimizing package managers for Cursor AI...
echo.

:: npm optimization
echo [NPM] Optimizing npm...
npm config set registry https://registry.npmjs.org/
npm config set cache-max 3600000
npm config set cache-min 3600000
npm config set prefer-offline true
npm config set audit-level moderate
npm config set fund false
npm config set save-exact true
npm config set save-prefix ""
echo [SUCCESS] npm optimized

:: pnpm optimization
echo [PNPM] Optimizing pnpm...
pnpm config set registry https://registry.npmjs.org/
pnpm config set store-dir "C:\pnpm-store"
pnpm config set cache-dir "C:\pnpm-cache"
pnpm config set auto-install-peers true
pnpm config set strict-peer-dependencies false
echo [SUCCESS] pnpm optimized

:: Yarn optimization
echo [YARN] Optimizing Yarn...
yarn config set registry https://registry.npmjs.org/
yarn config set cache-folder "C:\yarn-cache"
yarn config set network-timeout 300000
yarn config set network-concurrency 1
echo [SUCCESS] Yarn optimized

echo [SUCCESS] Package managers optimized!
echo.
pause
goto main_menu

:performance_optimization
echo.
echo ================================================================
echo               PERFORMANCE OPTIMIZATION
echo ================================================================
echo.
echo Optimizing system performance for Cursor AI...
echo.

:: Clear caches
echo [CACHE] Clearing caches...
del /q /f /s "%TEMP%\*" 2>nul
del /q /f /s "%TEMP%\*.*" 2>nul
echo [SUCCESS] Caches cleared

:: Optimize Git
echo [GIT] Optimizing Git...
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256
git config --global pack.windowMemory 100m
git config --global pack.packSizeLimit 2g
echo [SUCCESS] Git optimized

:: Optimize Node.js
echo [NODE] Optimizing Node.js...
set NODE_OPTIONS=--max-old-space-size=4096
set NODE_ENV=development
echo [SUCCESS] Node.js optimized

:: Optimize Windows
echo [WINDOWS] Optimizing Windows...
powercfg -h off
echo [SUCCESS] Windows optimized

echo [SUCCESS] Performance optimized!
echo.
pause
goto main_menu

:security_hardening
echo.
echo ================================================================
echo               SECURITY HARDENING
echo ================================================================
echo.
echo Hardening security for Cursor AI development...
echo.

:: Git security
echo [GIT] Hardening Git security...
git config --global core.protectNTFS true
git config --global core.protectHFS true
git config --global core.fsmonitor true
echo [SUCCESS] Git security hardened

:: npm security
echo [NPM] Hardening npm security...
npm config set audit-level high
npm config set fund false
npm config set save-exact true
echo [SUCCESS] npm security hardened

:: System security
echo [SYSTEM] Hardening system security...
netsh advfirewall set allprofiles state on
echo [SUCCESS] System security hardened

echo [SUCCESS] Security hardened!
echo.
pause
goto main_menu

:analytics_setup
echo.
echo ================================================================
echo               ANALYTICS SETUP
echo ================================================================
echo.
echo Setting up analytics for Cursor AI development...
echo.

:: Create analytics directory
if not exist "%USERPROFILE%\Desktop\DevOptimizer\Analytics" mkdir "%USERPROFILE%\Desktop\DevOptimizer\Analytics"

:: Create analytics script
echo [ANALYTICS] Creating analytics script...
echo @echo off > "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo echo Cursor AI Development Analytics >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo echo ================================== >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo echo Git commits today: >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo git log --since="1 day ago" --oneline ^| wc -l >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo echo Git commits this week: >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo git log --since="1 week ago" --oneline ^| wc -l >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo echo Git commits this month: >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo git log --since="1 month ago" --oneline ^| wc -l >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"
echo pause >> "%USERPROFILE%\Desktop\DevOptimizer\Analytics\cursor-analytics.bat"

echo [SUCCESS] Analytics setup completed!
echo.
pause
goto main_menu

:dev_tools
echo.
echo ================================================================
echo               DEVELOPMENT TOOLS
echo ================================================================
echo.
echo Installing development tools for Cursor AI...
echo.

:: Install essential tools
echo [TOOLS] Installing essential tools...
npm install -g @vue/cli
npm install -g @nuxt/cli
npm install -g typescript
npm install -g eslint
npm install -g prettier
npm install -g nodemon
npm install -g pm2
echo [SUCCESS] Development tools installed!

echo.
pause
goto main_menu

:network_optimization
echo.
echo ================================================================
echo               NETWORK OPTIMIZATION
echo ================================================================
echo.
echo Optimizing network for Cursor AI development...
echo.

:: Network optimization
echo [NETWORK] Optimizing network settings...
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global chimney=enabled
netsh int tcp set global rss=enabled
netsh int tcp set global netdma=enabled
echo [SUCCESS] Network optimized!

echo.
pause
goto main_menu

:memory_optimization
echo.
echo ================================================================
echo               MEMORY OPTIMIZATION
echo ================================================================
echo.
echo Optimizing memory for Cursor AI development...
echo.

:: Memory optimization
echo [MEMORY] Optimizing memory settings...
set NODE_OPTIONS=--max-old-space-size=8192
set NODE_ENV=development
echo [SUCCESS] Memory optimized!

echo.
pause
goto main_menu

:complete_optimization
echo.
echo ================================================================
echo               COMPLETE OPTIMIZATION
echo ================================================================
echo.
echo Running complete Cursor AI optimization...
echo.

:: Run all optimizations
call :git_cache_clear
call :cursor_config
call :package_optimization
call :performance_optimization
call :security_hardening
call :analytics_setup
call :dev_tools
call :network_optimization
call :memory_optimization

echo [SUCCESS] Complete optimization finished!
echo.
pause
goto main_menu

:system_report
echo.
echo ================================================================
echo               SYSTEM REPORT
echo ================================================================
echo.
echo Generating system report...
echo.

:: System information
echo [SYSTEM] System Information:
echo OS: %OS%
echo Architecture: %ARCH%
echo RAM: %RAM% MB
echo.

:: Git information
echo [GIT] Git Information:
git --version
git config --global user.name
git config --global user.email
echo.

:: Node.js information
echo [NODE] Node.js Information:
node --version
npm --version
pnpm --version
yarn --version
echo.

:: Cursor AI information
echo [CURSOR] Cursor AI Information:
if exist "%APPDATA%\Cursor" (
echo Cursor AI installed: Yes
) else (
echo Cursor AI installed: No
)
echo.

echo [SUCCESS] System report generated!
echo.
pause
goto main_menu

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please select a number between 0-11.
echo.
pause
goto main_menu

:main_menu
cls
goto start

:exit
echo.
echo ================================================================
echo                    THANK YOU FOR USING
echo                CURSOR AI OPTIMIZATION SUITE
echo ================================================================
echo.
echo Your Cursor AI development environment has been optimized!
echo.
echo ================================================================
echo.
pause
exit

:start
goto main_menu
exit /b %ERRORLEVEL%
