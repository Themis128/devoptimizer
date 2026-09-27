@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

@
echo off setlocal enabledelayedexpansion title DevOptimizer v4.0 Upgrade Deployment Tool color 0F echo.
echo
echo
echo DEVOPTIMIZER v4.0 UPGRADE DEPLOYMENT
echo Complete System Upgrade and Migration Tool
echo
echo echo.
echo UPGRADE DEPLOYMENT SEQUENCE
echo ==============================
echo.
echo This tool will:
echo Migrate existing scripts to new category structure
echo Update all menu systems to v4.0
echo Create missing configuration files
echo Set up the new generator system
echo Register all scripts in the new registry
echo Create comprehensive documentation echo. set /p "CONFIRM=Proceed with upgrade deployment? (y/N): " if /i not "%CONFIRM%"=="y" (
echo Upgrade cancelled. pause exit /b 0 ) echo.
echo PHASE 1: BACKUP AND PREPARATION
echo ==================================
echo. :: Create backup set "BACKUP_DIR=backups\pre-v4-upgrade_%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%" if not exist "backups" mkdir "backups" mkdir "%BACKUP_DIR%" >nul 2>&1
echo Creating backup of current system... for %%f in (*.bat *.ps1 *.json *.md) do ( copy "%%f" "%BACKUP_DIR%\" >nul 2>&1 )
echo Backup created: %BACKUP_DIR% echo.
echo PHASE 2: SCRIPT MIGRATION
echo =============================
echo. :: Auto-categorize existing scripts
echo Analyzing and categorizing existing scripts... :: System optimization scripts for %%f in (*optimization*.bat *system*.bat *registry*.bat *performance*.bat) do ( if exist "%%f" ( if not exist "categories\system" mkdir "categories\system" copy "%%f" "categories\system\" >nul 2>&1
echo Migrated %%f to system category ) ) :: Development tools for %%f in (*dev*.bat *cursor*.bat *vscode*.bat *docker*.bat *wsl*.bat *git*.bat) do ( if exist "%%f" ( if not exist "categories\development" mkdir "categories\development" copy "%%f" "categories\development\" >nul 2>&1
echo Migrated %%f to development category ) ) :: Maintenance scripts for %%f in (*clean*.bat *cache*.bat *temp*.bat *maintenance*.bat) do ( if exist "%%f" ( if not exist "categories\maintenance" mkdir "categories\maintenance" copy "%%f" "categories\maintenance\" >nul 2>&1
echo Migrated %%f to maintenance category ) ) :: AI tools for %%f in (*ai*.bat *ml*.bat *cursor-ai*.bat *insider*.bat) do ( if exist "%%f" ( if not exist "categories\ai-tools" mkdir "categories\ai-tools" copy "%%f" "categories\ai-tools\" >nul 2>&1
echo Migrated %%f to ai-tools category ) ) :: Gaming and streaming for %%f in (*gaming*.bat *gpu*.bat *nvidia*.bat *broadcast*.bat) do ( if exist "%%f" ( if not exist "categories\gaming" mkdir "categories\gaming" copy "%%f" "categories\gaming\" >nul 2>&1
echo Migrated %%f to gaming category ) ) :: Network optimization for %%f in (*network*.bat *wifi*.bat *internet*.bat *dns*.bat) do ( if exist "%%f" ( if not exist "categories\networking" mkdir "categories\networking" copy "%%f" "categories\networking\" >nul 2>&1
echo Migrated %%f to networking category ) ) :: Security scripts for %%f in (*security*.bat *firewall*.bat *defender*.bat *privacy*.bat) do ( if exist "%%f" ( if not exist "categories\security" mkdir "categories\security" copy "%%f" "categories\security\" >nul 2>&1
echo Migrated %%f to security category ) ) :: Everything else goes to utilities for %%f in (*.bat) do ( set "FOUND=false" :: Check if already categorized for /d %%d in (categories\*) do ( if exist "%%d\%%f" set "FOUND=true" ) :: Skip system files if "%%f"=="UPGRADE-DEPLOYMENT.bat" set "FOUND=true" if "%%f"=="DIAGNOSTIC-TEST-SUITE.bat" set "FOUND=true" if "%%f"=="ADVANCED-DIAGNOSTICS.ps1" set "FOUND=true" if "%%f"=="SYSTEM-FIXER-v4.bat" set "FOUND=true" if "!FOUND!"=="false" ( if not exist "categories\utilities" mkdir "categories\utilities" copy "%%f" "categories\utilities\" >nul 2>&1
echo Migrated %%f to utilities category ) ) echo.
echo PHASE 3: MENU SYSTEM UPDATE
echo ===============================
echo.
echo Generating new dynamic menu system... if exist "generators\MENU-GENERATOR.bat" ( call "generators\MENU-GENERATOR.bat" >nul 2>&1
echo Dynamic menus generated ) else (
echo Menu generator not found - manual menu creation needed ) echo.
echo PHASE 4: CONFIGURATION SETUP
echo ===============================
echo. :: Ensure all config files exist if not exist "config\system-config.json" (
echo Creating system configuration... powershell -ExecutionPolicy Bypass -Command "$config = @{ devOptimizer = @{ version = '4.0.0'; hubPath = (Get-Location).Path; settings = @{ autoDiscovery = $true; dynamicMenus = $true; logging = $true; categoryGrouping = $true } } }; $config | ConvertTo-Json -Depth 5 | Out-File -FilePath 'config\system-config.json' -Encoding UTF8"
echo System configuration created ) if not exist "registry\script-registry.json" (
echo Creating script registry... powershell -ExecutionPolicy Bypass -Command "$registry = @{ scriptRegistry = @{ version = '4.0.0'; totalScripts = 0; autoDiscovery = $true; scripts = @{} } }; $registry | ConvertTo-Json -Depth 3 | Out-File -FilePath 'registry\script-registry.json' -Encoding UTF8"
echo Script registry created ) echo.
echo PHASE 5: DOCUMENTATION CREATION
echo ==================================
echo. :: Create comprehensive README
echo Creating updated documentation... > "README-v4.md" (
echo # DevOptimizer v4.0 - Advanced Modular System echo.
echo ## What's New in v4.0 echo.
echo ### Major Improvements
echo - **Modular Category Structure** - Scripts organized by function
echo - **Dynamic Menu Generation** - Auto-updating menu system
echo - **Script Template Generator** - Easy creation of new scripts
echo - **Configuration-Driven System** - JSON-based configuration
echo - **Advanced Diagnostics** - Comprehensive system analysis
echo - **Automated Script Discovery** - Self-registering script system echo.
echo ### New Directory Structure
echo ```
echo DevOptimizer/
echo categories/ # Organized script categories
echo system/ # System optimization scripts
echo development/ # Development tools
echo maintenance/ # Cleanup and maintenance
echo ai-tools/ # AI and ML tools
echo gaming/ # Gaming and streaming
echo networking/ # Network optimization
echo security/ # Security and privacy
echo utilities/ # General utilities
echo generators/ # Script and menu generators
echo config/ # System configuration files
echo registry/ # Script registry and metadata
echo logs/ # System logs
echo backups/ # Automatic backups
echo docs/ # Documentation
echo ```
echo. echo ### How to Use v4.0 echo.
echo #### Quick Start
echo 1. **Run Main Launcher**: `00-DYNAMIC-LAUNCHER.bat`
echo 2. **Browse Categories**: Navigate through organized script categories
echo 3. **Execute Scripts**: Select and run individual optimization tools echo.
echo #### Adding New Scripts
echo 1. **Use Script Generator**: Run `generators\SCRIPT-GENERATOR.bat`
echo 2. **Follow Wizard**: Provide script details and category
echo 3. **Customize Logic**: Edit the generated template
echo 4. **Update Menus**: Run `generators\MENU-GENERATOR.bat` echo.
echo #### System Maintenance
echo - **Diagnostics**: Run `DIAGNOSTIC-TEST-SUITE.bat` for health checks
echo - **Advanced Analysis**: Use `ADVANCED-DIAGNOSTICS.ps1` for detailed reports
echo - **System Repair**: Execute `SYSTEM-FIXER-v4.bat` for issue resolution echo.
echo ### Configuration Files echo.
echo #### system-config.json
echo Main system configuration including categories, settings, and paths. echo.
echo #### script-registry.json
echo Automatic registry of all scripts with metadata and categorization. echo.
echo ### Development Features echo.
echo #### Script Templates
echo - Auto-generated BAT and PowerShell templates
echo - Built-in error handling and logging
echo - Admin privilege checking
echo - Consistent formatting and structure echo.
echo #### Dynamic Menus
echo - Automatic menu generation from script discovery
echo - Category-based organization
echo - Self-updating when scripts are added/removed echo.
echo ### Diagnostics and Troubleshooting echo.
echo #### Common Issues
echo - **File Locks**: Run system fixer to resolve
echo - **PowerShell Execution Policy**: Automatically configured
echo - **Missing Directories**: Auto-created on first run
echo - **Registry Issues**: Automatic registry repair echo.
echo #### Health Monitoring
echo - Real-time system resource monitoring
echo - Script execution tracking
echo - Error logging and reporting
echo - Performance metrics collection echo.
echo ### Migration from v3.x
echo.
echo Your existing scripts have been automatically migrated to the new category structure:
echo - Original files backed up to `backups\pre-v4-upgrade_[timestamp]\`
echo - Scripts auto-categorized based on naming patterns
echo - Legacy launchers preserved for compatibility echo.
echo ### Backward Compatibility
echo.
echo v4.0 maintains compatibility with existing scripts while providing new features:
echo - Legacy BAT files continue to work
echo - Original menu system preserved
echo - Gradual migration path available echo.
echo ### Best Practices echo.
echo #### Script Development
echo 1. Use the Script Generator for new scripts
echo 2. Follow the template structure for consistency
echo 3. Add proper error handling and logging
echo 4. Test scripts before deployment
echo 5. Document complex functionality echo.
echo #### System Management
echo 1. Run diagnostics regularly
echo 2. Keep backups of important configurations
echo 3. Update menus when adding new scripts
echo 4. Monitor system logs for issues
echo 5. Use categories to organize functionality echo.
echo ---
echo **DevOptimizer v4.0** - Advanced Windows Development Optimization System
echo Created: %date% %time%
echo Compatibility: Windows 10/11, PowerShell 5.1+ )
echo Documentation created: README-v4.md echo.
echo UPGRADE DEPLOYMENT COMPLETED!
echo ================================
echo. :: Generate summary report set "REPORT_FILE=logs\upgrade-deployment_%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
echo Upgrade Deployment Report - %date% %time% > "%REPORT_FILE%"
echo ================================================ >> "%REPORT_FILE%" echo. >> "%REPORT_FILE%"
echo System backed up to: %BACKUP_DIR% >> "%REPORT_FILE%"
echo Scripts migrated to category structure >> "%REPORT_FILE%"
echo Dynamic menu system generated >> "%REPORT_FILE%"
echo Configuration files created >> "%REPORT_FILE%"
echo Documentation updated >> "%REPORT_FILE%" echo. >> "%REPORT_FILE%"
echo DEPLOYMENT SUMMARY:
echo System backed up to: %BACKUP_DIR%
echo Scripts migrated to categories
echo Dynamic menus generated
echo Configuration system deployed
echo Documentation created
echo Deployment log: %REPORT_FILE% echo.
echo NEXT STEPS:
echo 1. Test the new 00-DYNAMIC-LAUNCHER.bat
echo 2. Explore the categorized script structure
echo 3. Try the Script Generator to create new tools
echo 4. Run diagnostics to verify system health
echo 5. Read README-v4.md for complete documentation echo.
echo Welcome to DevOptimizer v4.0!
echo Your system is now upgraded and ready for advanced development optimization. echo. set /p "LAUNCH_NEW=Launch the new dynamic menu system now? (y/N): " if /i "%LAUNCH_NEW%"=="y" ( if exist "00-DYNAMIC-LAUNCHER.bat" ( echo.
echo Launching DevOptimizer v4.0... call "00-DYNAMIC-LAUNCHER.bat" ) else (
echo Dynamic launcher not found. Please run the Menu Generator first. ) ) echo.
echo Thank you for upgrading to DevOptimizer v4.0! pause endlocal
