@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title DevOptimizer BAT Hub - Verbose Descriptions
color 0A

echo ========================================================================
echo                    DEVOPTIMIZER BAT HUB
echo                   Verbose Descriptions Version
echo ========================================================================
echo.
echo [STATUS] Initializing DevOptimizer BAT Hub...
echo [INFO] Scanning for all available BAT files...
echo [INFO] Enhanced version with detailed verbose descriptions
echo.

REM Check if running from correct directory
if not exist "%~dp0" (
echo [ERROR] Cannot determine script directory
echo [INFO] Please ensure you are running this from the DevOptimizer directory
pause
exit /b 1
)

REM Check if logs directory exists, create if not
if not exist "%~dp0logs" (
echo [WARNING] Logs directory not found, creating...
mkdir "%~dp0logs" 2>nul
if !errorlevel!==0 (
echo [SUCCESS] Logs directory created successfully
) else (
echo [ERROR] Failed to create logs directory
)
)

echo [SUCCESS] DevOptimizer BAT Hub initialized
echo.

REM Comprehensive system status check
echo ========================================================================
echo                       SYSTEM STATUS CHECK
echo ========================================================================
echo.

REM Check Ollama status
echo [STATUS] Checking Ollama service...
tasklist | findstr /I "ollama.exe" 2>NUL | findstr /I "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Ollama: ONLINE ^(Running^)
) else (
echo [WARNING] Ollama: OFFLINE ^(Not Running^)
)

REM Check OneDrive status
echo [STATUS] Checking OneDrive service...
tasklist | findstr /I "OneDrive.exe" 2>NUL | findstr /I "OneDrive.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] OneDrive: ONLINE ^(Running^)
) else (
echo [WARNING] OneDrive: OFFLINE ^(Not Running^)
)

REM Check Cursor AI status
echo [STATUS] Checking Cursor AI...
tasklist | findstr /I "Cursor.exe" 2>NUL | findstr /I "Cursor.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] Cursor AI: ONLINE ^(Running^)
) else (
echo [WARNING] Cursor AI: OFFLINE ^(Not Running^)
)

REM Check VS Code status
echo [STATUS] Checking VS Code...
tasklist | findstr /I "Code.exe" 2>NUL | findstr /I "Code.exe">NUL
if "%ERRORLEVEL%"=="0" (
echo [SUCCESS] VS Code: ONLINE ^(Running^)
) else (
echo [WARNING] VS Code: OFFLINE ^(Not Running^)
)

echo [INFO] System status check completed
echo.

REM Initialize counters
set /a counter=0
set /a ollama_count=0
set /a cursor_count=0
set /a m365_count=0
set /a system_count=0
set /a dev_count=0
set /a aws_count=0
set /a other_count=0

echo ========================================================================
echo                       AVAILABLE BAT TOOLS
echo ========================================================================
echo.
echo [INFO] Scanning for BAT files with verbose descriptions...
echo.

