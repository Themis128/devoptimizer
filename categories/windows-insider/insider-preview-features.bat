@echo off

@
echo off setlocal EnableExtensions EnableDelayedExpansion title Windows Insider Preview Features Manager color 0D :: Check for admin privileges call :checkAdmin if not "%IS_ADMIN%"=="1" (
echo This tool requires Administrator privileges.
echo Right-click and select "Run as administrator" pause exit /b 1 ) :menu cls
echo ================================================================
echo WINDOWS INSIDER PREVIEW FEATURES MANAGER v1.0
echo ================================================================
echo.
echo Windows Features:
echo 1) Manage Optional Features
echo 2) Enable/Disable Windows Subsystem for Linux (WSL)
echo 3) Manage Hyper-V Features
echo 4) Configure Windows Sandbox
echo 5) Manage .NET Framework Features echo.
echo Experimental Features:
echo 6) Enable Windows Insider Preview Features
echo 7) Configure Windows Feature Experience Pack
echo 8) Manage Dev Drive (ReFS)
echo 9) Configure Enhanced Security Features echo.
echo Registry Tweaks:
echo 10) Enable Advanced Windows Features
echo 11) Configure Insider-Specific Settings
echo 12) Reset Feature Configurations echo.
echo 0) Exit echo. set /p choice=Enter your choice (0-12): if "%choice%"=="1" goto optionalFeatures if "%choice%"=="2" goto wslFeatures if "%choice%"=="3" goto hypervFeatures if "%choice%"=="4" goto windowsSandbox if "%choice%"=="5" goto dotnetFeatures if "%choice%"=="6" goto previewFeatures if "%choice%"=="7" goto featureExperience if "%choice%"=="8" goto devDrive if "%choice%"=="9" goto securityFeatures if "%choice%"=="10" goto advancedFeatures if "%choice%"=="11" goto insiderSettings if "%choice%"=="12" goto resetFeatures if "%choice%"=="0" exit /b 0
echo Invalid choice. Please try again. timeout /t 2 >nul goto menu :optionalFeatures cls
echo ================================================================
echo OPTIONAL FEATURES MANAGER
echo ================================================================
echo.
echo Opening Windows Features dialog... start optionalfeatures.exe echo.
echo You can also manage features via PowerShell: echo.
echo View all features:
echo Get-WindowsOptionalFeature -Online echo.
echo Enable a feature:
echo Enable-WindowsOptionalFeature -Online -FeatureName "FeatureName" echo.
echo Disable a feature:
echo Disable-WindowsOptionalFeature -Online -FeatureName "FeatureName" echo. pause goto menu :wslFeatures cls
echo ================================================================
echo WSL FEATURES MANAGER
echo ================================================================
echo.
echo Current WSL Status: dism /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux 2>nul | findstr "State" dism /online /get-featureinfo /featurename:VirtualMachinePlatform 2>nul | findstr "State" echo.
echo WSL Management Options:
echo 1) Enable WSL 1 (Windows Subsystem for Linux)
echo 2) Enable WSL 2 (Full Linux kernel)
echo 3) Disable WSL
echo 4) Install Ubuntu (requires WSL)
echo 5) Set WSL default version echo.
echo 0) Back to main menu echo. set /p wsl=Choose option (0-5): if "%wsl%"=="0" goto menu if "%wsl%"=="1" goto enableWSL1 if "%wsl%"=="2" goto enableWSL2 if "%wsl%"=="3" goto disableWSL if "%wsl%"=="4" goto installUbuntu if "%wsl%"=="5" goto setWSLVersion goto wslFeatures :enableWSL1 echo.
echo Enabling WSL 1... dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
echo WSL 1 enabled. Restart required. pause goto wslFeatures :enableWSL2 echo.
echo Enabling WSL 2 (includes WSL 1 + Virtual Machine Platform)... dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
echo WSL 2 enabled. Restart required.
echo After restart, run: wsl --set-default-version 2 pause goto wslFeatures :disableWSL echo.
echo Disabling WSL... dism /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart dism /online /disable-feature /featurename:VirtualMachinePlatform /norestart
echo WSL disabled. Restart required. pause goto wslFeatures :installUbuntu echo.
echo Installing Ubuntu for WSL... where winget >nul 2>&1 if errorlevel 1 (
echo winget not found. Install from Microsoft Store manually. ) else ( winget install -e --id Canonical.Ubuntu ) pause goto wslFeatures :setWSLVersion echo.
echo Setting WSL default version...
echo 1) Set WSL 1 as default
echo 2) Set WSL 2 as default echo. set /p ver=Choose version (1-2): if "%ver%"=="1" wsl --set-default-version 1 if "%ver%"=="2" wsl --set-default-version 2 pause goto wslFeatures :hypervFeatures cls
echo ================================================================
echo HYPER-V FEATURES MANAGER
echo ================================================================
echo.
echo Current Hyper-V Status: dism /online /get-featureinfo /featurename:Microsoft-Hyper-V-All 2>nul | findstr "State" echo.
echo Hyper-V Management:
echo 1) Enable Hyper-V (Full)
echo 2) Enable Hyper-V Management Tools Only
echo 3) Disable Hyper-V
echo 4) Check System Compatibility echo.
echo 0) Back to main menu echo. set /p hyperv=Choose option (0-4): if "%hyperv%"=="0" goto menu if "%hyperv%"=="1" goto enableHyperV if "%hyperv%"=="2" goto enableHyperVTools if "%hyperv%"=="3" goto disableHyperV if "%hyperv%"=="4" goto checkHyperVCompat goto hypervFeatures :enableHyperV echo.
echo Enabling Hyper-V... dism /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart
echo Hyper-V enabled. Restart required. pause goto hypervFeatures :enableHyperVTools echo.
echo Enabling Hyper-V Management Tools... dism /online /enable-feature /featurename:Microsoft-Hyper-V-Tools-All /all /norestart
echo Hyper-V Management Tools enabled. Restart required. pause goto hypervFeatures :disableHyperV echo.
echo Disabling Hyper-V... dism /online /disable-feature /featurename:Microsoft-Hyper-V-All /norestart
echo Hyper-V disabled. Restart required. pause goto hypervFeatures :checkHyperVCompat echo.
echo Checking Hyper-V compatibility... systeminfo | findstr /C:"Hyper-V Requirements" pause goto hypervFeatures :windowsSandbox cls
echo ================================================================
echo WINDOWS SANDBOX MANAGER
echo ================================================================
echo.
echo Current Windows Sandbox Status: dism /online /get-featureinfo /featurename:Containers-DisposableClientVM 2>nul | findstr "State" echo.
echo Windows Sandbox Management:
echo 1) Enable Windows Sandbox
echo 2) Disable Windows Sandbox
echo 3) Launch Windows Sandbox
echo 4) Create Custom Sandbox Configuration echo.
echo 0) Back to main menu echo. set /p sandbox=Choose option (0-4): if "%sandbox%"=="0" goto menu if "%sandbox%"=="1" goto enableSandbox if "%sandbox%"=="2" goto disableSandbox if "%sandbox%"=="3" goto launchSandbox if "%sandbox%"=="4" goto customSandbox goto windowsSandbox :enableSandbox echo.
echo Enabling Windows Sandbox... dism /online /enable-feature /featurename:Containers-DisposableClientVM /all /norestart
echo Windows Sandbox enabled. Restart required. pause goto windowsSandbox :disableSandbox echo.
echo Disabling Windows Sandbox... dism /online /disable-feature /featurename:Containers-DisposableClientVM /norestart
echo Windows Sandbox disabled. Restart required. pause goto windowsSandbox :launchSandbox echo.
echo Launching Windows Sandbox... start WindowsSandbox.exe pause goto windowsSandbox :customSandbox echo.
echo Creating custom sandbox configuration... set "CONFIG_FILE=%USERPROFILE%\Desktop\CustomSandbox.wsb"
echo ^<Configuration^> > "%CONFIG_FILE%"
echo ^<VGpu^>Enable^</VGpu^> >> "%CONFIG_FILE%"
echo ^<Networking^>Enable^</Networking^> >> "%CONFIG_FILE%"
echo ^<MappedFolders^> >> "%CONFIG_FILE%"
echo ^<MappedFolder^> >> "%CONFIG_FILE%"
echo ^<HostFolder^>%USERPROFILE%\Downloads^</HostFolder^> >> "%CONFIG_FILE%"
echo ^<SandboxFolder^>C:\Users\WDAGUtilityAccount\Desktop\Downloads^</SandboxFolder^> >> "%CONFIG_FILE%"
echo ^<ReadOnly^>false^</ReadOnly^> >> "%CONFIG_FILE%"
echo ^</MappedFolder^> >> "%CONFIG_FILE%"
echo ^</MappedFolders^> >> "%CONFIG_FILE%"
echo ^</Configuration^> >> "%CONFIG_FILE%" echo.
echo Custom sandbox configuration created: %CONFIG_FILE%
echo Double-click the .wsb file to launch with custom settings. pause goto windowsSandbox :dotnetFeatures cls
echo ================================================================
echo .NET FRAMEWORK FEATURES
echo ================================================================
echo.
echo Current .NET Framework Status: dism /online /get-featureinfo /featurename:NetFx3 2>nul | findstr "State" dism /online /get-featureinfo /featurename:NetFx4Extended-ASPNET45 2>nul | findstr "State" echo.
echo .NET Framework Management:
echo 1) Enable .NET Framework 3.5
echo 2) Enable .NET Framework 4.x Advanced Services
echo 3) Disable .NET Framework 3.5
echo 4) Check Installed .NET Versions echo.
echo 0) Back to main menu echo. set /p dotnet=Choose option (0-4): if "%dotnet%"=="0" goto menu if "%dotnet%"=="1" goto enableNet35 if "%dotnet%"=="2" goto enableNet4x if "%dotnet%"=="3" goto disableNet35 if "%dotnet%"=="4" goto checkDotNet goto dotnetFeatures :enableNet35 echo.
echo Enabling .NET Framework 3.5... dism /online /enable-feature /featurename:NetFx3 /all
echo .NET Framework 3.5 installation completed. pause goto dotnetFeatures :enableNet4x echo.
echo Enabling .NET Framework 4.x Advanced Services... dism /online /enable-feature /featurename:NetFx4Extended-ASPNET45 /all
echo .NET Framework 4.x Advanced Services enabled. pause goto dotnetFeatures :disableNet35 echo.
echo Disabling .NET Framework 3.5... dism /online /disable-feature /featurename:NetFx3
echo .NET Framework 3.5 disabled. pause goto dotnetFeatures :checkDotNet echo.
echo Checking installed .NET versions... reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP" /s /v Version 2>nul | findstr "Version" echo.
echo For .NET Core/.NET 5+: where dotnet >nul 2>&1 && dotnet --list-runtimes pause goto dotnetFeatures :previewFeatures cls
echo ================================================================
echo INSIDER PREVIEW FEATURES
echo ================================================================
echo.
echo Enabling Windows Insider Preview Features... echo.
echo Registry tweaks for enhanced Insider experience: echo. :: Enable Developer Mode
echo Enabling Developer Mode... reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowAllTrustedApps /t REG_DWORD /d 1 /f >nul reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f >nul :: Enable advanced Windows features
echo Enabling advanced preview features... reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f >nul reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 1 /f >nul :: Enable experimental features reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\System" /v AllowExperimentation /t REG_DWORD /d 1 /f >nul echo.
echo Preview features enabled. Some changes require restart. pause goto menu :featureExperience cls
echo ================================================================
echo WINDOWS FEATURE EXPERIENCE PACK
echo ================================================================
echo.
echo Managing Windows Feature Experience Pack... echo.
echo Current Feature Experience Pack info: reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR 2>nul echo.
echo Feature Experience Pack allows Microsoft to deliver
echo new features outside of major Windows updates. echo.
echo To check for updates:
echo 1. Open Settings ^> Update ^& Security ^> Windows Update
echo 2. Click "Check for updates"
echo 3. Look for Feature Experience Pack updates echo.
echo Opening Windows Update... start ms-settings:windowsupdate pause goto menu :devDrive cls
echo ================================================================
echo DEV DRIVE (ReFS)
echo ================================================================
echo.
echo Dev Drive uses ReFS for better performance with development workloads.
echo Available on Windows 11 with Insider builds. echo.
echo Dev Drive Management:
echo 1) Check Dev Drive Support
echo 2) Create Dev Drive
echo 3) List Dev Drives
echo 4) Configure Dev Drive Settings echo.
echo 0) Back to main menu echo. set /p devdrive=Choose option (0-4): if "%devdrive%"=="0" goto menu if "%devdrive%"=="1" goto checkDevDrive if "%devdrive%"=="2" goto createDevDrive if "%devdrive%"=="3" goto listDevDrives if "%devdrive%"=="4" goto configDevDrive goto devDrive :checkDevDrive echo.
echo Checking Dev Drive support... powershell -ExecutionPolicy Bypass -Command "Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-DevDrive' -ErrorAction SilentlyContinue" echo.
echo Dev Drive requires:
echo - Windows 11 Insider Preview
echo - ReFS file system support
echo - Sufficient disk space pause goto devDrive :createDevDrive echo.
echo Creating Dev Drive...
echo This will open Disk Management for manual creation. echo.
echo To create a Dev Drive:
echo 1. Right-click unallocated space
echo 2. Select "New Simple Volume"
echo 3. Choose ReFS as file system
echo 4. Enable Dev Drive optimization echo. start diskmgmt.msc pause goto devDrive :listDevDrives echo.
echo Listing Dev Drives... powershell -ExecutionPolicy Bypass -Command "Get-Volume | Where-Object {$_.FileSystem -eq 'ReFS'} | Format-Table DriveLetter,Label,Size,SizeRemaining" pause goto devDrive :configDevDrive echo.
echo Configuring Dev Drive settings... echo.
echo Dev Drive optimizations:
echo - Faster file operations
echo - Better performance for Git repos
echo - Optimized for development tools echo.
echo Configure via Settings ^> System ^> Storage ^> Advanced storage settings start ms-settings:storagesense pause goto devDrive :securityFeatures cls
echo ================================================================
echo ENHANCED SECURITY FEATURES
echo ================================================================
echo.
echo Security Feature Management:
echo 1) Configure Windows Defender Application Guard
echo 2) Manage Core Isolation (Memory Integrity)
echo 3) Configure Smart App Control
echo 4) Manage Microsoft Defender SmartScreen echo.
echo 0) Back to main menu echo. set /p security=Choose option (0-4): if "%security%"=="0" goto menu if "%security%"=="1" goto appGuard if "%security%"=="2" goto coreIsolation if "%security%"=="3" goto smartAppControl if "%security%"=="4" goto smartScreen goto securityFeatures :appGuard echo.
echo Configuring Windows Defender Application Guard... dism /online /get-featureinfo /featurename:Windows-Defender-ApplicationGuard 2>nul | findstr "State" echo.
echo Enable Application Guard? (Y/N) set /p confirm= if /i "%confirm%"=="Y" ( dism /online /enable-feature /featurename:Windows-Defender-ApplicationGuard /all /norestart
echo Application Guard enabled. Restart required. ) pause goto securityFeatures :coreIsolation echo.
echo Managing Core Isolation (Memory Integrity)...
echo Opening Windows Security... start windowsdefender://coreisolation/ pause goto securityFeatures :smartAppControl echo.
echo Configuring Smart App Control...
echo Opening Windows Security... start windowsdefender://smartappcontrol/ pause goto securityFeatures :smartScreen echo.
echo Managing Microsoft Defender SmartScreen...
echo Opening Windows Security... start windowsdefender://smartscreen/ pause goto securityFeatures :advancedFeatures cls
echo ================================================================
echo ADVANCED WINDOWS FEATURES
echo ================================================================
echo.
echo Advanced Feature Toggles:
echo 1) Enable all Windows Communication Foundation features
echo 2) Enable Internet Information Services (IIS)
echo 3) Enable Windows PowerShell ISE
echo 4) Enable Telnet Client
echo 5) Enable TFTP Client echo.
echo 0) Back to main menu echo. set /p advanced=Choose option (0-5): if "%advanced%"=="0" goto menu if "%advanced%"=="1" ( dism /online /enable-feature /featurename:WCF-Services45 /all dism /online /enable-feature /featurename:WCF-HTTP-Activation45 /all
echo WCF features enabled. ) if "%advanced%"=="2" ( dism /online /enable-feature /featurename:IIS-WebServerRole /all
echo IIS enabled. ) if "%advanced%"=="3" ( dism /online /enable-feature /featurename:MicrosoftWindowsPowerShellISE /all
echo PowerShell ISE enabled. ) if "%advanced%"=="4" ( dism /online /enable-feature /featurename:TelnetClient /all
echo Telnet Client enabled. ) if "%advanced%"=="5" ( dism /online /enable-feature /featurename:TFTP /all
echo TFTP Client enabled. ) pause goto menu :insiderSettings cls
echo ================================================================
echo INSIDER-SPECIFIC SETTINGS
echo ================================================================
echo.
echo Applying Insider-optimized registry settings... echo. :: Enable advanced logging for feedback reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 3 /f >nul :: Enable feedback notifications reg add "HKCU\SOFTWARE\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 1 /f >nul :: Enable preview builds notifications reg add "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\UI\Strings" /v SuitableForAudience /t REG_DWORD /d 1 /f >nul :: Enable enhanced error reporting reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 0 /f >nul
echo Insider-specific settings applied.
echo These settings optimize your system for the Insider experience. pause goto menu :resetFeatures cls
echo ================================================================
echo RESET FEATURE CONFIGURATIONS
echo ================================================================
echo.
echo WARNING: This will reset Windows features to default state. echo. set /p confirm=Continue? (Y/N): if /i not "%confirm%"=="Y" goto menu echo.
echo Resetting Windows features... :: Reset optional features sfc /scannow :: Reset Windows features dism /online /cleanup-image /restorehealth :: Reset feature configurations reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /f >nul 2>&1 reg delete "HKCU\SOFTWARE\Microsoft\Siuf\Rules" /f >nul 2>&1 echo.
echo Feature configurations reset to defaults.
echo Restart recommended. pause goto menu :checkAdmin set "IS_ADMIN=0" fsutil dirty query %SystemDrive% >nul 2>&1 if errorlevel 1 ( net session >nul 2>&1 if not errorlevel 1 set "IS_ADMIN=1" ) else ( set "IS_ADMIN=1" ) exit /b endlocal
