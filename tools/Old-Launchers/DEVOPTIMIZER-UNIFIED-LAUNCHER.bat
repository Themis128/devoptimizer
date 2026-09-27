@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title DevOptimizer Unified Launcher - Auto-Detection System
color 0A

echo ========================================================================
echo                    DEVOPTIMIZER UNIFIED LAUNCHER
echo ========================================================================
echo.
echo [INFO] Auto-detecting system privileges and environment...
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
set "ADMIN_MODE=YES"
set "PRIVILEGE_LEVEL=Administrator"
echo [SUCCESS] Running with administrator privileges
color 0E
) else (
set "ADMIN_MODE=NO"
set "PRIVILEGE_LEVEL=Standard User"
echo [INFO] Running without administrator privileges
color 0A
)

echo [STATUS] Privilege Level: %PRIVILEGE_LEVEL%
echo [STATUS] Admin Mode: %ADMIN_MODE%
echo.

REM Display system status
echo ========================================================================
echo                        QUICK SYSTEM STATUS
echo ========================================================================
echo.

echo [STATUS] Checking core system components...

REM Check OneDrive
tasklist | findstr OneDrive >nul 2>&1
if %errorLevel%==0 (
echo [] OneDrive: RUNNING
) else (
echo [!] OneDrive: NOT RUNNING
)

REM Check Ollama
tasklist | findstr ollama >nul 2>&1
if %errorLevel%==0 (
echo [] Ollama: RUNNING
) else (
echo [!] Ollama: NOT RUNNING
)

REM Check Cursor AI
tasklist | findstr Cursor >nul 2>&1
if %errorLevel%==0 (
echo [] Cursor AI: RUNNING
) else (
echo [!] Cursor AI: NOT RUNNING
)

echo.

REM Main menu based on privilege level
if "%ADMIN_MODE%"=="YES" (
goto :admin_menu
) else (
goto :user_menu
)

:admin_menu
echo ========================================================================
echo                     ADMINISTRATOR MODE MENU
echo ========================================================================
echo.
echo [ADMIN] Full system access available
echo.
echo [1] Ollama Model Manager
echo [2] Ollama Server Manager (ADMIN)
echo [3] Ollama Quick Tests
echo [4] M365 Troubleshooter (ADMIN)
echo [5] Cursor AI Troubleshooter
echo [6] Ollama Troubleshooter (ADMIN)
echo [7] OneDrive Manager (ADMIN)
echo [8] System Health Check (ADMIN)
echo [9] Performance Optimization (ADMIN)
echo [A] Development Tools Manager (ADMIN)
echo [B] System Backup Manager (ADMIN)
echo [C] Network Manager (ADMIN)
echo [D] Security Manager (ADMIN)
echo [E] System Performance Monitor (ADMIN)
echo [F] DevOptimizer Comprehensive Launcher (ADMIN)
echo [S] Switch to Standard User Mode
echo [0] Exit
echo.
set /p choice="Enter your choice (0-F,S): "
goto :process_admin_choice

:user_menu
echo ========================================================================
echo                     STANDARD USER MODE MENU
echo ========================================================================
echo.
echo [USER] Limited access - some features require admin privileges
echo.
echo [1] Ollama Model Manager
echo [2] Ollama Server Manager (USER)
echo [3] Ollama Quick Tests
echo [5] Cursor AI Troubleshooter
echo [6] Ollama Troubleshooter (USER)
echo [7] OneDrive Manager (USER)
echo [8] System Health Check (USER)
echo [9] Performance Optimization (USER)
echo [A] Development Tools Manager (USER)
echo [B] System Backup Manager (USER)
echo [C] Network Manager (USER)
echo [D] Security Manager (USER)
echo [E] System Performance Monitor (USER)
echo [F] DevOptimizer Comprehensive Launcher (USER)
echo [S] Switch to Administrator Mode (Restart Required)
echo [0] Exit
echo.
set /p choice="Enter your choice (0-F,S): "
goto :process_user_choice

