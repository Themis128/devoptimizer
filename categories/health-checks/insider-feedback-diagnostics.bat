@echo off

@
echo off setlocal EnableExtensions EnableDelayedExpansion title Windows Insider Feedback & Diagnostics color 0E :: Check for admin privileges call :checkAdmin if not "%IS_ADMIN%"=="1" (
echo This tool requires Administrator privileges.
echo Right-click and select "Run as administrator" pause exit /b 1 ) :menu cls
echo ================================================================
echo WINDOWS INSIDER FEEDBACK ^& DIAGNOSTICS v1.0
echo ================================================================
echo.
echo Feedback Tools:
echo 1) Open Feedback Hub
echo 2) Generate System Diagnostics Report
echo 3) Collect Insider Build Information
echo 4) Export Event Logs for Feedback echo.
echo Diagnostics:
echo 5) Check Insider Program Status
echo 6) Validate System Files (SFC/DISM)
echo 7) Generate Hardware Compatibility Report
echo 8) Check Windows Feature Experience Pack echo.
echo Telemetry ^& Privacy:
echo 9) Configure Diagnostic Data Level
echo 10) View Diagnostic Data Viewer
echo 11) Clear Diagnostic Data Cache echo.
echo 0) Exit echo. set /p choice=Enter your choice (0-11): if "%choice%"=="1" goto feedbackHub if "%choice%"=="2" goto systemDiagnostics if "%choice%"=="3" goto buildInfo if "%choice%"=="4" goto exportLogs if "%choice%"=="5" goto insiderStatus if "%choice%"=="6" goto validateSystem if "%choice%"=="7" goto hardwareReport if "%choice%"=="8" goto featureExperience if "%choice%"=="9" goto diagnosticLevel if "%choice%"=="10" goto diagnosticViewer if "%choice%"=="11" goto clearDiagnostics if "%choice%"=="0" exit /b 0
echo Invalid choice. Please try again. timeout /t 2 >nul goto menu :feedbackHub cls
echo ================================================================
echo FEEDBACK HUB
echo ================================================================
echo.
echo Opening Feedback Hub... start ms-windows-store://pdp/?productid=9nblggh4r32n timeout /t 2 >nul echo.
echo Feedback Hub opened. Use it to:
echo - Report bugs and issues
echo - Suggest new features
echo - Upvote existing feedback
echo - Share diagnostic data with Microsoft echo. pause goto menu :systemDiagnostics cls
echo ================================================================
echo SYSTEM DIAGNOSTICS REPORT
echo ================================================================
echo. set "REPORT_DIR=%USERPROFILE%\Desktop\InsiderDiagnostics" if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"
echo Generating comprehensive diagnostics report...
echo Report will be saved to: %REPORT_DIR% echo. :: System Information
echo Collecting system information... systeminfo > "%REPORT_DIR%\systeminfo.txt" msinfo32 /report "%REPORT_DIR%\msinfo32.txt" /categories +all :: Hardware Information
echo Collecting hardware information... wmic computersystem get * /format:list > "%REPORT_DIR%\hardware.txt" wmic cpu get * /format:list >> "%REPORT_DIR%\hardware.txt" wmic memorychip get * /format:list >> "%REPORT_DIR%\hardware.txt" :: Driver Information
echo Collecting driver information... driverquery /v > "%REPORT_DIR%\drivers.txt" :: Windows Version Details
echo Collecting Windows version details... ver > "%REPORT_DIR%\version.txt" reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" >> "%REPORT_DIR%\version.txt" :: Installed Programs
echo Collecting installed programs... wmic product get name,version,vendor /format:csv > "%REPORT_DIR%\installed_programs.csv" :: Services Status
echo Collecting services status... sc query type=service state=all > "%REPORT_DIR%\services.txt" :: Network Configuration
echo Collecting network configuration... ipconfig /all > "%REPORT_DIR%\network.txt" netsh wlan show profiles >> "%REPORT_DIR%\network.txt" echo.
echo Diagnostics report generated successfully!
echo Location: %REPORT_DIR% echo.
echo You can attach these files when submitting feedback to Microsoft. pause goto menu :buildInfo cls
echo ================================================================
echo INSIDER BUILD INFORMATION
echo ================================================================
echo. set "BUILD_FILE=%USERPROFILE%\Desktop\InsiderBuildInfo.txt"
echo Collecting Insider build information...
echo Build Information Report > "%BUILD_FILE%"
echo Generated: %date% %time% >> "%BUILD_FILE%"
echo ================================== >> "%BUILD_FILE%" echo. >> "%BUILD_FILE%" :: Windows Version Information
echo Windows Version Information: >> "%BUILD_FILE%" for /f "skip=1 tokens=1,2,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" 2^>nul') do (
echo %%a: %%c >> "%BUILD_FILE%" ) echo. >> "%BUILD_FILE%" :: Insider Settings
echo Insider Program Settings: >> "%BUILD_FILE%" reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" >> "%BUILD_FILE%" 2>nul echo. >> "%BUILD_FILE%" :: Feature Experience Pack
echo Windows Feature Experience Pack: >> "%BUILD_FILE%" reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR >> "%BUILD_FILE%" 2>nul echo. >> "%BUILD_FILE%" :: System Specs
echo System Specifications: >> "%BUILD_FILE%" wmic computersystem get TotalPhysicalMemory,SystemType,Manufacturer,Model /format:list >> "%BUILD_FILE%" wmic cpu get Name,NumberOfCores,NumberOfLogicalProcessors /format:list >> "%BUILD_FILE%" echo. >> "%BUILD_FILE%" type "%BUILD_FILE%" echo.
echo Build information saved to: %BUILD_FILE% pause goto menu :exportLogs cls
echo ================================================================
echo EXPORT EVENT LOGS
echo ================================================================
echo. set "LOGS_DIR=%USERPROFILE%\Desktop\InsiderLogs" if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
echo Exporting relevant event logs for feedback...
echo Logs will be saved to: %LOGS_DIR% echo. :: Export System Log
echo Exporting System log... wevtutil epl System "%LOGS_DIR%\System.evtx" :: Export Application Log
echo Exporting Application log... wevtutil epl Application "%LOGS_DIR%\Application.evtx" :: Export Setup Log
echo Exporting Setup log... wevtutil epl Setup "%LOGS_DIR%\Setup.evtx" :: Export Windows Update Log
echo Exporting Windows Update log... wevtutil epl "Microsoft-Windows-WindowsUpdateClient/Operational" "%LOGS_DIR%\WindowsUpdate.evtx" 2>nul :: Export BSOD/Reliability logs
echo Exporting Reliability logs... wevtutil epl "Microsoft-Windows-Kernel-Power/Thermal-Operational" "%LOGS_DIR%\ThermalEvents.evtx" 2>nul wevtutil epl "Microsoft-Windows-WER-SystemErrorReporting/Operational" "%LOGS_DIR%\ErrorReporting.evtx" 2>nul echo.
echo Event logs exported successfully!
echo Location: %LOGS_DIR%
echo These can be attached to Feedback Hub reports. pause goto menu :insiderStatus cls
echo ================================================================
echo INSIDER PROGRAM STATUS
echo ================================================================
echo. :: Check Windows version
echo Current Windows Version: for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DisplayVersion 2^>nul') do
echo Version: %%i for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul') do
echo Build: %%i for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR 2^>nul') do
echo Revision: %%i echo. :: Check Insider enrollment
echo Insider Program Status: reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled 2>nul >nul if errorlevel 1 (
echo Status: Not enrolled in Windows Insider Program ) else ( for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled 2^>nul') do ( if "%%i"=="0x1" (
echo Status: Enrolled in Windows Insider Program for /f "tokens=3" %%j in ('reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v Ring 2^>nul') do ( if "%%j"=="2"
echo Channel: Dev Channel if "%%j"=="4"
echo Channel: Beta Channel if "%%j"=="8"
echo Channel: Release Preview Channel ) ) else (
echo Status: Enrolled but flighting disabled ) ) ) echo. :: Check Windows Update service
echo Windows Update Service: sc query wuauserv | findstr "STATE" | findstr "RUNNING" >nul if errorlevel 1 (
echo Status: Not running ) else (
echo Status: Running )
echo. :: Check last update check
echo Last Update Check: reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Detect" /v LastSuccessTime 2>nul echo. pause goto menu :validateSystem cls
echo ================================================================
echo VALIDATE SYSTEM FILES
echo ================================================================
echo.
echo This will run System File Checker and DISM to validate system integrity.
echo This process may take several minutes. echo. set /p confirm=Continue? (Y/N): if /i not "%confirm%"=="Y" goto menu echo.
echo Running System File Checker (SFC)... sfc /scannow echo.
echo Running DISM Health Check... dism /online /cleanup-image /checkhealth echo.
echo Running DISM Scan Health... dism /online /cleanup-image /scanhealth echo.
echo Running DISM Restore Health... dism /online /cleanup-image /restorehealth echo.
echo System validation completed.
echo Check the output above for any issues found. pause goto menu :hardwareReport cls
echo ================================================================
echo HARDWARE COMPATIBILITY REPORT
echo ================================================================
echo. set "HW_REPORT=%USERPROFILE%\Desktop\HardwareCompatibility.txt"
echo Generating hardware compatibility report...
echo Hardware Compatibility Report > "%HW_REPORT%"
echo Generated: %date% %time% >> "%HW_REPORT%"
echo ================================ >> "%HW_REPORT%" echo. >> "%HW_REPORT%" :: CPU Information
echo CPU Information: >> "%HW_REPORT%" wmic cpu get Name,Manufacturer,Family,Model,Stepping,MaxClockSpeed /format:list >> "%HW_REPORT%" echo. >> "%HW_REPORT%" :: Memory Information
echo Memory Information: >> "%HW_REPORT%" wmic computersystem get TotalPhysicalMemory /format:list >> "%HW_REPORT%" wmic memorychip get Speed,Capacity,MemoryType /format:list >> "%HW_REPORT%" echo. >> "%HW_REPORT%" :: Storage Information
echo Storage Information: >> "%HW_REPORT%" wmic diskdrive get Size,Model,InterfaceType /format:list >> "%HW_REPORT%" echo. >> "%HW_REPORT%" :: Graphics Information
echo Graphics Information: >> "%HW_REPORT%" wmic path win32_VideoController get Name,DriverVersion,VideoMemoryType /format:list >> "%HW_REPORT%" echo. >> "%HW_REPORT%" :: TPM Information
echo TPM Information: >> "%HW_REPORT%" wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get * /format:list >> "%HW_REPORT%" 2>nul echo. >> "%HW_REPORT%" :: UEFI/Secure Boot
echo UEFI/Secure Boot Information: >> "%HW_REPORT%" bcdedit /enum {current} | findstr "path" >> "%HW_REPORT%" powershell -ExecutionPolicy Bypass -Command "Confirm-SecureBootUEFI" >> "%HW_REPORT%" 2>nul echo.
echo Hardware compatibility report generated!
echo Location: %HW_REPORT% type "%HW_REPORT%" echo. pause goto menu :featureExperience cls
echo ================================================================
echo WINDOWS FEATURE EXPERIENCE PACK
echo ================================================================
echo.
echo Checking Windows Feature Experience Pack information... echo. :: Check Feature Experience Pack version reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DisplayVersion 2>nul reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR 2>nul echo.
echo Feature Experience Pack provides updates to Windows features
echo independently of major OS updates. echo.
echo To check for Feature Experience Pack updates:
echo 1. Open Settings ^> Windows Update
echo 2. Look for "Feature Experience Pack" updates
echo 3. Install any available updates echo. pause goto menu :diagnosticLevel cls
echo ================================================================
echo CONFIGURE DIAGNOSTIC DATA LEVEL
echo ================================================================
echo.
echo Current diagnostic data setting: for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry 2^>nul') do ( if "%%i"=="0"
echo Level: Security ^(Enterprise only^) if "%%i"=="1"
echo Level: Basic if "%%i"=="2"
echo Level: Enhanced ^(Deprecated^) if "%%i"=="3"
echo Level: Full ) echo.
echo Diagnostic Data Levels:
echo 1) Basic - Minimal data for security and reliability
echo 2) Full - Complete diagnostic data ^(Recommended for Insiders^) echo.
echo 0) Back to main menu echo. set /p level=Choose diagnostic level (0-2): if "%level%"=="0" goto menu if "%level%"=="1" ( reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 1 /f >nul
echo Diagnostic data level set to Basic. ) if "%level%"=="2" ( reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 3 /f >nul
echo Diagnostic data level set to Full. )
echo Please restart your computer for changes to take effect. pause goto menu :diagnosticViewer cls
echo ================================================================
echo DIAGNOSTIC DATA VIEWER
echo ================================================================
echo.
echo Opening Diagnostic Data Viewer... echo.
echo If not installed, it will open Microsoft Store to install it. start ms-windows-store://pdp/?productid=9n8wtrrsq8f7 timeout /t 2 >nul echo.
echo Diagnostic Data Viewer allows you to see what diagnostic
echo data Windows is collecting and sending to Microsoft. echo. pause goto menu :clearDiagnostics cls
echo ================================================================
echo CLEAR DIAGNOSTIC DATA CACHE
echo ================================================================
echo.
echo This will clear local diagnostic data cache files. echo. set /p confirm=Continue? (Y/N): if /i not "%confirm%"=="Y" goto menu echo.
echo Clearing diagnostic data cache... :: Clear Windows Error Reporting
echo Clearing Windows Error Reporting data... del /q /f /s "%ProgramData%\Microsoft\Windows\WER\*" >nul 2>&1 :: Clear telemetry cache
echo Clearing telemetry cache... del /q /f /s "%WINDIR%\System32\LogFiles\WMI\*" >nul 2>&1 :: Clear diagnostic tracking
echo Clearing diagnostic tracking data... del /q /f /s "%WINDIR%\appcompat\Programs\*" >nul 2>&1 :: Clear compatibility telemetry reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TelemetryController" /f >nul 2>&1 echo.
echo Diagnostic data cache cleared.
echo New diagnostic data will be generated as needed. pause goto menu :checkAdmin set "IS_ADMIN=0" fsutil dirty query %SystemDrive% >nul 2>&1 if errorlevel 1 ( net session >nul 2>&1 if not errorlevel 1 set "IS_ADMIN=1" ) else ( set "IS_ADMIN=1" ) exit /b endlocal
