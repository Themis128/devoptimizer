@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title System Backup Manager - DevOptimizer System
color 0B

echo.
echo ========================================================================
echo                    SYSTEM BACKUP MANAGER - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.
echo This script manages system backups and restore operations
echo.

cd /d "%~dp0"

if not exist "backups" mkdir "backups"
if not exist "logs" mkdir "logs"

echo [INFO] Starting System Backup Manager...
echo.

echo ========================================================================
echo                          BACKUP OPTIONS
echo ========================================================================
echo.
:start
echo [1] Full System Backup
echo [2] DevOptimizer Configuration Backup
echo [3] OneDrive Data Backup
echo [4] Ollama Models Backup
echo [5] Cursor AI Settings Backup
echo [6] Custom Folder Backup
echo [7] Restore from Backup
echo [8] Backup Status Check
echo [9] Cleanup Old Backups
echo [0] Exit
echo.

set /p choice="Enter your choice (0-9): "

if "%choice%"=="1" goto :full_backup
if "%choice%"=="2" goto :config_backup
if "%choice%"=="3" goto :onedrive_backup
if "%choice%"=="4" goto :ollama_backup
if "%choice%"=="5" goto :cursor_backup
if "%choice%"=="6" goto :custom_backup
if "%choice%"=="7" goto :restore_backup
if "%choice%"=="8" goto :backup_status
if "%choice%"=="9" goto :cleanup_backups
if "%choice%"=="0" goto :exit
goto :invalid_choice

:full_backup
echo.
echo ========================================================================
echo                        FULL SYSTEM BACKUP
echo ========================================================================
echo.

set "BACKUP_NAME=Full-System-Backup-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%"
set "BACKUP_NAME=%BACKUP_NAME: =0%"
set "BACKUP_PATH=backups\%BACKUP_NAME%"

echo [INFO] Creating full system backup...
echo [INFO] Backup location: %BACKUP_PATH%
echo.

if not exist "%BACKUP_PATH%" mkdir "%BACKUP_PATH%"

echo [STEP 1] Backing up DevOptimizer system...
xcopy "D:\DevOptimizer" "%BACKUP_PATH%\DevOptimizer" /E /I /H /Y >nul 2>&1
if %errorlevel% equ 0 (
echo [SUCCESS] DevOptimizer system backed up
) else (
echo [WARNING] DevOptimizer backup had issues
)

echo [STEP 2] Backing up OneDrive data...
if exist "C:\Users\%USERNAME%\OneDrive" (
xcopy "C:\Users\%USERNAME%\OneDrive" "%BACKUP_PATH%\OneDrive" /E /I /H /Y >nul 2>&1
echo [SUCCESS] OneDrive data backed up
) else (
echo [INFO] OneDrive folder not found
)

echo [STEP 3] Backing up Ollama models...
if exist "%USERPROFILE%\.ollama" (
xcopy "%USERPROFILE%\.ollama" "%BACKUP_PATH%\Ollama" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Ollama models backed up
) else (
echo [INFO] Ollama folder not found
)

echo [STEP 4] Backing up Cursor AI settings...
if exist "%USERPROFILE%\.cursor" (
xcopy "%USERPROFILE%\.cursor" "%BACKUP_PATH%\Cursor" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Cursor AI settings backed up
) else (
echo [INFO] Cursor AI folder not found
)

echo [SUCCESS] Full system backup completed
echo [INFO] Backup location: %BACKUP_PATH%
pause
goto :menu

:config_backup
echo.
echo ========================================================================
echo                    DEVOPTIMIZER CONFIGURATION BACKUP
echo ========================================================================
echo.

set "BACKUP_NAME=DevOptimizer-Config-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%"
set "BACKUP_NAME=%BACKUP_NAME: =0%"
set "BACKUP_PATH=backups\%BACKUP_NAME%"

echo [INFO] Creating DevOptimizer configuration backup...
echo [INFO] Backup location: %BACKUP_PATH%
echo.

if not exist "%BACKUP_PATH%" mkdir "%BACKUP_PATH%"

echo [STEP 1] Backing up configuration files...
if exist "configs" (
xcopy "configs" "%BACKUP_PATH%\configs" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Configuration files backed up
)

if exist "tools" (
xcopy "tools" "%BACKUP_PATH%\tools" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Tools directory backed up
)

echo [STEP 2] Backing up batch files...
xcopy "*.bat" "%BACKUP_PATH%\" /Y >nul 2>&1
echo [SUCCESS] Batch files backed up

