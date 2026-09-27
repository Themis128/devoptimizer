@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title Ollama Troubleshooter - DevOptimizer System
color 0E
echo.
echo ========================================================================
echo                     OLLAMA TROUBLESHOOTER - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.
echo This script diagnoses and fixes common Ollama issues
echo.
REM Change to script directory
cd /d "%~dp0"
echo [INFO] Starting Ollama diagnostics...
echo.
echo ========================================================================
echo                          DIAGNOSTIC CHECKS
echo ========================================================================
echo.
:check_ollama_installation
echo [CHECK 1] Verifying Ollama installation...
where ollama >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Ollama is installed and in PATH
set "OLLAMA_INSTALLED=1"
) else (
echo [WARNING] Ollama not found in PATH
if exist "C:\Users\%USERNAME%\AppData\Local\Programs\Ollama\ollama.exe" (
echo [SUCCESS] Ollama found in AppData
set "OLLAMA_INSTALLED=1"
set "OLLAMA_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Ollama\ollama.exe"
) else (
echo [ERROR] Ollama installation not found
set "OLLAMA_INSTALLED=0"
)
)
echo.
:check_ollama_processes
echo [CHECK 2] Checking Ollama processes...
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Ollama service is running
echo [INFO] Active Ollama processes:
tasklist | findstr /I "ollama.exe" /FO TABLE
set "OLLAMA_RUNNING=1"
) else (
echo [INFO] Ollama service is not running
set "OLLAMA_RUNNING=0"
)
echo.
:check_ollama_models
echo [CHECK 3] Checking installed Ollama models...
ollama list 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Ollama models are accessible
set "MODELS_ACCESSIBLE=1"
) else (
echo [ERROR] Cannot access Ollama models
set "MODELS_ACCESSIBLE=0"
)
echo.
:check_ollama_api
echo [CHECK 4] Testing Ollama API connectivity...
powershell -Command "
try {
$response = Invoke-WebRequest -Uri 'http://localhost:11434/api/tags' -UseBasicParsing -TimeoutSec 5
if ($response.StatusCode -eq 200) {
Write-Host '[SUCCESS] Ollama API is accessible on port 11434'
$models = $response.Content | ConvertFrom-Json
Write-Host '[INFO] Available models via API: ' $models.models.Count
}
} catch {
Write-Host '[ERROR] Ollama API is not accessible'
Write-Host '[INFO] Error: ' $_.Exception.Message
}
"
echo.
:check_ollama_performance
echo [CHECK 5] Checking Ollama performance...
powershell -Command "
$ollamaProcesses = Get-Process -Name 'ollama' -ErrorAction SilentlyContinue
if ($ollamaProcesses) {
$totalCPU = ($ollamaProcesses | Measure-Object CPU -Sum).Sum
$totalMemory = ($ollamaProcesses | Measure-Object WorkingSet -Sum).Sum
Write-Host '[INFO] Ollama CPU usage: ' $totalCPU 'seconds'
Write-Host '[INFO] Ollama memory usage: ' [math]::Round($totalMemory / 1MB, 2) 'MB'
} else {
Write-Host '[INFO] No Ollama processes found'
}
"
echo.
:check_ollama_config
echo [CHECK 6] Checking Ollama configuration...
set "OLLAMA_CONFIG=%USERPROFILE%\.ollama"
if exist "%OLLAMA_CONFIG%" (
echo [SUCCESS] Ollama config directory found: %OLLAMA_CONFIG%
set "CONFIG_FOUND=1"
) else (
echo [WARNING] Ollama config directory not found
set "CONFIG_FOUND=0"
)
echo.
echo ========================================================================
echo                        TROUBLESHOOTING OPTIONS
echo ========================================================================
echo.
:start
echo [1] Start/Stop Ollama Service
echo [2] Reset Ollama Configuration
echo [3] Clear Ollama Cache and Models
echo [4] Reinstall Ollama Models
echo [5] Fix Ollama API Issues
echo [6] Optimize Ollama Performance
echo [7] Test Ollama Model Responses
echo [8] Generate Ollama Diagnostic Report
echo [9] Advanced Ollama Diagnostics
echo [0] Exit
echo.
set /p choice="Enter your choice (0-9): "
if "%choice%"=="1" goto :manage_service
if "%choice%"=="2" goto :reset_config
if "%choice%"=="3" goto :clear_cache
if "%choice%"=="4" goto :reinstall_models
if "%choice%"=="5" goto :fix_api
if "%choice%"=="6" goto :optimize_performance
if "%choice%"=="7" goto :test_models
if "%choice%"=="8" goto :generate_report
if "%choice%"=="9" goto :advanced_diagnostics
if "%choice%"=="0" goto :exit
goto :invalid_choice
:manage_service
echo.
echo ========================================================================
echo                      MANAGING OLLAMA SERVICE
echo ========================================================================
echo.
echo [INFO] Managing Ollama service...
echo.
if "%OLLAMA_RUNNING%"=="1" (
echo [INFO] Ollama is currently running
echo [1] Stop Ollama Service
echo [2] Restart Ollama Service
set /p service_choice="Enter choice (1-2): "

if "!service_choice!"=="1" (
echo [INFO] Stopping Ollama service...
taskkill /F /IM ollama.exe >nul 2>&1
timeout /t 3 >nul
echo [SUCCESS] Ollama service stopped
) else if "!service_choice!"=="2" (
echo [INFO] Restarting Ollama service...
taskkill /F /IM ollama.exe >nul 2>&1
timeout /t 3 >nul
start "" "C:\Users\%USERNAME%\AppData\Local\Programs\Ollama\ollama.exe"
timeout /t 5 >nul
echo [SUCCESS] Ollama service restarted
)
) else (
echo [INFO] Ollama is not running
echo [1] Start Ollama Service
set /p service_choice="Enter choice (1): "

if "!service_choice!"=="1" (
echo [INFO] Starting Ollama service...
start "" "C:\Users\%USERNAME%\AppData\Local\Programs\Ollama\ollama.exe"
timeout /t 5 >nul
echo [SUCCESS] Ollama service started
)
)
pause
goto :menu
:reset_config
echo.
echo ========================================================================
echo                      RESETTING OLLAMA CONFIGURATION
echo ========================================================================
echo.
echo [INFO] Resetting Ollama configuration...
echo [WARNING] This will clear all Ollama settings and require reconfiguration
echo.
set /p confirm="Are you sure you want to proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto :menu
echo [STEP 1] Stopping Ollama service...
taskkill /F /IM ollama.exe >nul 2>&1
timeout /t 3 >nul
echo [STEP 2] Backing up current configuration...
if exist "%OLLAMA_CONFIG%" (
xcopy "%OLLAMA_CONFIG%" "D:\DevOptimizer\logs\ollama-config-backup" /E /I /H /Y >nul 2>&1
echo [SUCCESS] Configuration backed up
)
echo [STEP 3] Clearing Ollama configuration...
powershell -Command "
if (Test-Path '%OLLAMA_CONFIG%') {
Remove-Item -Path '%OLLAMA_CONFIG%' -Recurse -Force -ErrorAction SilentlyContinue
Write-Host '[SUCCESS] Configuration cleared'
}
"
echo [STEP 4] Restarting Ollama service...
start "" "C:\Users\%USERNAME%\AppData\Local\Programs\Ollama\ollama.exe"
timeout /t 5 >nul
echo [SUCCESS] Configuration reset completed
echo [INFO] Ollama will create new default configuration
pause
goto :menu
:clear_cache
echo.
echo ========================================================================
echo                    CLEARING OLLAMA CACHE AND MODELS
echo ========================================================================
echo.
echo [INFO] Clearing Ollama cache and temporary files...
echo [WARNING] This will clear downloaded models and cache
echo.
set /p confirm="Are you sure you want to proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto :menu
echo [STEP 1] Stopping Ollama service...
taskkill /F /IM ollama.exe >nul 2>&1
timeout /t 3 >nul
echo [STEP 2] Clearing Ollama cache...
powershell -Command "
$cachePaths = @()
'%OLLAMA_CONFIG%\models',
'%OLLAMA_CONFIG%\cache',
'%TEMP%\ollama*'
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
echo [STEP 3] Restarting Ollama service...
start "" "C:\Users\%USERNAME%\AppData\Local\Programs\Ollama\ollama.exe"
timeout /t 5 >nul
echo [SUCCESS] Cache clearing completed
pause
goto :menu
:reinstall_models
echo.
echo ========================================================================
echo                        REINSTALLING OLLAMA MODELS
echo ========================================================================
echo.
echo [INFO] Reinstalling Ollama models...
echo.
echo [STEP 1] Checking current models...
ollama list 2>nul
if %errorlevel% neq 0 (
echo [ERROR] Cannot access Ollama, please ensure it's running
pause
goto :menu
)
echo [STEP 2] Reinstalling qwen2.5:1.5b...
echo [INFO] Pulling qwen2.5:1.5b model...
ollama pull qwen2.5:1.5b
if %errorlevel%==0 (
echo [SUCCESS] qwen2.5:1.5b model installed
) else (
echo [ERROR] Failed to install qwen2.5:1.5b model
)
echo [STEP 3] Reinstalling qwen2.5-coder:7b...
echo [INFO] Pulling qwen2.5-coder:7b model...
ollama pull qwen2.5-coder:7b
if %errorlevel%==0 (
echo [SUCCESS] qwen2.5-coder:7b model installed
) else (
echo [ERROR] Failed to install qwen2.5-coder:7b model
)
echo [SUCCESS] Model reinstallation completed
pause
goto :menu
:fix_api
echo.
echo ========================================================================
echo                        FIXING OLLAMA API ISSUES
echo ========================================================================
echo.
echo [INFO] Fixing Ollama API issues...
echo.
echo [STEP 1] Checking API port availability...
netstat -an | findstr :11434 >nul
if %errorlevel%==0 (
echo [SUCCESS] Port 11434 is in use (Ollama API should be running)
) else (
echo [WARNING] Port 11434 is not in use
)
echo [STEP 2] Testing API connectivity...
powershell -Command "
try {
$response = Invoke-WebRequest -Uri 'http://localhost:11434/api/tags' -UseBasicParsing -TimeoutSec 10
if ($response.StatusCode -eq 200) {
Write-Host '[SUCCESS] API is responding correctly'
}
} catch {
Write-Host '[ERROR] API is not responding'
Write-Host '[INFO] Attempting to restart Ollama service...'
}
"
echo [STEP 3] Restarting Ollama service...
taskkill /F /IM ollama.exe >nul 2>&1
timeout /t 3 >nul
start "" "C:\Users\%USERNAME%\AppData\Local\Programs\Ollama\ollama.exe"
timeout /t 10 >nul
echo [STEP 4] Testing API after restart...
powershell -Command "
try {
$response = Invoke-WebRequest -Uri 'http://localhost:11434/api/tags' -UseBasicParsing -TimeoutSec 5
if ($response.StatusCode -eq 200) {
Write-Host '[SUCCESS] API is now responding correctly'
}
} catch {
Write-Host '[ERROR] API is still not responding'
}
"
echo [SUCCESS] API troubleshooting completed
pause
goto :menu
:optimize_performance
echo.
echo ========================================================================
echo                        OPTIMIZING OLLAMA PERFORMANCE
echo ========================================================================
echo.
echo [INFO] Optimizing Ollama performance...
echo.
echo [STEP 1] Setting Ollama environment variables...
setx OLLAMA_NUM_PARALLEL 2 >nul 2>&1
setx OLLAMA_MAX_LOADED_MODELS 1 >nul 2>&1
echo [SUCCESS] Performance environment variables set
echo [STEP 2] Checking system resources...
powershell -Command "
$memory = Get-WmiObject -Class Win32_ComputerSystem
$totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
$freeMemoryGB = [math]::Round((Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
Write-Host '[INFO] Total system memory: ' $totalMemoryGB 'GB'
Write-Host '[INFO] Available memory: ' $freeMemoryGB 'GB'
if ($freeMemoryGB -lt 4) {
Write-Host '[WARNING] Low available memory - consider closing other applications'
}
"
echo [STEP 3] Optimizing model loading...
echo [INFO] Configuring Ollama for optimal performance...
powershell -Command "
if (Test-Path '%OLLAMA_CONFIG%') {
$configContent = @'
{
\"num_parallel\": 2,
\"max_loaded_models\": 1,
\"gpu_memory_fraction\": 0.8
}
'@
$configContent | Out-File -FilePath '%OLLAMA_CONFIG%\config.json' -Encoding UTF8
Write-Host '[SUCCESS] Performance configuration saved'
}
"
echo [SUCCESS] Performance optimization completed
pause
goto :menu
:test_models
echo.
echo ========================================================================
echo                        TESTING OLLAMA MODEL RESPONSES
echo ========================================================================
echo.
echo [INFO] Testing Ollama model responses...
echo.
echo [TEST 1] Testing qwen2.5:1.5b model...
echo [INFO] Sending test prompt to qwen2.5:1.5b...
ollama run qwen2.5:1.5b "Hello, can you respond with 'Model test successful'?" --verbose
if %errorlevel%==0 (
echo [SUCCESS] qwen2.5:1.5b model is responding correctly
) else (
echo [ERROR] qwen2.5:1.5b model test failed
)
echo.
echo [TEST 2] Testing qwen2.5-coder:7b model...
echo [INFO] Sending test prompt to qwen2.5-coder:7b...
ollama run qwen2.5-coder:7b "Write a simple Python function that returns 'Hello World'" --verbose
if %errorlevel%==0 (
echo [SUCCESS] qwen2.5-coder:7b model is responding correctly
) else (
echo [ERROR] qwen2.5-coder:7b model test failed
)
echo.
echo [TEST 3] Testing multi-model system...
echo [INFO] Testing DevOptimizer multi-model integration...
call "D:\DevOptimizer\RUN-OLLAMA-ALL-MODELS.bat" "Test prompt for system verification"
if %errorlevel%==0 (
echo [SUCCESS] Multi-model system is working correctly
) else (
echo [ERROR] Multi-model system test failed
)
echo [SUCCESS] Model testing completed
pause
goto :menu
:generate_report
echo.
echo ========================================================================
echo                      GENERATING OLLAMA DIAGNOSTIC REPORT
echo ========================================================================
echo.
set "REPORT_FILE=D:\DevOptimizer\logs\Ollama-Diagnostic-Report-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%.txt"
set "REPORT_FILE=%REPORT_FILE: =0%"
echo [INFO] Generating Ollama diagnostic report...
echo [INFO] Report location: %REPORT_FILE%
if not exist "D:\DevOptimizer\logs" mkdir "D:\DevOptimizer\logs"
(
echo Ollama Diagnostic Report
echo Generated on: %date% %time%
echo Computer: %COMPUTERNAME%
echo User: %USERNAME%
echo.
echo ========================================================================
echo OLLAMA PROCESSES
echo ========================================================================
tasklist | findstr /I "OLLAMA"
echo.
echo ========================================================================
echo OLLAMA INSTALLATION
echo ========================================================================
where ollama
echo.
echo ========================================================================
echo OLLAMA MODELS
echo ========================================================================
ollama list 2>nul
echo.
echo ========================================================================
echo OLLAMA API STATUS
echo ========================================================================
netstat -an | findstr :11434
echo.
echo ========================================================================
echo OLLAMA CONFIGURATION
echo ========================================================================
dir "%OLLAMA_CONFIG%" 2>nul
echo.
echo ========================================================================
echo SYSTEM RESOURCES
echo ========================================================================
systeminfo | findstr /B /C:"Total Physical Memory" /C:"Available Physical Memory"
) > "%REPORT_FILE%"
echo [SUCCESS] Diagnostic report generated: %REPORT_FILE%
pause
goto :menu
:advanced_diagnostics
echo.
echo ========================================================================
echo                        ADVANCED OLLAMA DIAGNOSTICS
echo ========================================================================
echo.
echo [INFO] Running advanced Ollama diagnostics...
echo.
echo [CHECK 1] Ollama service health...
powershell -Command "
$ollamaProcesses = Get-Process -Name 'ollama' -ErrorAction SilentlyContinue
if ($ollamaProcesses) {
foreach ($process in $ollamaProcesses) {
Write-Host '[INFO] Process ID: ' $process.Id ', CPU: ' $process.CPU ', Memory: ' [math]::Round($process.WorkingSet / 1MB, 2) 'MB'
}
} else {
Write-Host '[WARNING] No Ollama processes found'
}
"
echo [CHECK 2] Model file integrity...
powershell -Command "
$modelsPath = '%OLLAMA_CONFIG%\models'
if (Test-Path $modelsPath) {
$modelFiles = Get-ChildItem -Path $modelsPath -Recurse -File
Write-Host '[INFO] Total model files: ' $modelFiles.Count
$totalSize = ($modelFiles | Measure-Object -Property Length -Sum).Sum
Write-Host '[INFO] Total model size: ' [math]::Round($totalSize / 1GB, 2) 'GB'
} else {
Write-Host '[WARNING] Models directory not found'
}
"
echo [CHECK 3] Network connectivity to Ollama registry...
ping -n 1 ollama.ai >nul
if %errorlevel%==0 (
echo [SUCCESS] Connection to Ollama registry: OK
) else (
echo [ERROR] Cannot reach Ollama registry
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
echo [INFO] Ollama Troubleshooter closed
echo [INFO] Thank you for using DevOptimizer System
exit /b 0
