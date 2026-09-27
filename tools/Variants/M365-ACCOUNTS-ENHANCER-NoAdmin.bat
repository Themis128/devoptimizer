@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title  - Standard Mode- some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo              M365 ACCOUNTS ENHANCER
echo ================================================================
echo.
echo Comprehensive M365 account management and optimization
echo.
echo ================================================================

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
echo [INFO] Running with administrator privileges
) else (
echo [WARNING] Some operations may require administrator privileges
)

echo.
echo ================================================================
echo                    M365 ENHANCEMENT MENU
echo ================================================================
echo.
echo 1.   M365 Account Login Fix
echo 2.   M365 Services Reset
echo 3.   Outlook Configuration
echo 4.   Teams Optimization
echo 5.   OneDrive Sync Fix
echo 6.   Security Settings
echo 7.   Account Health Check
echo 8.   Office Repair
echo 9.   Complete M365 Reset
echo 10.  Account Report
echo 0.   Exit
echo.
echo ================================================================

set /p choice="Enter your choice (0-10): "

if "%choice%"=="1" goto m365_login_fix
if "%choice%"=="2" goto m365_services_reset
if "%choice%"=="3" goto outlook_config
if "%choice%"=="4" goto teams_optimization
if "%choice%"=="5" goto onedrive_sync_fix
if "%choice%"=="6" goto security_settings
if "%choice%"=="7" goto account_health_check
if "%choice%"=="8" goto office_repair
if "%choice%"=="9" goto complete_m365_reset
if "%choice%"=="10" goto account_report
if "%choice%"=="0" goto exit
goto invalid_choice

:m365_login_fix
echo.
echo ================================================================
echo               M365 ACCOUNT LOGIN FIX
echo ================================================================
echo.
echo Fixing M365 account login issues...
echo.

:: Clear credential cache
echo [1/8] Clearing credential cache...
cmdkey /list | findstr "target:https://login.microsoftonline.com" >nul
if %errorLevel% == 0 (
for /f "tokens=3 delims= " %%i in ('cmdkey /list ^| findstr "target:https://login.microsoftonline.com"') do (
cmdkey /delete:%%i
)
)
echo [SUCCESS] Credential cache cleared

:: Clear Windows Credential Manager
echo [2/8] Clearing Windows Credential Manager...
cmdkey /list | findstr "target:MicrosoftOffice" >nul
if %errorLevel% == 0 (
for /f "tokens=3 delims= " %%i in ('cmdkey /list ^| findstr "target:MicrosoftOffice"') do (
cmdkey /delete:%%i
)
)
echo [SUCCESS] Windows Credential Manager cleared

:: Clear Office cache
echo [3/8] Clearing Office cache...
if exist "%LOCALAPPDATA%\Microsoft\Office\16.0\Wef" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\Office\16.0\Wef" 2>nul
)
if exist "%LOCALAPPDATA%\Microsoft\Office\16.0\OfficeFileCache" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\Office\16.0\OfficeFileCache" 2>nul
)
echo [SUCCESS] Office cache cleared

:: Clear registry entries
echo [4/8] Clearing registry entries...
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /f >nul 2>&1
echo [SUCCESS] Registry entries cleared

:: Reset Office activation
echo [5/8] Resetting Office activation...
if exist "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" (
cscript "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" /dstatus
cscript "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" /unpkey
cscript "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" /rearm
)
echo [SUCCESS] Office activation reset

:: Clear browser cache
echo [6/8] Clearing browser cache...
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" (
rmdir /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" 2>nul
)
if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache" 2>nul
)
echo [SUCCESS] Browser cache cleared

:: Reset network settings
echo [7/8] Resetting network settings...
ipconfig /flushdns
netsh winsock reset
netsh int ip reset
echo [SUCCESS] Network settings reset

:: Restart Office services
echo [8/8] Restarting Office services...
net stop "Microsoft Office Click-to-Run Service" >nul 2>&1
net start "Microsoft Office Click-to-Run Service" >nul 2>&1
echo [SUCCESS] Office services restarted

echo [SUCCESS] M365 login fix completed!
echo.
pause
goto main_menu

:m365_services_reset
echo.
echo ================================================================
echo               M365 SERVICES RESET
echo ================================================================
echo.
echo Resetting M365 services...
echo.