:process_admin_choice
if "%choice%"=="1" goto :ollama_model_manager
if "%choice%"=="2" goto :ollama_server_admin
if "%choice%"=="3" goto :ollama_quick_tests
if "%choice%"=="4" goto :m365_admin
if "%choice%"=="5" goto :cursor_troubleshooter
if "%choice%"=="6" goto :ollama_troubleshooter_admin
if "%choice%"=="7" goto :onedrive_admin
if "%choice%"=="8" goto :health_check_admin
if "%choice%"=="9" goto :performance_admin
if "%choice%"=="A" goto :devtools_admin
if "%choice%"=="B" goto :backup_admin
if "%choice%"=="C" goto :network_admin
if "%choice%"=="D" goto :security_admin
if "%choice%"=="E" goto :performance_monitor_admin
if "%choice%"=="F" goto :comprehensive_admin
if "%choice%"=="S" goto :switch_to_user
if "%choice%"=="0" goto :exit
goto :invalid_choice

:process_user_choice
if "%choice%"=="1" goto :ollama_model_manager
if "%choice%"=="2" goto :ollama_server_user
if "%choice%"=="3" goto :ollama_quick_tests
if "%choice%"=="5" goto :cursor_troubleshooter
if "%choice%"=="6" goto :ollama_troubleshooter_user
if "%choice%"=="7" goto :onedrive_user
if "%choice%"=="8" goto :health_check_user
if "%choice%"=="9" goto :performance_user
if "%choice%"=="A" goto :devtools_user
if "%choice%"=="B" goto :backup_user
if "%choice%"=="C" goto :network_user
if "%choice%"=="D" goto :security_user
if "%choice%"=="E" goto :performance_monitor_user
if "%choice%"=="F" goto :comprehensive_user
if "%choice%"=="S" goto :switch_to_admin
if "%choice%"=="0" goto :exit
goto :invalid_choice

:ollama_model_manager
echo [INFO] Launching Ollama Model Manager...
if exist "OLLAMA-MODEL-MANAGER.bat" (
call "OLLAMA-MODEL-MANAGER.bat"
) else (
echo [ERROR] OLLAMA-MODEL-MANAGER.bat not found
pause
)
goto :menu

:ollama_server_admin
echo [INFO] Launching Ollama Server Manager (Admin Mode)...
if exist "OLLAMA-SERVER-MANAGER.bat" (
call "OLLAMA-SERVER-MANAGER.bat"
) else (
echo [ERROR] OLLAMA-SERVER-MANAGER.bat not found
pause
)
goto :menu

:ollama_server_user
echo [INFO] Launching Ollama Server Manager (User Mode)...
if exist "OLLAMA-SERVER-MANAGER.bat" (
call "OLLAMA-SERVER-MANAGER.bat"
) else (
echo [ERROR] OLLAMA-SERVER-MANAGER.bat not found
pause
)
goto :menu

:ollama_quick_tests
echo [INFO] Launching Ollama Quick Tests...
if exist "OLLAMA-QUICK-TESTS.bat" (
call "OLLAMA-QUICK-TESTS.bat"
) else (
echo [ERROR] OLLAMA-QUICK-TESTS.bat not found
pause
)
goto :menu

:m365_admin
echo [INFO] Launching M365 Troubleshooter (Admin Mode)...
if exist "M365-TROUBLESHOOTER.bat" (
call "M365-TROUBLESHOOTER.bat"
) else (
echo [ERROR] M365-TROUBLESHOOTER.bat not found
pause
)
goto :menu

:cursor_troubleshooter
echo [INFO] Launching Cursor AI Troubleshooter...
if exist "CURSOR-AI-TROUBLESHOOTER.bat" (
call "CURSOR-AI-TROUBLESHOOTER.bat"
) else (
echo [ERROR] CURSOR-AI-TROUBLESHOOTER.bat not found
pause
)
goto :menu

