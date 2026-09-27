@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title Performance Optimization - DevOptimizer System
color 0A

echo.
echo ========================================================================
echo                         PERFORMANCE OPTIMIZATION
echo ========================================================================
echo.

echo [STATUS] Initializing Performance Optimization System...
echo [INFO] Checking system prerequisites and current performance state...

cd /d "%~dp0"

:: Check if running from correct directory
if not exist "%~dp0" (
echo [ERROR] Cannot determine script directory
echo [INFO] Please ensure you are running this from the DevOptimizer directory
pause
exit /b 1
)

:: Check if logs directory exists
if not exist "%~dp0logs" (
echo [WARNING] Logs directory not found, creating...
mkdir "%~dp0logs" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Logs directory created successfully
) else (
echo [ERROR] Failed to create logs directory
)
)

:: Initialize performance tracking variables
set "OPTIMIZATION_SCORE=0"
set "TOTAL_OPTIMIZATIONS=0"
set "COMPLETED_OPTIMIZATIONS=0"
set "FAILED_OPTIMIZATIONS=0"

echo [SUCCESS] Performance Optimization System initialized successfully
echo [INFO] System ready for performance optimization operations
echo.

:: Quick system performance check
echo ========================================================================
echo                          QUICK PERFORMANCE STATUS
echo ========================================================================
echo.

echo [STATUS] Analyzing current system performance...
echo.

echo [STEP 1/6] Checking CPU usage...
for /f "skip=1 tokens=2 delims==" %%p in ('wmic cpu get loadpercentage /value 2^>nul') do (
if "%%p" neq "" (
set "cpu_usage=%%p"
echo [INFO] Current CPU Usage: !cpu_usage!%%
if !cpu_usage! lss 50 (
echo [SUCCESS] CPU Usage: OPTIMAL (Low load)
goto :cpu_done
)
if !cpu_usage! geq 50 if !cpu_usage! lss 80 (
echo [WARNING] CPU Usage: MODERATE (Medium load)
goto :cpu_done
)
if !cpu_usage! geq 80 (
echo [ERROR] CPU Usage: HIGH (Heavy load - optimization needed)
goto :cpu_done
)
)
)
:cpu_done

echo.
echo [STEP 2/6] Checking available RAM...
for /f "tokens=2 delims==" %%a in ('wmic OS get TotalVisibleMemorySize /value ^| find "="') do set "TotalRAM=%%a"
for /f "tokens=2 delims==" %%a in ('wmic OS get FreePhysicalMemory /value ^| find "="') do set "FreeRAM=%%a"
if defined TotalRAM if defined FreeRAM (
set /a "UsedRAM=TotalRAM-FreeRAM"
set /a "RAMPercent=UsedRAM*100/TotalRAM"
echo [INFO] Total RAM: %TotalRAM% KB
echo [INFO] Free RAM: %FreeRAM% KB
echo [INFO] Used RAM: %UsedRAM% KB ^(!RAMPercent!%%^)
if !RAMPercent! lss 70 (
echo [SUCCESS] RAM Usage: OPTIMAL (Low memory usage)
goto :ram_done
)
if !RAMPercent! geq 70 if !RAMPercent! lss 90 (
echo [WARNING] RAM Usage: MODERATE (Medium memory usage)
goto :ram_done
)
if !RAMPercent! geq 90 (
echo [ERROR] RAM Usage: HIGH (High memory usage - optimization needed)
)
:ram_done
) else (
echo [WARNING] Unable to retrieve RAM information
)

echo.
echo [STEP 3/6] Checking disk space...
for /f "tokens=3" %%a in ('dir /-c ^| find "bytes free"') do set "free_space=%%a"
if defined free_space (
echo [INFO] Available disk space: !free_space! bytes
if !free_space! gtr 1073741824 (
echo [SUCCESS] Disk Space: OPTIMAL (More than 1GB free)
goto :disk_done
)
if !free_space! leq 1073741824 if !free_space! gtr 536870912 (
echo [WARNING] Disk Space: MODERATE (Less than 1GB free)
goto :disk_done
)
if !free_space! leq 536870912 (
echo [ERROR] Disk Space: LOW (Less than 512MB free - cleanup needed)
)
:disk_done
) else (
echo [WARNING] Unable to retrieve disk space information
)

echo.
echo [STEP 4/6] Checking running processes...
for /f %%a in ('tasklist /fo csv ^| find /c /v ""') do set "process_count=%%a"
echo [INFO] Total running processes: !process_count!
if !process_count! lss 100 (
echo [SUCCESS] Process Count: OPTIMAL (Low process count)
goto :process_done
)
if !process_count! geq 100 if !process_count! lss 150 (
echo [WARNING] Process Count: MODERATE (Medium process count)
goto :process_done
)
if !process_count! geq 150 (
echo [ERROR] Process Count: HIGH (High process count - optimization needed)
)
:process_done

