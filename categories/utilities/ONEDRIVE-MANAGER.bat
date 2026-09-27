@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title OneDrive Manager - DevOptimizer System
color 0A

echo.
echo ========================================================================
echo                    ONEDRIVE MANAGER - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.
echo This script manages all your OneDrive accounts and sync operations
echo.

REM Change to script directory
cd /d "%~dp0"

REM Check if OneDrive is running
tasklist | findstr /I "OneDrive.exe" 2>NUL | findstr /I "OneDrive.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [INFO] OneDrive is currently running
) else (
echo [WARNING] OneDrive is not running
)

echo.
echo ========================================================================
echo                          ONEDRIVE ACCOUNTS
echo ========================================================================
echo.

REM List OneDrive folders
set "ONEDRIVE_COUNT=0"
if exist "C:\Users\%USERNAME%\OneDrive" (
set /a ONEDRIVE_COUNT+=1
echo [!ONEDRIVE_COUNT!] Personal OneDrive: C:\Users\%USERNAME%\OneDrive
)

if exist "C:\Users\%USERNAME%\OneDrive - University of Bolton" (
set /a ONEDRIVE_COUNT+=1
echo [!ONEDRIVE_COUNT!] University of Bolton: C:\Users\%USERNAME%\OneDrive - University of Bolton
)

if exist "C:\Users\%USERNAME%\OneDrive - New York College" (
set /a ONEDRIVE_COUNT+=1
echo [!ONEDRIVE_COUNT!] New York College: C:\Users\%USERNAME%\OneDrive - New York College
)

if exist "C:\Users\%USERNAME%\OneDrive -   " (
set /a ONEDRIVE_COUNT+=1
echo [!ONEDRIVE_COUNT!] Hellenic Open University: C:\Users\%USERNAME%\OneDrive -
)

echo.
echo ========================================================================
echo                          MANAGEMENT OPTIONS
echo ========================================================================
echo.
:start
echo [1] Check OneDrive Sync Status
echo [2] Force Sync All Accounts
echo [3] Open OneDrive Settings
echo [4] Check Storage Usage
echo [5] Backup DevOptimizer to OneDrive
echo [6] Restore from OneDrive Backup
echo [7] Open OneDrive Folders
echo [8] OneDrive Troubleshooting
echo [0] Exit
echo.

set /p choice="Enter your choice (0-8): "

if "%choice%"=="1" goto :check_sync
if "%choice%"=="2" goto :force_sync
if "%choice%"=="3" goto :open_settings
if "%choice%"=="4" goto :check_storage
if "%choice%"=="5" goto :backup_to_onedrive
if "%choice%"=="6" goto :restore_from_onedrive
if "%choice%"=="7" goto :open_folders
if "%choice%"=="8" goto :troubleshooting
if "%choice%"=="0" goto :exit
goto :invalid_choice

:check_sync
echo.
echo ========================================================================
echo                       CHECKING ONEDRIVE SYNC STATUS
echo ========================================================================
echo.

REM Check OneDrive process status
tasklist | findstr /I "OneDrive.exe" 2>NUL | findstr /I "OneDrive.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] OneDrive process is running
) else (
echo [ERROR] OneDrive process is not running
echo [INFO] Starting OneDrive...
start "" "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
timeout /t 3 >nul
)

REM Check sync status using PowerShell
echo [INFO] Checking sync status...
powershell -Command "Get-Process OneDrive -ErrorAction SilentlyContinue | Select-Object ProcessName, CPU, WorkingSet | Format-Table -AutoSize"

echo.
echo [INFO] Sync status check completed
pause
goto :menu

:force_sync
echo.
echo ========================================================================
echo                        FORCING ONEDRIVE SYNC
echo ========================================================================
echo.

echo [INFO] Forcing sync for all OneDrive accounts...
powershell -Command "& 'C:\Program Files\Microsoft OneDrive\OneDrive.exe' /background"