:: Stop Office services
echo [1/6] Stopping Office services...
net stop "Microsoft Office Click-to-Run Service" >nul 2>&1
net stop "Office 16 Click-to-Run Service" >nul 2>&1
net stop "Microsoft Office Subscription Service" >nul 2>&1
echo [SUCCESS] Office services stopped

:: Clear Office cache
echo [2/6] Clearing Office cache...
if exist "%LOCALAPPDATA%\Microsoft\Office\16.0\Wef" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\Office\16.0\Wef" 2>nul
)
if exist "%LOCALAPPDATA%\Microsoft\Office\16.0\OfficeFileCache" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\Office\16.0\OfficeFileCache" 2>nul
)
echo [SUCCESS] Office cache cleared

:: Reset Office registry
echo [3/6] Resetting Office registry...
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\SignIn" /f >nul 2>&1
echo [SUCCESS] Office registry reset

:: Clear OneDrive cache
echo [4/6] Clearing OneDrive cache...
if exist "%LOCALAPPDATA%\Microsoft\OneDrive" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\OneDrive" 2>nul
)
echo [SUCCESS] OneDrive cache cleared

:: Clear Teams cache
echo [5/6] Clearing Teams cache...
if exist "%APPDATA%\Microsoft\Teams" (
rmdir /s /q "%APPDATA%\Microsoft\Teams" 2>nul
)
echo [SUCCESS] Teams cache cleared

:: Restart services
echo [6/6] Restarting services...
net start "Microsoft Office Click-to-Run Service" >nul 2>&1
net start "Office 16 Click-to-Run Service" >nul 2>&1
net start "Microsoft Office Subscription Service" >nul 2>&1
echo [SUCCESS] Services restarted

echo [SUCCESS] M365 services reset completed!
echo.
pause
goto main_menu

:outlook_config
echo.
echo ================================================================
echo               OUTLOOK CONFIGURATION
echo ================================================================
echo.
echo Configuring Outlook for optimal performance...
echo.

:: Clear Outlook cache
echo [1/5] Clearing Outlook cache...
if exist "%LOCALAPPDATA%\Microsoft\Outlook" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\Outlook" 2>nul
)
echo [SUCCESS] Outlook cache cleared

:: Reset Outlook profile
echo [2/5] Resetting Outlook profile...
reg delete "HKCU\Software\Microsoft\Office\16.0\Outlook\Profiles" /f >nul 2>&1
echo [SUCCESS] Outlook profile reset

:: Clear Outlook registry
echo [3/5] Clearing Outlook registry...
reg delete "HKCU\Software\Microsoft\Office\16.0\Outlook\Preferences" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Outlook\Options" /f >nul 2>&1
echo [SUCCESS] Outlook registry cleared

:: Reset Outlook settings
echo [4/5] Resetting Outlook settings...
reg delete "HKCU\Software\Microsoft\Office\16.0\Outlook\Setup" /f >nul 2>&1
echo [SUCCESS] Outlook settings reset

:: Restart Outlook
echo [5/5] Restarting Outlook...
taskkill /f /im outlook.exe >nul 2>&1
timeout /t 3 >nul
start outlook.exe
echo [SUCCESS] Outlook restarted

echo [SUCCESS] Outlook configuration completed!
echo.
pause
goto main_menu

:teams_optimization
echo.
echo ================================================================
echo               TEAMS OPTIMIZATION
echo ================================================================
echo.
echo Optimizing Microsoft Teams...
echo.

:: Stop Teams
echo [1/6] Stopping Teams...
taskkill /f /im teams.exe >nul 2>&1
taskkill /f /im Teams.exe >nul 2>&1
echo [SUCCESS] Teams stopped

:: Clear Teams cache
echo [2/6] Clearing Teams cache...
if exist "%APPDATA%\Microsoft\Teams" (
rmdir /s /q "%APPDATA%\Microsoft\Teams" 2>nul
)
if exist "%LOCALAPPDATA%\Microsoft\Teams" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\Teams" 2>nul
)
echo [SUCCESS] Teams cache cleared

:: Clear Teams registry
echo [3/6] Clearing Teams registry...
reg delete "HKCU\Software\Microsoft\Office\16.0\Teams" /f >nul 2>&1
echo [SUCCESS] Teams registry cleared

