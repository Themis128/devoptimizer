:: SYNOPSIS: DevOptimizer automation script: ENHANCED-SYSTEM-DIAGNOSTICS-Admin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title  - Admin Mode-12): "

if "%choice%"=="1" goto system_information
if "%choice%"=="2" goto hardware_analysis
if "%choice%"=="3" goto network_diagnostics
if "%choice%"=="4" goto security_analysis
if "%choice%"=="5" goto performance_metrics
if "%choice%"=="6" goto service_status
if "%choice%"=="7" goto disk_analysis
if "%choice%"=="8" goto registry_health
if "%choice%"=="9" goto event_log_analysis
if "%choice%"=="10" goto startup_analysis
if "%choice%"=="11" goto complete_diagnostics
if "%choice%"=="12" goto generate_report
if "%choice%"=="0" goto exit
goto invalid_choice

:system_information
echo.
echo ================================================================
echo               SYSTEM INFORMATION
echo ================================================================
echo.
echo Gathering system information...
echo.

:: Create reports directory
if not exist "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics" mkdir "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics"

:: Get system info
echo [1/8] Getting system information...
systeminfo > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\system-info.txt"
echo [SUCCESS] System information gathered

:: Get OS info
echo [2/8] Getting OS information...
wmic os get Caption,Version,Architecture,TotalVisibleMemorySize,FreePhysicalMemory /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\os-info.txt"
echo [SUCCESS] OS information gathered

:: Get computer info
echo [3/8] Getting computer information...
wmic computersystem get Name,Domain,Manufacturer,Model,TotalPhysicalMemory /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\computer-info.txt"
echo [SUCCESS] Computer information gathered

:: Get processor info
echo [4/8] Getting processor information...
wmic cpu get Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\processor-info.txt"
echo [SUCCESS] Processor information gathered

:: Get memory info
echo [5/8] Getting memory information...
wmic memorychip get Capacity,Speed,Manufacturer,PartNumber /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\memory-info.txt"
echo [SUCCESS] Memory information gathered

:: Get disk info
echo [6/8] Getting disk information...
wmic diskdrive get Model,Size,InterfaceType,MediaType /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\disk-info.txt"
echo [SUCCESS] Disk information gathered

:: Get network info
echo [7/8] Getting network information...
ipconfig /all > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\network-info.txt"
echo [SUCCESS] Network information gathered

:: Get installed programs
echo [8/8] Getting installed programs...
wmic product get Name,Version,Vendor /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\installed-programs.txt"
echo [SUCCESS] Installed programs gathered

echo [SUCCESS] System information analysis completed!
echo.
pause
goto main_menu

:hardware_analysis
echo.
echo ================================================================
echo               HARDWARE ANALYSIS
echo ================================================================
echo.
echo Analyzing hardware components...
echo.

:: Get CPU usage
echo [1/6] Getting CPU usage...
wmic cpu get LoadPercentage /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\cpu-usage.txt"
echo [SUCCESS] CPU usage gathered

:: Get memory usage
echo [2/6] Getting memory usage...
wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\memory-usage.txt"
echo [SUCCESS] Memory usage gathered

:: Get disk usage
echo [3/6] Getting disk usage...
for /f "tokens=3" %%a in ('dir /-c ^| find "bytes free"') do set freebytes=%%a
echo Free space: %%freebytes bytes > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\disk-usage.txt"
echo [SUCCESS] Disk usage gathered

:: Get temperature info
echo [4/6] Getting temperature information...
wmic /namespace:\\root\wmi path MSAcpi_ThermalZoneTemperature get CurrentTemperature /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\temperature-info.txt" 2>nul
echo [SUCCESS] Temperature information gathered

:: Get power info
echo [5/6] Getting power information...
powercfg /query > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\power-info.txt"
echo [SUCCESS] Power information gathered

:: Get hardware errors
echo [6/6] Getting hardware errors...
wmic path win32_systemdriver where state="running" get name,state /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\hardware-errors.txt"
echo [SUCCESS] Hardware errors gathered

echo [SUCCESS] Hardware analysis completed!
echo.
pause
goto main_menu

:network_diagnostics
echo.
echo ================================================================
echo               NETWORK DIAGNOSTICS
echo ================================================================
echo.
echo Running network diagnostics...
echo.

:: Test connectivity
echo [1/6] Testing connectivity...
ping -n 4 8.8.8.8 > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\ping-test.txt"
echo [SUCCESS] Connectivity test completed

:: Get network configuration
echo [2/6] Getting network configuration...
ipconfig /all > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\network-config.txt"
echo [SUCCESS] Network configuration gathered

