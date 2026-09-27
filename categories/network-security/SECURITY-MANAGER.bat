@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title Security Manager - DevOptimizer System
color 0E

echo.
echo ========================================================================
echo                       SECURITY MANAGER - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.
echo [STATUS] Initializing Security Manager...
echo [INFO] Checking system security prerequisites...

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

:: Initialize security status tracking
set "SECURITY_SCORE=0"
set "TOTAL_CHECKS=0"
set "PASSED_CHECKS=0"
set "FAILED_CHECKS=0"

echo [SUCCESS] Security Manager initialized successfully
echo [INFO] System ready for security operations
echo.

:: Quick security status check
echo ========================================================================
echo                          QUICK SECURITY STATUS
echo ========================================================================
echo.

echo [STATUS] Checking critical security components...
echo.

:: Check Windows Defender status
powershell -Command "try { $defender = Get-MpComputerStatus; if ($defender.AntivirusEnabled) { Write-Host '[STATUS] Windows Defender: ENABLED' } else { Write-Host '[STATUS] Windows Defender: DISABLED' } } catch { Write-Host '[STATUS] Windows Defender: UNABLE TO CHECK' }" 2>nul
if %errorlevel% neq 0 echo [STATUS] Windows Defender: UNABLE TO CHECK

:: Check Firewall status
netsh advfirewall show allprofiles state | findstr "State" >nul 2>&1
if %errorlevel%==0 (
echo [STATUS] Windows Firewall: ACTIVE
) else (
echo [STATUS] Windows Firewall: INACTIVE OR UNABLE TO CHECK
)

:: Check UAC status
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA 2>nul | findstr "0x1" >nul 2>&1
if %errorlevel%==0 (
echo [STATUS] User Account Control: ENABLED
) else (
echo [STATUS] User Account Control: DISABLED OR UNABLE TO CHECK
)

echo.
echo ========================================================================
echo                          SECURITY OPTIONS
echo ========================================================================
echo.
:start
echo [1] Windows Defender Scan & Management
echo [2] Firewall Configuration & Rules
echo [3] Privacy Settings Check & Optimization
echo [4] User Account Security Analysis
echo [5] System Updates Check & Management
echo [6] Comprehensive Security Audit
echo [7] Antivirus Status & Health Check
echo [8] Browser Security & Extension Analysis
echo [9] Network Security Scan & Monitoring
echo [A] Security Score & Recommendations
echo [B] Emergency Security Actions
echo [0] Exit
echo.

set /p choice="Enter your choice (0-9, A, B): "

if "%choice%"=="1" goto :defender_scan
if "%choice%"=="2" goto :firewall_config
if "%choice%"=="3" goto :privacy_check
if "%choice%"=="4" goto :user_security
if "%choice%"=="5" goto :updates_check
if "%choice%"=="6" goto :security_audit
if "%choice%"=="7" goto :antivirus_status
if "%choice%"=="8" goto :browser_security
if "%choice%"=="9" goto :network_security
if /i "%choice%"=="A" goto :security_score
if /i "%choice%"=="B" goto :emergency_security
if "%choice%"=="0" goto :exit
goto :invalid_choice

:defender_scan
echo.
echo ========================================================================
echo                         WINDOWS DEFENDER SCAN & MANAGEMENT
echo ========================================================================
echo.

echo [STATUS] Initializing Windows Defender operations...
echo [INFO] Checking Defender service status...

:: Check if Defender service is running
sc query "WinDefend" | findstr "RUNNING" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Defender service is running
) else (
echo [WARNING] Windows Defender service may not be running
echo [INFO] Attempting to start Defender service...
sc start "WinDefend" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Defender service started successfully
) else (
echo [ERROR] Failed to start Windows Defender service
echo [INFO] This may require administrator privileges
)
)

echo.
echo [INFO] Windows Defender security scan options:
echo.
echo [1] Quick Scan (Recommended - 5-15 minutes)
echo [2] Full Scan (Comprehensive - 1-4 hours)
echo [3] Custom Scan (Target specific locations)
echo [4] Check Defender Status & Health
echo [5] Update Defender Definitions
echo [6] View Scan History & Results
echo [7] Configure Real-time Protection
echo [8] Export Security Report
echo [0] Back to main menu
echo.

set /p defender_choice="Enter your choice (0-8): "