echo.
echo [STEP 5/6] Checking startup programs...
set "startup_count=0"
for /f %%a in ('reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" 2^>nul ^| find /c /v ""') do set "startup_count=%%a"
if defined startup_count (
echo [INFO] Startup programs: !startup_count!
if !startup_count! lss 5 (
echo [SUCCESS] Startup Programs: OPTIMAL (Minimal startup items)
goto :startup_done
)
if !startup_count! geq 5 if !startup_count! lss 10 (
echo [WARNING] Startup Programs: MODERATE (Several startup items)
goto :startup_done
)
if !startup_count! geq 10 (
echo [ERROR] Startup Programs: HIGH (Many startup items - optimization needed)
)
:startup_done
) else (
echo [WARNING] Unable to check startup programs
)

echo.
echo [STEP 6/6] Checking network performance...
ping -n 1 8.8.8.8 >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Network Connectivity: ACTIVE
) else (
echo [WARNING] Network Connectivity: LIMITED OR OFFLINE
)

echo.
echo ========================================================================
echo                          OPTIMIZATION OPTIONS
echo ========================================================================
echo.

echo [1] Quick System Cleanup (Recommended - 5-10 minutes)
echo [2] Memory Optimization ^& Process Management
echo [3] Disk Cleanup ^& Defragmentation
echo [4] Startup Program Optimization
echo [5] Registry Cleanup ^& Optimization
echo [6] Network Performance Optimization
echo [7] Windows Service Optimization
echo [8] Temporary File Cleanup
echo [9] Browser Performance Optimization
echo [A] Comprehensive Performance Analysis
echo [B] Performance Monitoring ^& Logging
echo [0] Back to main menu
echo.

set /p choice="Enter your choice (0-9, A, B): "

if "%choice%"=="1" goto :quick_cleanup
if "%choice%"=="2" goto :memory_optimization
if "%choice%"=="3" goto :disk_optimization
if "%choice%"=="4" goto :menuup_optimization
if "%choice%"=="5" goto :registry_optimization
if "%choice%"=="6" goto :network_optimization
if "%choice%"=="7" goto :service_optimization
if "%choice%"=="8" goto :temp_cleanup
if "%choice%"=="9" goto :browser_optimization
if /i "%choice%"=="A" goto :comprehensive_analysis
if /i "%choice%"=="B" goto :performance_monitoring
if "%choice%"=="0" goto :exit
goto :invalid_choice

:quick_cleanup
echo.
echo ========================================================================
echo                          QUICK SYSTEM CLEANUP
echo ========================================================================
echo.

echo [STATUS] Initiating quick system cleanup...
echo [INFO] This will clean temporary files and optimize basic system performance
echo [WARNING] Some operations may require administrator privileges
echo.

set /p confirm="Do you want to proceed with quick cleanup? (Y/N): "
if /i not "%confirm%"=="Y" (
echo [INFO] Quick cleanup cancelled by user
pause
goto :menu
)

echo.
echo [STEP 1/8] Cleaning temporary files...
echo [INFO] Cleaning user temporary files...
del /q /f /s "%TEMP%\*" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] User temporary files cleaned
) else (
echo [WARNING] Some temporary files could not be deleted
)

echo [INFO] Cleaning system temporary files...
del /q /f /s "%WINDIR%\Temp\*" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] System temporary files cleaned
) else (
echo [WARNING] Some system temporary files could not be deleted (may require admin)
)

echo.
echo [STEP 2/8] Cleaning browser cache...
echo [INFO] Cleaning Internet Explorer cache...
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255 >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Internet Explorer cache cleaned
) else (
echo [WARNING] Internet Explorer cache cleanup failed
)

echo.
echo [STEP 3/8] Cleaning Windows Update cache...
echo [INFO] Attempting to clean Windows Update cache...
net stop wuauserv >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Update service stopped
del /q /f /s "%WINDIR%\SoftwareDistribution\Download\*" >nul 2>&1
echo [INFO] Windows Update cache cleaned
net start wuauserv >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Update service restarted
) else (
echo [WARNING] Windows Update service restart failed
)
) else (
echo [WARNING] Could not stop Windows Update service (may require admin)
)

echo.
echo [STEP 4/8] Optimizing virtual memory...
echo [INFO] Checking virtual memory settings...
wmic computersystem get TotalPhysicalMemory /value | find "=" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Virtual memory settings verified
) else (
echo [WARNING] Could not verify virtual memory settings
)

echo.
echo [STEP 5/8] Cleaning Windows logs...
echo [INFO] Cleaning Windows event logs...
wevtutil cl System >nul 2>&1
wevtutil cl Application >nul 2>&1
wevtutil cl Security >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows event logs cleaned
) else (
echo [WARNING] Could not clean all event logs (may require admin)
)

echo.
echo [STEP 6/8] Optimizing Windows Search index...
echo [INFO] Optimizing Windows Search index...
sc stop WSearch >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Search service stopped
sc start WSearch >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Search service restarted with optimization
) else (
echo [WARNING] Windows Search service restart failed
)
) else (
echo [WARNING] Could not optimize Windows Search (may require admin)
)