:: Get network statistics
echo [3/6] Getting network statistics...
netstat -an > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\network-stats.txt"
echo [SUCCESS] Network statistics gathered

:: Get routing table
echo [4/6] Getting routing table...
route print > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\routing-table.txt"
echo [SUCCESS] Routing table gathered

:: Get DNS information
echo [5/6] Getting DNS information...
nslookup google.com > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\dns-test.txt"
echo [SUCCESS] DNS information gathered

:: Get network adapters
echo [6/6] Getting network adapters...
wmic path win32_networkadapter get name,adaptertype,netconnectionstatus /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\network-adapters.txt"
echo [SUCCESS] Network adapters gathered

echo [SUCCESS] Network diagnostics completed!
echo.
pause
goto main_menu

:security_analysis
echo.
echo ================================================================
echo               SECURITY ANALYSIS
echo ================================================================
echo.
echo Analyzing security settings...
echo.

:: Check Windows Defender
echo [1/5] Checking Windows Defender...
powershell -Command "Get-MpComputerStatus" > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\windows-defender.txt" 2>nul
echo [SUCCESS] Windows Defender status gathered

:: Check firewall
echo [2/5] Checking firewall...
netsh advfirewall show allprofiles > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\firewall-status.txt"
echo [SUCCESS] Firewall status gathered

:: Check UAC
echo [3/5] Checking UAC...
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\uac-status.txt"
echo [SUCCESS] UAC status gathered

:: Check Windows Update
echo [4/5] Checking Windows Update...
powershell -Command "Get-WindowsUpdate" > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\windows-update.txt" 2>nul
echo [SUCCESS] Windows Update status gathered

:: Check security policies
echo [5/5] Checking security policies...
secedit /export /cfg "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\security-policies.txt" >nul 2>&1
echo [SUCCESS] Security policies gathered

echo [SUCCESS] Security analysis completed!
echo.
pause
goto main_menu

:performance_metrics
echo.
echo ================================================================
echo               PERFORMANCE METRICS
echo ================================================================
echo.
echo Gathering performance metrics...
echo.

:: Get CPU performance
echo [1/5] Getting CPU performance...
wmic cpu get LoadPercentage /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\cpu-performance.txt"
echo [SUCCESS] CPU performance gathered

:: Get memory performance
echo [2/5] Getting memory performance...
wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\memory-performance.txt"
echo [SUCCESS] Memory performance gathered

:: Get disk performance
echo [3/5] Getting disk performance...
wmic logicaldisk get size,freespace /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\disk-performance.txt"
echo [SUCCESS] Disk performance gathered

:: Get process performance
echo [4/5] Getting process performance...
tasklist /fo csv > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\process-performance.txt"
echo [SUCCESS] Process performance gathered

:: Get service performance
echo [5/5] Getting service performance...
sc query state= all > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\service-performance.txt"
echo [SUCCESS] Service performance gathered

echo [SUCCESS] Performance metrics completed!
echo.
pause
goto main_menu

:service_status
echo.
echo ================================================================
echo               SERVICE STATUS
echo ================================================================
echo.
echo Checking service status...
echo.

:: Get all services
echo [1/3] Getting all services...
sc query state= all > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\all-services.txt"
echo [SUCCESS] All services gathered

:: Get running services
echo [2/3] Getting running services...
sc query state= running > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\running-services.txt"
echo [SUCCESS] Running services gathered

:: Get stopped services
echo [3/3] Getting stopped services...
sc query state= stopped > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\stopped-services.txt"
echo [SUCCESS] Stopped services gathered

echo [SUCCESS] Service status completed!
echo.
pause
goto main_menu

:disk_analysis
echo.
echo ================================================================
echo               DISK ANALYSIS
echo ================================================================
echo.
echo Analyzing disk health...
echo.

:: Get disk information
echo [1/4] Getting disk information...
wmic logicaldisk get deviceid,size,freespace,volumename /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\disk-info.txt"
echo [SUCCESS] Disk information gathered

:: Check disk health
echo [2/4] Checking disk health...
chkdsk C: /f /r > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\disk-health.txt" 2>&1
echo [SUCCESS] Disk health checked

:: Get disk usage
echo [3/4] Getting disk usage...
dir C:\ /s /-c | find "bytes" > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\disk-usage.txt"
echo [SUCCESS] Disk usage gathered

:: Get disk errors
echo [4/4] Getting disk errors...
wmic path win32_logicaldisk get deviceid,size,freespace,volumename /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\disk-errors.txt"
echo [SUCCESS] Disk errors gathered

echo [SUCCESS] Disk analysis completed!
echo.
pause
goto main_menu

:registry_health
echo.
echo ================================================================
echo               REGISTRY HEALTH
echo ================================================================
echo.
echo Checking registry health...
echo.