REM Ollama Tools
echo [OLLAMA TOOLS]
for %%f in ("%~dp0OLLAMA-*.bat") do (
if exist "%%f" (
set /a ollama_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=OLLAMA"

REM Add verbose descriptions based on filename
if "%%~nf"=="OLLAMA-MODEL-MANAGER" (
echo [!counter!] %%~nf
echo     ^>^>^> Manages Ollama AI models: install new models, remove unused models, list all available models, check model sizes and performance. Essential for maintaining your local AI model collection.
) else if "%%~nf"=="OLLAMA-SERVER-MANAGER" (
echo [!counter!] %%~nf
echo     ^>^>^> Controls Ollama server operations: start/stop the Ollama service, restart server, check server status, configure server settings, and manage server resources. Critical for AI functionality.
) else if "%%~nf"=="OLLAMA-QUICK-TESTS" (
echo [!counter!] %%~nf
echo     ^>^>^> Performs quick performance and functionality tests on Ollama models: speed tests, accuracy tests, memory usage analysis, response quality checks, and model comparison benchmarks.
) else if "%%~nf"=="OLLAMA-TROUBLESHOOTER" (
echo [!counter!] %%~nf
echo     ^>^>^> Diagnoses and fixes common Ollama issues: connection problems, model loading errors, performance issues, memory problems, and provides automated solutions for common problems.
) else if "%%~nf"=="ollama-ai-analyzer" (
echo [!counter!] %%~nf
echo     ^>^>^> AI-powered system analysis tool that uses Ollama models to analyze system performance, identify bottlenecks, suggest optimizations, and provide intelligent recommendations for system improvements.
) else if "%%~nf"=="ollama-intelligent-monitor" (
echo [!counter!] %%~nf
echo     ^>^>^> Intelligent system monitoring with AI assistance: real-time system monitoring, predictive analysis, anomaly detection, performance trending, and automated alert generation using AI models.
) else if "%%~nf"=="ollama-intelligent-optimizer" (
echo [!counter!] %%~nf
echo     ^>^>^> AI-driven system optimization tool: analyzes system configuration, identifies optimization opportunities, applies intelligent tweaks, monitors results, and continuously improves system performance using machine learning.
) else if "%%~nf"=="ollama-performance-scorer" (
echo [!counter!] %%~nf
echo     ^>^>^> Performance scoring and benchmarking tool: evaluates system performance across multiple metrics, generates performance scores, compares against baselines, tracks performance trends, and provides detailed performance reports.
) else if "%%~nf"=="ollama-predictive-maintenance" (
echo [!counter!] %%~nf
echo     ^>^>^> Predictive maintenance system using AI: monitors system health indicators, predicts potential failures, schedules preventive maintenance, tracks component lifecycles, and prevents system downtime through intelligent forecasting.
) else if "%%~nf"=="ollama-script-generator" (
echo [!counter!] %%~nf
echo     ^>^>^> AI-powered script generation tool: creates custom batch scripts, PowerShell scripts, and automation scripts based on natural language descriptions, learns from existing scripts, and generates optimized code solutions.
) else (
echo [!counter!] %%~nf
echo     ^>^>^> Ollama AI integration tool for advanced AI-powered system management and automation tasks.
)
)
)
if !ollama_count!==0 echo [INFO] No Ollama tools found
echo.

REM Cursor AI Tools
echo [CURSOR AI TOOLS]
for %%f in ("%~dp0CURSOR-*.bat") do (
if exist "%%f" (
set /a cursor_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=CURSOR"

if "%%~nf"=="CURSOR-AI-COMPLETE-OPTIMIZER" (
echo [!counter!] %%~nf
echo     ^>^>^> Complete Cursor AI optimization suite: optimizes Cursor AI settings, improves code completion accuracy, enhances AI response quality, configures AI models, and maximizes development productivity with intelligent AI assistance.
) else if "%%~nf"=="CURSOR-AI-ESSENTIAL-TOOLS" (
echo [!counter!] %%~nf
echo     ^>^>^> Essential Cursor AI development tools collection: provides core AI-powered development utilities, code analysis tools, intelligent refactoring, automated testing, and productivity enhancements for modern development workflows.
) else if "%%~nf"=="CURSOR-AI-GIT-CACHE-CLEAR" (
echo [!counter!] %%~nf
echo     ^>^>^> Clears Git cache for Cursor AI optimization: removes stale Git cache files, optimizes Git performance, clears AI-related cache, improves Cursor AI responsiveness, and resolves Git integration issues with AI features.
) else if "%%~nf"=="CURSOR-AI-OPTIMIZATION-SUITE" (
echo [!counter!] %%~nf
echo     ^>^>^> Comprehensive Cursor AI optimization suite: fine-tunes AI settings, optimizes memory usage, improves response times, configures AI models, enhances code suggestions, and maximizes AI development efficiency.
) else if "%%~nf"=="CURSOR-AI-TROUBLESHOOTER" (
echo [!counter!] %%~nf
echo     ^>^>^> Diagnoses and fixes Cursor AI issues: resolves AI connection problems, fixes code completion issues, troubleshoots AI model errors, optimizes AI performance, and provides solutions for common Cursor AI problems.
) else (
echo [!counter!] %%~nf
echo     ^>^>^> Cursor AI development tool for enhanced AI-powered coding assistance and development productivity.
)
)
)
if !cursor_count!==0 echo [INFO] No Cursor AI tools found
echo.

