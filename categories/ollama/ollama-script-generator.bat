@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

:: ================================================================
::           OLLAMA AUTOMATED SCRIPT GENERATOR FOR WIN11 BUILD 26120
:: ================================================================

set "BAT_HUB=%~dp0"
set "BAT_HUB=%BAT_HUB:~0,-1%"

call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Running Ollama Script Generator"

echo.
echo ================================================================
echo         OLLAMA AUTOMATED SCRIPT GENERATOR FOR WIN11 BUILD 26120
echo ================================================================
echo.
echo Choose script generation mode:
echo.
echo [1]  TASK-SPECIFIC - Generate script for specific task
echo [2]  WORKFLOW-AUTOMATION - Create workflow automation scripts
echo [3]  SYSTEM-REPAIR - Generate system repair and maintenance scripts
echo [4]  PERFORMANCE-BOOST - Create performance enhancement scripts
echo [5]  SECURITY-HARDENING - Generate security hardening scripts
echo [6]  MONITORING-SCRIPTS - Create monitoring and alerting scripts
echo [7]  TESTING-SCRIPTS - Generate testing and validation scripts
echo [8] [TOOL] CUSTOM-SCRIPTS - Create custom scripts based on requirements
echo [0] Back to main menu
echo.
set /p script_choice="Enter your choice (0-8): "

if "%script_choice%"=="0" goto :eof
if "%script_choice%"=="1" goto task_specific
if "%script_choice%"=="2" goto workflow_automation
if "%script_choice%"=="3" goto system_repair
if "%script_choice%"=="4" goto performance_boost
if "%script_choice%"=="5" goto security_hardening
if "%script_choice%"=="6" goto monitoring_scripts
if "%script_choice%"=="7" goto testing_scripts
if "%script_choice%"=="8" goto custom_scripts

echo Invalid choice. Please try again.
pause
goto :eof

:task_specific
echo.
echo  TASK-SPECIFIC MODE - Generate script for specific task
echo ================================================================
echo.
echo Available task categories:
echo [1] File Management
echo [2] System Configuration
echo [3] Network Operations
echo [4] Security Operations
echo [5] Performance Tuning
echo [6] Backup and Recovery
echo [7] Software Management
echo [8] Hardware Management
echo.
set /p task_cat="Select task category (1-8): "

if "%task_cat%"=="1" set "TASK_TYPE=File Management"
if "%task_cat%"=="2" set "TASK_TYPE=System Configuration"
if "%task_cat%"=="3" set "TASK_TYPE=Network Operations"
if "%task_cat%"=="4" set "TASK_TYPE=Security Operations"
if "%task_cat%"=="5" set "TASK_TYPE=Performance Tuning"
if "%task_cat%"=="6" set "TASK_TYPE=Backup and Recovery"
if "%task_cat%"=="7" set "TASK_TYPE=Software Management"
if "%task_cat%"=="8" set "TASK_TYPE=Hardware Management"

echo.
echo Describe the specific task you need:
set /p task_desc="Enter task description: "

echo Generating task-specific script...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Generate a Windows batch script for %TASK_TYPE% task: %task_desc%. System: Windows 11 Build 26120, Intel i9-12900H, 32GB RAM. Create a complete, executable batch script with proper error handling, logging, and safety checks. Include comments explaining each section." -output "%BAT_HUB%\generated-scripts\%TASK_TYPE%-%RANDOM%.bat"

echo Task-specific script generated!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Task-specific script generated: %TASK_TYPE%"
pause
goto :eof

:workflow_automation
echo.
echo  WORKFLOW-AUTOMATION MODE - Create workflow automation scripts
echo ================================================================
echo.
echo Describe your workflow automation needs:
set /p workflow_desc="Enter workflow description: "

echo Generating workflow automation script...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create a comprehensive workflow automation script for Windows 11 Build 26120. Workflow: %workflow_desc%. Include: 1) Step-by-step automation 2) Error handling and recovery 3) Progress tracking 4) Logging system 5) User notifications 6) Rollback capabilities. Generate a complete, production-ready script." -output "%BAT_HUB%\generated-scripts\workflow-%RANDOM%.bat"