echo [STEP 3] Creating backup manifest...
(
echo DevOptimizer Configuration Backup
echo Generated: %date% %time%
echo.
echo Contents:
echo - Configuration files
echo - Tools directory
echo - Batch files
echo - System settings
) > "%BACKUP_PATH%\backup-manifest.txt"

echo [SUCCESS] DevOptimizer configuration backup completed
echo [INFO] Backup location: %BACKUP_PATH%
pause
goto :menu

:onedrive_backup
echo.
echo ========================================================================
echo                        ONEDRIVE DATA BACKUP
echo ========================================================================
echo.

set "BACKUP_NAME=OneDrive-Backup-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%"
set "BACKUP_NAME=%BACKUP_NAME: =0%"
set "BACKUP_PATH=backups\%BACKUP_NAME%"

echo [INFO] Creating OneDrive data backup...
echo [INFO] Backup location: %BACKUP_PATH%
echo.

if not exist "%BACKUP_PATH%" mkdir "%BACKUP_PATH%"

echo [INFO] Backing up OneDrive folders...
if exist "C:\Users\%USERNAME%\OneDrive" (
xcopy "C:\Users\%USERNAME%\OneDrive" "%BACKUP_PATH%\Personal" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Personal OneDrive backed up
)

if exist "C:\Users\%USERNAME%\OneDrive - University of Bolton" (
xcopy "C:\Users\%USERNAME%\OneDrive - University of Bolton" "%BACKUP_PATH%\University" /E /I /H /Y >nul 2>&1
echo [SUCCESS] University OneDrive backed up
)

if exist "C:\Users\%USERNAME%\OneDrive - New York College" (
xcopy "C:\Users\%USERNAME%\OneDrive - New York College" "%BACKUP_PATH%\College" /E /I /H /Y >nul 2>&1
echo [SUCCESS] College OneDrive backed up
)

echo [SUCCESS] OneDrive data backup completed
echo [INFO] Backup location: %BACKUP_PATH%
pause
goto :menu

:ollama_backup
echo.
echo ========================================================================
echo                        OLLAMA MODELS BACKUP
echo ========================================================================
echo.

set "BACKUP_NAME=Ollama-Models-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%"
set "BACKUP_NAME=%BACKUP_NAME: =0%"
set "BACKUP_PATH=backups\%BACKUP_NAME%"

echo [INFO] Creating Ollama models backup...
echo [INFO] Backup location: %BACKUP_PATH%
echo.

if not exist "%BACKUP_PATH%" mkdir "%BACKUP_PATH%"

echo [STEP 1] Backing up Ollama models...
if exist "%USERPROFILE%\.ollama" (
xcopy "%USERPROFILE%\.ollama" "%BACKUP_PATH%\.ollama" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Ollama models backed up
) else (
echo [WARNING] Ollama folder not found
)

echo [STEP 2] Creating model list...
ollama list > "%BACKUP_PATH%\model-list.txt" 2>nul
if %errorlevel% equ 0 (
echo [SUCCESS] Model list created
) else (
echo [WARNING] Could not create model list
)

echo [SUCCESS] Ollama models backup completed
echo [INFO] Backup location: %BACKUP_PATH%
pause
goto :menu

:cursor_backup
echo.
echo ========================================================================
echo                      CURSOR AI SETTINGS BACKUP
echo ========================================================================
echo.

set "BACKUP_NAME=Cursor-AI-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%"
set "BACKUP_NAME=%BACKUP_NAME: =0%"
set "BACKUP_PATH=backups\%BACKUP_NAME%"

echo [INFO] Creating Cursor AI settings backup...
echo [INFO] Backup location: %BACKUP_PATH%
echo.

if not exist "%BACKUP_PATH%" mkdir "%BACKUP_PATH%"

echo [STEP 1] Backing up Cursor AI settings...
if exist "%USERPROFILE%\.cursor" (
xcopy "%USERPROFILE%\.cursor" "%BACKUP_PATH%\.cursor" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Cursor AI settings backed up
) else (
echo [WARNING] Cursor AI folder not found
)

echo [STEP 2] Backing up Cursor extensions...
if exist "%USERPROFILE%\.cursor\extensions" (
xcopy "%USERPROFILE%\.cursor\extensions" "%BACKUP_PATH%\extensions" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Cursor extensions backed up
) else (
echo [INFO] No extensions found
)

echo [SUCCESS] Cursor AI settings backup completed
echo [INFO] Backup location: %BACKUP_PATH%
pause
goto :menu

:custom_backup
echo.
echo ========================================================================
echo                        CUSTOM FOLDER BACKUP
echo ========================================================================
echo.