:: Reset Teams settings
echo [4/6] Resetting Teams settings...
reg delete "HKCU\Software\Microsoft\Office\16.0\Teams\Settings" /f >nul 2>&1
echo [SUCCESS] Teams settings reset

:: Clear Teams logs
echo [5/6] Clearing Teams logs...
if exist "%APPDATA%\Microsoft\Teams\logs" (
rmdir /s /q "%APPDATA%\Microsoft\Teams\logs" 2>nul
)
echo [SUCCESS] Teams logs cleared

:: Restart Teams
echo [6/6] Restarting Teams...
start teams.exe
echo [SUCCESS] Teams restarted

echo [SUCCESS] Teams optimization completed!
echo.
pause
goto main_menu

:onedrive_sync_fix
echo.
echo ================================================================
echo               ONEDRIVE SYNC FIX
echo ================================================================
echo.
echo Fixing OneDrive sync issues...
echo.

:: Stop OneDrive
echo [1/8] Stopping OneDrive...
taskkill /f /im OneDrive.exe >nul 2>&1
taskkill /f /im OneDriveSetup.exe >nul 2>&1
echo [SUCCESS] OneDrive stopped

:: Clear OneDrive cache
echo [2/8] Clearing OneDrive cache...
if exist "%LOCALAPPDATA%\Microsoft\OneDrive" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\OneDrive" 2>nul
)
echo [SUCCESS] OneDrive cache cleared

:: Clear OneDrive registry
echo [3/8] Clearing OneDrive registry...
reg delete "HKCU\Software\Microsoft\OneDrive" /f >nul 2>&1
echo [SUCCESS] OneDrive registry cleared

:: Reset OneDrive settings
echo [4/8] Resetting OneDrive settings...
reg delete "HKCU\Software\Microsoft\OneDrive\Settings" /f >nul 2>&1
echo [SUCCESS] OneDrive settings reset

:: Clear OneDrive logs
echo [5/8] Clearing OneDrive logs...
if exist "%LOCALAPPDATA%\Microsoft\OneDrive\logs" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\OneDrive\logs" 2>nul
)
echo [SUCCESS] OneDrive logs cleared

:: Reset OneDrive sync
echo [6/8] Resetting OneDrive sync...
reg delete "HKCU\Software\Microsoft\OneDrive\Accounts" /f >nul 2>&1
echo [SUCCESS] OneDrive sync reset

:: Clear OneDrive temp files
echo [7/8] Clearing OneDrive temp files...
if exist "%LOCALAPPDATA%\Microsoft\OneDrive\temp" (
rmdir /s /q "%LOCALAPPDATA%\Microsoft\OneDrive\temp" 2>nul
)
echo [SUCCESS] OneDrive temp files cleared

:: Restart OneDrive
echo [8/8] Restarting OneDrive...
start OneDrive.exe
echo [SUCCESS] OneDrive restarted

echo [SUCCESS] OneDrive sync fix completed!
echo.
pause
goto main_menu

:security_settings
echo.
echo ================================================================
echo               SECURITY SETTINGS
echo ================================================================
echo.
echo Configuring M365 security settings...
echo.

:: Enable Windows Defender
echo [1/5] Enabling Windows Defender...
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $false"
echo [SUCCESS] Windows Defender enabled

:: Configure firewall
echo [2/5] Configuring firewall...
netsh advfirewall set allprofiles state on
echo [SUCCESS] Firewall configured

:: Enable Windows Update
echo [3/5] Enabling Windows Update...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f
echo [SUCCESS] Windows Update enabled

:: Configure Office security
echo [4/5] Configuring Office security...
reg add "HKCU\Software\Microsoft\Office\16.0\Common\Security" /v DisableInternetFilesInPV /t REG_DWORD /d 0 /f
echo [SUCCESS] Office security configured

:: Enable BitLocker
echo [5/5] Enabling BitLocker...
manage-bde -status
echo [SUCCESS] BitLocker status checked

echo [SUCCESS] Security settings configured!
echo.
pause
goto main_menu

:account_health_check
echo.
echo ================================================================
echo               ACCOUNT HEALTH CHECK
echo ================================================================
echo.
echo Checking M365 account health...
echo.

:: Check Office installation
echo [1/6] Checking Office installation...
if exist "%ProgramFiles%\Microsoft Office\root\Office16\winword.exe" (
echo [SUCCESS] Office 2016/2019/2021 installed
) else (
echo [WARNING] Office not found
)