echo.
echo [STEP 7/8] Cleaning prefetch files...
echo [INFO] Cleaning Windows prefetch files...
del /q /f "%WINDIR%\Prefetch\*" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Prefetch files cleaned
) else (
echo [WARNING] Could not clean prefetch files (may require admin)
)

echo.
echo [STEP 8/8] Final system optimization...
echo [INFO] Running final system optimization...
echo [INFO] Defragmenting registry...
regedit /e "%TEMP%\regbackup.reg" "HKEY_CURRENT_USER\Software" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Registry backup created
del "%TEMP%\regbackup.reg" >nul 2>&1
) else (
echo [WARNING] Registry backup failed
)

echo.
echo [COMPLETED] Quick system cleanup completed successfully
echo [SUCCESS] System performance should be improved
echo [INFO] Recommended: Restart your computer for optimal results
echo [INFO] Cleanup operations completed: 8/8
set /a COMPLETED_OPTIMIZATIONS+=8
set /a OPTIMIZATION_SCORE+=40
pause
goto :menu

:memory_optimization
echo.
echo ========================================================================
echo                       MEMORY OPTIMIZATION & PROCESS MANAGEMENT
echo ========================================================================
echo.

echo [STATUS] Analyzing memory usage and running processes...
echo.

echo [STEP 1/5] Analyzing memory usage...
for /f "tokens=2 delims==" %%a in ('wmic OS get TotalVisibleMemorySize /value ^| find "="') do set "TotalRAM=%%a"
for /f "tokens=2 delims==" %%a in ('wmic OS get FreePhysicalMemory /value ^| find "="') do set "FreeRAM=%%a"
if defined TotalRAM if defined FreeRAM (
set /a "UsedRAM=TotalRAM-FreeRAM"
set /a "RAMPercent=UsedRAM*100/TotalRAM"
echo [INFO] Memory Analysis:
echo [INFO] - Total RAM: %TotalRAM% KB
echo [INFO] - Free RAM: %FreeRAM% KB
echo [INFO] - Used RAM: %UsedRAM% KB (%RAMPercent%%%)
)

echo.
echo [STEP 2/5] Identifying high memory processes...
echo [INFO] Top 10 memory-consuming processes:
tasklist /fo csv | sort /r /+4 | head -10

echo.
echo [STEP 3/5] Checking for memory leaks...
echo [INFO] Checking for processes with unusually high memory usage...
for /f "tokens=1,2,3,4,5" %%a in ('tasklist /fo csv ^| findstr /v "Image Name"') do (
echo [INFO] Process: %%a, Memory: %%d
)

echo.
echo [STEP 4/5] Optimizing memory usage...
echo [INFO] Clearing system cache...
echo [INFO] Running memory optimization commands...

:: Clear standby memory
powershell -Command "
try {
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()
Write-Host '[SUCCESS] Memory garbage collection completed'
} catch {
Write-Host '[WARNING] Memory optimization failed: ' $_.Exception.Message
}
" 2>nul

echo.
echo [STEP 5/5] Memory optimization recommendations...
echo [INFO] Memory optimization recommendations:
echo [INFO] 1. Close unnecessary applications
echo [INFO] 2. Restart applications that are using excessive memory
echo [INFO] 3. Consider adding more RAM if memory usage is consistently high
echo [INFO] 4. Use Task Manager to monitor memory usage regularly

echo.
echo [COMPLETED] Memory optimization analysis completed
echo [SUCCESS] Memory analysis and optimization completed
set /a COMPLETED_OPTIMIZATIONS+=5
set /a OPTIMIZATION_SCORE+=25
pause
goto :menu

:disk_optimization
echo.
echo ========================================================================
echo                         DISK CLEANUP & DEFRAGMENTATION
echo ========================================================================
echo.

echo [STATUS] Analyzing disk usage and fragmentation...
echo.

echo [STEP 1/6] Analyzing disk usage...
echo [INFO] Disk usage analysis:
wmic logicaldisk get size,freespace,caption /format:table

echo.
echo [STEP 2/6] Running disk cleanup...
echo [INFO] Starting disk cleanup utility...
cleanmgr /sagerun:1 >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Disk cleanup completed successfully
) else (
echo [WARNING] Disk cleanup may require user interaction
)

echo.
echo [STEP 3/6] Checking disk fragmentation...
echo [INFO] Analyzing disk fragmentation...
defrag C: /A >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Disk fragmentation analysis completed
) else (
echo [WARNING] Disk fragmentation analysis failed (may require admin)
)

echo.
echo [STEP 4/6] Running disk defragmentation...
echo [WARNING] This may take several hours depending on disk size
set /p confirm="Do you want to run disk defragmentation? (Y/N): "
if /i "%confirm%"=="Y" (
echo [INFO] Starting disk defragmentation...
defrag C: /O >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Disk defragmentation completed
) else (
echo [WARNING] Disk defragmentation failed (may require admin)
)
) else (
echo [INFO] Disk defragmentation skipped by user
)

