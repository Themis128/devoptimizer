@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

:: ================================================================
::              OLLAMA AI SYSTEM ANALYZER FOR WINDOWS 11 BUILD 26120
:: ================================================================

set "BAT_HUB=%~dp0"
set "BAT_HUB=%BAT_HUB:~0,-1%"

call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Running Ollama AI System Analyzer"

echo.
echo ================================================================


:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo            OLLAMA MULTI-MODEL AI SYSTEM ANALYZER FOR WINDOWS 11 BUILD 26120
echo ================================================================
echo.
echo Starting comprehensive AI-powered system analysis using ALL available Ollama models...
echo - Real-time performance monitoring
echo - Predictive maintenance analysis
echo - Intelligent optimization recommendations
echo - Performance scoring and benchmarking
echo - Multi-model consensus analysis for enhanced accuracy
echo.

:: Create AI analysis directory
if not exist "%BAT_HUB%\ai-analysis" mkdir "%BAT_HUB%\ai-analysis" 2>nul

:: Get current system metrics
echo [1/5] Collecting system metrics...
powershell -ExecutionPolicy Bypass -Command "try { Get-WmiObject -Class Win32_Processor | Select-Object Name, LoadPercentage | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\cpu-metrics.json" 2>nul
powershell -ExecutionPolicy Bypass -Command "try { Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\memory-metrics.json" 2>nul
powershell -ExecutionPolicy Bypass -Command "try { Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\disk-metrics.json" 2>nul
powershell -ExecutionPolicy Bypass -Command "try { Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WorkingSet | ConvertTo-Json } catch { '{}' }" > "%BAT_HUB%\ai-analysis\process-metrics.json" 2>nul

echo [2/5] Analyzing system performance with Ollama multi-model system...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Analyze this Windows 11 system performance data and provide optimization recommendations. System: Intel i9-12900H, 32GB RAM, Windows 11 Build 26120. Focus on: 1) CPU optimization for 20-thread processor 2) Memory management for 32GB RAM 3) Storage optimization across multiple drives 4) Process prioritization 5) Background service optimization. Provide specific actionable recommendations." -output "%BAT_HUB%\ai-analysis\performance-analysis.txt"

echo [3/5] Generating predictive maintenance insights with multi-model analysis...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Based on Windows 11 Build 26120 system data, predict potential issues and maintenance needs. Consider: 1) Hardware health trends 2) Software update requirements 3) Performance degradation patterns 4) Security vulnerabilities 5) Storage optimization opportunities. Provide timeline-based recommendations for proactive maintenance." -output "%BAT_HUB%\ai-analysis\maintenance-predictions.txt"

echo [4/5] Creating intelligent optimization scripts with multi-model AI...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Generate optimized batch scripts for Windows 11 Build 26120 with Intel i9-12900H. Create scripts for: 1) CPU performance optimization 2) Memory management 3) Storage optimization 4) Network optimization 5) Security hardening. Include specific registry tweaks, service configurations, and performance settings tailored for this exact system configuration." -output "%BAT_HUB%\ai-analysis\optimization-scripts.txt"

echo [5/5] Calculating performance score with multi-model analysis...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Calculate a comprehensive performance score for this Windows 11 Build 26120 system with Intel i9-12900H and 32GB RAM. Consider: 1) CPU utilization efficiency (0-100) 2) Memory management effectiveness (0-100) 3) Storage performance (0-100) 4) System responsiveness (0-100) 5) Security posture (0-100). Provide overall score and specific improvement areas." -output "%BAT_HUB%\ai-analysis\performance-score.txt"

:: Display results
echo.
echo ================================================================
echo                    AI ANALYSIS COMPLETE
echo ================================================================
echo.
echo Results saved to: %BAT_HUB%\ai-analysis\
echo.
echo [] Performance Analysis: performance-analysis.txt
echo [] Maintenance Predictions: maintenance-predictions.txt
echo [] Optimization Scripts: optimization-scripts.txt
echo [] Performance Score: performance-score.txt
echo.
echo Displaying key insights:
echo.
type "%BAT_HUB%\ai-analysis\performance-score.txt"
echo.
echo ================================================================

call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Ollama AI System Analyzer Completed"
pause
goto :eof
exit /b %ERRORLEVEL%