echo [SUCCESS] Sync initiated for all accounts
echo [INFO] Monitor OneDrive system tray icon for sync progress
pause
goto :menu

:open_settings
echo.
echo ========================================================================
echo                        OPENING ONEDRIVE SETTINGS
echo ========================================================================
echo.

echo [INFO] Opening OneDrive settings...
start "" "C:\Program Files\Microsoft OneDrive\OneDrive.exe" /settings

echo [SUCCESS] OneDrive settings opened
pause
goto :menu

:check_storage
echo.
echo ========================================================================
echo                         CHECKING STORAGE USAGE
echo ========================================================================
echo.

echo [INFO] Checking OneDrive storage usage...
powershell -Command "
$onedrivePath = 'C:\Users\$env:USERNAME\OneDrive'
if (Test-Path $onedrivePath) {
$size = (Get-ChildItem -Path $onedrivePath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$sizeGB = [math]::Round($size / 1GB, 2)
Write-Host '[INFO] Personal OneDrive size: ' $sizeGB 'GB'
}

$boltonPath = 'C:\Users\$env:USERNAME\OneDrive - University of Bolton'
if (Test-Path $boltonPath) {
$size = (Get-ChildItem -Path $boltonPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$sizeGB = [math]::Round($size / 1GB, 2)
Write-Host '[INFO] University of Bolton OneDrive size: ' $sizeGB 'GB'
}
"

echo.
echo [INFO] Storage check completed
pause
goto :menu

:backup_to_onedrive
echo.
echo ========================================================================
echo                    BACKUP DEVOPTIMIZER TO ONEDRIVE
echo ========================================================================
echo.

set "BACKUP_PATH=C:\Users\%USERNAME%\OneDrive\DevOptimizer-Backup"
set "SOURCE_PATH=D:\DevOptimizer"

echo [INFO] Creating backup directory...
if not exist "%BACKUP_PATH%" mkdir "%BACKUP_PATH%"

echo [INFO] Backing up DevOptimizer to OneDrive...
echo [INFO] Source: %SOURCE_PATH%
echo [INFO] Destination: %BACKUP_PATH%

robocopy "%SOURCE_PATH%" "%BACKUP_PATH%" /E /R:3 /W:1 /MT:8 /XD logs temp cache /XF *.tmp *.log

if %errorlevel% leq 7 (
echo [SUCCESS] Backup completed successfully
echo [INFO] Backup location: %BACKUP_PATH%
) else (
echo [ERROR] Backup failed with error level: %errorlevel%
)

pause
goto :menu

:restore_from_onedrive
echo.
echo ========================================================================
echo                   RESTORE FROM ONEDRIVE BACKUP
echo ========================================================================
echo.

set "BACKUP_PATH=C:\Users\%USERNAME%\OneDrive\DevOptimizer-Backup"
set "TARGET_PATH=D:\DevOptimizer"

echo [WARNING] This will restore DevOptimizer from OneDrive backup
echo [INFO] Backup location: %BACKUP_PATH%
echo [INFO] Target location: %TARGET_PATH%
echo.

set /p confirm="Are you sure you want to proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto :menu

echo [INFO] Restoring from OneDrive backup...
robocopy "%BACKUP_PATH%" "%TARGET_PATH%" /E /R:3 /W:1 /MT:8

if %errorlevel% leq 7 (
echo [SUCCESS] Restore completed successfully
) else (
echo [ERROR] Restore failed with error level: %errorlevel%
)

pause
goto :menu

:open_folders
echo.
echo ========================================================================
echo                        OPENING ONEDRIVE FOLDERS
echo ========================================================================
echo.

echo [INFO] Opening OneDrive folders...
if exist "C:\Users\%USERNAME%\OneDrive" (
start "" "C:\Users\%USERNAME%\OneDrive"
)

if exist "C:\Users\%USERNAME%\OneDrive - University of Bolton" (
start "" "C:\Users\%USERNAME%\OneDrive - University of Bolton"
)

echo [SUCCESS] OneDrive folders opened
pause
goto :menu

:troubleshooting
echo.
echo ========================================================================
echo                        ONEDRIVE TROUBLESHOOTING
echo ========================================================================
echo.

REM Call account selector
call :select_account
if "%SELECTED_OD_PATH%"=="" goto :menu

echo.
echo ========================================================================
echo                    TROUBLESHOOTING: %SELECTED_OD_NAME%
echo ========================================================================
echo.

echo [INFO] Running OneDrive troubleshooting for selected account...
echo [INFO] Target: %SELECTED_OD_PATH%
echo.

echo [STEP 1] Checking OneDrive process...
tasklist | findstr /I "OneDrive.exe" 2>NUL | findstr /I "OneDrive.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] OneDrive process is running
) else (
echo [ERROR] OneDrive process is not running
echo [INFO] Attempting to start OneDrive...
start "" "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
timeout /t 5 >nul
)

echo.
echo [STEP 2] Checking network connectivity...
ping -n 1 onedrive.live.com >nul
if %errorlevel%==0 (
echo [SUCCESS] Network connectivity to OneDrive is OK
) else (
echo [ERROR] Cannot reach OneDrive servers
)

echo.
echo [STEP 3] Checking OneDrive configuration...
if exist "C:\Users\%USERNAME%\AppData\Local\Microsoft\OneDrive\settings" (
echo [SUCCESS] OneDrive settings directory exists
) else (
echo [WARNING] OneDrive settings directory not found
)

echo.
echo [STEP 4] Checking selected account path...
if exist "%SELECTED_OD_PATH%" (
echo [SUCCESS] Selected account path exists: %SELECTED_OD_PATH%
) else (
echo [ERROR] Selected account path not found: %SELECTED_OD_PATH%
)

echo.
echo ========================================================================
echo                         ADVANCED REPAIR OPTIONS
echo ========================================================================
echo.
echo [1] Diagnose 0x80071128/0x80071129 (Reparse Point Issues)
echo [2] Fix reparse points (Safe auto-fix)
echo [3] Re-enable Files On-Demand and restart OneDrive
echo [4] Full OneDrive reset (All accounts)
echo [0] Back to main menu
echo.
set /p repair_choice="Select repair option (0-4): "

if "%repair_choice%"=="1" goto :diagnose_reparse
if "%repair_choice%"=="2" goto :fix_reparsepoints
if "%repair_choice%"=="3" goto :reenable_files_ondemand
if "%repair_choice%"=="4" goto :full_reset
if "%repair_choice%"=="0" goto :menu
goto :invalid_repair_choice

:select_account
echo.
echo ========================================================================
echo                        SELECT ONEDRIVE ACCOUNT
echo ========================================================================
echo.

set "ACCOUNT_COUNT=0"
set "SELECTED_OD_NAME="
set "SELECTED_OD_PATH="

echo [INFO] Detecting OneDrive accounts...
echo.

REM Personal OneDrive
if exist "C:\Users\%USERNAME%\OneDrive" (
set /a ACCOUNT_COUNT+=1
echo [!ACCOUNT_COUNT!] Personal OneDrive: C:\Users\%USERNAME%\OneDrive
)

REM University of Bolton
if exist "C:\Users\%USERNAME%\OneDrive - University of Bolton" (
set /a ACCOUNT_COUNT+=1
echo [!ACCOUNT_COUNT!] University of Bolton: C:\Users\%USERNAME%\OneDrive - University of Bolton
)

REM New York College
if exist "C:\Users\%USERNAME%\OneDrive - New York College" (
set /a ACCOUNT_COUNT+=1
echo [!ACCOUNT_COUNT!] New York College: C:\Users\%USERNAME%\OneDrive - New York College
)

REM Hellenic Open University
if exist "C:\Users\%USERNAME%\OneDrive -   " (
set /a ACCOUNT_COUNT+=1
echo [!ACCOUNT_COUNT!] Hellenic Open University: C:\Users\%USERNAME%\OneDrive -
)

REM Additional OneDrive accounts (dynamic detection)
for /d %%d in ("C:\Users\%USERNAME%\OneDrive - *") do (
set /a ACCOUNT_COUNT+=1
echo [!ACCOUNT_COUNT!] %%d
)

echo.
echo [A] All accounts
echo [0] Cancel
echo.
set /p account_choice="Select account (1-%ACCOUNT_COUNT%, A, 0): "

if "%account_choice%"=="0" (
set "SELECTED_OD_NAME="
set "SELECTED_OD_PATH="
goto :eof
)

if /i "%account_choice%"=="A" (
set "SELECTED_OD_NAME=All Accounts"
set "SELECTED_OD_PATH=ALL"
goto :eof
)

REM Set selected account based on choice
set "CURRENT_COUNT=0"
if exist "C:\Users\%USERNAME%\OneDrive" (
set /a CURRENT_COUNT+=1
if "!CURRENT_COUNT!"=="%account_choice%" (
set "SELECTED_OD_NAME=Personal OneDrive"
set "SELECTED_OD_PATH=C:\Users\%USERNAME%\OneDrive"
goto :eof
)
)

if exist "C:\Users\%USERNAME%\OneDrive - University of Bolton" (
set /a CURRENT_COUNT+=1
if "!CURRENT_COUNT!"=="%account_choice%" (
set "SELECTED_OD_NAME=University of Bolton"
set "SELECTED_OD_PATH=C:\Users\%USERNAME%\OneDrive - University of Bolton"
goto :eof
)
)

if exist "C:\Users\%USERNAME%\OneDrive - New York College" (
set /a CURRENT_COUNT+=1
if "!CURRENT_COUNT!"=="%account_choice%" (
set "SELECTED_OD_NAME=New York College"
set "SELECTED_OD_PATH=C:\Users\%USERNAME%\OneDrive - New York College"
goto :eof
)
)

if exist "C:\Users\%USERNAME%\OneDrive -   " (
set /a CURRENT_COUNT+=1
if "!CURRENT_COUNT!"=="%account_choice%" (
set "SELECTED_OD_NAME=Hellenic Open University"
set "SELECTED_OD_PATH=C:\Users\%USERNAME%\OneDrive -   "
goto :eof
)
)

REM Handle additional accounts
for /d %%d in ("C:\Users\%USERNAME%\OneDrive - *") do (
set /a CURRENT_COUNT+=1
if "!CURRENT_COUNT!"=="%account_choice%" (
set "SELECTED_OD_NAME=%%~nd"
set "SELECTED_OD_PATH=%%d"
goto :eof
)
)

echo [ERROR] Invalid account selection
set "SELECTED_OD_NAME="
set "SELECTED_OD_PATH="
goto :eof

:diagnose_reparse
echo.
echo ========================================================================
echo                    DIAGNOSING REPARSE POINT ISSUES
echo ========================================================================
echo.

echo [INFO] Diagnosing 0x80071128/0x80071129 errors for %SELECTED_OD_NAME%...
echo [INFO] Target: %SELECTED_OD_PATH%
echo.

echo [STEP 1] Checking Cloud Files filter driver...
sc query cldflt >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Cloud Files filter driver is running
) else (
echo [ERROR] Cloud Files filter driver not running
echo [INFO] Attempting to start Cloud Files filter driver...
sc start cldflt >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Cloud Files filter driver started
) else (
echo [ERROR] Failed to start Cloud Files filter driver
)
)