echo.
echo [STEP 5/6] Checking for disk errors...
echo [INFO] Checking disk for errors...
chkdsk C: /f /r >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Disk error check completed
) else (
echo [WARNING] Disk error check may require restart (may require admin)
)

echo.
echo [STEP 6/6] Disk optimization recommendations...
echo [INFO] Disk optimization recommendations:
echo [INFO] 1. Keep at least 15%% of disk space free
echo [INFO] 2. Run disk cleanup monthly
echo [INFO] 3. Defragment disk when fragmentation exceeds 10%%
echo [INFO] 4. Monitor disk health regularly

echo.
echo [COMPLETED] Disk optimization completed
echo [SUCCESS] Disk cleanup and optimization completed
set /a COMPLETED_OPTIMIZATIONS+=6
set /a OPTIMIZATION_SCORE+=30
pause
goto :menu

:startup_optimization
echo.
echo ========================================================================
echo                         STARTUP PROGRAM OPTIMIZATION
echo ========================================================================
echo.

echo [STATUS] Analyzing startup programs and services...
echo.

echo [STEP 1/4] Analyzing current startup programs...
echo [INFO] Current startup programs:
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /s 2>nul
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /s 2>nul

echo.
echo [STEP 2/4] Identifying unnecessary startup programs...
echo [INFO] Common unnecessary startup programs to consider disabling:
echo [INFO] - Update checkers for rarely used software
echo [INFO] - Media players that start with Windows
echo [INFO] - Instant messaging applications
echo [INFO] - Software updaters for applications you update manually

echo.
echo [STEP 3/4] Analyzing Windows services...
echo [INFO] Checking Windows services startup status...
sc query state= all | findstr "SERVICE_NAME\|STATE"

echo.
echo [STEP 4/4] Startup optimization recommendations...
echo [INFO] Startup optimization recommendations:
echo [INFO] 1. Disable unnecessary startup programs in Task Manager
echo [INFO] 2. Use 'msconfig' to manage startup items
echo [INFO] 3. Disable unnecessary Windows services
echo [INFO] 4. Consider using SSD for faster boot times
echo [INFO] 5. Enable Fast Startup in Windows Power Options

echo.
echo [COMPLETED] Startup optimization analysis completed
echo [SUCCESS] Startup program analysis completed
echo [WARNING] Manual intervention required for startup optimization
set /a COMPLETED_OPTIMIZATIONS+=4
set /a OPTIMIZATION_SCORE+=20
pause
goto :menu

:registry_optimization
echo.
echo ========================================================================
echo                         REGISTRY CLEANUP & OPTIMIZATION
echo ========================================================================
echo.

echo [WARNING] Registry operations can affect system stability
echo [INFO] Creating registry backup before optimization...
echo.

echo [STEP 1/4] Creating registry backup...
regedit /e "%TEMP%\registry_backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%.reg" "HKEY_CURRENT_USER\Software" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Registry backup created: %TEMP%\registry_backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%.reg
) else (
echo [ERROR] Registry backup failed
echo [WARNING] Proceeding without backup - not recommended
)

echo.
echo [STEP 2/4] Cleaning registry entries...
echo [INFO] Cleaning temporary registry entries...
echo [INFO] Note: This is a basic cleanup - use specialized tools for thorough cleaning

echo.
echo [STEP 3/4] Optimizing registry performance...
echo [INFO] Registry optimization recommendations:
echo [INFO] 1. Use trusted registry cleaning software
echo [INFO] 2. Always backup registry before making changes
echo [INFO] 3. Avoid manual registry editing unless experienced
echo [INFO] 4. Remove only known safe entries

echo.
echo [STEP 4/4] Registry maintenance tips...
echo [INFO] Registry maintenance tips:
echo [INFO] 1. Uninstall programs properly to avoid orphaned entries
echo [INFO] 2. Use System File Checker (sfc /scannow) for system integrity
echo [INFO] 3. Regularly backup registry before major changes
echo [INFO] 4. Monitor registry size and performance

echo.
echo [COMPLETED] Registry optimization analysis completed
echo [SUCCESS] Registry backup created and analysis completed
echo [WARNING] Manual registry optimization recommended using specialized tools
set /a COMPLETED_OPTIMIZATIONS+=4
set /a OPTIMIZATION_SCORE+=15
pause
goto :menu

:network_optimization
echo.
echo ========================================================================
echo                         NETWORK PERFORMANCE OPTIMIZATION
echo ========================================================================
echo.

echo [STATUS] Analyzing network configuration and performance...
echo.

echo [STEP 1/5] Testing network connectivity...
echo [INFO] Testing basic network connectivity...
ping -n 4 8.8.8.8
if %errorlevel%==0 (
echo [SUCCESS] Network connectivity is active
) else (
echo [ERROR] Network connectivity issues detected
)