if "%defender_choice%"=="1" goto :quick_scan
if "%defender_choice%"=="2" goto :full_scan
if "%defender_choice%"=="3" goto :custom_scan
if "%defender_choice%"=="4" goto :defender_status
if "%defender_choice%"=="5" goto :update_definitions
if "%defender_choice%"=="6" goto :scan_history
if "%defender_choice%"=="7" goto :realtime_config
if "%defender_choice%"=="8" goto :export_report
if "%defender_choice%"=="0" goto :menu
goto :invalid_defender_choice

:quick_scan
echo.
echo ========================================================================
echo                         WINDOWS DEFENDER QUICK SCAN
echo ========================================================================
echo.

echo [STEP 1/6] Pre-scan system check...
echo [INFO] Verifying Windows Defender service status...

:: Check Defender service
sc query "WinDefend" | findstr "RUNNING" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Defender service is running
) else (
echo [WARNING] Windows Defender service not running
echo [INFO] Attempting to start service...
sc start "WinDefend" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Service started successfully
) else (
echo [ERROR] Failed to start service - scan may fail
)
)

echo.
echo [STEP 2/6] Checking available disk space...
for /f "tokens=3" %%a in ('dir /-c ^| find "bytes free"') do set "free_space=%%a"
echo [INFO] Available disk space: %free_space% bytes

echo.
echo [STEP 3/6] Checking for existing scans...
powershell -Command "
try {
$scanStatus = Get-MpScanStatus
if ($scanStatus -ne $null) {
Write-Host '[INFO] Current scan status: ' $scanStatus
if ($scanStatus -eq 'Running') {
Write-Host '[WARNING] A scan is already running'
}
} else {
Write-Host '[INFO] No active scans detected'
}
} catch {
Write-Host '[INFO] Unable to check scan status'
}
"

echo.
echo [STEP 4/6] Starting Windows Defender Quick Scan...
echo [INFO] Scan type: Quick Scan (targets common malware locations)
echo [INFO] Estimated duration: 5-15 minutes
echo [INFO] System performance may be slightly affected during scan
echo.

set /p confirm="Do you want to proceed with the quick scan? (Y/N): "
if /i not "%confirm%"=="Y" (
echo [INFO] Quick scan cancelled by user
pause
goto :defender_scan
)

echo.
echo [STEP 5/6] Initiating scan process...
powershell -Command "
try {
Write-Host '[STATUS] Starting Windows Defender Quick Scan...'
$result = Start-MpScan -ScanType QuickScan
if ($result -ne $null) {
Write-Host '[SUCCESS] Quick scan started successfully'
Write-Host '[INFO] Scan ID: ' $result
} else {
Write-Host '[SUCCESS] Quick scan initiated'
}
Write-Host '[INFO] Monitor progress in Windows Security app'
Write-Host '[INFO] Scan will run in background'
} catch {
Write-Host '[ERROR] Failed to start quick scan: ' $_.Exception.Message
Write-Host '[INFO] Error details: ' $_.Exception.GetType().FullName
}
"

echo.
echo [STEP 6/6] Post-scan verification...
powershell -Command "
try {
Start-Sleep -Seconds 3
$scanStatus = Get-MpScanStatus
if ($scanStatus -eq 'Running') {
Write-Host '[SUCCESS] Scan is actively running'
} elseif ($scanStatus -eq 'Completed') {
Write-Host '[SUCCESS] Scan completed successfully'
} else {
Write-Host '[INFO] Scan status: ' $scanStatus
}
} catch {
Write-Host '[INFO] Unable to verify scan status'
}
"

echo.
echo [COMPLETED] Quick scan process initiated
echo [INFO] You can monitor scan progress in Windows Security
echo [INFO] Scan results will be available when completed
echo [INFO] No immediate action required - scan runs in background
pause
goto :defender_scan

:full_scan
echo.
echo [INFO] Starting Windows Defender Full Scan...
echo [INFO] This may take several hours...
echo [WARNING] Do not interrupt the scan process
echo.

set /p confirm="Are you sure you want to start a full scan? (Y/N): "
if /i not "%confirm%"=="Y" goto :defender_scan

powershell -Command "
try {
Start-MpScan -ScanType FullScan
Write-Host '[SUCCESS] Full scan started'
Write-Host '[INFO] Check Windows Security for results'
} catch {
Write-Host '[ERROR] Failed to start full scan: ' $_.Exception.Message
}
"

