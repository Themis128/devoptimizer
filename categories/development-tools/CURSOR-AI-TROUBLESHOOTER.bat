@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title Cursor AI Troubleshooter - DevOptimizer System
color 0D
echo.
echo ========================================================================
echo                   CURSOR AI TROUBLESHOOTER - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.
echo This script diagnoses and fixes common Cursor AI issues
echo.
REM Change to script directory
cd /d "%~dp0"
echo [INFO] Starting Cursor AI diagnostics...
echo.
echo ========================================================================
echo                          DIAGNOSTIC CHECKS
echo ========================================================================
echo.
:check_cursor_installation
echo [CHECK 1] Verifying Cursor AI installation...
if exist "C:\Users\%USERNAME%\AppData\Local\Programs\cursor\Cursor.exe" (
echo [SUCCESS] Cursor AI found in AppData
set "CURSOR_FOUND=1"
set "CURSOR_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\cursor\Cursor.exe"
) else (
echo [WARNING] Cursor AI installation not found in standard location
set "CURSOR_FOUND=0"
)
echo.
:check_cursor_processes
echo [CHECK 2] Checking Cursor AI processes...
tasklist | findstr /I "Cursor.exe" 2>NUL | findstr /I "Cursor.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Cursor AI is running
echo [INFO] Active Cursor processes:
tasklist | findstr /I "Cursor.exe" /FO TABLE
set "CURSOR_RUNNING=1"
) else (
echo [INFO] Cursor AI is not running
set "CURSOR_RUNNING=0"
)
echo.
:check_cursor_extensions
echo [CHECK 3] Checking Cursor AI extensions...
set "EXTENSIONS_PATH=C:\Users\%USERNAME\%\.cursor\extensions"
if exist "%EXTENSIONS_PATH%" (
echo [SUCCESS] Cursor extensions directory found
echo [INFO] Installed extensions:
dir "%EXTENSIONS_PATH%" /B /AD 2>nul | findstr /V "node_modules"
set "EXTENSIONS_FOUND=1"
) else (
echo [WARNING] Cursor extensions directory not found
set "EXTENSIONS_FOUND=0"
)
echo.
:check_cursor_settings
echo [CHECK 4] Checking Cursor AI settings...
set "SETTINGS_PATH=C:\Users\%USERNAME\%\.cursor\User\settings.json"
if exist "%SETTINGS_PATH%" (
echo [SUCCESS] Cursor settings file found
echo [INFO] Settings file location: %SETTINGS_PATH%
set "SETTINGS_FOUND=1"
) else (
echo [WARNING] Cursor settings file not found
set "SETTINGS_FOUND=0"
)
echo.
:check_cursor_workspace
echo [CHECK 5] Checking Cursor workspace integration...
if exist "D:\Nuxt Projects\llm-dev-agent" (
echo [SUCCESS] LLM Dev Agent workspace found
set "WORKSPACE_FOUND=1"
) else (
echo [WARNING] LLM Dev Agent workspace not found
set "WORKSPACE_FOUND=0"
)
echo.
:check_ollama_integration
echo [CHECK 6] Checking Ollama integration with Cursor...
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
:start
echo [SUCCESS] Ollama is running and available for Cursor
set "OLLAMA_INTEGRATION=1"
) else (
echo [WARNING] Ollama is not running
set "OLLAMA_INTEGRATION=0"
)
echo.
echo ========================================================================
echo                        TROUBLESHOOTING OPTIONS
echo ========================================================================
echo.
echo [1] Reset Cursor AI Settings
echo [2] Clear Cursor Cache and Temporary Files
echo [3] Restart Cursor AI Services
echo [4] Reinstall Cursor Extensions
echo [5] Fix Cursor-Ollama Integration
echo [6] Reset Cursor Workspace
echo [7] Update Cursor AI
echo [8] Generate Cursor Diagnostic Report
echo [9] Advanced Cursor Diagnostics
echo [0] Exit
echo.
set /p choice="Enter your choice (0-9): "
if "%choice%"=="1" goto :reset_settings
if "%choice%"=="2" goto :clear_cache
if "%choice%"=="3" goto :restart_services
if "%choice%"=="4" goto :reinstall_extensions
if "%choice%"=="5" goto :fix_ollama_integration
if "%choice%"=="6" goto :reset_workspace
if "%choice%"=="7" goto :update_cursor
if "%choice%"=="8" goto :generate_report
if "%choice%"=="9" goto :advanced_diagnostics
if "%choice%"=="0" goto :exit
goto :invalid_choice
:reset_settings
echo.
echo ========================================================================
echo                        RESETTING CURSOR AI SETTINGS
echo ========================================================================
echo.
echo [INFO] Resetting Cursor AI settings...
echo [WARNING] This will restore Cursor to default settings
echo.
set /p confirm="Are you sure you want to proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto :menu
echo [STEP 1] Stopping Cursor AI...
taskkill /F /IM Cursor.exe >nul 2>&1
timeout /t 3 >nul
echo [STEP 2] Backing up current settings...
if exist "C:\Users\%USERNAME\%\.cursor\User\settings.json" (
copy "C:\Users\%USERNAME\%\.cursor\User\settings.json" "C:\Users\%USERNAME\%\.cursor\User\settings.json.backup.%date:~-4,4%%date:~-10,2%%date:~-7,2%" >nul 2>&1
echo [SUCCESS] Settings backed up
)
echo [STEP 3] Removing Cursor settings...
if exist "C:\Users\%USERNAME\%\.cursor" (
powershell -Command "
Remove-Item -Path 'C:\Users\$env:USERNAME\.cursor\User\settings.json' -Force -ErrorAction SilentlyContinue
Remove-Item -Path 'C:\Users\$env:USERNAME\.cursor\CachedExtensions' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path 'C:\Users\$env:USERNAME\.cursor\logs' -Recurse -Force -ErrorAction SilentlyContinue
"
echo [SUCCESS] Settings cleared
)
echo [STEP 4] Starting Cursor AI...
if exist "%CURSOR_PATH%" (
start "" "%CURSOR_PATH%"
echo [SUCCESS] Cursor AI started with default settings
) else (
echo [ERROR] Cursor AI executable not found
)
echo [SUCCESS] Settings reset completed
pause
goto :menu
:clear_cache
echo.
echo ========================================================================
echo                    CLEARING CURSOR CACHE AND TEMP FILES
echo ========================================================================
echo.
echo [INFO] Clearing Cursor AI cache and temporary files...
echo.
echo [STEP 1] Stopping Cursor AI...
taskkill /F /IM Cursor.exe >nul 2>&1
timeout /t 3 >nul
echo [STEP 2] Clearing Cursor cache...
powershell -Command "
$cachePaths = @()
'C:\Users\$env:USERNAME\.cursor\CachedExtensions',
'C:\Users\$env:USERNAME\.cursor\logs',
'C:\Users\$env:USERNAME\AppData\Roaming\Cursor\User\workspaceStorage',
'C:\Users\$env:USERNAME\AppData\Roaming\Cursor\CachedExtensions'
)
foreach ($path in $cachePaths) {
if (Test-Path $path) {
try {
Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
Write-Host '[SUCCESS] Cleared cache: ' $path
} catch {
Write-Host '[WARNING] Could not clear: ' $path
}
}
}
"
echo [STEP 3] Clearing temporary files...
powershell -Command "
$tempPaths = @()
'$env:TEMP\*Cursor*',
'$env:TEMP\*cursor*',
'$env:LOCALAPPDATA\Temp\*Cursor*'
)
foreach ($pattern in $tempPaths) {
try {
Remove-Item -Path $pattern -Recurse -Force -ErrorAction SilentlyContinue
Write-Host '[SUCCESS] Cleared temp files matching: ' $pattern
} catch {
Write-Host '[INFO] No temp files found for: ' $pattern
}
}
"
echo [SUCCESS] Cache clearing completed
pause
goto :menu
:restart_services
echo.
echo ========================================================================
echo                     RESTARTING CURSOR AI SERVICES
echo ========================================================================
echo.
echo [INFO] Restarting Cursor AI services...
echo.
echo [STEP 1] Stopping all Cursor processes...
taskkill /F /IM Cursor.exe >nul 2>&1
timeout /t 5 >nul
echo [STEP 2] Waiting for processes to fully stop...
timeout /t 3 >nul
echo [STEP 3] Starting Cursor AI...
if exist "%CURSOR_PATH%" (
start "" "%CURSOR_PATH%"
echo [SUCCESS] Cursor AI restarted
) else (
echo [ERROR] Cursor AI executable not found
)
echo [SUCCESS] Cursor AI services restarted
pause
goto :menu
:reinstall_extensions
echo.
echo ========================================================================
echo                      REINSTALLING CURSOR EXTENSIONS
echo ========================================================================
echo.
echo [INFO] Reinstalling Cursor AI extensions...
echo.
echo [STEP 1] Stopping Cursor AI...
taskkill /F /IM Cursor.exe >nul 2>&1
timeout /t 3 >nul
echo [STEP 2] Backing up extension list...
if exist "C:\Users\%USERNAME\%\.cursor\extensions" (
dir "C:\Users\%USERNAME\%\.cursor\extensions" /B /AD > "D:\DevOptimizer\logs\cursor-extensions-backup.txt" 2>nul
echo [SUCCESS] Extension list backed up
)
echo [STEP 3] Clearing extensions cache...
powershell -Command "
if (Test-Path 'C:\Users\$env:USERNAME\.cursor\CachedExtensions') {
Remove-Item -Path 'C:\Users\$env:USERNAME\.cursor\CachedExtensions' -Recurse -Force -ErrorAction SilentlyContinue
Write-Host '[SUCCESS] Extensions cache cleared'
}
"
echo [STEP 4] Starting Cursor AI for extension reinstall...
if exist "%CURSOR_PATH%" (
start "" "%CURSOR_PATH%"
echo [INFO] Cursor AI started - extensions will be reinstalled automatically
) else (
echo [ERROR] Cursor AI executable not found
)
echo [SUCCESS] Extension reinstallation initiated
pause
goto :menu
:fix_ollama_integration
echo.
echo ========================================================================
echo                    FIXING CURSOR-OLLAMA INTEGRATION
echo ========================================================================
echo.
echo [INFO] Fixing Cursor AI and Ollama integration...
echo.
echo [STEP 1] Checking Ollama status...
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Ollama is running
) else (
echo [WARNING] Ollama is not running, attempting to start...
start "" "C:\Users\%USERNAME\AppData\Local\Programs\Ollama\ollama.exe"
timeout /t 5 >nul
)
echo [STEP 2] Checking Ollama models...
ollama list 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Ollama models are accessible
) else (
echo [ERROR] Cannot access Ollama models
)
echo [STEP 3] Testing Ollama connectivity...
powershell -Command "
try {
$response = Invoke-WebRequest -Uri 'http://localhost:11434/api/tags' -UseBasicParsing -TimeoutSec 5
if ($response.StatusCode -eq 200) {
Write-Host '[SUCCESS] Ollama API is accessible'
}
} catch {
Write-Host '[ERROR] Ollama API is not accessible'
}
"
echo [STEP 4] Configuring Cursor for Ollama...
echo [INFO] Please ensure Cursor AI has the Ollama extension installed
echo [INFO] Check Cursor settings for Ollama API endpoint: http://localhost:11434
echo [SUCCESS] Ollama integration check completed
pause
goto :menu
:reset_workspace
echo.
echo ========================================================================
echo                         RESETTING CURSOR WORKSPACE
echo ========================================================================
echo.
echo [INFO] Resetting Cursor workspace...
echo.
echo [STEP 1] Stopping Cursor AI...
taskkill /F /IM Cursor.exe >nul 2>&1
timeout /t 3 >nul
echo [STEP 2] Clearing workspace storage...
powershell -Command "
$workspacePaths = @()
'C:\Users\$env:USERNAME\AppData\Roaming\Cursor\User\workspaceStorage',
'C:\Users\$env:USERNAME\AppData\Roaming\Cursor\logs'
)
foreach ($path in $workspacePaths) {
if (Test-Path $path) {
try {
Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
Write-Host '[SUCCESS] Cleared workspace storage: ' $path
} catch {
Write-Host '[WARNING] Could not clear: ' $path
}
}
}
"
echo [STEP 3] Opening workspace...
if exist "D:\Nuxt Projects\llm-dev-agent" (
if exist "%CURSOR_PATH%" (
start "" "%CURSOR_PATH%" "D:\Nuxt Projects\llm-dev-agent"
echo [SUCCESS] Workspace opened with Cursor AI
) else (
echo [ERROR] Cursor AI executable not found
)
) else (
echo [WARNING] LLM Dev Agent workspace not found
)
echo [SUCCESS] Workspace reset completed
pause
goto :menu
:update_cursor
echo.
echo ========================================================================
echo                          UPDATING CURSOR AI
echo ========================================================================
echo.
echo [INFO] Checking for Cursor AI updates...
echo.
echo [STEP 1] Stopping Cursor AI...
taskkill /F /IM Cursor.exe >nul 2>&1
timeout /t 3 >nul
echo [STEP 2] Checking current version...
if exist "%CURSOR_PATH%" (
powershell -Command "
$fileInfo = Get-ItemProperty '%CURSOR_PATH%'
Write-Host '[INFO] Current Cursor version: ' $fileInfo.VersionInfo.FileVersion
"
) else (
echo [ERROR] Cursor AI executable not found
echo [STEP 3] Downloading latest version...
echo [INFO] Please visit https://cursor.sh/ to download the latest version
echo [INFO] Or use the built-in update mechanism in Cursor AI
echo [SUCCESS] Update check completed
pause
goto :menu
:generate_report
echo.
echo ========================================================================
echo                      GENERATING CURSOR DIAGNOSTIC REPORT
echo ========================================================================
echo.
set "REPORT_FILE=D:\DevOptimizer\logs\Cursor-Diagnostic-Report-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%.txt"
set "REPORT_FILE=%REPORT_FILE: =0%"
echo [INFO] Generating Cursor diagnostic report...
echo [INFO] Report location: %REPORT_FILE%
if not exist "D:\DevOptimizer\logs" mkdir "D:\DevOptimizer\logs"
(
echo Cursor AI Diagnostic Report
echo Generated on: %date% %time%
echo Computer: %COMPUTERNAME%
echo User: %USERNAME%
echo.
echo ========================================================================
echo CURSOR AI PROCESSES
echo ========================================================================
tasklist | findstr /I "CURSOR"
echo.
echo ========================================================================
echo CURSOR AI INSTALLATION
echo ========================================================================
dir "C:\Users\%USERNAME%\AppData\Local\Programs\cursor" 2>nul
echo.
echo ========================================================================
echo CURSOR EXTENSIONS
echo ========================================================================
dir "C:\Users\%USERNAME\%\.cursor\extensions" /B /AD 2>nul
echo.
echo ========================================================================
echo OLLAMA INTEGRATION
echo ========================================================================
ollama list 2>nul
echo.
echo ========================================================================
echo WORKSPACE STATUS
echo ========================================================================
dir "D:\Nuxt Projects\llm-dev-agent" 2>nul
) > "%REPORT_FILE%"
echo [SUCCESS] Diagnostic report generated: %REPORT_FILE%
pause
goto :menu
:advanced_diagnostics
echo.
echo ========================================================================
echo                        ADVANCED CURSOR DIAGNOSTICS
echo ========================================================================
echo.
echo [INFO] Running advanced Cursor AI diagnostics...
echo.
echo [CHECK 1] Cursor AI configuration health...
if exist "C:\Users\%USERNAME\%\.cursor\User\settings.json" (
echo [SUCCESS] Settings file exists
powershell -Command "
try {
$settings = Get-Content 'C:\Users\$env:USERNAME\.cursor\User\settings.json' | ConvertFrom-Json
Write-Host '[INFO] Settings file is valid JSON'
} catch {
Write-Host '[ERROR] Settings file is corrupted'
}
"
) else (
echo [WARNING] Settings file not found
echo [CHECK 2] Extension compatibility check...
if exist "C:\Users\%USERNAME\%\.cursor\extensions" (
echo [SUCCESS] Extensions directory found
powershell -Command "
$extensions = Get-ChildItem 'C:\Users\$env:USERNAME\.cursor\extensions' -Directory
Write-Host '[INFO] Total extensions installed: ' $extensions.Count
"
) else (
echo [WARNING] Extensions directory not found
echo [CHECK 3] Performance metrics...
powershell -Command "
$cursorProcesses = Get-Process -Name 'Cursor' -ErrorAction SilentlyContinue
if ($cursorProcesses) {
$totalCPU = ($cursorProcesses | Measure-Object CPU -Sum).Sum
$totalMemory = ($cursorProcesses | Measure-Object WorkingSet -Sum).Sum
Write-Host '[INFO] Total CPU usage: ' $totalCPU 'seconds'
Write-Host '[INFO] Total memory usage: ' [math]::Round($totalMemory / 1MB, 2) 'MB'
}
"
echo [SUCCESS] Advanced diagnostics completed
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
echo [INFO] Cursor AI Troubleshooter closed
echo [INFO] Thank you for using DevOptimizer System
exit /b 0