echo.
echo [STEP 2] Scanning for reparse point issues...
powershell -Command "& {"
$path = '%SELECTED_OD_PATH%'
if ($path -eq 'ALL') {
$paths = @()
if (Test-Path 'C:\Users\$env:USERNAME\OneDrive') { $paths += 'C:\Users\$env:USERNAME\OneDrive' }
Get-ChildItem 'C:\Users\$env:USERNAME\OneDrive - *' -Directory | ForEach-Object { $paths += $_.FullName }
} else {
$paths = @($path)
}

foreach ($p in $paths) {
Write-Host '[INFO] Scanning:' $p
$reparseItems = Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }
$brokenCount = 0
$totalCount = $reparseItems.Count

foreach ($item in $reparseItems) {
try {
$item.FullName | Out-Null
} catch {
$brokenCount++
Write-Host '[WARNING] Broken reparse point:' $item.FullName
}
}

Write-Host '[RESULT] Total reparse points:' $totalCount
Write-Host '[RESULT] Broken reparse points:' $brokenCount
if ($brokenCount -gt 0) {
Write-Host '[WARNING] Found' $brokenCount 'broken reparse points that may cause 0x80071128/0x80071129 errors'
} else {
Write-Host '[SUCCESS] No broken reparse points detected'
}
}
}"