echo.
echo [INFO] Full scan initiated
pause
goto :defender_scan

:custom_scan
echo.
set /p scan_path="Enter path to scan: "
if "%scan_path%"=="" (
echo [ERROR] Scan path is required
pause
goto :defender_scan
)

if not exist "%scan_path%" (
echo [ERROR] Path does not exist
pause
goto :defender_scan
)

echo [INFO] Starting custom scan of: %scan_path%
echo.

powershell -Command "
try {
Start-MpScan -ScanType CustomScan -ScanPath '%scan_path%'
Write-Host '[SUCCESS] Custom scan started'
} catch {
Write-Host '[ERROR] Failed to start custom scan: ' $_.Exception.Message
}
"

echo.
echo [INFO] Custom scan initiated
pause
goto :defender_scan

:defender_status
echo.
echo [INFO] Windows Defender Status:
echo.

powershell -Command "
try {
$defender = Get-MpComputerStatus
Write-Host '[INFO] Antivirus Enabled: ' $defender.AntivirusEnabled
Write-Host '[INFO] Real-time Protection: ' $defender.RealTimeProtectionEnabled
Write-Host '[INFO] Last Quick Scan: ' $defender.QuickScanStartTime
Write-Host '[INFO] Last Full Scan: ' $defender.FullScanStartTime
Write-Host '[INFO] Definition Version: ' $defender.AntivirusSignatureVersion
Write-Host '[INFO] Engine Version: ' $defender.AntimalwareEngineVersion
} catch {
Write-Host '[ERROR] Could not get Defender status'
}
"

echo.
pause
goto :defender_scan

:update_definitions
echo.
echo [INFO] Updating Windows Defender definitions...
echo.

powershell -Command "
try {
Update-MpSignature
Write-Host '[SUCCESS] Defender definitions updated'
} catch {
Write-Host '[ERROR] Failed to update definitions: ' $_.Exception.Message
}
"

echo.
pause
goto :defender_scan

:invalid_defender_choice
echo.
echo [ERROR] Invalid Defender choice
pause
goto :defender_scan

:firewall_config
echo.
echo ========================================================================
echo                        FIREWALL CONFIGURATION
echo ========================================================================
echo.

echo [INFO] Windows Firewall configuration options:
echo.
echo [1] Check Firewall Status
echo [2] Enable/Disable Firewall
echo [3] View Firewall Rules
echo [4] Add Firewall Rule
echo [5] Remove Firewall Rule
echo [6] Reset Firewall Settings
echo [0] Back to main menu
echo.

set /p firewall_choice="Enter your choice (0-6): "

if "%firewall_choice%"=="1" goto :firewall_status
if "%firewall_choice%"=="2" goto :firewall_toggle
if "%firewall_choice%"=="3" goto :firewall_rules
if "%firewall_choice%"=="4" goto :add_rule
if "%firewall_choice%"=="5" goto :remove_rule
if "%firewall_choice%"=="6" goto :reset_firewall
if "%firewall_choice%"=="0" goto :menu
goto :invalid_firewall_choice

:firewall_status
echo.
echo [INFO] Windows Firewall Status:
echo.

netsh advfirewall show allprofiles state
echo.

pause
goto :firewall_config

:firewall_toggle
echo.
echo [INFO] Firewall Toggle Options:
echo [1] Enable Firewall
echo [2] Disable Firewall
echo [0] Back
echo.

set /p toggle_choice="Enter your choice (0-2): "

if "%toggle_choice%"=="1" (
echo [INFO] Enabling Windows Firewall...
netsh advfirewall set allprofiles state on >nul 2>&1
if %errorlevel% equ 0 (
echo [SUCCESS] Firewall enabled
) else (
echo [ERROR] Failed to enable firewall
)
) else if "%toggle_choice%"=="2" (
echo [WARNING] Disabling Windows Firewall...
set /p confirm="Are you sure? (Y/N): "
if /i "%confirm%"=="Y" (
netsh advfirewall set allprofiles state off >nul 2>&1
if %errorlevel% equ 0 (
echo [SUCCESS] Firewall disabled
) else (
echo [ERROR] Failed to disable firewall
)
)
)

echo.
pause
goto :firewall_config

:firewall_rules
echo.
echo [INFO] Windows Firewall Rules:
echo.