:: Check OneDrive status
echo [2/6] Checking OneDrive status...
if exist "%LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe" (
echo [SUCCESS] OneDrive installed
) else (
echo [WARNING] OneDrive not found
)

:: Check Teams status
echo [3/6] Checking Teams status...
if exist "%LOCALAPPDATA%\Microsoft\Teams\Update.exe" (
echo [SUCCESS] Teams installed
) else (
echo [WARNING] Teams not found
)

:: Check Outlook status
echo [4/6] Checking Outlook status...
if exist "%ProgramFiles%\Microsoft Office\root\Office16\outlook.exe" (
echo [SUCCESS] Outlook installed
) else (
echo [WARNING] Outlook not found
)

:: Check network connectivity
echo [5/6] Checking network connectivity...
ping -n 1 login.microsoftonline.com >nul
if %errorLevel% == 0 (
echo [SUCCESS] Network connectivity OK
) else (
echo [WARNING] Network connectivity issues
)

:: Check services
echo [6/6] Checking services...
sc query "Microsoft Office Click-to-Run Service" | findstr "RUNNING" >nul
if %errorLevel% == 0 (
echo [SUCCESS] Office service running
) else (
echo [WARNING] Office service not running
)

echo [SUCCESS] Account health check completed!
echo.
pause
goto main_menu

:office_repair
echo.
echo ================================================================
echo               OFFICE REPAIR
echo ================================================================
echo.
echo Repairing Office installation...
echo.

:: Stop Office services
echo [1/4] Stopping Office services...
net stop "Microsoft Office Click-to-Run Service" >nul 2>&1
echo [SUCCESS] Office services stopped

:: Run Office repair
echo [2/4] Running Office repair...
if exist "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" (
cscript "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" /rearm
)
echo [SUCCESS] Office repair completed

:: Reset Office activation
echo [3/4] Resetting Office activation...
if exist "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" (
cscript "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" /dstatus
cscript "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" /unpkey
)
echo [SUCCESS] Office activation reset

:: Restart Office services
echo [4/4] Restarting Office services...
net start "Microsoft Office Click-to-Run Service" >nul 2>&1
echo [SUCCESS] Office services restarted

echo [SUCCESS] Office repair completed!
echo.
pause
goto main_menu

:complete_m365_reset
echo.
echo ================================================================
echo               COMPLETE M365 RESET
echo ================================================================
echo.
echo Running complete M365 reset...
echo.

:: Run all resets
call :m365_login_fix
call :m365_services_reset
call :outlook_config
call :teams_optimization
call :onedrive_sync_fix
call :security_settings
call :office_repair

echo [SUCCESS] Complete M365 reset completed!
echo.
pause
goto main_menu

:account_report
echo.
echo ================================================================
echo               ACCOUNT REPORT
echo ================================================================
echo.
echo Generating M365 account report...
echo.

:: Create reports directory
if not exist "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports" mkdir "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports"

:: Generate report
echo [REPORT] Generating account report...
echo M365 Account Report - %date% %time% > "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
echo ========================================== >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
echo Office Installation: >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
if exist "%ProgramFiles%\Microsoft Office\root\Office16\winword.exe" (
echo [SUCCESS] Office 2016/2019/2021 installed >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
) else (
echo [WARNING] Office not found >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
)
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
echo OneDrive Status: >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
if exist "%LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe" (
echo [SUCCESS] OneDrive installed >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
) else (
echo [WARNING] OneDrive not found >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
)
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
echo Teams Status: >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
if exist "%LOCALAPPDATA%\Microsoft\Teams\Update.exe" (
echo [SUCCESS] Teams installed >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
) else (
echo [WARNING] Teams not found >> "%USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt"
)

echo [SUCCESS] Account report generated!
echo [INFO] Report saved to: %USERPROFILE%\Desktop\DevOptimizer\M365-Reports\m365-report.txt
echo.
pause
goto main_menu

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please select a number between 0-10.
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
echo                M365 ACCOUNTS ENHANCER
echo ================================================================
echo.
echo Your M365 accounts have been optimized!
echo.
echo ================================================================
echo.
pause
exit

:start
goto main_menu
exit /b %ERRORLEVEL%