REM M365 Tools
echo [MICROSOFT 365 TOOLS]
for %%f in ("%~dp0M365-*.bat") do (
if exist "%%f" (
set /a m365_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=M365"

if "%%~nf"=="M365-ACCOUNTS-ENHANCER" (
echo [!counter!] %%~nf
echo     ^>^>^> Enhances Microsoft 365 account settings and configurations: optimizes account settings, improves sync performance, configures security settings, manages licenses, and enhances overall Microsoft 365 experience.
) else if "%%~nf"=="M365-TROUBLESHOOTER" (
echo [!counter!] %%~nf
echo     ^>^>^> Diagnoses and fixes Microsoft 365 issues: resolves authentication problems, fixes sync issues, troubleshoots Office applications, resolves licensing problems, and provides automated solutions for common M365 issues.
) else (
echo [!counter!] %%~nf
echo     ^>^>^> Microsoft 365 management and optimization tool for enhanced productivity and reliability.
)
)
)
for %%f in ("%~dp0ONEDRIVE-*.bat") do (
if exist "%%f" (
set /a m365_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=M365"
echo [!counter!] %%~nf
echo     ^>^>^> Manages OneDrive sync and settings: optimizes sync performance, resolves sync conflicts, manages storage, configures sync settings, troubleshoots sync issues, and ensures reliable cloud file synchronization.
)
)
if !m365_count!==0 echo [INFO] No M365 tools found
echo.

REM System Tools
echo [SYSTEM TOOLS]
for %%f in ("%~dp0SYSTEM-*.bat") do (
if exist "%%f" (
set /a system_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=SYSTEM"

if "%%~nf"=="SYSTEM-BACKUP-MANAGER" (
echo [!counter!] %%~nf
echo     ^>^>^> Creates and manages comprehensive system backups: automated backup scheduling, incremental backups, system restore points, file versioning, backup verification, and disaster recovery preparation.
) else if "%%~nf"=="SYSTEM-PERFORMANCE-MONITOR" (
echo [!counter!] %%~nf
echo     ^>^>^> Monitors system performance metrics in real-time: CPU usage, memory consumption, disk I/O, network performance, process monitoring, performance alerts, and detailed performance reporting.
) else if "%%~nf"=="SYSTEM-COMPLETION-SUMMARY" (
echo [!counter!] %%~nf
echo     ^>^>^> Generates comprehensive system completion summary: system status overview, completed tasks, pending operations, system health summary, and detailed completion reports for system maintenance.
) else if "%%~nf"=="SYSTEM-IMPROVEMENT-PLAN" (
echo [!counter!] %%~nf
echo     ^>^>^> Creates detailed system improvement plans: identifies improvement opportunities, prioritizes optimizations, creates implementation schedules, tracks progress, and provides actionable improvement recommendations.
) else (
echo [!counter!] %%~nf
echo     ^>^>^> Advanced system management tool for comprehensive system administration and optimization.
)
)
)
for %%f in ("%~dp0HEALTH-*.bat") do (
if exist "%%f" (
set /a system_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=SYSTEM"
echo [!counter!] %%~nf
echo     ^>^>^> System health monitoring and diagnostics: comprehensive health checks, system diagnostics, performance analysis, health scoring, preventive maintenance, and detailed health reporting.
)
)
for %%f in ("%~dp0PERFORMANCE-*.bat") do (
if exist "%%f" (
set /a system_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=SYSTEM"
echo [!counter!] %%~nf
echo     ^>^>^> Performance optimization and monitoring: system performance tuning, optimization recommendations, performance benchmarking, resource optimization, and continuous performance improvement.
)
)
for %%f in ("%~dp0NETWORK-*.bat") do (
if exist "%%f" (
set /a system_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=SYSTEM"
echo [!counter!] %%~nf
echo     ^>^>^> Network configuration and diagnostics: network optimization, connection troubleshooting, bandwidth management, network security, performance monitoring, and network health analysis.
)
)
for %%f in ("%~dp0SECURITY-*.bat") do (
if exist "%%f" (
set /a system_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=SYSTEM"
echo [!counter!] %%~nf
echo     ^>^>^> Security settings and monitoring: security configuration, threat detection, security scanning, vulnerability assessment, security hardening, and comprehensive security management.
)
)
if !system_count!==0 echo [INFO] No System tools found
echo.