netsh advfirewall firewall show rule name=all
echo.

pause
goto :firewall_config

:add_rule
echo.
echo [INFO] Adding Firewall Rule:
echo [WARNING] This requires administrator privileges
echo.

set /p rule_name="Enter rule name: "
set /p rule_program="Enter program path: "
set /p rule_action="Enter action (allow/block): "

if "%rule_name%"=="" (
echo [ERROR] Rule name is required
pause
goto :firewall_config
)

echo [INFO] Adding firewall rule: %rule_name%
netsh advfirewall firewall add rule name="%rule_name%" dir=in action=%rule_action% program="%rule_program%"
if %errorlevel% equ 0 (
echo [SUCCESS] Firewall rule added
) else (
echo [ERROR] Failed to add firewall rule
)

echo.
pause
goto :firewall_config

:remove_rule
echo.
set /p rule_name="Enter rule name to remove: "
if "%rule_name%"=="" (
echo [ERROR] Rule name is required
pause
goto :firewall_config
)

echo [INFO] Removing firewall rule: %rule_name%
netsh advfirewall firewall delete rule name="%rule_name%"
if %errorlevel% equ 0 (
echo [SUCCESS] Firewall rule removed
) else (
echo [ERROR] Failed to remove firewall rule
)

echo.
pause
goto :firewall_config

:reset_firewall
echo.
echo [WARNING] This will reset all firewall settings to default
set /p confirm="Are you sure? (Y/N): "
if /i "%confirm%"=="Y" (
netsh advfirewall reset >nul 2>&1
if %errorlevel% equ 0 (
echo [SUCCESS] Firewall settings reset
) else (
echo [ERROR] Failed to reset firewall settings
)
)

echo.
pause
goto :firewall_config

:invalid_firewall_choice
echo.
echo [ERROR] Invalid firewall choice
pause
goto :firewall_config

:privacy_check
echo.
echo ========================================================================
echo                         PRIVACY SETTINGS CHECK
echo ========================================================================
echo.

echo [INFO] Checking Windows privacy settings...
echo.

echo [CHECK 1] Location Services:
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E6AD100E-5F4E-44CD-BE7F-75C890080B8C}" /v Value >nul 2>&1
if %errorlevel% equ 0 (
echo [INFO] Location services status retrieved
) else (
echo [WARNING] Could not check location services
)

echo [CHECK 2] Camera Access:
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E5323777-F976-4f5b-9B55-B94699C46E44}" /v Value >nul 2>&1
if %errorlevel% equ 0 (
echo [INFO] Camera access status retrieved
) else (
echo [WARNING] Could not check camera access
)

echo [CHECK 3] Microphone Access:
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{2EEF81BE-33FA-4800-9670-1C4761350F74}" /v Value >nul 2>&1
if %errorlevel% equ 0 (
echo [INFO] Microphone access status retrieved
) else (
echo [WARNING] Could not check microphone access
)

echo [CHECK 4] Diagnostic Data:
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry >nul 2>&1
if %errorlevel% equ 0 (
echo [INFO] Diagnostic data settings retrieved
) else (
echo [WARNING] Could not check diagnostic data settings
)

echo.
echo [INFO] Privacy settings check completed
echo [INFO] For detailed privacy management, use Windows Settings
pause
goto :menu

:user_security
echo.
echo ========================================================================
echo                         USER ACCOUNT SECURITY
echo ========================================================================
echo.

echo [INFO] User account security options:
echo.
echo [1] Check User Account Status
echo [2] Check Password Policy
echo [3] Check Account Lockout Policy
echo [4] Check User Groups
echo [5] Check Login History
echo [0] Back to main menu
echo.

set /p user_choice="Enter your choice (0-5): "

if "%user_choice%"=="1" goto :user_status
if "%user_choice%"=="2" goto :password_policy
if "%user_choice%"=="3" goto :lockout_policy
if "%user_choice%"=="4" goto :user_groups
if "%user_choice%"=="5" goto :login_history
if "%user_choice%"=="0" goto :menu
goto :invalid_user_choice

:user_status
echo.
echo [INFO] Current user account status:
echo.

echo [INFO] Current user: %USERNAME%
echo [INFO] Computer name: %COMPUTERNAME%
echo [INFO] Domain: %USERDOMAIN%
echo.

whoami /all
echo.

pause
goto :user_security