:ollama_troubleshooter_admin
echo [INFO] Launching Ollama Troubleshooter (Admin Mode)...
if exist "OLLAMA-TROUBLESHOOTER.bat" (
call "OLLAMA-TROUBLESHOOTER.bat"
) else (
echo [ERROR] OLLAMA-TROUBLESHOOTER.bat not found
pause
)
goto :menu

:ollama_troubleshooter_user
echo [INFO] Launching Ollama Troubleshooter (User Mode)...
if exist "OLLAMA-TROUBLESHOOTER.bat" (
call "OLLAMA-TROUBLESHOOTER.bat"
) else (
echo [ERROR] OLLAMA-TROUBLESHOOTER.bat not found
pause
)
goto :menu

:onedrive_admin
echo [INFO] Launching OneDrive Manager (Admin Mode)...
if exist "ONEDRIVE-MANAGER.bat" (
call "ONEDRIVE-MANAGER.bat"
) else (
echo [ERROR] ONEDRIVE-MANAGER.bat not found
pause
)
goto :menu

:onedrive_user
echo [INFO] Launching OneDrive Manager (User Mode)...
if exist "ONEDRIVE-MANAGER.bat" (
call "ONEDRIVE-MANAGER.bat"
) else (
echo [ERROR] ONEDRIVE-MANAGER.bat not found
pause
)
goto :menu

:health_check_admin
echo [INFO] Launching System Health Check (Admin Mode)...
if exist "SYSTEM-HEALTH-CHECK.bat" (
call "SYSTEM-HEALTH-CHECK.bat"
) else (
echo [ERROR] SYSTEM-HEALTH-CHECK.bat not found
pause
)
goto :menu

:health_check_user
echo [INFO] Launching System Health Check (User Mode)...
if exist "SYSTEM-HEALTH-CHECK.bat" (
call "SYSTEM-HEALTH-CHECK.bat"
) else (
echo [ERROR] SYSTEM-HEALTH-CHECK.bat not found
pause
)
goto :menu

:performance_admin
echo [INFO] Launching Performance Optimization (Admin Mode)...
if exist "01-Quick-Optimization.bat" (
call "01-Quick-Optimization.bat"
) else (
echo [ERROR] 01-Quick-Optimization.bat not found
pause
)
goto :menu

:performance_user
echo [INFO] Launching Performance Optimization (User Mode)...
if exist "01-Quick-Optimization.bat" (
call "01-Quick-Optimization.bat"
) else (
echo [ERROR] 01-Quick-Optimization.bat not found
pause
)
goto :menu

:devtools_admin
echo [INFO] Launching Development Tools Manager (Admin Mode)...
if exist "DEVTOOLS-MANAGER.bat" (
call "DEVTOOLS-MANAGER.bat"
) else (
echo [ERROR] DEVTOOLS-MANAGER.bat not found
pause
)
goto :menu

:devtools_user
echo [INFO] Launching Development Tools Manager (User Mode)...
if exist "DEVTOOLS-MANAGER.bat" (
call "DEVTOOLS-MANAGER.bat"
) else (
echo [ERROR] DEVTOOLS-MANAGER.bat not found
pause
)
goto :menu

:backup_admin
echo [INFO] Launching System Backup Manager (Admin Mode)...
if exist "SYSTEM-BACKUP-MANAGER.bat" (
call "SYSTEM-BACKUP-MANAGER.bat"
) else (
echo [ERROR] SYSTEM-BACKUP-MANAGER.bat not found
pause
)
goto :menu

:backup_user
echo [INFO] Launching System Backup Manager (User Mode)...
if exist "SYSTEM-BACKUP-MANAGER.bat" (
call "SYSTEM-BACKUP-MANAGER.bat"
) else (
echo [ERROR] SYSTEM-BACKUP-MANAGER.bat not found
pause
)
goto :menu

:network_admin
echo [INFO] Launching Network Manager (Admin Mode)...
if exist "NETWORK-MANAGER.bat" (
call "NETWORK-MANAGER.bat"
) else (
echo [ERROR] NETWORK-MANAGER.bat not found
pause
)
goto :menu

