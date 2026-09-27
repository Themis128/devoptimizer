@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Power Management and Performance Profiles (Admin Required) 
echo.
echo =====================================================
echo POWER MANAGEMENT AND PERFORMANCE PROFILES
echo ===================================================== echo.
echo Select a power optimization profile: echo.
echo GAMING PROFILE:
echo - High Performance power plan
echo - Disable USB selective suspend
echo - Maximum processor performance
echo - Disable CPU core parking
echo - Optimized for consistent frame rates echo.
echo DEVELOPMENT PROFILE:
echo - High Performance power plan
echo - Never turn off display during work
echo - Prevent system sleep during builds
echo - Keep USB devices always active
echo - Optimized for long coding sessions echo.
echo BATTERY SAVING PROFILE:
echo - Power Saver plan activated
echo - Aggressive display timeout
echo - Enable all power saving features
echo - Minimum processor performance
echo - Maximized battery life echo.
echo MAXIMUM PERFORMANCE PROFILE:
echo - Ultimate Performance power plan
echo - All power saving features disabled
echo - Maximum CPU and GPU performance
echo - No throttling or parking
echo - Best for intensive workloads echo.
echo BALANCED PROFILE:
echo - Windows Balanced power plan
echo - Standard power management
echo - Good performance with efficiency
echo - Default Windows behavior echo.
echo POWER ANALYSIS:
echo - Generate detailed power efficiency report
echo - Analyze current power consumption
echo - Identify power-hungry components
echo - Get optimization recommendations echo.
echo Choose your option: set /p choice="Enter choice (Gaming/Development/Battery/Maximum/Balanced/Analysis): " if /i "%choice%"=="Gaming" ( set profile=Gaming ) else if /i "%choice%"=="Development" ( set profile=Development ) else if /i "%choice%"=="Battery" ( set profile=Battery ) else if /i "%choice%"=="Maximum" ( set profile=Maximum ) else if /i "%choice%"=="Balanced" ( set profile=Balanced ) else if /i "%choice%"=="Analysis" ( set profile=Analysis ) else ( echo.
echo Invalid choice! Please run the script again. pause exit /b 1 ) echo.
echo Applying %profile% power configuration... echo. if "%profile%"=="Analysis" (
echo Generating power efficiency report...
echo This will monitor your system for 10 seconds... echo. powershell -ExecutionPolicy Bypass -Command "& { Set-ExecutionPolicy Bypass -Scope Process -Force . '%~dp0power-management.ps1' Get-PowerReport }" ) else ( powershell -ExecutionPolicy Bypass -Command "& { Set-ExecutionPolicy Bypass -Scope Process -Force . '%~dp0power-management.ps1' Write-Host 'Current power plans:' -ForegroundColor Cyan Get-PowerPlans Write-Host '' Write-Host 'Applying %profile% profile...' -ForegroundColor Green $result = Optimize-PowerSettings -Profile '%profile%' if ($result) { Write-Host '' Write-Host 'Power profile applied successfully!' -ForegroundColor Green Write-Host 'Verifying current power plan...' -ForegroundColor Cyan Get-PowerPlans } else { Write-Host 'Failed to apply power profile!' -ForegroundColor Red exit 1 } }" ) if %errorlevel% neq 0 ( echo.
echo ERROR: Power management configuration failed! echo.
echo Possible causes:
echo - Not running as Administrator
echo - Power plan not available on this system
echo - Group Policy restrictions
echo - Hardware not supporting advanced power features echo.
echo Solutions:
echo 1. Run as Administrator
echo 2. Check if Ultimate Performance plan is available
echo 3. Update power management drivers
echo 4. Check Group Policy settings echo. pause exit /b 1 ) echo.
echo POWER MANAGEMENT COMPLETED! echo. if "%profile%"=="Analysis" (
echo POWER ANALYSIS RESULTS:
echo Power efficiency report generated
echo Report opened in default browser
echo Check report for optimization recommendations echo.
echo POWER OPTIMIZATION TIPS:
echo - Review devices causing wake-ups
echo - Check for inefficient power settings
echo - Update drivers for better power management
echo - Consider SSD upgrade for better efficiency ) else (
echo POWER PROFILE SUMMARY:
echo Power plan optimized for %profile%
echo Processor performance configured
echo USB power management optimized
echo Display and sleep settings adjusted echo.
echo PROFILE-SPECIFIC NOTES: if "%profile%"=="Gaming" (
echo - Optimized for consistent performance
echo - May increase power consumption
echo - Best for gaming and intensive applications ) if "%profile%"=="Development" (
echo - Prevents interruptions during work
echo - Keeps system responsive during builds
echo - Optimized for long development sessions ) if "%profile%"=="Battery" (
echo - Maximizes battery life on laptops
echo - May reduce performance significantly
echo - Best for mobile productivity work ) if "%profile%"=="Maximum" (
echo - Absolute maximum performance
echo - Highest power consumption
echo - Best for workstations and intensive tasks ) if "%profile%"=="Balanced" (
echo - Good balance of performance and efficiency
echo - Standard Windows power management
echo - Suitable for most users ) ) echo.
echo POWER MANAGEMENT TIPS:
echo - Monitor system performance after changes
echo - Adjust settings based on usage patterns
echo - Use different profiles for different scenarios
echo - Check power efficiency regularly echo. pause