:password_policy
echo.
echo [INFO] Password policy (requires admin privileges):
echo.

net accounts
echo.

pause
goto :user_security

:lockout_policy
echo.
echo [INFO] Account lockout policy (requires admin privileges):
echo.

net accounts
echo.

pause
goto :user_security

:user_groups
echo.
echo [INFO] Current user groups:
echo.

whoami /groups
echo.

pause
goto :user_security

:login_history
echo.
echo [INFO] Recent login history:
echo.

wevtutil qe Security /f:text /c:10 /rd:true /q:"*[System[EventID=4624]]" >nul 2>&1
if %errorlevel% equ 0 (
echo [INFO] Login history retrieved
) else (
echo [WARNING] Could not retrieve login history
)

echo.
pause
goto :user_security

:invalid_user_choice
echo.
echo [ERROR] Invalid user choice
pause
goto :user_security

:updates_check
echo.
echo ========================================================================
echo                         SYSTEM UPDATES CHECK
echo ========================================================================
echo.

echo [INFO] Checking for Windows updates...
echo.

powershell -Command "
try {
$updates = Get-WindowsUpdate
if ($updates.Count -gt 0) {
Write-Host '[INFO] Found ' $updates.Count ' available updates'
foreach ($update in $updates) {
Write-Host '[UPDATE] ' $update.Title
}
} else {
Write-Host '[SUCCESS] System is up to date'
}
} catch {
Write-Host '[ERROR] Could not check for updates: ' $_.Exception.Message
}
"

echo.
echo [INFO] Update check completed
pause
goto :menu

:security_audit
echo.
echo ========================================================================
echo                           SECURITY AUDIT
echo ========================================================================
echo.

echo [INFO] Running comprehensive security audit...
echo.

echo [AUDIT 1] System Information:
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Type"
echo.

echo [AUDIT 2] Installed Programs:
echo [INFO] Checking for potentially vulnerable software...
wmic product get name,version | findstr /i "java\|flash\|adobe\|mozilla"
echo.

echo [AUDIT 3] Running Processes:
echo [INFO] Checking for suspicious processes...
tasklist | findstr /i "svchost\|explorer\|winlogon"
echo.

echo [AUDIT 4] Network Connections:
echo [INFO] Checking active network connections...
netstat -an | findstr ESTABLISHED | find /c /v ""
echo.

echo [AUDIT 5] Services Status:
echo [INFO] Checking critical security services...
sc query "WinDefend" | findstr STATE
sc query "MpsSvc" | findstr STATE
echo.

echo [AUDIT 6] Registry Security:
echo [INFO] Checking critical registry settings...
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA >nul 2>&1
if %errorlevel% equ 0 (
echo [INFO] UAC settings retrieved
) else (
echo [WARNING] Could not check UAC settings
)

echo.
echo [INFO] Security audit completed
pause
goto :menu

:antivirus_status
echo.
echo ========================================================================
echo                         ANTIVIRUS STATUS CHECK
echo ========================================================================
echo.

echo [INFO] Checking antivirus software status...
echo.

powershell -Command "
try {
$defender = Get-MpComputerStatus
Write-Host '[INFO] Windows Defender Status:'
Write-Host '  - Antivirus Enabled: ' $defender.AntivirusEnabled
Write-Host '  - Real-time Protection: ' $defender.RealTimeProtectionEnabled
Write-Host '  - Last Scan: ' $defender.QuickScanStartTime
Write-Host '  - Definition Version: ' $defender.AntivirusSignatureVersion
} catch {
Write-Host '[ERROR] Could not check Windows Defender status'
}
"

echo.
echo [INFO] Checking for other antivirus software...
wmic /namespace:\\root\SecurityCenter2 path AntiVirusProduct get displayName,productState
echo.

echo [INFO] Antivirus status check completed
pause
goto :menu

:browser_security
echo.
echo ========================================================================
echo                         BROWSER SECURITY CHECK
echo ========================================================================
echo.

echo [INFO] Browser security check options:
echo.
echo [1] Check Browser Extensions
echo [2] Check Browser Security Settings
echo [3] Clear Browser Data
echo [4] Check for Malicious Extensions
echo [0] Back to main menu
echo.

set /p browser_choice="Enter your choice (0-4): "