:network_user
echo [INFO] Launching Network Manager (User Mode)...
if exist "NETWORK-MANAGER.bat" (
call "NETWORK-MANAGER.bat"
) else (
echo [ERROR] NETWORK-MANAGER.bat not found
pause
)
goto :menu

:security_admin
echo [INFO] Launching Security Manager (Admin Mode)...
if exist "SECURITY-MANAGER.bat" (
call "SECURITY-MANAGER.bat"
) else (
echo [ERROR] SECURITY-MANAGER.bat not found
pause
)
goto :menu

:security_user
echo [INFO] Launching Security Manager (User Mode)...
if exist "SECURITY-MANAGER.bat" (
call "SECURITY-MANAGER.bat"
) else (
echo [ERROR] SECURITY-MANAGER.bat not found
pause
)
goto :menu

:performance_monitor_admin
echo [INFO] Launching System Performance Monitor (Admin Mode)...
if exist "SYSTEM-PERFORMANCE-MONITOR.bat" (
call "SYSTEM-PERFORMANCE-MONITOR.bat"
) else (
echo [ERROR] SYSTEM-PERFORMANCE-MONITOR.bat not found
pause
)
goto :menu

:performance_monitor_user
echo [INFO] Launching System Performance Monitor (User Mode)...
if exist "SYSTEM-PERFORMANCE-MONITOR.bat" (
call "SYSTEM-PERFORMANCE-MONITOR.bat"
) else (
echo [ERROR] SYSTEM-PERFORMANCE-MONITOR.bat not found
pause
)
goto :menu

:comprehensive_admin
echo [INFO] Launching DevOptimizer Comprehensive Launcher (Admin Mode)...
if exist "DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat" (
call "DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat"
) else (
echo [ERROR] DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat not found
pause
)
goto :menu

:comprehensive_user
echo [INFO] Launching DevOptimizer Comprehensive Launcher (User Mode)...
if exist "DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat" (
call "DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat"
) else (
echo [ERROR] DEVOPTIMIZER-COMPREHENSIVE-LAUNCHER.bat not found
pause
)
goto :menu

:switch_to_user
echo [INFO] Switching to Standard User Mode...
echo [STATUS] Restarting launcher in user mode...
start "" "%~f0"
exit /b 0

:switch_to_admin
echo [INFO] Switching to Administrator Mode...
echo [STATUS] Requesting administrator privileges...
powershell -Command "Start-Process '%~f0' -Verb RunAs"
exit /b 0

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please enter a valid option.
pause
goto :menu

:menu
cls
if "%ADMIN_MODE%"=="YES" (
goto :admin_menu
) else (
goto :user_menu
)

:exit
echo.
echo [INFO] DevOptimizer Unified Launcher closed
echo [STATUS] Thank you for using DevOptimizer!
echo.
exit /b 0


REM ================================================================================
REM                           [AI] AI-POWERED EXECUTION ANALYSIS
REM ================================================================================
REM This section was automatically added by the BAT Testing Framework
REM to provide AI-powered execution analysis using Ollama

echo.
echo [AI] Script execution completed. Starting intelligent analysis...
echo.

REM Create a temporary PowerShell script for AI analysis
set "AI_ANALYSIS_SCRIPT=%TEMP%\ai_analysis_%RANDOM%.ps1"

