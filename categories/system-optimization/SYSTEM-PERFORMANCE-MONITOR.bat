@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title System Performance Monitor - DevOptimizer System
color 0F

echo.
echo ========================================================================
echo                  SYSTEM PERFORMANCE MONITOR - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.
echo This script monitors system performance in real-time
echo.

cd /d "%~dp0"

echo [INFO] Starting System Performance Monitor...
echo.

echo ========================================================================
echo                       PERFORMANCE MONITOR OPTIONS
echo ========================================================================
echo.
:start
echo [1] Real-time CPU Monitor
echo [2] Memory Usage Monitor
echo [3] Disk Performance Monitor
echo [4] Network Performance Monitor
echo [5] Process Performance Monitor
echo [6] System Temperature Monitor
echo [7] Battery Performance Monitor
echo [8] Comprehensive Performance Dashboard
echo [9] Performance Logging
echo [0] Exit
echo.

set /p choice="Enter your choice (0-9): "

if "%choice%"=="1" goto :cpu_monitor
if "%choice%"=="2" goto :memory_monitor
if "%choice%"=="3" goto :disk_monitor
if "%choice%"=="4" goto :network_monitor
if "%choice%"=="5" goto :process_monitor
if "%choice%"=="6" goto :temperature_monitor
if "%choice%"=="7" goto :battery_monitor
if "%choice%"=="8" goto :dashboard
if "%choice%"=="9" goto :performance_logging
if "%choice%"=="0" goto :exit
goto :invalid_choice

:cpu_monitor
echo.
echo ========================================================================
echo                         REAL-TIME CPU MONITOR
echo ========================================================================
echo.

echo [INFO] Real-time CPU monitoring started
echo [INFO] Press Ctrl+C to stop monitoring
echo.

:cpu_loop
cls
echo ========================================================================
echo                         REAL-TIME CPU MONITOR
echo ========================================================================
echo.

echo [INFO] CPU Usage:
powershell -Command "
try {
$cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
$load = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average
Write-Host '[INFO] CPU Name: ' $cpu.Name
Write-Host '[INFO] CPU Usage: ' $load.Average '%'
Write-Host '[INFO] CPU Cores: ' $cpu.NumberOfCores
Write-Host '[INFO] CPU Speed: ' $cpu.MaxClockSpeed 'MHz'
} catch {
Write-Host '[ERROR] Could not retrieve CPU information'
}
"

echo.
echo [INFO] Top CPU-consuming processes:
powershell -Command "
try {
$processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
foreach ($process in $processes) {
$cpu = $process.CPU
$memory = [math]::Round($process.WorkingSet / 1MB, 2)
Write-Host '[INFO] ' $process.ProcessName ' - CPU: ' $cpu 's, Memory: ' $memory 'MB'
}
} catch {
Write-Host '[ERROR] Could not retrieve process information'
}
"

echo.
echo Press any key to refresh or 'Q' to quit...
set /p refresh="Refresh (Enter) or Quit (Q): "
if /i "%refresh%"=="Q" goto :menu
goto :cpu_loop

:memory_monitor
echo.
echo ========================================================================
echo                         MEMORY USAGE MONITOR
echo ========================================================================
echo.

echo [INFO] Real-time memory monitoring started
echo [INFO] Press Ctrl+C to stop monitoring
echo.

:memory_loop
cls
echo ========================================================================
echo                         MEMORY USAGE MONITOR
echo ========================================================================
echo.

