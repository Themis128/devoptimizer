:: SYNOPSIS: DevOptimizer automation script: ollama-intelligent-optimizer-NoAdmin.
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

:: ================================================================
::           OLLAMA INTELLIGENT SYSTEM OPTIMIZER FOR WIN11 BUILD 26120
:: ================================================================

set "BAT_HUB=%~dp0"
set "BAT_HUB=%BAT_HUB:~0,-1%"

call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Running Ollama Intelligent System Optimizer"

echo.
echo ================================================================


:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo         OLLAMA INTELLIGENT SYSTEM OPTIMIZER FOR WIN11 BUILD 26120
echo ================================================================
echo.
echo Choose optimization mode:
echo.
echo [1]  AUTO-OPTIMIZE - AI-driven automatic system optimization
echo [2]  PERFORMANCE-FOCUS - Maximize performance for Intel i9-12900H
echo [3]  SECURITY-FOCUS - Enhanced security with performance balance
echo [4]  STORAGE-FOCUS - Optimize multi-drive storage configuration
echo [5]  NETWORK-FOCUS - Network and connectivity optimization
echo [6]  CUSTOM-PROFILE - Create custom optimization profile
echo [7]  BENCHMARK-MODE - Performance benchmarking and comparison
echo [0] Back to main menu
echo.
set /p opt_choice="Enter your choice (0-7): "

if "%opt_choice%"=="0" goto :eof
if "%opt_choice%"=="1" goto auto_optimize
if "%opt_choice%"=="2" goto performance_focus
if "%opt_choice%"=="3" goto security_focus
if "%opt_choice%"=="4" goto storage_focus
if "%opt_choice%"=="5" goto network_focus
if "%opt_choice%"=="6" goto custom_profile
if "%opt_choice%"=="7" goto benchmark_mode

echo Invalid choice. Please try again.
pause
goto :eof

:auto_optimize
echo.
echo  AUTO-OPTIMIZE MODE - AI-driven automatic optimization
echo ================================================================
echo.
echo Analyzing current system state...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Analyze Windows 11 Build 26120 system and create automatic optimization plan. System: Intel i9-12900H (20 threads), 32GB RAM. Generate step-by-step optimization commands for: 1) CPU performance tuning 2) Memory optimization 3) Storage configuration 4) Background process management 5) Registry optimizations. Output as executable batch commands." -output "%BAT_HUB%\ai-analysis\auto-optimize-plan.txt"

echo Applying AI-generated optimizations...
call "%BAT_HUB%\ai-analysis\auto-optimize-plan.txt"

echo Auto-optimization complete!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Auto-optimization completed"
pause
goto :eof

:performance_focus
echo.
echo  PERFORMANCE-FOCUS MODE - Maximize Intel i9-12900H performance
echo ================================================================
echo.
echo Generating performance-focused optimizations...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create performance-focused optimization for Intel i9-12900H (20 threads) on Windows 11 Build 26120. Focus on: 1) CPU core utilization optimization 2) Thread scheduling improvements 3) Cache optimization 4) Memory bandwidth optimization 5) Process priority management. Generate specific registry tweaks and system configurations." -output "%BAT_HUB%\ai-analysis\performance-optimize.txt"

echo Applying performance optimizations...
call "%BAT_HUB%\ai-analysis\performance-optimize.txt"

echo Performance optimization complete!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Performance optimization completed"
pause
goto :eof

:security_focus
echo.
echo  SECURITY-FOCUS MODE - Enhanced security with performance balance
echo ================================================================
echo.
echo Generating security-focused optimizations...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create security-focused optimization for Windows 11 Build 26120 with performance balance. Focus on: 1) Windows Defender optimization 2) Firewall configuration 3) Process isolation 4) Memory protection 5) Network security. Ensure performance impact is minimal while maximizing security posture." -output "%BAT_HUB%\ai-analysis\security-optimize.txt"

echo Applying security optimizations...
call "%BAT_HUB%\ai-analysis\security-optimize.txt"

echo Security optimization complete!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Security optimization completed"
pause
goto :eof

:storage_focus
echo.
echo  STORAGE-FOCUS MODE - Multi-drive storage optimization
echo ================================================================
echo.
echo Generating storage-focused optimizations...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create storage optimization for Windows 11 Build 26120 with multiple drives (C: 672GB, D: 145GB, E: 135GB free). Focus on: 1) Drive performance optimization 2) File system tuning 3) Cache configuration 4) Disk I/O optimization 5) Storage space management. Generate specific optimizations for each drive." -output "%BAT_HUB%\ai-analysis\storage-optimize.txt"

echo Applying storage optimizations...
call "%BAT_HUB%\ai-analysis\storage-optimize.txt"

echo Storage optimization complete!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Storage optimization completed"
pause
goto :eof

:network_focus
echo.
echo  NETWORK-FOCUS MODE - Network and connectivity optimization
echo ================================================================
echo.
echo Generating network-focused optimizations...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create network optimization for Windows 11 Build 26120. Focus on: 1) TCP/IP stack optimization 2) DNS configuration 3) Network adapter tuning 4) Bandwidth optimization 5) Latency reduction. Generate specific network registry tweaks and configurations." -output "%BAT_HUB%\ai-analysis\network-optimize.txt"

echo Applying network optimizations...
call "%BAT_HUB%\ai-analysis\network-optimize.txt"

echo Network optimization complete!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Network optimization completed"
pause
goto :eof

:custom_profile
echo.
echo  CUSTOM-PROFILE MODE - Create custom optimization profile
echo ================================================================
echo.
echo Describe your optimization requirements:
echo (e.g., "Gaming performance", "Development workflow", "Video editing", etc.)
set /p custom_req="Enter your requirements: "

echo Generating custom optimization profile...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create custom optimization profile for Windows 11 Build 26120 with Intel i9-12900H (20 threads), 32GB RAM. Requirements: %custom_req%. Generate specific optimizations tailored to these requirements while maintaining system stability." -output "%BAT_HUB%\ai-analysis\custom-optimize.txt"

echo Applying custom optimizations...
call "%BAT_HUB%\ai-analysis\custom-optimize.txt"

echo Custom optimization complete!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Custom optimization completed: %custom_req%"
pause
goto :eof

:benchmark_mode
echo.
echo  BENCHMARK-MODE - Performance benchmarking and comparison
echo ================================================================
echo.
echo Running comprehensive performance benchmarks...
call "%~dp0tools\ollama-batch-helper.bat" -prompt "Create comprehensive benchmarking script for Windows 11 Build 26120 with Intel i9-12900H. Generate benchmarks for: 1) CPU performance 2) Memory bandwidth 3) Storage I/O 4) Network performance 5) System responsiveness. Include comparison with optimal configurations." -output "%BAT_HUB%\ai-analysis\benchmark-script.txt"

echo Executing benchmarks...
call "%BAT_HUB%\ai-analysis\benchmark-script.txt"

echo Benchmarking complete!
call "%~dp0..\DEVOPTIMIZER-LAUNCHER.bat" :log "Benchmarking completed"
pause
goto :eof
exit /b %ERRORLEVEL%