:: Check registry integrity
echo [1/3] Checking registry integrity...
sfc /scannow > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\registry-integrity.txt" 2>&1
echo [SUCCESS] Registry integrity checked

:: Get registry size
echo [2/3] Getting registry size...
reg query "HKLM\SOFTWARE" /s > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\registry-size.txt" 2>nul
echo [SUCCESS] Registry size gathered

:: Check registry errors
echo [3/3] Checking registry errors...
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\registry-errors.txt" 2>nul
echo [SUCCESS] Registry errors gathered

echo [SUCCESS] Registry health completed!
echo.
pause
goto main_menu

:event_log_analysis
echo.
echo ================================================================
echo               EVENT LOG ANALYSIS
echo ================================================================
echo.
echo Analyzing event logs...
echo.

:: Get system events
echo [1/4] Getting system events...
wevtutil qe System /c:10 /rd:true /f:text > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\system-events.txt" 2>nul
echo [SUCCESS] System events gathered

:: Get application events
echo [2/4] Getting application events...
wevtutil qe Application /c:10 /rd:true /f:text > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\application-events.txt" 2>nul
echo [SUCCESS] Application events gathered

:: Get security events
echo [3/4] Getting security events...
wevtutil qe Security /c:10 /rd:true /f:text > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\security-events.txt" 2>nul
echo [SUCCESS] Security events gathered

:: Get error events
echo [4/4] Getting error events...
wevtutil qe System /c:10 /rd:true /f:text /q:"*[System[Level=2]]" > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\error-events.txt" 2>nul
echo [SUCCESS] Error events gathered

echo [SUCCESS] Event log analysis completed!
echo.
pause
goto main_menu

:startup_analysis
echo.
echo ================================================================
echo               STARTUP ANALYSIS
echo ================================================================
echo.
echo Analyzing startup programs...
echo.

:: Get startup programs
echo [1/3] Getting startup programs...
wmic startup get command,caption /format:table > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\startup-programs.txt"
echo [SUCCESS] Startup programs gathered

:: Get startup services
echo [2/3] Getting startup services...
sc query state= all | findstr "AUTO_START" > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\startup-services.txt"
echo [SUCCESS] Startup services gathered

:: Get startup registry
echo [3/3] Getting startup registry...
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\startup-registry.txt" 2>nul
echo [SUCCESS] Startup registry gathered

echo [SUCCESS] Startup analysis completed!
echo.
pause
goto main_menu

:complete_diagnostics
echo.
echo ================================================================
echo               COMPLETE DIAGNOSTICS
echo ================================================================
echo.
echo Running complete system diagnostics...
echo.

:: Run all diagnostics
call :system_information
call :hardware_analysis
call :network_diagnostics
call :security_analysis
call :performance_metrics
call :service_status
call :disk_analysis
call :registry_health
call :event_log_analysis
call :startup_analysis

echo [SUCCESS] Complete diagnostics completed!
echo.
pause
goto main_menu

:generate_report
echo.
echo ================================================================
echo               GENERATE REPORT
echo ================================================================
echo.
echo Generating comprehensive diagnostic report...
echo.

:: Create HTML report
echo [REPORT] Creating HTML report...
echo ^<!DOCTYPE html^> > "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<html^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<head^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<title^>System Diagnostic Report^</title^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<style^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo body { font-family: Arial, sans-serif; margin: 20px; } >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; } >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; } >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^</style^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^</head^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<body^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<div class="header"^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<h1^>System Diagnostic Report^</h1^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<p^>Generated: %date% %time%^</p^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^</div^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<div class="section"^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<h2^>System Information^</h2^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<p^>Check system-info.txt for detailed information^</p^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^</div^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<div class="section"^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<h2^>Hardware Analysis^</h2^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<p^>Check hardware analysis files for detailed information^</p^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^</div^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<div class="section"^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<h2^>Network Diagnostics^</h2^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<p^>Check network diagnostics files for detailed information^</p^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^</div^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<div class="section"^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<h2^>Security Analysis^</h2^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^<p^>Check security analysis files for detailed information^</p^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^</div^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^</body^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"
echo ^</html^> >> "%USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html"

echo [SUCCESS] Diagnostic report generated!
echo [INFO] Report saved to: %USERPROFILE%\Desktop\DevOptimizer\Diagnostics\diagnostic-report.html
echo.
pause
goto main_menu

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please select a number between 0-12.
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
echo                ENHANCED SYSTEM DIAGNOSTICS
echo ================================================================
echo.
echo Your system has been thoroughly analyzed!
echo.
echo ================================================================
echo.
pause
exit

:start
goto main_menu


:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================

:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