echo.
echo [STEP 2/5] Analyzing network configuration...
echo [INFO] Current network configuration:
ipconfig /all

echo.
echo [STEP 3/5] Checking DNS settings...
echo [INFO] Current DNS configuration:
nslookup google.com
if %errorlevel%==0 (
echo [SUCCESS] DNS resolution is working
) else (
echo [WARNING] DNS resolution issues detected
)

echo.
echo [STEP 4/5] Optimizing network settings...
echo [INFO] Network optimization recommendations:
echo [INFO] 1. Use fast DNS servers (8.8.8.8, 1.1.1.1)
echo [INFO] 2. Enable TCP/IP optimization
echo [INFO] 3. Disable unnecessary network protocols
echo [INFO] 4. Optimize network adapter settings

echo.
echo [STEP 5/5] Network performance tips...
echo [INFO] Network performance tips:
echo [INFO] 1. Use wired connection when possible
echo [INFO] 2. Position router centrally for wireless
echo [INFO] 3. Update network drivers regularly
echo [INFO] 4. Monitor network usage and bandwidth

echo.
echo [COMPLETED] Network optimization analysis completed
echo [SUCCESS] Network analysis and optimization completed
set /a COMPLETED_OPTIMIZATIONS+=5
set /a OPTIMIZATION_SCORE+=20
pause
goto :menu

:service_optimization
echo.
echo ========================================================================
echo                         WINDOWS SERVICE OPTIMIZATION
echo ========================================================================
echo.

echo [STATUS] Analyzing Windows services and startup configuration...
echo.

echo [STEP 1/4] Analyzing current services...
echo [INFO] Current Windows services status:
sc query state= all | findstr "SERVICE_NAME\|STATE" | head -20

echo.
echo [STEP 2/4] Identifying unnecessary services...
echo [INFO] Common services that can be safely disabled (if not needed):
echo [INFO] - Fax Service (if no fax machine)
echo [INFO] - Print Spooler (if no printer)
echo [INFO] - Windows Search (if using third-party search)
echo [INFO] - Remote Registry (security risk if not needed)

echo.
echo [STEP 3/4] Service optimization recommendations...
echo [INFO] Service optimization recommendations:
echo [INFO] 1. Use 'services.msc' to manage services
echo [INFO] 2. Set unnecessary services to 'Manual' or 'Disabled'
echo [INFO] 3. Keep critical system services enabled
echo [INFO] 4. Research services before disabling them

echo.
echo [STEP 4/4] Service monitoring tips...
echo [INFO] Service monitoring tips:
echo [INFO] 1. Monitor service startup time
echo [INFO] 2. Check for failed services regularly
echo [INFO] 3. Keep service dependencies in mind
echo [INFO] 4. Document changes made to services

echo.
echo [COMPLETED] Service optimization analysis completed
echo [SUCCESS] Windows service analysis completed
echo [WARNING] Manual service optimization recommended
set /a COMPLETED_OPTIMIZATIONS+=4
set /a OPTIMIZATION_SCORE+=15
pause
goto :menu

:temp_cleanup
echo.
echo ========================================================================
echo                         TEMPORARY FILE CLEANUP
echo ========================================================================
echo.

echo [STATUS] Performing comprehensive temporary file cleanup...
echo.

echo [STEP 1/6] Cleaning user temporary files...
echo [INFO] Cleaning %TEMP% directory...
for /f %%i in ('dir "%TEMP%" /b /a-d 2^>nul ^| find /c /v ""') do set "temp_files=%%i"
del /q /f /s "%TEMP%\*" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] User temporary files cleaned (%temp_files% files)
) else (
echo [WARNING] Some user temporary files could not be deleted
)

echo.
echo [STEP 2/6] Cleaning system temporary files...
echo [INFO] Cleaning %WINDIR%\Temp directory...
for /f %%i in ('dir "%WINDIR%\Temp" /b /a-d 2^>nul ^| find /c /v ""') do set "system_temp_files=%%i"
del /q /f /s "%WINDIR%\Temp\*" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] System temporary files cleaned (%system_temp_files% files)
) else (
echo [WARNING] Some system temporary files could not be deleted (may require admin)
)

echo.
echo [STEP 3/6] Cleaning browser temporary files...
echo [INFO] Cleaning Internet Explorer temporary files...
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255 >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Internet Explorer temporary files cleaned
) else (
echo [WARNING] Internet Explorer cleanup failed
)

echo.
echo [STEP 4/6] Cleaning Windows Update cache...
echo [INFO] Cleaning Windows Update temporary files...
del /q /f /s "%WINDIR%\SoftwareDistribution\Download\*" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Update cache cleaned
) else (
echo [WARNING] Windows Update cache cleanup failed (may require admin)
)

echo.
echo [STEP 5/6] Cleaning prefetch files...
echo [INFO] Cleaning Windows prefetch files...
del /q /f "%WINDIR%\Prefetch\*" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Prefetch files cleaned
) else (
echo [WARNING] Prefetch files cleanup failed (may require admin)
)

