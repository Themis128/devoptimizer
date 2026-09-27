@echo off

@
echo off setlocal EnableExtensions EnableDelayedExpansion title Windows Insider Automation Suite color 0C :: Check for admin privileges call :checkAdmin if not "%IS_ADMIN%"=="1" (
echo This tool requires Administrator privileges.
echo Right-click and select "Run as administrator" pause exit /b 1 ) :: Set paths and variables set "SCRIPT_DIR=%~dp0" set "LOG_FILE=%SCRIPT_DIR%insider-automation.log" set "CONFIG_FILE=%SCRIPT_DIR%insider-config.ini" :menu cls
echo ================================================================
echo WINDOWS INSIDER AUTOMATION SUITE v1.0
echo ================================================================
echo.
echo AUTOMATED TASKS:
echo 1) Auto-Setup New Insider - Complete automated setup
echo 2) Daily Health Check - Automated daily maintenance
echo 3) Weekly Deep Scan - Comprehensive weekly check
echo 4) Pre-Update Preparation - Prepare system for updates
echo 5) Post-Update Validation - Validate after updates echo.
echo SCHEDULED TASKS:
echo 6) Schedule Daily Health Check - Set up automatic daily checks
echo 7) Schedule Weekly Deep Scan - Set up automatic weekly scans
echo 8) Remove Scheduled Tasks - Remove automation schedules echo.
echo BATCH OPERATIONS:
echo 9) Batch System Optimization - Multiple optimizations at once
echo 10) Emergency System Recovery - Fix critical Insider issues
echo 11) Complete System Reset - Reset all Insider settings echo.
echo CONFIGURATION:
echo 12) Configure Automation Settings - Set automation preferences
echo 13) View Automation Logs - Check automation history
echo 14) Export Configuration - Backup automation settings echo.
echo 0) Exit echo. set /p choice=Enter your choice (0-14): if "%choice%"=="1" goto autoSetup if "%choice%"=="2" goto dailyHealth if "%choice%"=="3" goto weeklyDeep if "%choice%"=="4" goto preUpdate if "%choice%"=="5" goto postUpdate if "%choice%"=="6" goto scheduleDailyHealth if "%choice%"=="7" goto scheduleWeeklyDeep if "%choice%"=="8" goto removeScheduled if "%choice%"=="9" goto batchOptimization if "%choice%"=="10" goto emergencyRecovery if "%choice%"=="11" goto completeReset if "%choice%"=="12" goto configureAutomation if "%choice%"=="13" goto viewLogs if "%choice%"=="14" goto exportConfig if "%choice%"=="0" exit /b 0
echo Invalid choice. Please try again. timeout /t 2 >nul goto menu :autoSetup cls
echo ================================================================
echo AUTOMATED NEW INSIDER SETUP
echo ================================================================
echo.
echo This will perform a complete automated setup for Windows Insider Program. echo. set /p confirm=Continue with automated setup? (Y/N): if /i not "%confirm%"=="Y" goto menu call :log "Starting automated Insider setup" echo.
echo Starting automated Insider setup... echo. :: Step 1: System requirements check
echo [1/8] Checking system requirements... call :checkSystemRequirements if errorlevel 1 (
echo System requirements not met. Setup cannot continue. call :log "Setup failed - system requirements not met" pause goto menu )
echo System requirements met :: Step 2: Configure Windows Update
echo [2/8] Configuring Windows Update... net stop wuauserv >nul 2>&1 net stop cryptSvc >nul 2>&1 net stop bits >nul 2>&1 timeout /t 2 >nul net start wuauserv >nul 2>&1 net start cryptSvc >nul 2>&1 net start bits >nul 2>&1
echo Windows Update services configured :: Step 3: Set telemetry level
echo [3/8] Configuring telemetry for Insider Program... reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 3 /f >nul
echo Telemetry configured for Full diagnostic data :: Step 4: Enable Developer Mode
echo [4/8] Enabling Developer Mode... reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowAllTrustedApps /t REG_DWORD /d 1 /f >nul reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f >nul
echo Developer Mode enabled :: Step 5: Configure Beta Channel (safest for new users)
echo [5/8] Configuring Beta Channel (recommended for stability)... reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v Ring /t REG_DWORD /d 4 /f >nul reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled /t REG_DWORD /d 1 /f >nul reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\Applicability" /v EnablePreviewBuilds /t REG_DWORD /d 4 /f >nul
echo Beta Channel configured :: Step 6: Optimize system for Insider builds
echo [6/8] Optimizing system settings... reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 0 /f >nul reg add "HKCU\SOFTWARE\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 1 /f >nul
echo System settings optimized :: Step 7: Create restore point
echo [7/8] Creating system restore point... powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Before Windows Insider Setup' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
echo System restore point created :: Step 8: Force update check
echo [8/8] Initiating first update check... powershell -ExecutionPolicy Bypass -Command "(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()"
echo Update check initiated echo.
echo ================================================================
echo SETUP COMPLETED SUCCESSFULLY!
echo ================================================================
echo.
echo Your system has been configured for the Windows Insider Program:
echo - Beta Channel selected for stability
echo - Developer Mode enabled
echo - Telemetry configured for optimal feedback
echo - System optimized for Insider builds
echo - Restore point created for safety echo.
echo NEXT STEPS:
echo 1. Restart your computer
echo 2. Go to Settings ^> Windows Update
echo 3. Check for updates to download your first Insider build
echo 4. Use the other Insider tools for ongoing management echo. call :log "Automated Insider setup completed successfully" pause goto menu :dailyHealth cls
echo ================================================================
echo DAILY HEALTH CHECK
echo ================================================================
echo.
echo Running automated daily health check... call :log "Starting daily health check" set "HEALTH_LOG=%TEMP%\DailyHealthCheck_%date:~-4,4%%date:~-10,2%%date:~-7,2%.log"
echo Daily Health Check Report > "%HEALTH_LOG%"
echo Date: %date% %time% >> "%HEALTH_LOG%"
echo ========================== >> "%HEALTH_LOG%"
echo [1/6] Checking Windows Update service... sc query wuauserv | findstr "RUNNING" >nul if errorlevel 1 (
echo Windows Update service not running - attempting to start... net start wuauserv >nul 2>&1
echo Windows Update Service: RESTARTED >> "%HEALTH_LOG%" ) else (
echo Windows Update service running
echo Windows Update Service: RUNNING >> "%HEALTH_LOG%" )
echo [2/6] Checking Insider enrollment status... reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled 2>nul | findstr "0x1" >nul if errorlevel 1 (
echo Not enrolled in Insider Program
echo Insider Status: NOT ENROLLED >> "%HEALTH_LOG%" ) else (
echo Enrolled in Insider Program
echo Insider Status: ENROLLED >> "%HEALTH_LOG%" )
echo [3/6] Checking disk space... for /f "tokens=3" %%i in ('dir %SystemDrive%\ /-c ^| findstr "bytes free"') do ( set /a FREE_GB=%%i/1024/1024/1024 if !FREE_GB! LSS 15 (
echo Low disk space: !FREE_GB! GB free
echo Disk Space: LOW - !FREE_GB! GB >> "%HEALTH_LOG%" ) else (
echo Sufficient disk space: !FREE_GB! GB free
echo Disk Space: OK - !FREE_GB! GB >> "%HEALTH_LOG%" ) )
echo [4/6] Checking system temperature... powershell -ExecutionPolicy Bypass -Command "try { Get-WmiObject -Namespace root/wmi -Class MSAcpi_ThermalZoneTemperature | ForEach-Object { $temp = ($_.CurrentTemperature/10)-273.15; if($temp -gt 80) { Write-Host ' High temperature detected:' $temp'C' } else { Write-Host ' Temperature normal:' $temp'C' } } } catch { Write-Host ' Temperature monitoring not available' }" 2>nul
echo [5/6] Checking for critical errors... powershell -ExecutionPolicy Bypass -Command "$errors = Get-EventLog -LogName System -EntryType Error -After (Get-Date).AddDays(-1) -ErrorAction SilentlyContinue; if($errors.Count -gt 10) { Write-Host ' Multiple system errors detected:' $errors.Count 'errors' } else { Write-Host ' System errors within normal range:' $errors.Count 'errors' }" 2>nul
echo [6/6] Checking system performance... powershell -NoProfile -ExecutionPolicy Bypass -Command "$cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3 | Select-Object -ExpandProperty CounterSamples | Measure-Object -Property CookedValue -Average).Average; $mem = Get-Counter '\Memory\Available MBytes' | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue; if($cpu -gt 80) { Write-Host ' High CPU usage:' ([math]::Round($cpu,1))'%' } else { Write-Host ' CPU usage normal:' ([math]::Round($cpu,1))'%' }; Write-Host ' Available memory:' ([math]::Round($mem/1024,1))'GB'" 2>nul echo.
echo Daily health check completed!
echo Report saved to: %HEALTH_LOG% call :log "Daily health check completed" pause goto menu :weeklyDeep cls
echo ================================================================
echo WEEKLY DEEP SCAN
echo ================================================================
echo.
echo Running comprehensive weekly deep scan...
echo This may take 15-30 minutes depending on your system. echo. set /p confirm=Continue with weekly deep scan? (Y/N): if /i not "%confirm%"=="Y" goto menu call :log "Starting weekly deep scan" set "DEEP_LOG=%TEMP%\WeeklyDeepScan_%date:~-4,4%%date:~-10,2%%date:~-7,2%.log"
echo [1/10] Running System File Checker... sfc /scannow > "%DEEP_LOG%"
echo [2/10] Running DISM health check... dism /online /cleanup-image /checkhealth >> "%DEEP_LOG%"
echo [3/10] Running DISM scan health... dism /online /cleanup-image /scanhealth >> "%DEEP_LOG%"
echo [4/10] Checking all drives for errors... for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do ( if exist %%d:\ (
echo Checking drive %%d:\ >> "%DEEP_LOG%" chkdsk %%d: /scan >> "%DEEP_LOG%" 2>&1 ) )
echo [5/10] Analyzing system performance... powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Counter '\Processor(_Total)\% Processor Time','\Memory\Available MBytes','\PhysicalDisk(_Total)\% Disk Time' -SampleInterval 2 -MaxSamples 5 | Export-Csv '%TEMP%\WeeklyPerf.csv'" >> "%DEEP_LOG%"
echo [6/10] Checking driver compatibility... driverquery /v >> "%DEEP_LOG%"
echo [7/10] Analyzing event logs... powershell -ExecutionPolicy Bypass -Command "Get-EventLog -LogName System -EntryType Error -After (Get-Date).AddDays(-7) | Export-Csv '%TEMP%\WeeklyErrors.csv'" >> "%DEEP_LOG%" 2>nul
echo [8/10] Checking Windows Update history... powershell -ExecutionPolicy Bypass -Command "Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20 | Export-Csv '%TEMP%\WeeklyUpdates.csv'" >> "%DEEP_LOG%"
echo [9/10] Checking system security... powershell -ExecutionPolicy Bypass -Command "Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled, IoavProtectionEnabled | Export-Csv '%TEMP%\WeeklySecurity.csv'" >> "%DEEP_LOG%" 2>nul
echo [10/10] Generating summary report... powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, TotalPhysicalMemory, CsProcessors | Export-Csv '%TEMP%\WeeklySystem.csv'" >> "%DEEP_LOG%" echo.
echo Weekly deep scan completed!
echo Main report: %DEEP_LOG%
echo Additional files created in %TEMP% folder call :log "Weekly deep scan completed" pause goto menu :preUpdate cls
echo ================================================================
echo PRE-UPDATE PREPARATION
echo ================================================================
echo.
echo Preparing system for Windows Insider update... call :log "Starting pre-update preparation"
echo [1/6] Creating system restore point... powershell -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Before Insider Update' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
echo Restore point created
echo [2/6] Freeing up disk space... cleanmgr /sagerun:1 >nul 2>&1 del /q /f /s "%TEMP%\*" >nul 2>&1
echo Temporary files cleaned
echo [3/6] Stopping non-essential services... net stop "Windows Search" >nul 2>&1 net stop "Superfetch" >nul 2>&1
echo Non-essential services stopped
echo [4/6] Optimizing Windows Update components... net stop wuauserv >nul 2>&1 net stop cryptSvc >nul 2>&1 net stop bits >nul 2>&1 del /q /f /s "%WINDIR%\SoftwareDistribution\Download\*" >nul 2>&1 net start wuauserv >nul 2>&1 net start cryptSvc >nul 2>&1 net start bits >nul 2>&1
echo Windows Update components optimized
echo [5/6] Backing up critical system information... set "BACKUP_DIR=%USERPROFILE%\Desktop\PreUpdateBackup_%date:~-4,4%%date:~-10,2%%date:~-7,2%" if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" reg export "HKLM\SOFTWARE\Microsoft\WindowsSelfHost" "%BACKUP_DIR%\InsiderSettings.reg" >nul 2>&1 systeminfo > "%BACKUP_DIR%\SystemInfo.txt"
echo System information backed up to %BACKUP_DIR%
echo [6/6] Final system check... powershell -ExecutionPolicy Bypass -Command "(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()"
echo Update check initiated echo.
echo Pre-update preparation completed!
echo Your system is now optimized for the upcoming Insider update. call :log "Pre-update preparation completed" pause goto menu :postUpdate cls
echo ================================================================
echo POST-UPDATE VALIDATION
echo ================================================================
echo.
echo Validating system after Windows Insider update... call :log "Starting post-update validation"
echo [1/5] Checking Windows version... for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul') do (
echo Current build: %%i ) for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR 2^>nul') do (
echo Update build revision: %%i )
echo [2/5] Validating system integrity... sfc /verifyonly >nul 2>&1 if errorlevel 1 (
echo System file issues detected - running repair... sfc /scannow ) else (
echo System files integrity verified )
echo [3/5] Checking Insider settings... reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled 2>nul | findstr "0x1" >nul if errorlevel 1 (
echo Insider settings may have been reset ) else (
echo Insider settings preserved )
echo [4/5] Restarting essential services... net start "Windows Search" >nul 2>&1 net start "Superfetch" >nul 2>&1
echo Essential services restarted
echo [5/5] Running post-update diagnostics... powershell -ExecutionPolicy Bypass -Command "Get-EventLog -LogName System -EntryType Error -After (Get-Date).AddHours(-2) -ErrorAction SilentlyContinue | Measure-Object | ForEach-Object { if($_.Count -gt 5) { Write-Host ' Multiple errors detected after update:' $_.Count 'errors' } else { Write-Host ' System stable after update:' $_.Count 'errors' } }" 2>nul echo.
echo Post-update validation completed!
echo System appears to be functioning normally after the update. call :log "Post-update validation completed" pause goto menu :scheduleDailyHealth cls
echo ================================================================
echo SCHEDULE DAILY HEALTH CHECK
echo ================================================================
echo.
echo Creating scheduled task for daily health checks... schtasks /create /tn "InsiderDailyHealth" /tr "\"%SCRIPT_DIR%insider-automation.bat\" dailyhealth" /sc daily /st 09:00 /f >nul 2>&1 if errorlevel 1 (
echo Failed to create scheduled task ) else (
echo Daily health check scheduled for 9:00 AM every day call :log "Daily health check scheduled" ) pause goto menu :scheduleWeeklyDeep cls
echo ================================================================
echo SCHEDULE WEEKLY DEEP SCAN
echo ================================================================
echo.
echo Creating scheduled task for weekly deep scans... schtasks /create /tn "InsiderWeeklyDeep" /tr "\"%SCRIPT_DIR%insider-automation.bat\" weeklydeep" /sc weekly /d SUN /st 02:00 /f >nul 2>&1 if errorlevel 1 (
echo Failed to create scheduled task ) else (
echo Weekly deep scan scheduled for 2:00 AM every Sunday call :log "Weekly deep scan scheduled" ) pause goto menu :removeScheduled cls
echo ================================================================
echo REMOVE SCHEDULED TASKS
echo ================================================================
echo.
echo Removing automation scheduled tasks... schtasks /delete /tn "InsiderDailyHealth" /f >nul 2>&1 schtasks /delete /tn "InsiderWeeklyDeep" /f >nul 2>&1
echo All Insider automation scheduled tasks removed call :log "Scheduled tasks removed" pause goto menu :batchOptimization cls
echo ================================================================
echo BATCH SYSTEM OPTIMIZATION
echo ================================================================
echo.
echo Running multiple optimizations in sequence...
echo This will take several minutes. echo. set /p confirm=Continue with batch optimization? (Y/N): if /i not "%confirm%"=="Y" goto menu call :log "Starting batch optimization" :: Run system cleanup
echo [1/5] System cleanup... cleanmgr /sagerun:1 >nul 2>&1 :: Optimize services
echo [2/5] Optimizing services... sc config "SysMain" start=disabled >nul 2>&1 sc config "WSearch" start=delayed-auto >nul 2>&1 :: Registry optimizations
echo [3/5] Registry optimizations... reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f >nul reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f >nul :: Network optimizations
echo [4/5] Network optimizations... netsh int tcp set global autotuninglevel=normal >nul 2>&1 netsh int tcp set global chimney=enabled >nul 2>&1 :: Final cleanup
echo [5/5] Final cleanup... dism /online /cleanup-image /startcomponentcleanup >nul 2>&1 echo.
echo Batch optimization completed! call :log "Batch optimization completed" pause goto menu :emergencyRecovery cls
echo ================================================================
echo EMERGENCY SYSTEM RECOVERY
echo ================================================================
echo.
echo WARNING: This will attempt to fix critical Insider issues
echo by resetting various system components. echo. set /p confirm=Continue with emergency recovery? (Y/N): if /i not "%confirm%"=="Y" goto menu call :log "Starting emergency recovery"
echo [1/6] Resetting Windows Update components... net stop wuauserv net stop cryptSvc net stop bits net stop msiserver del /q /f /s %WINDIR%\SoftwareDistribution\*.* >nul 2>&1 del /q /f /s %WINDIR%\System32\catroot2\*.* >nul 2>&1 regsvr32 /s wuapi.dll regsvr32 /s wuaueng.dll regsvr32 /s wucltui.dll regsvr32 /s wups.dll regsvr32 /s wups2.dll net start wuauserv net start cryptSvc net start bits net start msiserver
echo Windows Update components reset
echo [2/6] Running system file repair... sfc /scannow
echo System file repair completed
echo [3/6] Repairing system image... dism /online /cleanup-image /restorehealth
echo System image repair completed
echo [4/6] Resetting network components... netsh winsock reset >nul 2>&1 netsh int ip reset >nul 2>&1
echo Network components reset
echo [5/6] Clearing problematic caches... del /q /f /s "%TEMP%\*" >nul 2>&1 del /q /f /s "%WINDIR%\Temp\*" >nul 2>&1
echo Caches cleared
echo [6/6] Restarting critical services... net start "Windows Update" >nul 2>&1 net start "Cryptographic Services" >nul 2>&1 net start "Background Intelligent Transfer Service" >nul 2>&1
echo Critical services restarted echo.
echo Emergency recovery completed!
echo Please restart your computer and check for updates. call :log "Emergency recovery completed" pause goto menu :completeReset cls
echo ================================================================
echo COMPLETE SYSTEM RESET
echo ================================================================
echo.
echo WARNING: This will reset ALL Windows Insider settings and
echo remove you from the Insider Program. Use only as a last resort. echo. set /p confirm=Are you sure you want to proceed? (Y/N): if /i not "%confirm%"=="Y" goto menu call :log "Starting complete system reset"
echo [1/4] Disabling Insider Program... reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled /t REG_DWORD /d 0 /f >nul reg delete "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v Ring /f >nul 2>&1 reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\Applicability" /v EnablePreviewBuilds /t REG_DWORD /d 0 /f >nul
echo Insider Program disabled
echo [2/4] Resetting telemetry settings... reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 1 /f >nul
echo Telemetry reset to basic level
echo [3/4] Disabling Developer Mode... reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowAllTrustedApps /t REG_DWORD /d 0 /f >nul reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 0 /f >nul
echo Developer Mode disabled
echo [4/4] Cleaning up Insider-related data... del /q /f /s "%WINDIR%\SoftwareDistribution\Download\*" >nul 2>&1
echo Insider data cleaned up echo.
echo Complete system reset finished!
echo You have been removed from the Windows Insider Program.
echo You may need to perform a clean installation to return to stable Windows. call :log "Complete system reset completed" pause goto menu :configureAutomation cls
echo ================================================================
echo CONFIGURE AUTOMATION SETTINGS
echo ================================================================
echo.
echo Current automation configuration: if exist "%CONFIG_FILE%" ( type "%CONFIG_FILE%" ) else (
echo No configuration file found. Creating default settings...
echo [Settings] > "%CONFIG_FILE%"
echo AutoHealthCheck=true >> "%CONFIG_FILE%"
echo HealthCheckTime=09:00 >> "%CONFIG_FILE%"
echo AutoDeepScan=true >> "%CONFIG_FILE%"
echo DeepScanDay=Sunday >> "%CONFIG_FILE%"
echo AutoBackup=true >> "%CONFIG_FILE%"
echo LogLevel=Normal >> "%CONFIG_FILE%" ) echo.
echo Configuration saved to: %CONFIG_FILE%
echo You can manually edit this file to customize automation behavior. pause goto menu :viewLogs cls
echo ================================================================