set /p source_folder="Enter source folder path: "
if "%source_folder%"=="" (
echo [ERROR] Source folder path is required
pause
goto :menu
)

if not exist "%source_folder%" (
echo [ERROR] Source folder does not exist
pause
goto :menu
)

set "BACKUP_NAME=Custom-Backup-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%"
set "BACKUP_NAME=%BACKUP_NAME: =0%"
set "BACKUP_PATH=backups\%BACKUP_NAME%"

echo [INFO] Creating custom folder backup...
echo [INFO] Source: %source_folder%
echo [INFO] Backup location: %BACKUP_PATH%
echo.

if not exist "%BACKUP_PATH%" mkdir "%BACKUP_PATH%"

xcopy "%source_folder%" "%BACKUP_PATH%" /E /I /H /Y
if %errorlevel% equ 0 (
echo [SUCCESS] Custom folder backup completed
echo [INFO] Backup location: %BACKUP_PATH%
) else (
echo [ERROR] Custom folder backup failed
)

pause
goto :menu

:restore_backup
echo.
echo ========================================================================
echo                          RESTORE FROM BACKUP
echo ========================================================================
echo.

echo [INFO] Available backups:
echo.
dir "backups" /AD /B 2>nul
echo.

set /p backup_name="Enter backup folder name: "
if "%backup_name%"=="" (
echo [ERROR] Backup name is required
pause
goto :menu
)

set "BACKUP_PATH=backups\%backup_name%"
if not exist "%BACKUP_PATH%" (
echo [ERROR] Backup folder does not exist
pause
goto :menu
)

echo [WARNING] This will restore from backup: %backup_name%
set /p confirm="Are you sure you want to proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto :menu

echo [INFO] Restoring from backup...
echo [INFO] This may take several minutes...

if exist "%BACKUP_PATH%\DevOptimizer" (
echo [INFO] Restoring DevOptimizer system...
xcopy "%BACKUP_PATH%\DevOptimizer" "D:\DevOptimizer" /E /I /H /Y >nul 2>&1
echo [SUCCESS] DevOptimizer system restored
)

if exist "%BACKUP_PATH%\OneDrive" (
echo [INFO] Restoring OneDrive data...
xcopy "%BACKUP_PATH%\OneDrive" "C:\Users\%USERNAME%\OneDrive" /E /I /H /Y >nul 2>&1
echo [SUCCESS] OneDrive data restored
)

if exist "%BACKUP_PATH%\Ollama" (
echo [INFO] Restoring Ollama models...
xcopy "%BACKUP_PATH%\Ollama" "%USERPROFILE%\.ollama" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Ollama models restored
)

if exist "%BACKUP_PATH%\Cursor" (
echo [INFO] Restoring Cursor AI settings...
xcopy "%BACKUP_PATH%\Cursor" "%USERPROFILE%\.cursor" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Cursor AI settings restored
)

echo [SUCCESS] Restore from backup completed
pause
goto :menu

:backup_status
echo.
echo ========================================================================
echo                          BACKUP STATUS CHECK
echo ========================================================================
echo.

echo [INFO] Checking backup status...
echo.

if exist "backups" (
echo [INFO] Available backups:
dir "backups" /AD /B 2>nul
echo.

echo [INFO] Backup folder sizes:
for /d %%d in ("backups\*") do (
echo [INFO] %%~nd:
dir "%%d" /S /-C | findstr "File(s)"
)
) else (
echo [INFO] No backups found
)

echo.
echo [INFO] Backup status check completed
pause
goto :menu

:cleanup_backups
echo.
echo ========================================================================
echo                          CLEANUP OLD BACKUPS
echo ========================================================================
echo.

echo [INFO] Available backups:
echo.
dir "backups" /AD /B 2>nul
echo.

set /p days="Enter number of days (backups older than this will be deleted): "
if "%days%"=="" (
echo [ERROR] Number of days is required
pause
goto :menu
)

echo [WARNING] This will delete backups older than %days% days
set /p confirm="Are you sure you want to proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto :menu

echo [INFO] Cleaning up old backups...
forfiles /p "backups" /d -%days% /c "cmd /c if @isdir==TRUE rmdir /s /q @path"

echo [SUCCESS] Old backups cleanup completed
pause
goto :menu

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please enter a number between 0-9.
pause
goto :menu

:menu
cls
goto :menu

:exit
echo.
echo [INFO] System Backup Manager closed
echo [INFO] Thank you for using DevOptimizer System
exit /b 0