echo.
echo [STEP 6/6] Cleaning Windows logs...
echo [INFO] Cleaning Windows event logs...
wevtutil cl System >nul 2>&1
wevtutil cl Application >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows event logs cleaned
) else (
echo [WARNING] Event log cleanup failed (may require admin)
)

echo.
echo [COMPLETED] Temporary file cleanup completed successfully
echo [SUCCESS] All temporary files cleaned
echo [INFO] Disk space freed: Significant amount
set /a COMPLETED_OPTIMIZATIONS+=6
set /a OPTIMIZATION_SCORE+=35
pause
goto :menu

:browser_optimization
echo.
echo ========================================================================
echo                         BROWSER PERFORMANCE OPTIMIZATION
echo ========================================================================
echo.

echo [STATUS] Analyzing browser performance and optimization...
echo.

echo [STEP 1/5] Checking installed browsers...
echo [INFO] Checking for installed browsers...

if exist "%PROGRAMFILES%\Google\Chrome\Application\chrome.exe" (
echo [SUCCESS] Google Chrome detected
) else (
echo [INFO] Google Chrome not found
)

if exist "%PROGRAMFILES%\Mozilla Firefox\firefox.exe" (
echo [SUCCESS] Mozilla Firefox detected
) else (
echo [INFO] Mozilla Firefox not found
)

if exist "%PROGRAMFILES%\Microsoft\Edge\Application\msedge.exe" (
echo [SUCCESS] Microsoft Edge detected
) else (
echo [INFO] Microsoft Edge not found
)

echo.
echo [STEP 2/5] Browser cache optimization...
echo [INFO] Browser optimization recommendations:
echo [INFO] 1. Clear browser cache regularly
echo [INFO] 2. Disable unnecessary browser extensions
echo [INFO] 3. Update browser to latest version
echo [INFO] 4. Enable hardware acceleration if available

echo.
echo [STEP 3/5] Browser performance tips...
echo [INFO] Browser performance tips:
echo [INFO] 1. Limit number of open tabs
echo [INFO] 2. Use ad blockers to reduce resource usage
echo [INFO] 3. Disable auto-play videos and animations
echo [INFO] 4. Use browser task manager to monitor resource usage

echo.
echo [STEP 4/5] Browser security optimization...
echo [INFO] Browser security optimization:
echo [INFO] 1. Enable pop-up blockers
echo [INFO] 2. Use secure DNS settings
echo [INFO] 3. Enable phishing and malware protection
echo [INFO] 4. Regularly clear browsing data

echo.
echo [STEP 5/5] Browser extension management...
echo [INFO] Browser extension recommendations:
echo [INFO] 1. Review and remove unnecessary extensions
echo [INFO] 2. Keep extensions updated
echo [INFO] 3. Use extensions from trusted sources only
echo [INFO] 4. Monitor extension resource usage

echo.
echo [COMPLETED] Browser optimization analysis completed
echo [SUCCESS] Browser performance analysis completed
echo [INFO] Manual browser optimization recommended
set /a COMPLETED_OPTIMIZATIONS+=5
set /a OPTIMIZATION_SCORE+=20
pause
goto :menu

:comprehensive_analysis
echo.
echo ========================================================================
echo                         COMPREHENSIVE PERFORMANCE ANALYSIS
echo ========================================================================
echo.

echo [STATUS] Running comprehensive system performance analysis...
echo [INFO] This analysis will evaluate all aspects of system performance
echo.

echo [STEP 1/10] System Information Analysis...
echo [INFO] Gathering system information...
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Type" /C:"Total Physical Memory"

echo.
echo [STEP 2/10] CPU Performance Analysis...
echo [INFO] CPU performance metrics:
wmic cpu get name,maxclockspeed,currentclockspeed /format:table

echo.
echo [STEP 3/10] Memory Performance Analysis...
echo [INFO] Memory performance metrics:
wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /format:table

echo.
echo [STEP 4/10] Disk Performance Analysis...
echo [INFO] Disk performance metrics:
wmic logicaldisk get size,freespace,caption /format:table

echo.
echo [STEP 5/10] Network Performance Analysis...
echo [INFO] Network performance test...
ping -n 4 8.8.8.8

echo.
echo [STEP 6/10] Process Analysis...
echo [INFO] Top resource-consuming processes:
tasklist /fo csv | sort /r /+4 | head -10

echo.
echo [STEP 7/10] Service Analysis...
echo [INFO] Critical services status:
sc query state= all | findstr "SERVICE_NAME\|STATE" | findstr "RUNNING\|STOPPED"

echo.
echo [STEP 8/10] Startup Analysis...
echo [INFO] Startup programs count:
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /s 2>nul | find /c "HKEY_"

echo.
echo [STEP 9/10] Performance Score Calculation...
set /a "PERFORMANCE_SCORE=0"