REM Development Tools
echo [DEVELOPMENT TOOLS]
for %%f in ("%~dp0DEVOPTIMIZER-*.bat") do (
if exist "%%f" (
set /a dev_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=DEV"
echo [!counter!] %%~nf
echo     ^>^>^> DevOptimizer comprehensive launcher: central hub for all development tools, system optimization, AI integration, and development environment management with intelligent automation and productivity features.
)
)
for %%f in ("%~dp0DEVTOOLS-*.bat") do (
if exist "%%f" (
set /a dev_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=DEV"
echo [!counter!] %%~nf
echo     ^>^>^> Development tools manager: manages development environment, installs development tools, configures development settings, optimizes development workflow, and provides comprehensive development tool management.
)
)
if !dev_count!==0 echo [INFO] No Development tools found
echo.

REM AWS Tools
echo [AWS TOOLS]
for %%f in ("%~dp0AWS-*.bat") do (
if exist "%%f" (
set /a aws_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=AWS"

if "%%~nf"=="AWS-IAC-MANAGER" (
echo [!counter!] %%~nf
echo     ^>^>^> Infrastructure as Code management: manages AWS infrastructure using code, automates infrastructure deployment, manages Terraform configurations, handles infrastructure versioning, and provides infrastructure lifecycle management.
) else if "%%~nf"=="AWS-IAC-MANAGER-ASCII" (
echo [!counter!] %%~nf
echo     ^>^>^> ASCII-based AWS IAC management: provides text-based interface for AWS infrastructure management, ASCII diagrams for infrastructure visualization, command-line infrastructure management, and simplified IAC operations.
) else if "%%~nf"=="AWS-POWERSHELL-MODULES-DOWNLOADER" (
echo [!counter!] %%~nf
echo     ^>^>^> Downloads AWS PowerShell modules: automatically downloads and installs AWS PowerShell modules, manages module versions, configures AWS PowerShell environment, and ensures up-to-date AWS PowerShell integration.
) else if "%%~nf"=="AWS-TERRAFORM-ANALYZER" (
echo [!counter!] %%~nf
echo     ^>^>^> Analyzes Terraform configurations: validates Terraform code, analyzes infrastructure configurations, identifies optimization opportunities, provides security recommendations, and generates detailed Terraform analysis reports.
) else (
echo [!counter!] %%~nf
echo     ^>^>^> AWS cloud management and automation tool for comprehensive cloud infrastructure management.
)
)
)
if !aws_count!==0 echo [INFO] No AWS tools found
echo.