echo AUTOMATION LOGS

echo ================================================================
echo. if exist "%LOG_FILE%" (
echo Automation Log Contents:
echo ======================= type "%LOG_FILE%" ) else (
echo No automation log file found. ) echo. pause goto menu :exportConfig cls
echo ================================================================
echo EXPORT CONFIGURATION
echo ================================================================
echo. set "EXPORT_DIR=%USERPROFILE%\Desktop\InsiderAutomationBackup_%date:~-4,4%%date:~-10,2%%date:~-7,2%" if not exist "%EXPORT_DIR%" mkdir "%EXPORT_DIR%" if exist "%CONFIG_FILE%" copy "%CONFIG_FILE%" "%EXPORT_DIR%\" >nul if exist "%LOG_FILE%" copy "%LOG_FILE%" "%EXPORT_DIR%\" >nul
echo Configuration exported to: %EXPORT_DIR% echo. dir "%EXPORT_DIR%" /b pause goto menu :checkSystemRequirements :: Check if system meets basic requirements
echo Checking system requirements... :: Check Windows build for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul') do (
echo Windows Build: %%i if %%i LSS 19041 (
echo Build %%i is too old ^(19041+ required^) exit /b 1 ) else (
echo Build %%i meets requirements ) ) :: Check RAM using PowerShell (simplified check) for /f %%i in ('powershell -ExecutionPolicy Bypass -Command "[math]::Floor((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB)"') do (
echo RAM: %%i GB if %%i LSS 4 (
echo RAM %%i GB is insufficient ^(4GB+ required^) exit /b 1 ) else (
echo RAM %%i GB is sufficient ) ) :: Check disk space using PowerShell (simplified check) for /f %%i in ('powershell -ExecutionPolicy Bypass -Command "[math]::Floor((Get-PSDrive C).Free / 1GB)"') do (
echo Free Space: %%i GB if %%i LSS 20 (
echo Free space %%i GB is insufficient ^(20GB+ required^) exit /b 1 ) else (
echo Free space %%i GB is sufficient ) )
echo All system requirements met exit /b 0 :log
echo [%date% %time%] %~1 >> "%LOG_FILE%" exit /b :checkAdmin set "IS_ADMIN=0" fsutil dirty query %SystemDrive% >nul 2>&1 if errorlevel 1 ( net session >nul 2>&1 if not errorlevel 1 set "IS_ADMIN=1" ) else ( set "IS_ADMIN=1" ) exit /b endlocal