echo Workflow automation script generated!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Workflow automation script generated"
pause
goto :eof

:system_repair
echo.
echo  SYSTEM-REPAIR MODE - Generate system repair and maintenance scripts
echo ================================================================
echo.
echo Choose repair type:
echo [1] Registry Repair
echo [2] File System Repair
echo [3] Network Repair
echo [4] Performance Repair
echo [5] Security Repair
echo [6] Complete System Repair
echo.
set /p repair_type="Select repair type (1-6): "

if "%repair_type%"=="1" set "REPAIR_TARGET=Registry Repair"
if "%repair_type%"=="2" set "REPAIR_TARGET=File System Repair"
if "%repair_type%"=="3" set "REPAIR_TARGET=Network Repair"
if "%repair_type%"=="4" set "REPAIR_TARGET=Performance Repair"
if "%repair_type%"=="5" set "REPAIR_TARGET=Security Repair"
if "%repair_type%"=="6" set "REPAIR_TARGET=Complete System Repair"

echo Generating system repair script...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create a comprehensive %REPAIR_TARGET% script for Windows 11 Build 26120 with Intel i9-12900H. Include: 1) Diagnostic checks 2) Repair procedures 3) Backup creation 4) Rollback options 5) Progress monitoring 6) Success verification. Generate a safe, reversible repair script." -output "%BAT_HUB%\generated-scripts\%REPAIR_TARGET%-%RANDOM%.bat"

echo System repair script generated!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "System repair script generated: %REPAIR_TARGET%"
pause
goto :eof

:performance_boost
echo.
echo  PERFORMANCE-BOOST MODE - Create performance enhancement scripts
echo ================================================================
echo.
echo Choose performance focus:
echo [1] CPU Optimization
echo [2] Memory Optimization
echo [3] Storage Optimization
echo [4] Network Optimization
echo [5] Overall System Performance
echo.
set /p perf_focus="Select performance focus (1-5): "

if "%perf_focus%"=="1" set "PERF_TARGET=CPU Optimization"
if "%perf_focus%"=="2" set "PERF_TARGET=Memory Optimization"
if "%perf_focus%"=="3" set "PERF_TARGET=Storage Optimization"
if "%perf_focus%"=="4" set "PERF_TARGET=Network Optimization"
if "%perf_focus%"=="5" set "PERF_TARGET=Overall System Performance"

echo Generating performance boost script...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create a %PERF_TARGET% script for Windows 11 Build 26120 with Intel i9-12900H (20 threads), 32GB RAM. Focus on maximizing performance while maintaining system stability. Include: 1) Performance baseline measurement 2) Optimization procedures 3) Performance monitoring 4) Rollback options 5) Performance validation." -output "%BAT_HUB%\generated-scripts\%PERF_TARGET%-%RANDOM%.bat"

echo Performance boost script generated!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Performance boost script generated: %PERF_TARGET%"
pause
goto :eof

:security_hardening
echo.
echo  SECURITY-HARDENING MODE - Generate security hardening scripts
echo ================================================================
echo.
echo Choose security focus:
echo [1] Windows Defender Optimization
echo [2] Firewall Configuration
echo [3] User Account Security
echo [4] System Security Policies
echo [5] Network Security
echo [6] Complete Security Hardening
echo.
set /p sec_focus="Select security focus (1-6): "

if "%sec_focus%"=="1" set "SEC_TARGET=Windows Defender Optimization"
if "%sec_focus%"=="2" set "SEC_TARGET=Firewall Configuration"
if "%sec_focus%"=="3" set "SEC_TARGET=User Account Security"
if "%sec_focus%"=="4" set "SEC_TARGET=System Security Policies"
if "%sec_focus%"=="5" set "SEC_TARGET=Network Security"
if "%sec_focus%"=="6" set "SEC_TARGET=Complete Security Hardening"