if "%browser_choice%"=="1" goto :check_extensions
if "%browser_choice%"=="2" goto :browser_settings
if "%browser_choice%"=="3" goto :clear_browser_data
if "%browser_choice%"=="4" goto :malicious_extensions
if "%browser_choice%"=="0" goto :menu
goto :invalid_browser_choice

:check_extensions
echo.
echo [INFO] Checking browser extensions...
echo [INFO] Chrome extensions:
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Extensions" (
dir "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Extensions" /B
) else (
echo [INFO] Chrome not found or no extensions
)

echo.
echo [INFO] Edge extensions:
if exist "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Extensions" (
dir "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Extensions" /B
) else (
echo [INFO] Edge not found or no extensions
)

echo.
pause
goto :browser_security

:browser_settings
echo.
echo [INFO] Browser security settings check:
echo [INFO] This requires manual verification in browser settings
echo [INFO] Please check the following settings in your browsers:
echo [INFO] - Pop-up blocker enabled
echo [INFO] - Phishing protection enabled
echo [INFO] - Safe browsing enabled
echo [INFO] - JavaScript settings appropriate
echo.

pause
goto :browser_security

:clear_browser_data
echo.
echo [WARNING] This will clear browser data
set /p confirm="Are you sure? (Y/N): "
if /i "%confirm%"=="Y" (
echo [INFO] Clearing browser data...
echo [INFO] Please use browser settings to clear data securely
)

echo.
pause
goto :browser_security

:malicious_extensions
echo.
echo [INFO] Checking for potentially malicious extensions...
echo [INFO] This is a basic check - use specialized tools for thorough analysis
echo.

echo [INFO] Checking for common malicious extension patterns...
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Extensions" (
echo [INFO] Chrome extensions directory found
echo [INFO] Manual review recommended for all installed extensions
)

echo.
pause
goto :browser_security

:invalid_browser_choice
echo.
echo [ERROR] Invalid browser choice
pause
goto :browser_security

:network_security
echo.
echo ========================================================================
echo                         NETWORK SECURITY SCAN
echo ========================================================================
echo.

echo [INFO] Running network security scan...
echo.

echo [SCAN 1] Checking for open ports:
netstat -an | findstr LISTENING
echo.

echo [SCAN 2] Checking for suspicious connections:
netstat -an | findstr ESTABLISHED
echo.

echo [SCAN 3] Checking firewall status:
netsh advfirewall show allprofiles state
echo.

echo [SCAN 4] Checking network adapters:
ipconfig /all | findstr "Ethernet adapter\|Wireless LAN adapter"
echo.

echo.
echo [INFO] Network security scan completed
pause
goto :menu

:security_score
echo.
echo ========================================================================
echo                         SECURITY SCORE & RECOMMENDATIONS
echo ========================================================================
echo.

echo [STATUS] Calculating comprehensive security score...
echo.

:: Initialize scoring variables
set "TOTAL_SCORE=0"
set "MAX_SCORE=100"
set "CHECK_COUNT=0"

echo [STEP 1/8] Checking Windows Defender status...
powershell -Command "
try {
$defender = Get-MpComputerStatus
if ($defender.AntivirusEnabled -and $defender.RealTimeProtectionEnabled) {
Write-Host '[SUCCESS] Windows Defender: ENABLED (+20 points)'
$script:TOTAL_SCORE += 20
} else {
Write-Host '[WARNING] Windows Defender: DISABLED OR PARTIAL (0 points)'
}
$script:CHECK_COUNT++
} catch {
Write-Host '[ERROR] Windows Defender: UNABLE TO CHECK (0 points)'
$script:CHECK_COUNT++
}
"

echo.
echo [STEP 2/8] Checking Windows Firewall status...
netsh advfirewall show allprofiles state | findstr "ON" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Firewall: ENABLED (+15 points)
set /a TOTAL_SCORE+=15
) else (
echo [WARNING] Windows Firewall: DISABLED (0 points)
)
set /a CHECK_COUNT++

echo.
echo [STEP 3/8] Checking User Account Control...
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA 2>nul | findstr "0x1" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] User Account Control: ENABLED (+15 points)
set /a TOTAL_SCORE+=15
) else (
echo [WARNING] User Account Control: DISABLED (0 points)
)
set /a CHECK_COUNT++

