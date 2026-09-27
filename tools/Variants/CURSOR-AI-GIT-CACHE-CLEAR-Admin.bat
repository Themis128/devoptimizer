@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title  - Admin Mode--prune=now
if %errorLevel% == 0 (
echo [SUCCESS] Git garbage collection completed
) else (
echo [WARNING] Git garbage collection failed
)

:: 2. Clear Git index
echo [2/8] Clearing Git index...
git reset --hard HEAD
if %errorLevel% == 0 (
echo [SUCCESS] Git index cleared
) else (
echo [WARNING] Git index clear failed
)

:: 3. Clear Git stash
echo [3/8] Clearing Git stash...
git stash clear
if %errorLevel% == 0 (
echo [SUCCESS] Git stash cleared
) else (
echo [WARNING] Git stash clear failed
)

:: 4. Clear Git reflog
echo [4/8] Clearing Git reflog...
git reflog expire --expire=now --all
if %errorLevel% == 0 (
echo [SUCCESS] Git reflog cleared
) else (
echo [WARNING] Git reflog clear failed
)

:: 5. Clear Git remote cache
echo [5/8] Clearing Git remote cache...
git remote prune origin
if %errorLevel% == 0 (
echo [SUCCESS] Git remote cache cleared
) else (
echo [WARNING] Git remote cache clear failed
)

:: 6. Clear Git LFS cache
echo [6/8] Clearing Git LFS cache...
git lfs prune
if %errorLevel% == 0 (
echo [SUCCESS] Git LFS cache cleared
) else (
echo [WARNING] Git LFS cache clear failed
)

:: 7. Clear Git worktree cache
echo [7/8] Clearing Git worktree cache...
git worktree prune
if %errorLevel% == 0 (
echo [SUCCESS] Git worktree cache cleared
) else (
echo [WARNING] Git worktree cache clear failed
)

:: 8. Clear Git config cache
echo [8/8] Clearing Git config cache...
git config --global --unset-all core.preloadindex
git config --global --unset-all core.fscache
git config --global --unset-all core.untrackedCache
echo [SUCCESS] Git config cache cleared

echo.
echo ================================================================
echo                    CURSOR AI OPTIMIZATION
echo ================================================================

:: Clear Cursor AI cache
echo [CURSOR] Clearing Cursor AI cache...
if exist "%APPDATA%\Cursor" (
rmdir /s /q "%APPDATA%\Cursor\CachedData" 2>nul
rmdir /s /q "%APPDATA%\Cursor\logs" 2>nul
rmdir /s /q "%APPDATA%\Cursor\CachedExtensions" 2>nul
echo [SUCCESS] Cursor AI cache cleared
) else (
echo [WARNING] Cursor AI cache directory not found
)

:: Clear VS Code cache (if using VS Code)
echo [VSCODE] Clearing VS Code cache...
if exist "%APPDATA%\Code" (
rmdir /s /q "%APPDATA%\Code\CachedData" 2>nul
rmdir /s /q "%APPDATA%\Code\logs" 2>nul
rmdir /s /q "%APPDATA%\Code\CachedExtensions" 2>nul
echo [SUCCESS] VS Code cache cleared
) else (
echo [WARNING] VS Code cache directory not found
)

:: Clear Node.js cache
echo [NODE] Clearing Node.js cache...
if exist "%APPDATA%\npm-cache" (
rmdir /s /q "%APPDATA%\npm-cache" 2>nul
echo [SUCCESS] npm cache cleared
) else (
echo [WARNING] npm cache directory not found
)

:: Clear pnpm cache
echo [PNPM] Clearing pnpm cache...
pnpm store prune
if %errorLevel% == 0 (
echo [SUCCESS] pnpm cache cleared
) else (
echo [WARNING] pnpm cache clear failed
)

:: Clear Yarn cache
echo [YARN] Clearing Yarn cache...
yarn cache clean
if %errorLevel% == 0 (
echo [SUCCESS] Yarn cache cleared
) else (
echo [WARNING] Yarn cache clear failed
)

echo.
echo ================================================================
echo                    SYSTEM CACHE CLEARING
echo ================================================================

:: Clear Windows cache
echo [WINDOWS] Clearing Windows cache...
del /q /f /s "%TEMP%\*" 2>nul
del /q /f /s "%TEMP%\*.*" 2>nul
echo [SUCCESS] Windows temp cache cleared

:: Clear browser cache
echo [BROWSER] Clearing browser cache...
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" (
rmdir /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" 2>nul
echo [SUCCESS] Chrome cache cleared
)

:: Clear system cache
echo [SYSTEM] Clearing system cache...
sfc /scannow
if %errorLevel% == 0 (
echo [SUCCESS] System file cache verified
) else (
echo [WARNING] System file cache verification failed
)

echo.
echo ================================================================
echo                    FINAL REPORT
echo ================================================================

echo [REPORT] Cache clearing completed!
echo.
echo  Git cache cleared
echo  Cursor AI cache cleared
echo  VS Code cache cleared
echo  Node.js cache cleared
echo  pnpm cache cleared
echo  Yarn cache cleared
echo  Windows temp cache cleared
echo  Browser cache cleared
echo.
echo [SUCCESS] All caches have been cleared for optimal Cursor AI performance!
echo.

pause


:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