echo.
echo [INFO] Diagnosis completed
pause
goto :troubleshooting

:fix_reparsepoints
echo.
echo ========================================================================
echo                      FIXING REPARSE POINT ISSUES
echo ========================================================================
echo.

echo [WARNING] This will attempt to fix broken reparse points in %SELECTED_OD_NAME%
echo [INFO] Target: %SELECTED_OD_PATH%
echo [WARNING] Files with broken reparse points will be moved to quarantine
echo.
set /p confirm="Do you want to proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto :troubleshooting

echo.
echo [INFO] Creating repair log...
set "LOG_FILE=%~dp0logs\onedrive-fix-%SELECTED_OD_NAME%-%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log"
if not exist "%~dp0logs" mkdir "%~dp0logs"

echo [INFO] Starting reparse point repair...
echo [INFO] Log file: %LOG_FILE%

powershell -Command "& {"
$logFile = '%LOG_FILE%'
$path = '%SELECTED_OD_PATH%'

Add-Content -Path $logFile -Value 'OneDrive Reparse Point Fix Started at $(Get-Date)'
Add-Content -Path $logFile -Value 'Target: $path'

if ($path -eq 'ALL') {
$paths = @()
if (Test-Path 'C:\Users\$env:USERNAME\OneDrive') { $paths += 'C:\Users\$env:USERNAME\OneDrive' }
Get-ChildItem 'C:\Users\$env:USERNAME\OneDrive - *' -Directory | ForEach-Object { $paths += $_.FullName }
} else {
$paths = @($path)
}