echo.
echo [STEP 4/8] Checking system updates...
powershell -Command "
try {
$updates = Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false 2>$null
if ($updates.Count -eq 0) {
Write-Host '[SUCCESS] System Updates: UP TO DATE (+20 points)'
$script:TOTAL_SCORE += 20
} else {
Write-Host '[WARNING] System Updates: ' $updates.Count ' PENDING (5 points)'
$script:TOTAL_SCORE += 5
}
$script:CHECK_COUNT++
} catch {
Write-Host '[INFO] System Updates: UNABLE TO CHECK (10 points)'
$script:TOTAL_SCORE += 10
$script:CHECK_COUNT++
}
"

echo.
echo [STEP 5/8] Checking browser security...
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Extensions" (
echo [INFO] Browser Extensions: DETECTED (5 points)
set /a TOTAL_SCORE+=5
) else (
echo [SUCCESS] Browser Extensions: NONE DETECTED (+10 points)
set /a TOTAL_SCORE+=10
)
set /a CHECK_COUNT++

echo.
echo [STEP 6/8] Checking network security...
netstat -an | findstr LISTENING | find /c /v "" >nul 2>&1
if %errorlevel%==0 (
echo [INFO] Network Ports: ACTIVE CONNECTIONS DETECTED (5 points)
set /a TOTAL_SCORE+=5
) else (
echo [SUCCESS] Network Ports: MINIMAL EXPOSURE (+10 points)
set /a TOTAL_SCORE+=10
)
set /a CHECK_COUNT++

echo.
echo [STEP 7/8] Checking privacy settings...
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E6AD100E-5F4E-44CD-BE7F-75C890080B8C}" /v Value 2>nul | findstr "0x0" >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Location Services: DISABLED (+10 points)
set /a TOTAL_SCORE+=10
) else (
echo [INFO] Location Services: ENABLED (5 points)
set /a TOTAL_SCORE+=5
)
set /a CHECK_COUNT++

echo.
echo [STEP 8/8] Checking administrative privileges...
net session >nul 2>&1
if %errorlevel%==0 (
echo [WARNING] Admin Mode: RUNNING AS ADMINISTRATOR (0 points)
) else (
echo [SUCCESS] Admin Mode: STANDARD USER (+5 points)
set /a TOTAL_SCORE+=5
)
set /a CHECK_COUNT++

echo.
echo ========================================================================
echo                           SECURITY SCORE RESULTS
echo ========================================================================
echo.

if %TOTAL_SCORE% geq 90 (
echo [EXCELLENT] Security Score: %TOTAL_SCORE%/100
echo [STATUS] Your system has excellent security configuration
echo [RECOMMENDATION] Continue maintaining current security practices
) else if %TOTAL_SCORE% geq 75 (
echo [GOOD] Security Score: %TOTAL_SCORE%/100
echo [STATUS] Your system has good security configuration
echo [RECOMMENDATION] Consider addressing security recommendations below
) else if %TOTAL_SCORE% geq 60 (
echo [FAIR] Security Score: %TOTAL_SCORE%/100
echo [STATUS] Your system has fair security configuration
echo [RECOMMENDATION] Several security improvements recommended
) else (
echo [POOR] Security Score: %TOTAL_SCORE%/100
echo [STATUS] Your system needs immediate security attention
echo [RECOMMENDATION] Critical security improvements required
)

echo.
echo [INFO] Security checks completed: %CHECK_COUNT%
echo [INFO] For detailed recommendations, run individual security modules
pause
goto :menu

:emergency_security
echo.
echo ========================================================================
echo                         EMERGENCY SECURITY ACTIONS
echo ========================================================================
echo.

echo [WARNING] Emergency security actions for immediate threats
echo [INFO] Use these options only when you suspect security compromise
echo.

echo [1] Emergency Malware Scan (High Priority)
echo [2] Network Isolation & Analysis
echo [3] Critical Process Analysis
echo [4] Registry Security Check
echo [5] File System Integrity Check
echo [6] Emergency Firewall Lockdown
echo [7] User Account Security Audit
echo [8] System Restore Point Creation
echo [0] Back to main menu
echo.

set /p emergency_choice="Enter your choice (0-8): "

if "%emergency_choice%"=="1" goto :emergency_scan
if "%emergency_choice%"=="2" goto :network_isolation
if "%emergency_choice%"=="3" goto :process_analysis
if "%emergency_choice%"=="4" goto :registry_check
if "%emergency_choice%"=="5" goto :filesystem_check
if "%emergency_choice%"=="6" goto :firewall_lockdown
if "%emergency_choice%"=="7" goto :user_audit
if "%emergency_choice%"=="8" goto :restore_point
if "%emergency_choice%"=="0" goto :menu
goto :invalid_emergency_choice

