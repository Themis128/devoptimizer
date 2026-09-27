@echo off

@
echo off setlocal EnableExtensions EnableDelayedExpansion title Windows Insider Channel Manager color 0B :: Check for admin privileges call :checkAdmin if not "%IS_ADMIN%"=="1" (
echo This tool requires Administrator privileges.
echo Right-click and select "Run as administrator" pause exit /b 1 ) :menu cls
echo ================================================================
echo WINDOWS INSIDER CHANNEL MANAGER v1.0
echo ================================================================
echo.
echo Current Windows Version: for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DisplayVersion 2^>nul') do
echo %%i
echo.
echo Insider Channel Management:
echo 1) Check Current Insider Settings
echo 2) Switch to Dev Channel (Latest builds)
echo 3) Switch to Beta Channel (More stable)
echo 4) Switch to Release Preview (Most stable)
echo 5) Leave Insider Program (Stable release) echo.
echo Insider Tools:
echo 6) Force Check for Updates
echo 7) View Insider Build History
echo 8) Reset Windows Update Components echo.
echo 0) Exit echo. set /p choice=Enter your choice (0-8): if "%choice%"=="1" goto checkSettings if "%choice%"=="2" goto devChannel if "%choice%"=="3" goto betaChannel if "%choice%"=="4" goto releasePreview if "%choice%"=="5" goto leaveProgram if "%choice%"=="6" goto forceUpdate if "%choice%"=="7" goto buildHistory if "%choice%"=="8" goto resetWU if "%choice%"=="0" exit /b 0
echo Invalid choice. Please try again. timeout /t 2 >nul goto menu :checkSettings cls
echo ================================================================
echo CURRENT INSIDER SETTINGS
echo ================================================================
echo.
echo Checking Windows Insider settings... echo. :: Check Insider ring reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v Ring 2>nul if errorlevel 1 (
echo Status: Not enrolled in Windows Insider Program ) else ( for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v Ring 2^>nul') do ( if "%%i"=="2"
echo Current Channel: Dev Channel if "%%i"=="4"
echo Current Channel: Beta Channel if "%%i"=="8"
echo Current Channel: Release Preview Channel ) ) :: Check flighting reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled 2>nul if not errorlevel 1 ( for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled 2^>nul') do ( if "%%i"=="0x1"
echo Flighting: Enabled if "%%i"=="0x0"
echo Flighting: Disabled ) ) echo.
echo Windows Update Service Status: sc query wuauserv | findstr "STATE" echo. pause goto menu :devChannel cls
echo ================================================================
echo SWITCHING TO DEV CHANNEL
echo ================================================================
echo.
echo WARNING: Dev Channel receives the earliest builds with latest features
echo but may have stability issues and bugs. echo. set /p confirm=Continue? (Y/N): if /i not "%confirm%"=="Y" goto menu echo.
echo Configuring Dev Channel... reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v Ring /t REG_DWORD /d 2 /f >nul reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled /t REG_DWORD /d 1 /f >nul reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\Applicability" /v EnablePreviewBuilds /t REG_DWORD /d 2 /f >nul if errorlevel 1 (
echo Failed to configure Dev Channel settings. ) else (
echo Successfully configured Dev Channel.
echo Please restart your computer and check for updates. ) echo. pause goto menu :betaChannel cls
echo ================================================================
echo SWITCHING TO BETA CHANNEL
echo ================================================================
echo.
echo Beta Channel provides more stable builds with validated features. echo. set /p confirm=Continue? (Y/N): if /i not "%confirm%"=="Y" goto menu echo.
echo Configuring Beta Channel... reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v Ring /t REG_DWORD /d 4 /f >nul reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled /t REG_DWORD /d 1 /f >nul reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\Applicability" /v EnablePreviewBuilds /t REG_DWORD /d 4 /f >nul if errorlevel 1 (
echo Failed to configure Beta Channel settings. ) else (
echo Successfully configured Beta Channel.
echo Please restart your computer and check for updates. ) echo. pause goto menu :releasePreview cls
echo ================================================================
echo SWITCHING TO RELEASE PREVIEW CHANNEL
echo ================================================================
echo.
echo Release Preview provides the most stable preview builds. echo. set /p confirm=Continue? (Y/N): if /i not "%confirm%"=="Y" goto menu echo.
echo Configuring Release Preview Channel... reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v Ring /t REG_DWORD /d 8 /f >nul reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled /t REG_DWORD /d 1 /f >nul reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\Applicability" /v EnablePreviewBuilds /t REG_DWORD /d 8 /f >nul if errorlevel 1 (
echo Failed to configure Release Preview Channel settings. ) else (
echo Successfully configured Release Preview Channel.
echo Please restart your computer and check for updates. ) echo. pause goto menu :leaveProgram cls
echo ================================================================
echo LEAVE INSIDER PROGRAM
echo ================================================================
echo.
echo WARNING: This will stop receiving Insider builds.
echo You may need to clean install Windows to return to stable release. echo. set /p confirm=Are you sure? (Y/N): if /i not "%confirm%"=="Y" goto menu echo.
echo Disabling Insider Program... reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v IsFlightingEnabled /t REG_DWORD /d 0 /f >nul reg delete "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection" /v Ring /f >nul 2>nul reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\Applicability" /v EnablePreviewBuilds /t REG_DWORD /d 0 /f >nul
echo Insider Program disabled.
echo You may need to perform a clean installation to return to stable Windows. echo. pause goto menu :forceUpdate cls
echo ================================================================
echo FORCE CHECK FOR UPDATES
echo ================================================================
echo.
echo Stopping Windows Update service... net stop wuauserv >nul 2>&1 net stop cryptSvc >nul 2>&1 net stop bits >nul 2>&1 net stop msiserver >nul 2>&1
echo Clearing update cache... del /q /f /s %WINDIR%\SoftwareDistribution\Download\*.* >nul 2>&1
echo Starting Windows Update service... net start wuauserv >nul 2>&1 net start cryptSvc >nul 2>&1 net start bits >nul 2>&1 net start msiserver >nul 2>&1 echo.
echo Forcing update check... powershell -ExecutionPolicy Bypass -Command "& {(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()}" echo.
echo Update check initiated. Please check Windows Update in Settings. pause goto menu :buildHistory cls
echo ================================================================
echo INSIDER BUILD HISTORY
echo ================================================================
echo.
echo Recent Windows builds on this system: echo. :: Check registry for build history for /f "skip=1 tokens=1,2,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" 2^>nul') do ( if "%%a"=="CurrentBuild"
echo Current Build: %%c if "%%a"=="CurrentBuildNumber"
echo Build Number: %%c if "%%a"=="DisplayVersion"
echo Version: %%c if "%%a"=="ReleaseId"
echo Release ID: %%c if "%%a"=="UBR"
echo Update Build Revision: %%c ) echo.
echo For complete build history, check:
echo - Windows Update history in Settings
echo - Event Viewer ^> Windows Logs ^> Setup echo. pause goto menu :resetWU cls
echo ================================================================
echo RESET WINDOWS UPDATE COMPONENTS
echo ================================================================
echo.
echo This will reset all Windows Update components. echo. set /p confirm=Continue? (Y/N): if /i not "%confirm%"=="Y" goto menu echo.
echo Resetting Windows Update components... :: Stop services
echo Stopping services... net stop wuauserv net stop cryptSvc net stop bits net stop msiserver :: Delete temp files
echo Clearing temporary files... del /q /f /s %WINDIR%\SoftwareDistribution\*.* >nul 2>&1 del /q /f /s %WINDIR%\System32\catroot2\*.* >nul 2>&1 :: Re-register DLLs
echo Re-registering Windows Update DLLs... regsvr32 /s wuapi.dll regsvr32 /s wuaueng.dll regsvr32 /s wuaueng1.dll regsvr32 /s wucltui.dll regsvr32 /s wups.dll regsvr32 /s wups2.dll :: Restart services
echo Starting services... net start wuauserv net start cryptSvc net start bits net start msiserver echo.
echo Windows Update components reset successfully.
echo Please restart your computer and check for updates. pause goto menu :checkAdmin set "IS_ADMIN=0" fsutil dirty query %SystemDrive% >nul 2>&1 if errorlevel 1 ( net session >nul 2>&1 if not errorlevel 1 set "IS_ADMIN=1" ) else ( set "IS_ADMIN=1" ) exit /b endlocal