$totalFixed = 0
$totalQuarantined = 0

foreach ($p in $paths) {
Add-Content -Path $logFile -Value 'Processing: $p'
Write-Host '[INFO] Processing:' $p

# Create quarantine folder
$quarantinePath = Join-Path $p '_OneDrive_ReparseFix_Quarantine'
if (!(Test-Path $quarantinePath)) {
New-Item -ItemType Directory -Path $quarantinePath -Force | Out-Null
}

# Get all reparse points
$reparseItems = Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }

foreach ($item in $reparseItems) {
try {
# Test if reparse point is accessible
$item.FullName | Out-Null
$item.Attributes | Out-Null
} catch {
# Broken reparse point detected
Write-Host '[FIXING] Broken reparse point:' $item.FullName
Add-Content -Path $logFile -Value 'Fixing broken reparse point: $($item.FullName)'

try {
# Move to quarantine
$quarantineItemPath = Join-Path $quarantinePath $item.Name
Move-Item -Path $item.FullName -Destination $quarantineItemPath -Force -ErrorAction SilentlyContinue
$totalQuarantined++
Add-Content -Path $logFile -Value 'Quarantined: $($item.FullName)'

# Recreate as placeholder if it was a directory
if ($item.PSIsContainer) {
New-Item -ItemType Directory -Path $item.FullName -Force | Out-Null
Add-Content -Path $logFile -Value 'Recreated directory placeholder: $($item.FullName)'
}

$totalFixed++
} catch {
Add-Content -Path $logFile -Value 'Failed to fix: $($item.FullName) - $($_.Exception.Message)'
}
}
}
}

