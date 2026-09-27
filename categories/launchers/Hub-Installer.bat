@echo off

@
echo off setlocal EnableExtensions EnableDelayedExpansion chcp 65001 >nul 2>&1 :: ===================================================== :: DEVOPTIMIZER HUB INSTALLER v4.0 :: Complete installation and setup of DevOptimizer Hub :: ===================================================== title DevOptimizer Hub Installer v4.0 color 0A :: Initialize variables set "INSTALLER_VERSION=4.0.0" set "DEFAULT_HUB_PATH=D:\DevOptimizer" set "INSTALLER_LOG=%TEMP%\devoptimizer-installer.log" :: Check admin privileges call :checkAdmin if not "%IS_ADMIN%"=="1" (
echo This installer requires Administrator privileges.
echo Right-click and select "Run as administrator" pause exit /b 1 ) call :log "INFO" "DevOptimizer Hub Installer v%INSTALLER_VERSION% started" :welcomeScreen cls echo.
echo
echo DEVOPTIMIZER HUB INSTALLER v%INSTALLER_VERSION%
echo Complete Setup Wizard
echo echo.
echo Welcome to the DevOptimizer Hub Installation Wizard! echo.
echo This installer will:
echo Create the DevOptimizer Hub directory structure
echo Install PowerShell modules and scripts
echo Configure system registry entries
echo Set up environment variables
echo Create portable BAT files
echo Configure Windows integration echo.
echo Press any key to continue or Ctrl+C to cancel... pause >nul :selectInstallPath cls echo.
echo
echo INSTALLATION PATH SELECTION
echo echo.
echo Choose installation location: echo.
echo [1] Default location: %DEFAULT_HUB_PATH%
echo [2] Custom location
echo [3] Show disk space information echo.
echo [0] Cancel installation echo. :getPathChoice set "path_choice=" set /p "path_choice=Enter your choice [0-3]: " if "%path_choice%"=="0" (
echo Installation cancelled by user. call :log "INFO" "Installation cancelled by user" pause exit /b 0 ) if "%path_choice%"=="1" ( set "HUB_PATH=%DEFAULT_HUB_PATH%" goto confirmInstallation ) if "%path_choice%"=="2" goto customPath if "%path_choice%"=="3" goto showDiskSpace
echo Invalid choice. Please try again. timeout /t 2 >nul goto selectInstallPath :customPath echo.
echo Enter custom installation path:
echo (Example: C:\tools\DevOptimizer) echo. set "custom_path=" set /p "custom_path=Installation path: " if "%custom_path%"=="" (
echo No path specified. timeout /t 2 >nul goto selectInstallPath ) set "HUB_PATH=%custom_path%" goto confirmInstallation :showDiskSpace echo.
echo Disk Space Information:
echo for /f "tokens=1,2,3" %%a in ('wmic logicaldisk get size^,freespace^,caption') do ( if not "%%a"=="Caption" if not "%%a"=="" ( set /a "free_gb=%%a/1024/1024/1024" 2>nul set /a "total_gb=%%c/1024/1024/1024" 2>nul if defined free_gb if defined total_gb (
echo Drive %%b: !free_gb! GB free of !total_gb! GB total ) ) ) echo.
echo DevOptimizer Hub requires approximately 100 MB of disk space. echo. pause goto selectInstallPath :confirmInstallation cls echo.
echo
echo INSTALLATION CONFIRMATION
echo echo.
echo Installation Summary:
echo
echo Hub Location: %HUB_PATH%
echo Installer Version: %INSTALLER_VERSION%
echo Administrator: Yes echo.
echo Components to install:
echo Directory structure
echo PowerShell modules (4 modules)
echo Registry entries
echo Environment variables
echo Portable BAT files (2 files)
echo Configuration templates echo. :: Check if path already exists if exist "%HUB_PATH%" (
echo WARNING: Installation directory already exists!
echo Existing files may be overwritten. echo. ) set "final_confirm=" set /p "final_confirm=Proceed with installation? (Y/N): " if /i "%final_confirm%"=="Y" goto startInstallation if /i "%final_confirm%"=="N" (
echo Installation cancelled. pause exit /b 0 )
echo Please enter Y or N. timeout /t 2 >nul goto confirmInstallation :startInstallation cls echo.
echo
echo INSTALLATION IN PROGRESS
echo echo. call :log "INFO" "Starting installation to: %HUB_PATH%"
echo [1/8] Creating directory structure... call :createDirectoryStructure call :updateProgress 12
echo [2/8] Installing PowerShell modules... call :installPowerShellModules call :updateProgress 25
echo [3/8] Configuring registry entries... call :configureRegistry call :updateProgress 37
echo [4/8] Setting environment variables... call :setEnvironmentVariables call :updateProgress 50
echo [5/8] Creating portable BAT files... call :createPortableBATFiles call :updateProgress 62
echo [6/8] Installing configuration templates... call :installConfigurationTemplates call :updateProgress 75
echo [7/8] Setting up Windows integration... call :setupWindowsIntegration call :updateProgress 87
echo [8/8] Finalizing installation... call :finalizeInstallation call :updateProgress 100 echo. call :displaySuccess "DevOptimizer Hub installation completed successfully!" call :log "SUCCESS" "Installation completed successfully" goto installationComplete :: ===================================================== :: INSTALLATION FUNCTIONS :: ===================================================== :createDirectoryStructure call :log "INFO" "Creating directory structure" set "directories=scripts logs config backups templates tools reports exports" for %%d in (%directories%) do ( if not exist "%HUB_PATH%\%%d" ( mkdir "%HUB_PATH%\%%d" >nul 2>&1 if errorlevel 1 ( call :log "ERROR" "Failed to create directory: %HUB_PATH%\%%d"
echo Failed to create: %%d ) else ( call :log "INFO" "Created directory: %HUB_PATH%\%%d"
echo Created: %%d ) ) else (
echo Exists: %%d ) ) exit /b 0 :installPowerShellModules call :log "INFO" "Installing PowerShell modules" :: Check if source modules exist (from current directory) set "source_dir=%~dp0scripts" if not exist "%source_dir%" ( set "source_dir=%~dp0" ) set "modules=DevOptimizer-Core.ps1 Insider-Automation.ps1 Cursor-AI-Module.ps1 Hub-Registry.ps1" for %%m in (%modules%) do ( if exist "%source_dir%\%%m" ( copy "%source_dir%\%%m" "%HUB_PATH%\scripts\%%m" >nul 2>&1 if errorlevel 1 ( call :log "ERROR" "Failed to copy module: %%m"
echo Failed: %%m ) else ( call :log "INFO" "Installed module: %%m"
echo Installed: %%m ) ) else if exist "%%m" ( copy "%%m" "%HUB_PATH%\scripts\%%m" >nul 2>&1 if errorlevel 1 ( call :log "ERROR" "Failed to copy module: %%m"
echo Failed: %%m ) else ( call :log "INFO" "Installed module: %%m"
echo Installed: %%m ) ) else ( call :log "WARNING" "Module not found: %%m"
echo Not found: %%m ) ) exit /b 0 :configureRegistry call :log "INFO" "Configuring registry entries" :: Create system registry entries reg add "HKLM\SOFTWARE\DevOptimizer" /f >nul 2>&1 reg add "HKLM\SOFTWARE\DevOptimizer" /v "HubPath" /t REG_SZ /d "%HUB_PATH%" /f >nul 2>&1 reg add "HKLM\SOFTWARE\DevOptimizer" /v "Version" /t REG_SZ /d "%INSTALLER_VERSION%" /f >nul 2>&1 reg add "HKLM\SOFTWARE\DevOptimizer" /v "InstallDate" /t REG_SZ /d "%date% %time%" /f >nul 2>&1 if errorlevel 1 ( call :log "ERROR" "Failed to create system registry entries"
echo System registry failed ) else ( call :log "INFO" "System registry entries created"
echo System registry configured ) :: Create user registry entries reg add "HKCU\SOFTWARE\DevOptimizer" /f >nul 2>&1 reg add "HKCU\SOFTWARE\DevOptimizer" /v "HubPath" /t REG_SZ /d "%HUB_PATH%" /f >nul 2>&1 reg add "HKCU\SOFTWARE\DevOptimizer" /v "UserPreferences" /t REG_SZ /d "Default" /f >nul 2>&1 if errorlevel 1 ( call :log "ERROR" "Failed to create user registry entries"
echo User registry failed ) else ( call :log "INFO" "User registry entries created"
echo User registry configured ) exit /b 0 :setEnvironmentVariables call :log "INFO" "Setting environment variables" :: Set system environment variable setx DEVOPTIMIZER_HUB "%HUB_PATH%" /M >nul 2>&1 if errorlevel 1 ( call :log "ERROR" "Failed to set system environment variable"
echo System environment variable failed ) else ( call :log "INFO" "System environment variable set"
echo System environment variable set ) :: Set user environment variable setx DEVOPTIMIZER_HUB "%HUB_PATH%" >nul 2>&1 if errorlevel 1 ( call :log "ERROR" "Failed to set user environment variable"
echo User environment variable failed ) else ( call :log "INFO" "User environment variable set"
echo User environment variable set ) :: Set for current session set "DEVOPTIMIZER_HUB=%HUB_PATH%"
echo Current session variable set exit /b 0 :createPortableBATFiles call :log "INFO" "Creating portable BAT files" :: Check if portable BAT files exist in source if exist "%~dp0Portable-DevOptimizer.bat" ( copy "%~dp0Portable-DevOptimizer.bat" "%HUB_PATH%\Portable-DevOptimizer.bat" >nul 2>&1 if errorlevel 1 ( call :log "ERROR" "Failed to copy Portable-DevOptimizer.bat"
echo Failed: Portable-DevOptimizer.bat ) else ( call :log "INFO" "Created Portable-DevOptimizer.bat"
echo Created: Portable-DevOptimizer.bat ) ) else ( call :log "WARNING" "Portable-DevOptimizer.bat not found"
echo Not found: Portable-DevOptimizer.bat ) if exist "%~dp0Portable-InsiderAutomation.bat" ( copy "%~dp0Portable-InsiderAutomation.bat" "%HUB_PATH%\Portable-InsiderAutomation.bat" >nul 2>&1 if errorlevel 1 ( call :log "ERROR" "Failed to copy Portable-InsiderAutomation.bat"
echo Failed: Portable-InsiderAutomation.bat ) else ( call :log "INFO" "Created Portable-InsiderAutomation.bat"
echo Created: Portable-InsiderAutomation.bat ) ) else ( call :log "WARNING" "Portable-InsiderAutomation.bat not found"
echo Not found: Portable-InsiderAutomation.bat ) exit /b 0 :installConfigurationTemplates call :log "INFO" "Installing configuration templates" :: Create default configuration file
echo Creating default configuration... (
echo {
echo "Version": "%INSTALLER_VERSION%",
echo "HubPath": "%HUB_PATH%",
echo "InstallDate": "%date% %time%",
echo "Settings": {
echo "LogLevel": "INFO",
echo "MaxLogFiles": 10,
echo "AutoBackup": true,
echo "BackupRetention": 30
echo },
echo "Modules": {
echo "SystemOptimization": true,
echo "CursorAI": true,
echo "WindowsInsider": true,
echo "DevelopmentTools": true
echo }
echo } ) > "%HUB_PATH%\config\devoptimizer.json" if errorlevel 1 ( call :log "ERROR" "Failed to create default configuration"
echo Default configuration failed ) else ( call :log "INFO" "Default configuration created"
echo Default configuration created ) :: Create BAT registry file
echo {} > "%HUB_PATH%\config\bat-registry.json"
echo BAT registry initialized exit /b 0 :setupWindowsIntegration call :log "INFO" "Setting up Windows integration" :: Create Start Menu shortcuts (optional) set "start_menu=%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\DevOptimizer" if not exist "%start_menu%" mkdir "%start_menu%" >nul 2>&1 :: Create desktop shortcuts (optional)
echo Windows integration configured exit /b 0 :finalizeInstallation call :log "INFO" "Finalizing installation" :: Test hub connectivity powershell -NoProfile -ExecutionPolicy Bypass -File "%HUB_PATH%\scripts\Hub-Registry.ps1" -Operation "test" -Silent >nul 2>&1 if errorlevel 1 ( call :log "WARNING" "Hub connectivity test failed"
echo Hub connectivity test failed ) else ( call :log "INFO" "Hub connectivity test passed"
echo Hub connectivity verified ) :: Create installation completion marker
echo Installation completed: %date% %time% > "%HUB_PATH%\INSTALLATION_COMPLETE.txt"
echo Installer Version: %INSTALLER_VERSION% >> "%HUB_PATH%\INSTALLATION_COMPLETE.txt"
echo Hub Path: %HUB_PATH% >> "%HUB_PATH%\INSTALLATION_COMPLETE.txt"
echo Installation finalized exit /b 0 :: ===================================================== :: COMPLETION SCREEN :: ===================================================== :installationComplete cls echo.
echo
echo INSTALLATION COMPLETE!
echo echo.
echo DevOptimizer Hub has been successfully installed! echo.
echo Installation Details: echo
echo Hub Location: %HUB_PATH%
echo Version: %INSTALLER_VERSION%
echo Installation Date: %date% %time% echo.
echo Available Components:
echo PowerShell Modules (4 modules installed)
echo Portable BAT Files (can be moved anywhere)
echo Registry Integration (system-wide discovery)
echo Environment Variables (session integration)
echo Configuration Templates (ready to customize) echo.
echo Quick Start:
echo 1. Run: %HUB_PATH%\Portable-DevOptimizer.bat
echo 2. Or copy portable BAT files anywhere on your PC
echo 3. They will automatically connect to this hub echo.
echo Next Steps:
echo Test the installation with portable BAT files
echo Customize configuration in: %HUB_PATH%\config\
echo Check logs in: %HUB_PATH%\logs\
echo View installation log: %INSTALLER_LOG% echo. set "launch_choice=" set /p "launch_choice=Launch DevOptimizer now? (Y/N): " if /i "%launch_choice%"=="Y" ( echo.
echo Launching DevOptimizer... start "DevOptimizer" cmd /k "cd /d "%HUB_PATH%" && Portable-DevOptimizer.bat" ) echo.
echo Installation log saved to: %INSTALLER_LOG% echo.
echo Thank you for installing DevOptimizer Hub v%INSTALLER_VERSION%! pause call :log "INFO" "Installation wizard completed" exit /b 0 :: ===================================================== :: UTILITY FUNCTIONS :: ===================================================== :checkAdmin set "IS_ADMIN=0" fsutil dirty query %SystemDrive% >nul 2>&1 if errorlevel 1 ( net session >nul 2>&1 if not errorlevel 1 set "IS_ADMIN=1" ) else ( set "IS_ADMIN=1" ) exit /b 0 :log set "level=%~1" set "message=%~2"
echo %date% %time% - [%level%] %message% >> "%INSTALLER_LOG%" exit /b 0 :updateProgress set "percent=%~1" set /a "bars=%percent%/5" set "progress=" for /l %%i in (1,1,%bars%) do set "progress=!progress!" for /l %%i in (%bars%,1,19) do set "progress=!progress!"
echo [!progress!] %percent%%% exit /b 0 :displaySuccess echo.
echo %~1
echo. exit /b 0 endlocal