REM Generate the AI analysis script
(
echo # AI-Powered Execution Analysis with Ollama
echo Import-Module "D:\Nuxt Projects\llm-dev-agent\BAT\tests\modules\OllamaInsights.psm1" -Force
echo.
echo # Collect comprehensive execution data
echo $executionData = @{
echo     ScriptName = "%~nx0"
echo     ExecutionTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
echo     ErrorLevel = %ERRORLEVEL%
echo     SystemChanges = @()
echo     CommandsExecuted = @()
echo     MemoryUsage = ""
echo     DiskSpace = ""
echo     ProcessCount = ""
echo     Warnings = @()
echo     Errors = @()
echo     ScriptPath = "%~f0"
echo     WorkingDirectory = "%~dp0"
echo }
echo.
echo # Enhanced system analysis
echo try {
echo     # Memory analysis with detailed metrics
echo     $memInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
echo     if ($memInfo^) {
echo         $totalMem = [math]::Round($memInfo.TotalVisibleMemorySize / 1MB, 2^)
echo         $freeMem = [math]::Round($memInfo.FreePhysicalMemory / 1MB, 2^)
echo         $usedMem = $totalMem - $freeMem
echo         $memPercent = [math]::Round(($usedMem / $totalMem^) * 100, 1^)
echo         $executionData.MemoryUsage = "$memPercent%% ($usedMem MB used of $totalMem MB^)"
echo     }
echo.
echo     # Disk space analysis
echo     $diskInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
echo     if ($diskInfo^) {
echo         $freeSpace = [math]::Round($diskInfo.FreeSpace / 1GB, 2^)
echo         $totalSpace = [math]::Round($diskInfo.Size / 1GB, 2^)
echo         $usedSpace = $totalSpace - $freeSpace
echo         $diskPercent = [math]::Round(($usedSpace / $totalSpace^) * 100, 1^)
echo         $executionData.DiskSpace = "$diskPercent%% ($usedSpace GB used of $totalSpace GB^)"
echo     }
echo.
echo     # Process and service analysis
echo     $processCount = (Get-Process^).Count
echo     $serviceCount = (Get-Service^).Count
echo     $executionData.ProcessCount = "$processCount processes, $serviceCount services"
echo.
echo     # Detect system changes and modifications
echo     $systemChanges = @()
echo     if (Test-Path "C:\Windows\Temp\*"^) { $systemChanges += "Temporary files accessed" }
echo     if (Get-Service | Where-Object { $_.Status -eq "Running" -and $_.Name -like "*Update*" }^) { $systemChanges += "Windows Update active" }
echo     if (Get-Process | Where-Object { $_.ProcessName -like "*ollama*" }^) { $systemChanges += "Ollama AI service running" }
echo     $executionData.SystemChanges = $systemChanges
echo.
echo     # Performance warnings
echo     $warnings = @()
echo     if ($memPercent -gt 85^) { $warnings += "High memory usage detected" }
echo     if ($diskPercent -gt 90^) { $warnings += "Low disk space warning" }
echo     if ($processCount -gt 150^) { $warnings += "High process count detected" }
echo     if (%ERRORLEVEL% NEQ 0^) { $warnings += "Script execution errors present" }
echo     $executionData.Warnings = $warnings
echo.
echo     # Error analysis
echo     $errors = @()
echo     if (%ERRORLEVEL% NEQ 0^) {
echo         $errors += "Exit code: %ERRORLEVEL%"
echo     }
echo     $executionData.Errors = $errors
echo.
echo     # Generate AI-powered insights using Ollama
echo     Write-Host "[AI] Analyzing execution data with Ollama..." -ForegroundColor Cyan
echo     $insights = [OllamaInsights]::AnalyzeExecution($executionData^)
echo     $report = $insights.GenerateInsightReport^(^)
echo.
echo     # Display the comprehensive AI report
echo     Write-Host $report -ForegroundColor Cyan
echo.
echo } catch {
echo     Write-Host "AI Analysis Error: $($_.Exception.Message^)" -ForegroundColor Red
echo     Write-Host "Falling back to enhanced basic analysis..." -ForegroundColor Yellow
echo.
echo     # Enhanced fallback analysis
echo     Write-Host "=================================================================================" -ForegroundColor Cyan
echo     Write-Host "                     ENHANCED EXECUTION ANALYSIS" -ForegroundColor Cyan
echo     Write-Host "=================================================================================" -ForegroundColor Cyan
echo     Write-Host ""
echo     Write-Host " Script: %~nx0" -ForegroundColor White
echo     Write-Host "  Completion: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'^)" -ForegroundColor White
echo     Write-Host " Exit Code: %ERRORLEVEL%" -ForegroundColor White
echo     Write-Host ""
echo.
echo     # System status
echo     $memInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
echo     if ($memInfo^) {
echo         $totalMem = [math]::Round($memInfo.TotalVisibleMemorySize / 1MB, 2^)
echo         $freeMem = [math]::Round($memInfo.FreePhysicalMemory / 1MB, 2^)
echo         $usedMem = $totalMem - $freeMem
echo         $memPercent = [math]::Round(($usedMem / $totalMem^) * 100, 1^)
echo         Write-Host " Memory: $memPercent%% used ($usedMem MB / $totalMem MB^)" -ForegroundColor White
echo     }
echo.
echo     $diskInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
echo     if ($diskInfo^) {
echo         $freeSpace = [math]::Round($diskInfo.FreeSpace / 1GB, 2^)
echo         $totalSpace = [math]::Round($diskInfo.Size / 1GB, 2^)
echo         $usedSpace = $totalSpace - $freeSpace
echo         $diskPercent = [math]::Round(($usedSpace / $totalSpace^) * 100, 1^)
echo         Write-Host " Disk: $diskPercent%% used ($usedSpace GB / $totalSpace GB^)" -ForegroundColor White
echo     }
echo.
echo     $processCount = (Get-Process^).Count
echo     Write-Host "  Processes: $processCount running" -ForegroundColor White
echo     Write-Host ""
echo.
echo     if (%ERRORLEVEL% NEQ 0^) {
echo         Write-Host " Script completed with errors (Exit code: %ERRORLEVEL%^)" -ForegroundColor Red
echo         Write-Host " Recommendations:" -ForegroundColor Yellow
echo         Write-Host "    Check error messages above" -ForegroundColor White
echo         Write-Host "    Run as Administrator if needed" -ForegroundColor White
echo         Write-Host "    Verify file permissions and paths" -ForegroundColor White
echo     } else {
echo         Write-Host " Script completed successfully!" -ForegroundColor Green
echo         Write-Host " Next steps:" -ForegroundColor Yellow
echo         Write-Host "    Monitor system performance" -ForegroundColor White
echo         Write-Host "    Run optimization if needed" -ForegroundColor White
echo     }
echo     Write-Host ""
echo     Write-Host "  Available tools:" -ForegroundColor Cyan
echo     Write-Host "    System Monitor: .\SYSTEM-PERFORMANCE-MONITOR.bat" -ForegroundColor White
echo     Write-Host "    Optimization: .\01-Quick-Optimization.bat" -ForegroundColor White
echo     Write-Host "    Health Check: .\SYSTEM-HEALTH-CHECK.bat" -ForegroundColor White
echo     Write-Host "    BAT Testing: .\Test-AllBATFiles.ps1" -ForegroundColor White
echo     Write-Host ""
echo     Write-Host "=================================================================================" -ForegroundColor Cyan
echo     Write-Host "                         Press any key to continue..." -ForegroundColor Cyan
echo     Write-Host "=================================================================================" -ForegroundColor Cyan
echo }
echo.
echo # Clean up
echo if (Test-Path "$AI_ANALYSIS_SCRIPT"^) { Remove-Item "$AI_ANALYSIS_SCRIPT" -Force }
) > "$AI_ANALYSIS_SCRIPT"

REM Execute the AI analysis
echo [AI] Starting intelligent analysis...
powershell -ExecutionPolicy Bypass -File "$AI_ANALYSIS_SCRIPT"

REM Clean up temporary file
del "$AI_ANALYSIS_SCRIPT" 2>nul

echo.
echo [AI] Analysis complete. Thank you for using AI-powered insights!

REM Mark that AI pause has been added
set "AI_PAUSE_ADDED=TRUE"
set "AI_MODEL_USED=llama3.1:8b"