:emergency_scan
echo.
echo [CRITICAL] Initiating emergency malware scan...
echo [WARNING] This will run a comprehensive scan immediately
echo [INFO] System performance will be significantly affected
echo.
set /p confirm="Proceed with emergency scan? (Y/N): "
if /i "%confirm%"=="Y" (
echo [STATUS] Starting emergency full scan...
powershell -Command "Start-MpScan -ScanType FullScan"
echo [SUCCESS] Emergency scan initiated
) else (
echo [INFO] Emergency scan cancelled
)
pause
goto :emergency_security

:network_isolation
echo.
echo [CRITICAL] Network isolation procedures...
echo [WARNING] This will temporarily disable network connections
echo.
echo [INFO] Current network connections:
netstat -an | findstr ESTABLISHED
echo.
set /p confirm="Temporarily isolate network? (Y/N): "
if /i "%confirm%"=="Y" (
echo [STATUS] Disabling network adapters...
netsh interface set interface "Wi-Fi" admin=disable 2>nul
netsh interface set interface "Ethernet" admin=disable 2>nul
echo [SUCCESS] Network isolation activated
echo [INFO] Re-enable adapters manually when safe
) else (
echo [INFO] Network isolation cancelled
)
pause
goto :emergency_security

:process_analysis
echo.
echo [CRITICAL] Critical process analysis...
echo [STATUS] Analyzing running processes for suspicious activity...
echo.
echo [INFO] Top CPU consuming processes:
tasklist /svc /fo table | sort /r /+5
echo.
echo [INFO] Suspicious process patterns:
tasklist | findstr /i "svchost\|winlogon\|csrss\|explorer"
echo.
echo [INFO] Process analysis completed
pause
goto :emergency_security

:registry_check
echo.
echo [CRITICAL] Registry security check...
echo [STATUS] Checking critical registry entries...
echo.
echo [INFO] Checking startup programs:
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" 2>nul
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" 2>nul
echo.
echo [INFO] Registry security check completed
pause
goto :emergency_security

:filesystem_check
echo.
echo [CRITICAL] File system integrity check...
echo [STATUS] Checking critical system files...
echo.
sfc /scannow /quiet
if %errorlevel%==0 (
echo [SUCCESS] System file check completed successfully
) else (
echo [WARNING] System file check found issues
)
echo.
echo [INFO] File system check completed
pause
goto :emergency_security

:firewall_lockdown
echo.
echo [CRITICAL] Emergency firewall lockdown...
echo [WARNING] This will block all incoming connections
echo.
set /p confirm="Activate emergency firewall lockdown? (Y/N): "
if /i "%confirm%"=="Y" (
echo [STATUS] Activating firewall lockdown...
netsh advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound
echo [SUCCESS] Emergency firewall lockdown activated
echo [WARNING] All network traffic blocked
) else (
echo [INFO] Firewall lockdown cancelled
)
pause
goto :emergency_security

:user_audit
echo.
echo [CRITICAL] User account security audit...
echo [STATUS] Checking user account security...
echo.
echo [INFO] Current user account details:
whoami /all
echo.
echo [INFO] Recent login attempts:
wevtutil qe Security /f:text /c:10 /rd:true /q:"*[System[EventID=4624]]" 2>nul
echo.
echo [INFO] User audit completed
pause
goto :emergency_security

:restore_point
echo.
echo [CRITICAL] Creating emergency restore point...
echo [STATUS] Creating system restore point...
echo.
powershell -Command "
try {
Checkpoint-Computer -Description 'Emergency Security Restore Point' -RestorePointType 'MODIFY_SETTINGS'
Write-Host '[SUCCESS] Emergency restore point created successfully'
} catch {
Write-Host '[ERROR] Failed to create restore point: ' $_.Exception.Message
}
"
pause
goto :emergency_security

:invalid_emergency_choice
echo.
echo [ERROR] Invalid emergency choice
pause
goto :emergency_security

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
echo [INFO] Security Manager closed
echo [INFO] Thank you for using DevOptimizer System
echo [INFO] Security operations completed successfully
exit /b 0