REM Other Tools
echo [OTHER TOOLS]
for %%f in ("%~dp0*.bat") do (
if exist "%%f" (
set "filename=%%~nf"
set "skip=0"

REM Skip already categorized files
if "!filename:~0,7!"=="OLLAMA-" set "skip=1"
if "!filename:~0,7!"=="CURSOR-" set "skip=1"
if "!filename:~0,4!"=="M365-" set "skip=1"
if "!filename:~0,7!"=="ONEDRIVE-" set "skip=1"
if "!filename:~0,7!"=="SYSTEM-" set "skip=1"
if "!filename:~0,7!"=="HEALTH-" set "skip=1"
if "!filename:~0,12!"=="PERFORMANCE-" set "skip=1"
if "!filename:~0,8!"=="NETWORK-" set "skip=1"
if "!filename:~0,9!"=="SECURITY-" set "skip=1"
if "!filename:~0,12!"=="DEVOPTIMIZER-" set "skip=1"
if "!filename:~0,8!"=="DEVTOOLS-" set "skip=1"
if "!filename:~0,4!"=="AWS-" set "skip=1"

if !skip!==0 (
set /a other_count+=1
set /a counter+=1
set "bat_!counter!=%%~nf"
set "bat_path_!counter!=%%f"
set "bat_category_!counter!=OTHER"

REM Add verbose descriptions for common tools
if "!filename!"=="01-Quick-Optimization" (
echo [!counter!] !filename!
echo     ^>^>^> Quick system optimization: performs fast system optimizations, cleans temporary files, optimizes registry, improves startup performance, and provides immediate system performance improvements.
) else if "!filename!"=="02-Ultra-Performance" (
echo [!counter!] !filename!
echo     ^>^>^> Ultra performance mode activation: enables maximum performance mode, optimizes system for speed, disables unnecessary services, maximizes resource allocation, and provides extreme performance tuning.
) else if "!filename!"=="06-System-Health-Check" (
echo [!counter!] !filename!
echo     ^>^>^> Comprehensive system health check: performs thorough system diagnostics, checks hardware health, analyzes system performance, identifies potential issues, and provides detailed health assessment reports.
) else if "!filename!"=="12-Power-Management" (
echo [!counter!] !filename!
echo     ^>^>^> Power management optimization: optimizes power settings, manages power profiles, improves battery life, configures power management, and provides intelligent power optimization for laptops and desktops.
) else if "!filename!"=="18-Screen-Settings-Manager" (
echo [!counter!] !filename!
echo     ^>^>^> Screen resolution and display settings manager: manages display configurations, optimizes screen settings, configures multiple monitors, adjusts resolution, and provides comprehensive display management.
) else if "!filename!"=="BATCH-FILE-FIXER" (
echo [!counter!] !filename!
echo     ^>^>^> Fixes common batch file issues: automatically detects and fixes syntax errors, missing quotes, unbalanced parentheses, infinite loops, and other common batch file problems with intelligent error correction.
) else if "!filename!"=="CREATE-DESKTOP-SHORTCUT" (
echo [!counter!] !filename!
echo     ^>^>^> Creates desktop shortcuts: generates desktop shortcuts for applications, creates custom shortcuts, manages shortcut properties, and provides convenient access to frequently used programs and tools.
) else if "!filename!"=="INSTALL" (
echo [!counter!] !filename!
echo     ^>^>^> Installs development tools: automated installation of development tools, package managers, programming languages, development frameworks, and essential development environment components.
) else if "!filename!"=="UNINSTALL" (
echo [!counter!] !filename!
echo     ^>^>^> Uninstalls tools and cleanup: removes installed tools, cleans up system files, removes registry entries, clears temporary files, and provides comprehensive system cleanup and tool removal.
) else if "!filename!"=="organize-files" (
echo [!counter!] !filename!
echo     ^>^>^> Organizes files into categories: automatically categorizes and organizes files, creates folder structures, moves files to appropriate locations, and maintains organized file system structure.
) else if "!filename!"=="optimizer" (
echo [!counter!] !filename!
echo     ^>^>^> General system optimizer: comprehensive system optimization tool that improves performance, cleans system files, optimizes settings, enhances stability, and provides overall system improvement.
) else (
echo [!counter!] !filename!
echo     ^>^>^> Utility tool for system management, optimization, and automation tasks.
)
)
)
)
if !other_count!==0 echo [INFO] No Other tools found
echo.

echo ========================================================================
echo [SUMMARY] Found !counter! BAT tools available
echo [OLLAMA: !ollama_count!] [CURSOR: !cursor_count!] [M365: !m365_count!] [SYSTEM: !system_count!] [DEV: !dev_count!] [AWS: !aws_count!] [OTHER: !other_count!]
echo ========================================================================
echo.

:main_menu
echo [0] Exit Hub
echo.
set /p "choice=Enter your choice (number): "

if "%choice%"=="0" goto :exit

REM Validate choice
if %choice% LSS 1 goto :invalid_choice
if %choice% GTR !counter! goto :invalid_choice

REM Get the selected tool
set "selected_tool=!bat_%choice%!"
set "selected_path=!bat_path_%choice%!"
set "selected_category=!bat_category_%choice%!"

if "%selected_tool%"=="" goto :invalid_choice

echo.
echo [INFO] Selected: !selected_tool! (!selected_category! category)
echo [INFO] Path: !selected_path!
echo [INFO] Launching tool...
echo.

REM Launch the selected tool
if exist "!selected_path!" (
call "!selected_path!"
) else (
echo [ERROR] Tool file not found: !selected_path!
echo [INFO] Please check if the file exists
)

echo.
echo [INFO] Tool execution completed
echo [INFO] Press any key to return to main menu...
pause >nul
goto :main_menu

:invalid_choice
echo.
echo [ERROR] Invalid choice: %choice%
echo [INFO] Please enter a number between 0 and !counter!
echo [INFO] Press any key to continue...
pause >nul
goto :main_menu

:exit
echo.
echo [INFO] Exiting DevOptimizer BAT Hub...
echo [SUCCESS] Thank you for using DevOptimizer!
echo.
exit /b 0