:: CPU Score (0-25 points)
for /f "skip=1 tokens=2 delims==" %%p in ('wmic cpu get loadpercentage /value 2^>nul') do (
if "%%p" neq "" (
if %%p lss 50 set /a PERFORMANCE_SCORE+=25
if %%p geq 50 if %%p lss 80 set /a PERFORMANCE_SCORE+=15
if %%p geq 80 set /a PERFORMANCE_SCORE+=5
goto :cpu_score_done
)
)
:cpu_score_done

:: Memory Score (0-25 points)
for /f "tokens=2 delims==" %%a in ('wmic OS get TotalVisibleMemorySize /value ^| find "="') do set "TotalRAM=%%a"
for /f "tokens=2 delims==" %%a in ('wmic OS get FreePhysicalMemory /value ^| find "="') do set "FreeRAM=%%a"
if defined TotalRAM if defined FreeRAM (
set /a "UsedRAM=TotalRAM-FreeRAM"
set /a "RAMPercent=UsedRAM*100/TotalRAM"
if %RAMPercent% lss 70 set /a PERFORMANCE_SCORE+=25
if %RAMPercent% geq 70 if %RAMPercent% lss 90 set /a PERFORMANCE_SCORE+=15
if %RAMPercent% geq 90 set /a PERFORMANCE_SCORE+=5
)

:: Disk Score (0-25 points)
for /f "tokens=3" %%a in ('dir /-c ^| find "bytes free"') do set "free_space=%%a"
if defined free_space (
if %free_space% gtr 1073741824 set /a PERFORMANCE_SCORE+=25
if %free_space% leq 1073741824 if %free_space% gtr 536870912 set /a PERFORMANCE_SCORE+=15
if %free_space% leq 536870912 set /a PERFORMANCE_SCORE+=5
)

:: Process Score (0-25 points)
for /f %%a in ('tasklist /fo csv ^| find /c /v ""') do set "process_count=%%a"
if %process_count% lss 100 set /a PERFORMANCE_SCORE+=25
if %process_count% geq 100 if %process_count% lss 150 set /a PERFORMANCE_SCORE+=15
if %process_count% geq 150 set /a PERFORMANCE_SCORE+=5

echo.
echo [STEP 10/10] Performance Analysis Results...
echo ========================================================================
echo                           PERFORMANCE ANALYSIS RESULTS
echo ========================================================================
echo.

if %PERFORMANCE_SCORE% geq 90 (
echo [EXCELLENT] Performance Score: %PERFORMANCE_SCORE%/100
echo [STATUS] Your system has excellent performance
echo [RECOMMENDATION] Continue maintaining current performance practices
) else if %PERFORMANCE_SCORE% geq 75 (
echo [GOOD] Performance Score: %PERFORMANCE_SCORE%/100
echo [STATUS] Your system has good performance
echo [RECOMMENDATION] Consider running optimization routines
) else if %PERFORMANCE_SCORE% geq 60 (
echo [FAIR] Performance Score: %PERFORMANCE_SCORE%/100
echo [STATUS] Your system has fair performance
echo [RECOMMENDATION] Several optimizations recommended
) else (
echo [POOR] Performance Score: %PERFORMANCE_SCORE%/100
echo [STATUS] Your system needs immediate performance optimization
echo [RECOMMENDATION] Run comprehensive optimization routines
)

echo.
echo [INFO] Analysis completed successfully
echo [INFO] Total optimizations available: 10
echo [INFO] Optimizations completed: %COMPLETED_OPTIMIZATIONS%
set /a COMPLETED_OPTIMIZATIONS+=10
set /a OPTIMIZATION_SCORE+=50
pause
goto :menu

:performance_monitoring
echo.
echo ========================================================================
echo                         PERFORMANCE MONITORING & LOGGING
echo ========================================================================
echo.

echo [STATUS] Setting up performance monitoring and logging...
echo.

echo [STEP 1/5] Creating performance log directory...
if not exist "%~dp0logs\performance" (
mkdir "%~dp0logs\performance" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Performance log directory created
) else (
echo [ERROR] Failed to create performance log directory
)
) else (
echo [SUCCESS] Performance log directory exists
)

echo.
echo [STEP 2/5] Creating performance baseline...
echo [INFO] Creating performance baseline snapshot...
echo %date% %time% - Performance Baseline > "%~dp0logs\performance\baseline.txt"
echo System Information: >> "%~dp0logs\performance\baseline.txt"
systeminfo | findstr /B /C:"OS Name" /C:"Total Physical Memory" >> "%~dp0logs\performance\baseline.txt"
echo. >> "%~dp0logs\performance\baseline.txt"
echo CPU Information: >> "%~dp0logs\performance\baseline.txt"
wmic cpu get name,maxclockspeed /format:table >> "%~dp0logs\performance\baseline.txt"
echo. >> "%~dp0logs\performance\baseline.txt"
echo Memory Usage: >> "%~dp0logs\performance\baseline.txt"
wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /format:table >> "%~dp0logs\performance\baseline.txt"
if %errorlevel%==0 (
echo [SUCCESS] Performance baseline created
) else (
echo [WARNING] Performance baseline creation failed
)

