@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
:: ================================================================
::           OLLAMA PERFORMANCE SCORER FOR WINDOWS 11 BUILD 26120
:: ================================================================
set "BAT_HUB=%~dp0"
set "BAT_HUB=%BAT_HUB:~0,-1%"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Running Ollama Performance Scorer"
echo.
echo ================================================================
:: Check for admin privileges
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
echo.
echo [ERROR] This script requires Administrator privileges.
echo Please run this script as Administrator.
echo.
pause
exit /b 1
) else (
echo [INFO] Running with Administrator privileges
)
echo         OLLAMA MULTI-MODEL PERFORMANCE SCORER FOR WINDOWS 11 BUILD 26120
echo ================================================================
echo.
echo Choose scoring mode (using multi-model consensus analysis):
echo.
echo [1]  COMPREHENSIVE-SCORE - Complete system performance scoring
echo [2]  CPU-PERFORMANCE - Intel i9-12900H CPU performance analysis
echo [3]  MEMORY-PERFORMANCE - 32GB RAM performance evaluation
echo [4]  STORAGE-PERFORMANCE - Multi-drive storage performance
echo [5]  NETWORK-PERFORMANCE - Network and connectivity scoring
echo [6]  SECURITY-PERFORMANCE - Security posture evaluation
echo [7]  RESPONSIVENESS-SCORE - System responsiveness analysis
echo [8]  BENCHMARK-COMPARISON - Compare against benchmarks
echo [9]  TREND-ANALYSIS - Performance trend over time
echo [0] Back to main menu
echo.
set /p score_choice="Enter your choice (0-9): "
if "%score_choice%"=="0" goto :eof
if "%score_choice%"=="1" goto comprehensive_score
if "%score_choice%"=="2" goto cpu_performance
if "%score_choice%"=="3" goto memory_performance
if "%score_choice%"=="4" goto storage_performance
if "%score_choice%"=="5" goto network_performance
if "%score_choice%"=="6" goto security_performance
if "%score_choice%"=="7" goto responsiveness_score
if "%score_choice%"=="8" goto benchmark_comparison
if "%score_choice%"=="9" goto trend_analysis
echo Invalid choice. Please try again.
pause
goto :eof
:comprehensive_score
echo.
echo  COMPREHENSIVE-SCORE MODE - Complete system performance scoring
echo ================================================================
echo.
echo [1/6] Collecting CPU performance data...
powershell -ExecutionPolicy Bypass -Command "try { Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 5 | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\cpu-score-data.json" 2>nul
powershell -ExecutionPolicy Bypass -Command "try { Get-WmiObject -Class Win32_Processor | Select-Object Name, MaxClockSpeed, CurrentClockSpeed, LoadPercentage | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\cpu-detailed.json" 2>nul
echo [2/6] Collecting memory performance data...
powershell -ExecutionPolicy Bypass -Command "try { Get-Counter '\Memory\Available MBytes', '\Memory\Committed Bytes', '\Memory\Pool Nonpaged Bytes' -SampleInterval 1 -MaxSamples 5 | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\memory-score-data.json" 2>nul
powershell -ExecutionPolicy Bypass -Command "try { Get-WmiObject -Class Win32_PhysicalMemory | Select-Object Capacity, Speed, Manufacturer | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\memory-detailed.json" 2>nul
echo [3/6] Collecting storage performance data...
powershell -ExecutionPolicy Bypass -Command "try { Get-Counter '\PhysicalDisk(_Total)\% Disk Time', '\PhysicalDisk(_Total)\Avg. Disk Queue Length', '\PhysicalDisk(_Total)\Disk Read Bytes/sec', '\PhysicalDisk(_Total)\Disk Write Bytes/sec' -SampleInterval 1 -MaxSamples 5 | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\storage-score-data.json" 2>nul
powershell -ExecutionPolicy Bypass -Command "try { Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace, FileSystem | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\storage-detailed.json" 2>nul
echo [4/6] Collecting network performance data...
powershell -ExecutionPolicy Bypass -Command "try { Get-Counter '\Network Interface(*)\Bytes Total/sec', '\Network Interface(*)\Packets/sec' -SampleInterval 1 -MaxSamples 5 | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\network-score-data.json" 2>nul
echo [5/6] Collecting system responsiveness data...
powershell -ExecutionPolicy Bypass -Command "try { Get-Counter '\System\Processor Queue Length', '\System\Context Switches/sec' -SampleInterval 1 -MaxSamples 5 | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\responsiveness-data.json" 2>nul
echo [6/6] Calculating comprehensive performance score...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Calculate comprehensive performance score for Windows 11 Build 26120 with Intel i9-12900H (20 threads), 32GB RAM. Analyze all collected performance data and provide: 1) Overall performance score (0-1000) 2) CPU performance score (0-1000) 3) Memory performance score (0-1000) 4) Storage performance score (0-1000) 5) Network performance score (0-1000) 6) System responsiveness score (0-1000) 7) Detailed analysis of each component 8) Specific improvement recommendations 9) Performance ranking and comparison. Format as comprehensive performance report." -output "%BAT_HUB%\ai-analysis\comprehensive-score.txt"
echo Comprehensive scoring complete!
type "%BAT_HUB%\ai-analysis\comprehensive-score.txt"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Comprehensive scoring completed"
pause
goto :eof
:cpu_performance
echo.
echo  CPU-PERFORMANCE MODE - Intel i9-12900H CPU performance analysis
echo ================================================================
echo.
echo Analyzing CPU performance...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Analyze Intel i9-12900H CPU performance on Windows 11 Build 26120. Focus on: 1) CPU utilization efficiency 2) Core and thread performance 3) Cache performance 4) Thermal performance 5) Power efficiency 6) Performance per watt 7) Multitasking capability 8) Single-threaded performance 9) Multi-threaded performance 10) Performance consistency. Provide detailed CPU performance score (0-1000) and optimization recommendations." -output "%BAT_HUB%\ai-analysis\cpu-performance-score.txt"
echo CPU performance analysis complete!
type "%BAT_HUB%\ai-analysis\cpu-performance-score.txt"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "CPU performance analysis completed"
pause
goto :eof
:memory_performance
echo.
echo  MEMORY-PERFORMANCE MODE - 32GB RAM performance evaluation
echo ================================================================
echo.
echo Analyzing memory performance...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Analyze 32GB RAM performance on Windows 11 Build 26120 with Intel i9-12900H. Focus on: 1) Memory bandwidth utilization 2) Memory latency performance 3) Cache hierarchy efficiency 4) Memory allocation patterns 5) Page file usage 6) Memory compression effectiveness 7) Multi-threaded memory access 8) Memory pool management 9) Garbage collection impact 10) Memory fragmentation. Provide detailed memory performance score (0-1000) and optimization recommendations." -output "%BAT_HUB%\ai-analysis\memory-performance-score.txt"
echo Memory performance analysis complete!
type "%BAT_HUB%\ai-analysis\memory-performance-score.txt"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Memory performance analysis completed"
pause
goto :eof
:storage_performance
echo.
echo  STORAGE-PERFORMANCE MODE - Multi-drive storage performance
echo ================================================================
echo.
echo Analyzing storage performance...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Analyze multi-drive storage performance on Windows 11 Build 26120. Drives: C: 672GB free, D: 145GB free, E: 135GB free. Focus on: 1) Sequential read/write performance 2) Random I/O performance 3) IOPS capabilities 4) Latency characteristics 5) Queue depth handling 6) Multi-drive coordination 7) File system efficiency 8) Storage space utilization 9) Defragmentation status 10) Storage health indicators. Provide detailed storage performance score (0-1000) and optimization recommendations." -output "%BAT_HUB%\ai-analysis\storage-performance-score.txt"
echo Storage performance analysis complete!
type "%BAT_HUB%\ai-analysis\storage-performance-score.txt"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Storage performance analysis completed"
pause
goto :eof
:network_performance
echo.
echo  NETWORK-PERFORMANCE MODE - Network and connectivity scoring
echo ================================================================
echo.
echo Analyzing network performance...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Analyze network performance on Windows 11 Build 26120. Focus on: 1) Network bandwidth utilization 2) Latency characteristics 3) Packet loss rates 4) Connection stability 5) DNS resolution speed 6) Network adapter performance 7) TCP/IP stack optimization 8) Network security performance 9) Wireless vs wired performance 10) Network congestion handling. Provide detailed network performance score (0-1000) and optimization recommendations." -output "%BAT_HUB%\ai-analysis\network-performance-score.txt"
echo Network performance analysis complete!
type "%BAT_HUB%\ai-analysis\network-performance-score.txt"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Network performance analysis completed"
pause
goto :eof
:security_performance
echo.
echo  SECURITY-PERFORMANCE MODE - Security posture evaluation
echo ================================================================
echo.
echo Analyzing security performance...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Analyze security performance on Windows 11 Build 26120. Focus on: 1) Windows Defender effectiveness 2) Firewall configuration 3) User account security 4) System security policies 5) Network security posture 6) Application security 7) Data protection measures 8) Security update status 9) Vulnerability assessment 10) Security monitoring capabilities. Provide detailed security performance score (0-1000) and improvement recommendations." -output "%BAT_HUB%\ai-analysis\security-performance-score.txt"
echo Security performance analysis complete!
type "%BAT_HUB%\ai-analysis\security-performance-score.txt"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Security performance analysis completed"
pause
goto :eof
:responsiveness_score
echo.
echo  RESPONSIVENESS-SCORE MODE - System responsiveness analysis
echo ================================================================
echo.
echo Analyzing system responsiveness...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Analyze system responsiveness on Windows 11 Build 26120 with Intel i9-12900H. Focus on: 1) Boot time performance 2) Application launch speed 3) System response time 4) UI responsiveness 5) Context switching speed 6) Process scheduling efficiency 7) System stability 8) Error recovery time 9) Resource allocation speed 10) Overall user experience. Provide detailed responsiveness score (0-1000) and optimization recommendations." -output "%BAT_HUB%\ai-analysis\responsiveness-score.txt"
echo Responsiveness analysis complete!
type "%BAT_HUB%\ai-analysis\responsiveness-score.txt"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Responsiveness analysis completed"
pause
goto :eof
:benchmark_comparison
echo.
echo  BENCHMARK-COMPARISON MODE - Compare against benchmarks
echo ================================================================
echo.
echo Comparing against benchmarks...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Compare Windows 11 Build 26120 performance with Intel i9-12900H against industry benchmarks. Include: 1) CPU benchmark comparison 2) Memory benchmark comparison 3) Storage benchmark comparison 4) Network benchmark comparison 5) Overall system benchmark comparison 6) Performance ranking 7) Competitive analysis 8) Optimization potential 9) Performance gaps 10) Improvement opportunities. Provide detailed benchmark comparison report." -output "%BAT_HUB%\ai-analysis\benchmark-comparison.txt"
echo Benchmark comparison complete!
type "%BAT_HUB%\ai-analysis\benchmark-comparison.txt"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Benchmark comparison completed"
pause
goto :eof
:trend_analysis
echo.
echo  TREND-ANALYSIS MODE - Performance trend over time
echo ================================================================
echo.
echo Analyzing performance trends...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Analyze performance trends for Windows 11 Build 26120 with Intel i9-12900H over time. Focus on: 1) Performance degradation trends 2) Improvement opportunities 3) Seasonal performance patterns 4) Usage-based performance changes 5) Maintenance impact on performance 6) Performance prediction models 7) Trend-based optimization recommendations 8) Performance sustainability 9) Long-term performance outlook 10) Performance investment priorities. Provide detailed trend analysis report." -output "%BAT_HUB%\ai-analysis\trend-analysis.txt"
echo Trend analysis complete!
type "%BAT_HUB%\ai-analysis\trend-analysis.txt"
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Trend analysis completed"
pause
goto :eof
:: ================================================================
::                    ADMIN PRIVILEGE FUNCTIONS
:: ================================================================
:checkAdmin
set "IS_ADMIN=0"
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
exit /b