echo [INFO] System Memory:
powershell -Command "
try {
$memory = Get-WmiObject -Class Win32_ComputerSystem
$totalMemory = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
$freeMemory = [math]::Round((Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
$usedMemory = [math]::Round($totalMemory - $freeMemory, 2)
$memoryPercent = [math]::Round(($usedMemory / $totalMemory) * 100, 2)

Write-Host '[INFO] Total Memory: ' $totalMemory 'GB'
Write-Host '[INFO] Used Memory: ' $usedMemory 'GB'
Write-Host '[INFO] Free Memory: ' $freeMemory 'GB'
Write-Host '[INFO] Memory Usage: ' $memoryPercent '%'
} catch {
Write-Host '[ERROR] Could not retrieve memory information'
}
"

echo.
echo [INFO] Virtual Memory:
powershell -Command "
try {
$virtualMemory = Get-WmiObject -Class Win32_PageFileUsage
foreach ($vm in $virtualMemory) {
$size = [math]::Round($vm.AllocatedBaseSize / 1024, 2)
$used = [math]::Round($vm.CurrentUsage / 1024, 2)
Write-Host '[INFO] Virtual Memory - Size: ' $size 'GB, Used: ' $used 'GB'
}
} catch {
Write-Host '[ERROR] Could not retrieve virtual memory information'
}
"

echo.
echo [INFO] Top memory-consuming processes:
powershell -Command "
try {
$processes = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5
foreach ($process in $processes) {
$memory = [math]::Round($process.WorkingSet / 1MB, 2)
Write-Host '[INFO] ' $process.ProcessName ' - Memory: ' $memory 'MB'
}
} catch {
Write-Host '[ERROR] Could not retrieve process information'
}
"

echo.
echo Press any key to refresh or 'Q' to quit...
set /p refresh="Refresh (Enter) or Quit (Q): "
if /i "%refresh%"=="Q" goto :menu
goto :memory_loop

:disk_monitor
echo.
echo ========================================================================
echo                         DISK PERFORMANCE MONITOR
echo ========================================================================
echo.

echo [INFO] Real-time disk monitoring started
echo [INFO] Press Ctrl+C to stop monitoring
echo.

:disk_loop
cls
echo ========================================================================
echo                         DISK PERFORMANCE MONITOR
echo ========================================================================
echo.

echo [INFO] Disk Usage:
powershell -Command "
try {
$disks = Get-WmiObject -Class Win32_LogicalDisk
foreach ($disk in $disks) {
if ($disk.Size -gt 0) {
$size = [math]::Round($disk.Size / 1GB, 2)
$free = [math]::Round($disk.FreeSpace / 1GB, 2)
$used = [math]::Round($size - $free, 2)
$percent = [math]::Round(($used / $size) * 100, 2)
Write-Host '[INFO] Drive ' $disk.DeviceID ' - Size: ' $size 'GB, Used: ' $used 'GB, Free: ' $free 'GB, Usage: ' $percent '%'
}
}
} catch {
Write-Host '[ERROR] Could not retrieve disk information'
}
"

echo.
echo [INFO] Disk Performance:
powershell -Command "
try {
$diskPerformance = Get-Counter -Counter '\PhysicalDisk(*)\Disk Reads/sec','\PhysicalDisk(*)\Disk Writes/sec' -SampleInterval 1 -MaxSamples 1
foreach ($counter in $diskPerformance.CounterSamples) {
$instance = $counter.InstanceName
$value = [math]::Round($counter.CookedValue, 2)
if ($counter.Path -like '*Disk Reads/sec*') {
Write-Host '[INFO] ' $instance ' - Reads/sec: ' $value
} else {
Write-Host '[INFO] ' $instance ' - Writes/sec: ' $value
}
}
} catch {
Write-Host '[ERROR] Could not retrieve disk performance information'
}
"

echo.
echo Press any key to refresh or 'Q' to quit...
set /p refresh="Refresh (Enter) or Quit (Q): "
if /i "%refresh%"=="Q" goto :menu
goto :disk_loop

:network_monitor
echo.
echo ========================================================================
echo                         NETWORK PERFORMANCE MONITOR
echo ========================================================================
echo.

echo [INFO] Real-time network monitoring started
echo [INFO] Press Ctrl+C to stop monitoring
echo.

:network_loop
cls
echo ========================================================================
echo                         NETWORK PERFORMANCE MONITOR
echo ========================================================================
echo.

echo [INFO] Network Statistics:
netstat -e
echo.

echo [INFO] Network Adapter Performance:
powershell -Command "
try {
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
foreach ($adapter in $adapters) {
$stats = Get-NetAdapterStatistics -Name $adapter.Name
$rxMB = [math]::Round($stats.BytesReceived / 1MB, 2)
$txMB = [math]::Round($stats.BytesSent / 1MB, 2)
Write-Host '[INFO] ' $adapter.Name ' - RX: ' $rxMB 'MB, TX: ' $txMB 'MB'
}
} catch {
Write-Host '[ERROR] Could not retrieve network adapter information'
}
"

echo.
echo [INFO] Active Connections:
netstat -an | findstr ESTABLISHED | find /c /v ""
echo [INFO] Active connections count retrieved
echo.

echo Press any key to refresh or 'Q' to quit...
set /p refresh="Refresh (Enter) or Quit (Q): "
if /i "%refresh%"=="Q" goto :menu
goto :network_loop

:process_monitor
echo.
echo ========================================================================
echo                         PROCESS PERFORMANCE MONITOR
echo ========================================================================
echo.

echo [INFO] Real-time process monitoring started
echo [INFO] Press Ctrl+C to stop monitoring
echo.

:process_loop
cls
echo ========================================================================
echo                         PROCESS PERFORMANCE MONITOR
echo ========================================================================
echo.

echo [INFO] Top CPU-consuming processes:
powershell -Command "
try {
$processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
foreach ($process in $processes) {
$cpu = $process.CPU
$memory = [math]::Round($process.WorkingSet / 1MB, 2)
$pid = $process.Id
Write-Host '[INFO] ' $process.ProcessName ' (PID: ' $pid ') - CPU: ' $cpu 's, Memory: ' $memory 'MB'
}
} catch {
Write-Host '[ERROR] Could not retrieve process information'
}
"

echo.
echo [INFO] Top memory-consuming processes:
powershell -Command "
try {
$processes = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10
foreach ($process in $processes) {
$memory = [math]::Round($process.WorkingSet / 1MB, 2)
$pid = $process.Id
Write-Host '[INFO] ' $process.ProcessName ' (PID: ' $pid ') - Memory: ' $memory 'MB'
}
} catch {
Write-Host '[ERROR] Could not retrieve process information'
}
"

echo.
echo [INFO] Total processes:
tasklist | find /c /v ""
echo.

echo Press any key to refresh or 'Q' to quit...
set /p refresh="Refresh (Enter) or Quit (Q): "
if /i "%refresh%"=="Q" goto :menu
goto :process_loop

:temperature_monitor
echo.
echo ========================================================================
echo                         SYSTEM TEMPERATURE MONITOR
echo ========================================================================
echo.

echo [INFO] System temperature monitoring started
echo [INFO] Press Ctrl+C to stop monitoring
echo.

:temperature_loop
cls
echo ========================================================================
echo                         SYSTEM TEMPERATURE MONITOR
echo ========================================================================
echo.

echo [INFO] System Temperature:
powershell -Command "
try {
$temperature = Get-WmiObject -Namespace 'root\wmi' -Class MSAcpi_ThermalZoneTemperature
foreach ($temp in $temperature) {
$celsius = ($temp.CurrentTemperature / 10) - 273.15
$fahrenheit = ($celsius * 9/5) + 32
Write-Host '[INFO] Temperature: ' [math]::Round($celsius, 2) 'Β°C (' [math]::Round($fahrenheit, 2) 'Β°F)'
}
} catch {
Write-Host '[ERROR] Could not retrieve temperature information'
Write-Host '[INFO] Temperature monitoring may not be available on this system'
}
"

echo.
echo [INFO] CPU Temperature (if available):
powershell -Command "
try {
$cpuTemp = Get-WmiObject -Namespace 'root\cimv2' -Class Win32_TemperatureProbe
foreach ($temp in $cpuTemp) {
$celsius = ($temp.CurrentReading / 10) - 273.15
Write-Host '[INFO] CPU Temperature: ' [math]::Round($celsius, 2) 'Β°C'
}
} catch {
Write-Host '[INFO] CPU temperature monitoring not available'
}
"

echo.
echo Press any key to refresh or 'Q' to quit...
set /p refresh="Refresh (Enter) or Quit (Q): "
if /i "%refresh%"=="Q" goto :menu
goto :temperature_loop

:battery_monitor
echo.
echo ========================================================================
echo                         BATTERY PERFORMANCE MONITOR
echo ========================================================================
echo.

echo [INFO] Battery performance monitoring started
echo [INFO] Press Ctrl+C to stop monitoring
echo.

:battery_loop
cls
echo ========================================================================
echo                         BATTERY PERFORMANCE MONITOR
echo ========================================================================
echo.

echo [INFO] Battery Status:
powershell -Command "
try {
$battery = Get-WmiObject -Class Win32_Battery
if ($battery) {
foreach ($bat in $battery) {
Write-Host '[INFO] Battery Name: ' $bat.Name
Write-Host '[INFO] Battery Status: ' $bat.BatteryStatus
Write-Host '[INFO] Estimated Charge Remaining: ' $bat.EstimatedChargeRemaining '%'
Write-Host '[INFO] Estimated Run Time: ' $bat.EstimatedRunTime 'minutes'
Write-Host '[INFO] Power Management Capabilities: ' $bat.PowerManagementCapabilities
}
} else {
Write-Host '[INFO] No battery found - system may be desktop'
}
} catch {
Write-Host '[ERROR] Could not retrieve battery information'
}
"

echo.
echo [INFO] Power Configuration:
powercfg /query
echo.

echo Press any key to refresh or 'Q' to quit...
set /p refresh="Refresh (Enter) or Quit (Q): "
if /i "%refresh%"=="Q" goto :menu
goto :battery_loop

:dashboard
echo.
echo ========================================================================
echo                      COMPREHENSIVE PERFORMANCE DASHBOARD
echo ========================================================================
echo.

echo [INFO] Comprehensive performance dashboard started
echo [INFO] Press Ctrl+C to stop monitoring
echo.

:dashboard_loop
cls
echo ========================================================================
echo                      COMPREHENSIVE PERFORMANCE DASHBOARD
echo ========================================================================
echo.

echo [INFO] System Overview:
powershell -Command "
try {
$cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
$memory = Get-WmiObject -Class Win32_ComputerSystem
$os = Get-WmiObject -Class Win32_OperatingSystem

Write-Host '[INFO] Computer: ' $memory.Name
Write-Host '[INFO] OS: ' $os.Caption
Write-Host '[INFO] CPU: ' $cpu.Name
Write-Host '[INFO] Total Memory: ' [math]::Round($memory.TotalPhysicalMemory / 1GB, 2) 'GB'
Write-Host '[INFO] Free Memory: ' [math]::Round($os.FreePhysicalMemory / 1MB, 2) 'GB'
} catch {
Write-Host '[ERROR] Could not retrieve system information'
}
"

echo.
echo [INFO] Performance Summary:
powershell -Command "
try {
$cpuLoad = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average
$memory = Get-WmiObject -Class Win32_OperatingSystem
$totalMemory = Get-WmiObject -Class Win32_ComputerSystem
$memoryPercent = [math]::Round((($totalMemory.TotalPhysicalMemory - $memory.FreePhysicalMemory) / $totalMemory.TotalPhysicalMemory) * 100, 2)

Write-Host '[INFO] CPU Usage: ' $cpuLoad.Average '%'
Write-Host '[INFO] Memory Usage: ' $memoryPercent '%'
} catch {
Write-Host '[ERROR] Could not retrieve performance information'
}
"

echo.
echo [INFO] Disk Usage:
powershell -Command "
try {
$disks = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.Size -gt 0 }
foreach ($disk in $disks) {
$size = [math]::Round($disk.Size / 1GB, 2)
$free = [math]::Round($disk.FreeSpace / 1GB, 2)
$percent = [math]::Round((($size - $free) / $size) * 100, 2)
Write-Host '[INFO] Drive ' $disk.DeviceID ' - Usage: ' $percent '%'
}
} catch {
Write-Host '[ERROR] Could not retrieve disk information'
}
"

echo.
echo [INFO] Network Status:
netstat -an | findstr ESTABLISHED | find /c /v ""
echo [INFO] Active connections: Retrieved
echo.

echo [INFO] Top Processes:
powershell -Command "
try {
$processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 3
foreach ($process in $processes) {
$memory = [math]::Round($process.WorkingSet / 1MB, 2)
Write-Host '[INFO] ' $process.ProcessName ' - Memory: ' $memory 'MB'
}
} catch {
Write-Host '[ERROR] Could not retrieve process information'
}
"

echo.
echo Press any key to refresh or 'Q' to quit...
set /p refresh="Refresh (Enter) or Quit (Q): "
if /i "%refresh%"=="Q" goto :menu
goto :dashboard_loop

:performance_logging
echo.
echo ========================================================================
echo                           PERFORMANCE LOGGING
echo ========================================================================
echo.

if not exist "logs" mkdir "logs"

echo [INFO] Performance logging options:
echo.
echo [1] Start Performance Logging
echo [2] Stop Performance Logging
echo [3] View Performance Logs
echo [4] Clear Performance Logs
echo [0] Back to main menu
echo.

set /p logging_choice="Enter your choice (0-4): "

if "%logging_choice%"=="1" goto :menu_logging
if "%logging_choice%"=="2" goto :stop_logging
if "%logging_choice%"=="3" goto :view_logs
if "%logging_choice%"=="4" goto :clear_logs
if "%logging_choice%"=="0" goto :menu
goto :invalid_logging_choice

:start_logging
echo.
set /p log_duration="Enter logging duration in minutes (or 0 for continuous): "
if "%log_duration%"=="" set "log_duration=60"

echo [INFO] Starting performance logging...
echo [INFO] Log duration: %log_duration% minutes
echo [INFO] Log file: logs\performance-log-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%.txt

powershell -Command "
try {
$logFile = 'logs\performance-log-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.txt'
$duration = %log_duration%

if ($duration -eq 0) {
Write-Host '[INFO] Continuous logging started - use option 2 to stop'
} else {
Write-Host '[INFO] Logging for ' $duration ' minutes'
}

# Log performance data
$cpu = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average
$memory = Get-WmiObject -Class Win32_OperatingSystem
$totalMemory = Get-WmiObject -Class Win32_ComputerSystem
$memoryPercent = [math]::Round((($totalMemory.TotalPhysicalMemory - $memory.FreePhysicalMemory) / $totalMemory.TotalPhysicalMemory) * 100, 2)

$logEntry = (Get-Date).ToString() + ' - CPU: ' + $cpu.Average + '% - Memory: ' + $memoryPercent + '%'
Add-Content -Path $logFile -Value $logEntry

Write-Host '[SUCCESS] Performance logging started'
} catch {
Write-Host '[ERROR] Failed to start performance logging: ' $_.Exception.Message
}
"

echo.
pause
goto :performance_logging

:stop_logging
echo.
echo [INFO] Stopping performance logging...
echo [INFO] Performance logging stopped
pause
goto :performance_logging

:view_logs
echo.
echo [INFO] Available performance logs:
echo.
dir "logs\performance-log-*.txt" /B 2>nul
echo.

set /p log_file="Enter log file name to view: "
if "%log_file%"=="" (
echo [ERROR] Log file name is required
pause
goto :performance_logging
)

if exist "logs\%log_file%" (
echo [INFO] Contents of %log_file%:
type "logs\%log_file%"
) else (
echo [ERROR] Log file not found
)

echo.
pause
goto :performance_logging

:clear_logs
echo.
echo [WARNING] This will delete all performance logs
set /p confirm="Are you sure? (Y/N): "
if /i "%confirm%"=="Y" (
del "logs\performance-log-*.txt" >nul 2>&1
echo [SUCCESS] Performance logs cleared
) else (
echo [INFO] Log clearing cancelled
)

echo.
pause
goto :performance_logging

:invalid_logging_choice
echo.
echo [ERROR] Invalid logging choice
pause
goto :performance_logging

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
echo [INFO] System Performance Monitor closed
echo [INFO] Thank you for using DevOptimizer System
exit /b 0