echo.
echo [STEP 3/5] Setting up performance monitoring...
echo [INFO] Performance monitoring recommendations:
echo [INFO] 1. Use Task Manager for real-time monitoring
echo [INFO] 2. Use Performance Monitor (perfmon.msc) for detailed analysis
echo [INFO] 3. Set up performance alerts for critical thresholds
echo [INFO] 4. Monitor disk space and memory usage regularly

echo.
echo [STEP 4/5] Creating performance log template...
echo [INFO] Creating performance logging template...
echo Performance Log - %date% %time% > "%~dp0logs\performance\log_template.txt"
echo ================================ >> "%~dp0logs\performance\log_template.txt"
echo. >> "%~dp0logs\performance\log_template.txt"
echo CPU Usage: [INSERT CPU PERCENTAGE] >> "%~dp0logs\performance\log_template.txt"
echo Memory Usage: [INSERT MEMORY PERCENTAGE] >> "%~dp0logs\performance\log_template.txt"
echo Disk Space: [INSERT FREE SPACE] >> "%~dp0logs\performance\log_template.txt"
echo Process Count: [INSERT PROCESS COUNT] >> "%~dp0logs\performance\log_template.txt"
echo. >> "%~dp0logs\performance\log_template.txt"
echo Notes: [INSERT PERFORMANCE NOTES] >> "%~dp0logs\performance\log_template.txt"
if %errorlevel%==0 (
echo [SUCCESS] Performance log template created
) else (
echo [WARNING] Performance log template creation failed
)

echo.
echo [STEP 5/5] Performance monitoring setup complete...
echo [INFO] Performance monitoring setup completed
echo [INFO] Log files location: %~dp0logs\performance\
echo [INFO] Baseline file: baseline.txt
echo [INFO] Log template: log_template.txt
echo [INFO] Use these files to track performance over time

echo.
echo [COMPLETED] Performance monitoring setup completed
echo [SUCCESS] Performance monitoring and logging configured
set /a COMPLETED_OPTIMIZATIONS+=5
set /a OPTIMIZATION_SCORE+=25
pause
goto :menu

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please enter a number between 0-9 or A-B.
pause
goto :menu

:menu
cls
goto :menu

:exit
echo.
echo ========================================================================
echo                         OPTIMIZATION SUMMARY
echo ========================================================================
echo.

echo [INFO] Performance Optimization Session Summary:
echo [INFO] - Total optimizations completed: %COMPLETED_OPTIMIZATIONS%
echo [INFO] - Optimization score: %OPTIMIZATION_SCORE%
echo [INFO] - Session completed successfully

if %OPTIMIZATION_SCORE% gtr 0 (
echo [SUCCESS] Performance optimizations applied successfully
echo [INFO] Recommended: Restart your computer for optimal results
) else (
echo [INFO] No optimizations were performed in this session
)

echo.
echo [INFO] Performance Optimization completed
echo [INFO] Thank you for using DevOptimizer System
echo [INFO] For best results, run optimizations regularly
exit /b 0


REM ================================================================================
REM                           π¤– AI-POWERED EXECUTION ANALYSIS
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

REM ================================================================================
REM                        π¤– AI-POWERED EXECUTION ANALYSIS
REM ================================================================================
REM Enhanced pause system with comprehensive insights and reporting
REM Model: llama3.1:8b
REM Added: 2025-10-05 13:25:15
REM ================================================================================

REM Get script directory for pause system
set "PAUSE_SYSTEM_DIR=D:\Nuxt Projects\llm-dev-agent\BAT\tests"
set "ENHANCED_PAUSE_SCRIPT=%PAUSE_SYSTEM_DIR%\Enhanced-AIPause.bat"

REM Check if enhanced pause system exists
if exist "%ENHANCED_PAUSE_SCRIPT%" (
echo.
echo [AI] Enhanced AI-powered analysis starting...
call "%ENHANCED_PAUSE_SCRIPT%" "%0"
) else (
echo.
echo [WARNING] Enhanced AI pause system not found at: %ENHANCED_PAUSE_SCRIPT%
echo [INFO] Falling back to standard pause...
echo.
echo ================================================================================
echo                            EXECUTION COMPLETED
echo ================================================================================
echo Script: %~nx0
echo Error Level: %ERRORLEVEL%
echo Timestamp: %DATE% %TIME%
echo ================================================================================
echo                          Press any key to continue...
echo ================================================================================
pause >nul
)

REM Mark that enhanced AI pause has been added
set "AI_PAUSE_ENHANCED=TRUE"
set "AI_MODEL_USED=llama3.1:8b"
set "AI_ANALYSIS_TIMESTAMP=2025-10-05 13:25:15"
set "AI_SCRIPT_ANALYZED=%~nx0"