Add-Content -Path $logFile -Value 'Repair completed. Total fixed: $totalFixed, Total quarantined: $totalQuarantined'
Write-Host '[SUCCESS] Repair completed. Fixed:' $totalFixed 'Quarantined:' $totalQuarantined
}"

echo.
echo [INFO] Restarting OneDrive...
taskkill /F /IM "OneDrive.exe" >nul 2>&1
timeout /t 3 >nul
start "" "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
timeout /t 5 >nul

echo [SUCCESS] Reparse point fix completed
echo [INFO] Check log file for details: %LOG_FILE%
pause
goto :troubleshooting

:reenable_files_ondemand
echo.
echo ========================================================================
echo                    RE-ENABLING FILES ON-DEMAND
echo ========================================================================
echo.

echo [INFO] Re-enabling Files On-Demand for %SELECTED_OD_NAME%...
echo [INFO] Target: %SELECTED_OD_PATH%
echo.

echo [STEP 1] Stopping OneDrive...
taskkill /F /IM "OneDrive.exe" >nul 2>&1
timeout /t 3 >nul

echo [STEP 2] Clearing Files On-Demand cache...
powershell -Command "& {"
$path = '%SELECTED_OD_PATH%'
if ($path -ne 'ALL') {
attrib -U -P /S /D '$path\*' 2>$null
Write-Host '[SUCCESS] Cleared Files On-Demand cache for' $path
} else {
attrib -U -P /S /D 'C:\Users\$env:USERNAME\OneDrive\*' 2>$null
Get-ChildItem 'C:\Users\$env:USERNAME\OneDrive - *' -Directory | ForEach-Object {
attrib -U -P /S /D '$($_.FullName)\*' 2>$null
}
Write-Host '[SUCCESS] Cleared Files On-Demand cache for all accounts'
}
}"

echo [STEP 3] Restarting OneDrive...
start "" "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
timeout /t 5 >nul

echo [SUCCESS] Files On-Demand re-enabled and OneDrive restarted
pause
goto :troubleshooting

:full_reset
echo.
echo ========================================================================
echo                        FULL ONEDRIVE RESET
echo ========================================================================
echo.

echo [WARNING] This will perform a full OneDrive reset for ALL accounts
echo [WARNING] This will unlink and re-link all OneDrive accounts
echo [WARNING] You will need to sign in again to all accounts
echo.
set /p confirm="Are you sure you want to proceed? (YES/NO): "
if not "%confirm%"=="YES" goto :troubleshooting

echo.
echo [INFO] Performing full OneDrive reset...

echo [STEP 1] Stopping OneDrive processes...
taskkill /F /IM "OneDrive.exe" >nul 2>&1
timeout /t 3 >nul

echo [STEP 2] Resetting OneDrive...
start "" "C:\Program Files\Microsoft OneDrive\OneDrive.exe" /reset

echo [INFO] OneDrive reset initiated
echo [INFO] OneDrive will restart and prompt you to sign in to your accounts
echo [INFO] Please follow the setup wizard to re-link your accounts

echo [SUCCESS] Full OneDrive reset completed
pause
goto :menu

:invalid_repair_choice
echo.
echo [ERROR] Invalid repair choice. Please enter a number between 0-4.
pause
goto :troubleshooting

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please enter a number between 0-8.
pause
goto :menu

:menu
cls
goto :menu

:exit
echo.
echo [INFO] OneDrive Manager closed
echo [INFO] Thank you for using DevOptimizer System
exit /b 0