echo Generating security hardening script...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create a %SEC_TARGET% script for Windows 11 Build 26120. Focus on enhancing security while maintaining usability. Include: 1) Security assessment 2) Hardening procedures 3) Security monitoring 4) Rollback options 5) Security validation. Ensure compliance with security best practices." -output "%BAT_HUB%\generated-scripts\%SEC_TARGET%-%RANDOM%.bat"

echo Security hardening script generated!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Security hardening script generated: %SEC_TARGET%"
pause
goto :eof

:monitoring_scripts
echo.
echo  MONITORING-SCRIPTS MODE - Create monitoring and alerting scripts
echo ================================================================
echo.
echo Choose monitoring type:
echo [1] System Performance Monitoring
echo [2] Hardware Health Monitoring
echo [3] Security Event Monitoring
echo [4] Network Activity Monitoring
echo [5] Application Performance Monitoring
echo [6] Comprehensive System Monitoring
echo.
set /p mon_type="Select monitoring type (1-6): "

if "%mon_type%"=="1" set "MON_TARGET=System Performance Monitoring"
if "%mon_type%"=="2" set "MON_TARGET=Hardware Health Monitoring"
if "%mon_type%"=="3" set "MON_TARGET=Security Event Monitoring"
if "%mon_type%"=="4" set "MON_TARGET=Network Activity Monitoring"
if "%mon_type%"=="5" set "MON_TARGET=Application Performance Monitoring"
if "%mon_type%"=="6" set "MON_TARGET=Comprehensive System Monitoring"

echo Generating monitoring script...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create a %MON_TARGET% script for Windows 11 Build 26120 with Intel i9-12900H. Include: 1) Real-time monitoring 2) Alert system 3) Data logging 4) Performance thresholds 5) Automated responses 6) Reporting capabilities. Generate a comprehensive monitoring solution." -output "%BAT_HUB%\generated-scripts\%MON_TARGET%-%RANDOM%.bat"

echo Monitoring script generated!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Monitoring script generated: %MON_TARGET%"
pause
goto :eof

:testing_scripts
echo.
echo  TESTING-SCRIPTS MODE - Generate testing and validation scripts
echo ================================================================
echo.
echo Choose testing type:
echo [1] System Functionality Testing
echo [2] Performance Benchmarking
echo [3] Security Testing
echo [4] Compatibility Testing
echo [5] Stress Testing
echo [6] Comprehensive Testing Suite
echo.
set /p test_type="Select testing type (1-6): "

if "%test_type%"=="1" set "TEST_TARGET=System Functionality Testing"
if "%test_type%"=="2" set "TEST_TARGET=Performance Benchmarking"
if "%test_type%"=="3" set "TEST_TARGET=Security Testing"
if "%test_type%"=="4" set "TEST_TARGET=Compatibility Testing"
if "%test_type%"=="5" set "TEST_TARGET=Stress Testing"
if "%test_type%"=="6" set "TEST_TARGET=Comprehensive Testing Suite"

echo Generating testing script...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create a %TEST_TARGET% script for Windows 11 Build 26120 with Intel i9-12900H. Include: 1) Test case execution 2) Results collection 3) Performance metrics 4) Error detection 5) Reporting system 6) Test validation. Generate a comprehensive testing solution." -output "%BAT_HUB%\generated-scripts\%TEST_TARGET%-%RANDOM%.bat"

echo Testing script generated!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Testing script generated: %TEST_TARGET%"
pause
goto :eof

:custom_scripts
echo.
echo [TOOL] CUSTOM-SCRIPTS MODE - Create custom scripts based on requirements
echo ================================================================
echo.
echo Describe your custom script requirements:
set /p custom_req="Enter detailed requirements: "

echo Generating custom script...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create a custom Windows batch script for Windows 11 Build 26120 with Intel i9-12900H, 32GB RAM. Requirements: %custom_req%. Generate a complete, executable script with proper error handling, logging, safety checks, and documentation. Ensure the script is optimized for this specific system configuration." -output "%BAT_HUB%\generated-scripts\custom-%RANDOM%.bat"

echo Custom script generated!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Custom script generated"
pause
goto :eof
exit /b %ERRORLEVEL%
