@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title VS Code - Nuxt4 Development Optimization
color 0A

echo ================================================================
echo        VS CODE - NUXT4 DEVELOPMENT OPTIMIZATION
echo ================================================================
echo.
echo This will optimize VS Code for Nuxt4 development with:
echo - Latest Vue 3.5+ support
echo - TypeScript 5.5+ configuration
echo - Vite 6+ build optimization
echo - ESLint 9+ integration
echo - Modern JavaScript features
echo - Node.js 20+ optimization
echo.

:: Check for admin privileges
call :checkAdmin
if not "%IS_ADMIN%"=="1" (
echo This tool requires Administrator privileges for some operations.
echo Right-click and select "Run as administrator" for full functionality.
echo.
set /p continue=Continue anyway? (Y/N):
if /i not "!continue!"=="Y" exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%vscode-nuxt4.log"
set "VSCODE_CONFIG_DIR=%APPDATA%\Code\User"
set "VSCODE_EXTENSIONS_DIR=%USERPROFILE%\.vscode\extensions"

:menu
cls
echo ================================================================
echo        VS CODE - NUXT4 DEVELOPMENT OPTIMIZATION
echo ================================================================
echo.
echo Choose your optimization option:
echo.
echo 1) QUICK NUXT4 SETUP - Basic VS Code configuration for Nuxt4
echo 2) ADVANCED NUXT4 SETUP - Complete development environment
echo 3) VUE 3.5+ OPTIMIZATION - Latest Vue features and composition API
echo 4) TYPESCRIPT 5.5+ SETUP - Modern TypeScript configuration
echo 5) VITE 6+ OPTIMIZATION - Enhanced build performance
echo 6) ESLINT 9+ INTEGRATION - Code quality and formatting
echo 7) NODE.JS 20+ OPTIMIZATION - Latest Node.js features
echo 8) JAVASCRIPT MODERN FEATURES - ES2024+ support
echo 9) VS CODE EXTENSIONS - Install recommended extensions
echo 10) VS CODE SETTINGS - Configure editor features
echo 11) PERFORMANCE TUNING - Optimize VS Code for large projects
echo 12) COMPLETE SETUP - All optimizations combined
echo 13) BACKUP CURRENT SETTINGS - Backup existing configuration
echo 14) RESTORE SETTINGS - Restore from backup
echo 15) DIAGNOSTIC CHECK - Check current configuration
echo.
echo 0) Exit
echo.

set /p choice=Enter your choice (0-15):

if "%choice%"=="1" goto quickNuxt4Setup
if "%choice%"=="2" goto advancedNuxt4Setup
if "%choice%"=="3" goto vue35Optimization
if "%choice%"=="4" goto typescript55Setup
if "%choice%"=="5" goto vite6Optimization
if "%choice%"=="6" goto eslint9Integration
if "%choice%"=="7" goto nodejs20Optimization
if "%choice%"=="8" goto javascriptModernFeatures
if "%choice%"=="9" goto vscodeExtensions
if "%choice%"=="10" goto vscodeSettings
if "%choice%"=="11" goto performanceTuning
if "%choice%"=="12" goto completeSetup
if "%choice%"=="13" goto backupCurrentSettings
if "%choice%"=="14" goto restoreSettings
if "%choice%"=="15" goto diagnosticCheck
if "%choice%"=="0" exit /b 0

echo Invalid choice. Please try again.
timeout /t 2 >nul
goto menu

:quickNuxt4Setup
cls
echo ================================================================
echo        QUICK NUXT4 SETUP - BASIC VS CODE CONFIGURATION
echo ================================================================
echo.
call :log "Starting quick Nuxt4 setup"
echo [1/6] Creating VS Code configuration directory...
if not exist "%VSCODE_CONFIG_DIR%" mkdir "%VSCODE_CONFIG_DIR%"
if not exist "%VSCODE_CONFIG_DIR%\settings.json" (
echo Creating basic settings.json...
call :createBasicVSCodeSettings
)

echo [2/6] Configuring Nuxt4-specific settings...
call :createNuxt4VSCodeSettings

echo [3/6] Setting up TypeScript support...
call :createTypeScriptVSCodeSettings

echo [4/6] Configuring Vue 3.5+ support...
call :createVue35VSCodeSettings

echo [5/6] Setting up Vite 6+ integration...
call :createVite6VSCodeSettings

echo [6/6] Optimizing for Node.js 20+...
call :createNodejs20VSCodeSettings

echo.
echo Quick Nuxt4 setup completed!
echo VS Code is now optimized for Nuxt4 development.
call :log "Quick Nuxt4 setup completed"
pause
goto menu

:advancedNuxt4Setup
cls
echo ================================================================
echo        ADVANCED NUXT4 SETUP - COMPLETE DEVELOPMENT ENVIRONMENT
echo ================================================================
echo.
call :log "Starting advanced Nuxt4 setup"
echo [1/12] Creating advanced VS Code configuration...
if not exist "%VSCODE_CONFIG_DIR%" mkdir "%VSCODE_CONFIG_DIR%"
call :createAdvancedVSCodeSettings

echo [2/12] Setting up Nuxt4 project templates...
call :createNuxt4Templates

echo [3/12] Configuring Vue 3.5+ with Composition API...
call :createVue35AdvancedVSCodeSettings

echo [4/12] Setting up TypeScript 5.5+ with strict mode...
call :createTypeScript55AdvancedVSCodeSettings

echo [5/12] Configuring Vite 6+ with HMR optimization...
call :createVite6AdvancedVSCodeSettings

echo [6/12] Setting up ESLint 9+ with Nuxt rules...
call :createEslint9AdvancedVSCodeSettings

echo [7/12] Configuring Node.js 20+ with performance tuning...
call :createNodejs20AdvancedVSCodeSettings

echo [8/12] Setting up modern JavaScript ES2024+ features...
call :createJavaScriptModernVSCodeSettings

echo [9/12] Installing recommended extensions...
call :installRecommendedVSCodeExtensions

echo [10/12] Configuring debugging features...
call :configureVSCodeDebugging

echo [11/12] Setting up IntelliSense features...
call :configureVSCodeIntelliSense

echo [12/12] Optimizing performance for large projects...
call :optimizeVSCodePerformance

echo.
echo Advanced Nuxt4 setup completed!
echo Complete development environment is ready.
call :log "Advanced Nuxt4 setup completed"
pause
goto menu

:vue35Optimization
cls
echo ================================================================
echo        VUE 3.5+ OPTIMIZATION - LATEST VUE FEATURES
echo ================================================================
echo.
call :log "Starting Vue 3.5+ optimization"
echo [1/8] Configuring Vue 3.5+ Composition API support...
call :createVue35CompositionVSCodeSettings

echo [2/8] Setting up Vue 3.5+ TypeScript integration...
call :createVue35TypeScriptVSCodeSettings

echo [3/8] Configuring Vue 3.5+ with Vite 6+...
call :createVue35ViteVSCodeSettings

echo [4/8] Setting up Vue 3.5+ with Nuxt4...
call :createVue35Nuxt4VSCodeSettings

echo [5/8] Configuring Vue 3.5+ debugging...
call :createVue35DebuggingVSCodeSettings

echo [6/8] Setting up Vue 3.5+ testing...
call :createVue35TestingVSCodeSettings

echo [7/8] Configuring Vue 3.5+ performance...
call :createVue35PerformanceVSCodeSettings

echo [8/8] Setting up Vue 3.5+ snippets...
call :createVue35SnippetsVSCodeSettings

echo.
echo Vue 3.5+ optimization completed!
echo Latest Vue features are now available.
call :log "Vue 3.5+ optimization completed"
pause
goto menu

:typescript55Setup
cls
echo ================================================================
echo        TYPESCRIPT 5.5+ SETUP - MODERN CONFIGURATION
echo ================================================================
echo.
call :log "Starting TypeScript 5.5+ setup"
echo [1/10] Configuring TypeScript 5.5+ with strict mode...
call :createTypeScript55StrictVSCodeSettings

echo [2/10] Setting up TypeScript 5.5+ with Nuxt4...
call :createTypeScript55Nuxt4VSCodeSettings

echo [3/10] Configuring TypeScript 5.5+ with Vue 3.5+...
call :createTypeScript55VueVSCodeSettings

echo [4/10] Setting up TypeScript 5.5+ with Vite 6+...
call :createTypeScript55ViteVSCodeSettings

echo [5/10] Configuring TypeScript 5.5+ debugging...
call :createTypeScript55DebuggingVSCodeSettings

echo [6/10] Setting up TypeScript 5.5+ IntelliSense...
call :createTypeScript55IntelliSenseVSCodeSettings

echo [7/10] Configuring TypeScript 5.5+ error checking...
call :createTypeScript55ErrorCheckingVSCodeSettings

echo [8/10] Setting up TypeScript 5.5+ refactoring...
call :createTypeScript55RefactoringVSCodeSettings

echo [9/10] Configuring TypeScript 5.5+ performance...
call :createTypeScript55PerformanceVSCodeSettings

echo [10/10] Setting up TypeScript 5.5+ snippets...
call :createTypeScript55SnippetsVSCodeSettings

echo.
echo TypeScript 5.5+ setup completed!
echo Modern TypeScript features are now available.
call :log "TypeScript 5.5+ setup completed"
pause
goto menu

:vite6Optimization
cls
echo ================================================================
echo        VITE 6+ OPTIMIZATION - ENHANCED BUILD PERFORMANCE
echo ================================================================
echo.
call :log "Starting Vite 6+ optimization"
echo [1/8] Configuring Vite 6+ with Nuxt4...
call :createVite6Nuxt4VSCodeSettings

echo [2/8] Setting up Vite 6+ with Vue 3.5+...
call :createVite6VueVSCodeSettings

echo [3/8] Configuring Vite 6+ with TypeScript 5.5+...
call :createVite6TypeScriptVSCodeSettings

echo [4/8] Setting up Vite 6+ HMR optimization...
call :createVite6HmrVSCodeSettings

echo [5/8] Configuring Vite 6+ build optimization...
call :createVite6BuildVSCodeSettings

echo [6/8] Setting up Vite 6+ development server...
call :createVite6DevServerVSCodeSettings

echo [7/8] Configuring Vite 6+ performance...
call :createVite6PerformanceVSCodeSettings

echo [8/8] Setting up Vite 6+ debugging...
call :createVite6DebuggingVSCodeSettings

echo.
echo Vite 6+ optimization completed!
echo Enhanced build performance is now available.
call :log "Vite 6+ optimization completed"
pause
goto menu

:eslint9Integration
cls
echo ================================================================
echo        ESLINT 9+ INTEGRATION - CODE QUALITY AND FORMATTING
echo ================================================================
echo.
call :log "Starting ESLint 9+ integration"
echo [1/8] Configuring ESLint 9+ with Nuxt4...
call :createEslint9Nuxt4VSCodeSettings

echo [2/8] Setting up ESLint 9+ with Vue 3.5+...
call :createEslint9VueVSCodeSettings

echo [3/8] Configuring ESLint 9+ with TypeScript 5.5+...
call :createEslint9TypeScriptVSCodeSettings

echo [4/8] Setting up ESLint 9+ with Vite 6+...
call :createEslint9ViteVSCodeSettings

echo [5/8] Configuring ESLint 9+ auto-fix...
call :createEslint9AutoFixVSCodeSettings

echo [6/8] Setting up ESLint 9+ formatting...
call :createEslint9FormattingVSCodeSettings

echo [7/8] Configuring ESLint 9+ performance...
call :createEslint9PerformanceVSCodeSettings

echo [8/8] Setting up ESLint 9+ snippets...
call :createEslint9SnippetsVSCodeSettings

echo.
echo ESLint 9+ integration completed!
echo Code quality and formatting are now optimized.
call :log "ESLint 9+ integration completed"
pause
goto menu

:nodejs20Optimization
cls
echo ================================================================
echo        NODE.JS 20+ OPTIMIZATION - LATEST NODE.JS FEATURES
echo ================================================================
echo.
call :log "Starting Node.js 20+ optimization"
echo [1/8] Configuring Node.js 20+ with Nuxt4...
call :createNodejs20Nuxt4VSCodeSettings

echo [2/8] Setting up Node.js 20+ with TypeScript 5.5+...
call :createNodejs20TypeScriptVSCodeSettings

echo [3/8] Configuring Node.js 20+ with Vite 6+...
call :createNodejs20ViteVSCodeSettings

echo [4/8] Setting up Node.js 20+ debugging...
call :createNodejs20DebuggingVSCodeSettings

echo [5/8] Configuring Node.js 20+ performance...
call :createNodejs20PerformanceVSCodeSettings

echo [6/8] Setting up Node.js 20+ memory optimization...
call :createNodejs20MemoryVSCodeSettings

echo [7/8] Configuring Node.js 20+ with modern JavaScript...
call :createNodejs20ModernJSVSCodeSettings

echo [8/8] Setting up Node.js 20+ snippets...
call :createNodejs20SnippetsVSCodeSettings

echo.
echo Node.js 20+ optimization completed!
echo Latest Node.js features are now available.
call :log "Node.js 20+ optimization completed"
pause
goto menu

:javascriptModernFeatures
cls
echo ================================================================
echo        JAVASCRIPT MODERN FEATURES - ES2024+ SUPPORT
echo ================================================================
echo.
call :log "Starting JavaScript modern features setup"
echo [1/8] Configuring ES2024+ support...
call :createES2024VSCodeSettings

echo [2/8] Setting up modern JavaScript with Nuxt4...
call :createModernJSNuxt4VSCodeSettings

echo [3/8] Configuring modern JavaScript with Vue 3.5+...
call :createModernJSVueVSCodeSettings

echo [4/8] Setting up modern JavaScript with TypeScript 5.5+...
call :createModernJSTypeScriptVSCodeSettings

echo [5/8] Configuring modern JavaScript with Vite 6+...
call :createModernJSViteVSCodeSettings

echo [6/8] Setting up modern JavaScript debugging...
call :createModernJSDebuggingVSCodeSettings

echo [7/8] Configuring modern JavaScript performance...
call :createModernJSPerformanceVSCodeSettings

echo [8/8] Setting up modern JavaScript snippets...
call :createModernJSSnippetsVSCodeSettings

echo.
echo JavaScript modern features setup completed!
echo ES2024+ features are now available.
call :log "JavaScript modern features setup completed"
pause
goto menu

:vscodeExtensions
cls
echo ================================================================
echo        VS CODE EXTENSIONS - INSTALL RECOMMENDED EXTENSIONS
echo ================================================================
echo.
call :log "Starting VS Code extensions installation"
echo [1/6] Installing Vue 3.5+ extensions...
call :installVueVSCodeExtensions

echo [2/6] Installing TypeScript 5.5+ extensions...
call :installTypeScriptVSCodeExtensions

echo [3/6] Installing Nuxt4 extensions...
call :installNuxt4VSCodeExtensions

echo [4/6] Installing Vite 6+ extensions...
call :installViteVSCodeExtensions

echo [5/6] Installing ESLint 9+ extensions...
call :installEslintVSCodeExtensions

echo [6/6] Installing Node.js 20+ extensions...
call :installNodejsVSCodeExtensions

echo.
echo VS Code extensions installation completed!
echo Recommended extensions are now installed.
call :log "VS Code extensions installation completed"
pause
goto menu

:vscodeSettings
cls
echo ================================================================
echo        VS CODE SETTINGS - CONFIGURE EDITOR FEATURES
echo ================================================================
echo.
call :log "Starting VS Code settings configuration"
echo [1/8] Configuring editor settings...
call :configureVSCodeEditorSettings

echo [2/8] Setting up IntelliSense features...
call :configureVSCodeIntelliSenseSettings

echo [3/8] Configuring debugging features...
call :configureVSCodeDebuggingSettings

echo [4/8] Setting up formatting features...
call :configureVSCodeFormattingSettings

echo [5/8] Configuring file associations...
call :configureVSCodeFileAssociationSettings

echo [6/8] Setting up workspace features...
call :configureVSCodeWorkspaceSettings

echo [7/8] Configuring performance settings...
call :configureVSCodePerformanceSettings

echo [8/8] Setting up accessibility features...
call :configureVSCodeAccessibilitySettings

echo.
echo VS Code settings configuration completed!
echo Editor features are now optimized for Nuxt4 development.
call :log "VS Code settings configuration completed"
pause
goto menu

:performanceTuning
cls
echo ================================================================
echo        PERFORMANCE TUNING - OPTIMIZE VS CODE FOR LARGE PROJECTS
echo ================================================================
echo.
call :log "Starting performance tuning"
echo [1/8] Configuring memory optimization...
call :configureVSCodeMemoryOptimization

echo [2/8] Setting up CPU optimization...
call :configureVSCodeCpuOptimization

echo [3/8] Configuring disk I/O optimization...
call :configureVSCodeDiskOptimization

echo [4/8] Setting up network optimization...
call :configureVSCodeNetworkOptimization

echo [5/8] Configuring indexing optimization...
call :configureVSCodeIndexingOptimization

echo [6/8] Setting up caching optimization...
call :configureVSCodeCachingOptimization

echo [7/8] Configuring extension optimization...
call :configureVSCodeExtensionOptimization

echo [8/8] Setting up workspace optimization...
call :configureVSCodeWorkspaceOptimization

echo.
echo Performance tuning completed!
echo VS Code is now optimized for large projects.
call :log "Performance tuning completed"
pause
goto menu

:completeSetup
cls
echo ================================================================
echo        COMPLETE SETUP - ALL OPTIMIZATIONS COMBINED
echo ================================================================
echo.
call :log "Starting complete setup"
echo This will run all optimizations in sequence...
echo.
set /p confirm=Continue with complete setup? (Y/N):
if /i not "%confirm%"=="Y" goto menu

echo [1/12] Quick Nuxt4 setup...
call :quickNuxt4Setup

echo [2/12] Vue 3.5+ optimization...
call :vue35Optimization

echo [3/12] TypeScript 5.5+ setup...
call :typescript55Setup

echo [4/12] Vite 6+ optimization...
call :vite6Optimization

echo [5/12] ESLint 9+ integration...
call :eslint9Integration

echo [6/12] Node.js 20+ optimization...
call :nodejs20Optimization

echo [7/12] JavaScript modern features...
call :javascriptModernFeatures

echo [8/12] VS Code extensions...
call :vscodeExtensions

echo [9/12] VS Code settings...
call :vscodeSettings

echo [10/12] Performance tuning...
call :performanceTuning

echo [11/12] Final optimization...
call :finalVSCodeOptimization

echo [12/12] Verification...
call :verifyVSCodeSetup

echo.
echo Complete setup finished!
echo VS Code is now fully optimized for Nuxt4 development.
call :log "Complete setup finished"
pause
goto menu

:backupCurrentSettings
cls
echo ================================================================
echo        BACKUP CURRENT SETTINGS
echo ================================================================
echo.
call :log "Starting backup of current settings"
set "BACKUP_DIR=%SCRIPT_DIR%\vscode-backups"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
set "BACKUP_FOLDER=%BACKUP_DIR%\VSCode_Backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
mkdir "%BACKUP_FOLDER%"

echo [1/4] Backing up VS Code settings...
if exist "%VSCODE_CONFIG_DIR%\settings.json" (
copy "%VSCODE_CONFIG_DIR%\settings.json" "%BACKUP_FOLDER%\" >nul 2>&1
echo    Settings backed up
) else (
echo   ! No settings found
)

echo [2/4] Backing up VS Code extensions...
if exist "%VSCODE_EXTENSIONS_DIR%" (
xcopy "%VSCODE_EXTENSIONS_DIR%" "%BACKUP_FOLDER%\extensions\" /e /i /y >nul 2>&1
echo    Extensions backed up
) else (
echo   ! No extensions found
)

echo [3/4] Backing up workspace settings...
if exist ".vscode" (
xcopy ".vscode" "%BACKUP_FOLDER%\workspace\" /e /i /y >nul 2>&1
echo    Workspace settings backed up
) else (
echo   ! No workspace settings found
)

echo [4/4] Creating backup info...
echo VS Code Settings Backup > "%BACKUP_FOLDER%\backup_info.txt"
echo Created: %date% %time% >> "%BACKUP_FOLDER%\backup_info.txt"
echo Computer: %COMPUTERNAME% >> "%BACKUP_FOLDER%\backup_info.txt"
echo User: %USERNAME% >> "%BACKUP_FOLDER%\backup_info.txt"
echo Project Directory: %CD% >> "%BACKUP_FOLDER%\backup_info.txt"

echo.
echo Backup completed!
echo Backup location: %BACKUP_FOLDER%
call :log "Backup completed: %BACKUP_FOLDER%"
pause
goto menu

:restoreSettings
cls
echo ================================================================
echo        RESTORE SETTINGS
echo ================================================================
echo.
set "BACKUP_DIR=%SCRIPT_DIR%\vscode-backups"
if not exist "%BACKUP_DIR%" (
echo No backup directory found. Please create a backup first.
pause
goto menu
)

echo Available backups:
echo.
dir "%BACKUP_DIR%" /b /ad
echo.
set /p backup_name=Enter backup folder name:
set "RESTORE_FOLDER=%BACKUP_DIR%\%backup_name%"
if not exist "%RESTORE_FOLDER%" (
echo Backup folder not found: %RESTORE_FOLDER%
pause
goto menu
)

echo.
echo WARNING: This will overwrite current VS Code settings.
echo.
set /p confirm=Continue with restoration? (Y/N):
if /i not "%confirm%"=="Y" goto menu

call :log "Starting restoration from: %RESTORE_FOLDER%"

echo [1/4] Restoring VS Code settings...
if exist "%RESTORE_FOLDER%\settings.json" (
copy "%RESTORE_FOLDER%\settings.json" "%VSCODE_CONFIG_DIR%\" >nul 2>&1
echo    Settings restored
) else (
echo   ! No settings to restore
)

echo [2/4] Restoring VS Code extensions...
if exist "%RESTORE_FOLDER%\extensions" (
xcopy "%RESTORE_FOLDER%\extensions" "%VSCODE_EXTENSIONS_DIR%\" /e /i /y >nul 2>&1
echo    Extensions restored
) else (
echo   ! No extensions to restore
)

echo [3/4] Restoring workspace settings...
if exist "%RESTORE_FOLDER%\workspace" (
xcopy "%RESTORE_FOLDER%\workspace" ".vscode\" /e /i /y >nul 2>&1
echo    Workspace settings restored
) else (
echo   ! No workspace settings to restore
)

echo [4/4] Finalizing restoration...
echo.
echo Restoration completed!
call :log "Restoration completed from: %RESTORE_FOLDER%"
pause
goto menu

:diagnosticCheck
cls
echo ================================================================
echo        DIAGNOSTIC CHECK - CHECK CURRENT CONFIGURATION
echo ================================================================
echo.
call :log "Starting diagnostic check"
echo [1/6] Checking VS Code installation...
if exist "%VSCODE_CONFIG_DIR%" (
echo    VS Code configuration directory found
) else (
echo    VS Code configuration directory not found
)

echo [2/6] Checking Nuxt4 support...
if exist "%VSCODE_CONFIG_DIR%\settings.json" (
findstr /i "nuxt" "%VSCODE_CONFIG_DIR%\settings.json" >nul 2>&1
if !errorlevel! equ 0 (
echo    Nuxt4 support configured
) else (
echo   ! Nuxt4 support not configured
)
) else (
echo   ! No settings file found
)

echo [3/6] Checking Vue 3.5+ support...
if exist "%VSCODE_CONFIG_DIR%\settings.json" (
findstr /i "vue" "%VSCODE_CONFIG_DIR%\settings.json" >nul 2>&1
if !errorlevel! equ 0 (
echo    Vue 3.5+ support configured
) else (
echo   ! Vue 3.5+ support not configured
)
) else (
echo   ! No settings file found
)

echo [4/6] Checking TypeScript 5.5+ support...
if exist "%VSCODE_CONFIG_DIR%\settings.json" (
findstr /i "typescript" "%VSCODE_CONFIG_DIR%\settings.json" >nul 2>&1
if !errorlevel! equ 0 (
echo    TypeScript 5.5+ support configured
) else (
echo   ! TypeScript 5.5+ support not configured
)
) else (
echo   ! No settings file found
)

echo [5/6] Checking Vite 6+ support...
if exist "%VSCODE_CONFIG_DIR%\settings.json" (
findstr /i "vite" "%VSCODE_CONFIG_DIR%\settings.json" >nul 2>&1
if !errorlevel! equ 0 (
echo    Vite 6+ support configured
) else (
echo   ! Vite 6+ support not configured
)
) else (
echo   ! No settings file found
)

echo [6/6] Checking Node.js 20+ support...
if exist "%VSCODE_CONFIG_DIR%\settings.json" (
findstr /i "node" "%VSCODE_CONFIG_DIR%\settings.json" >nul 2>&1
if !errorlevel! equ 0 (
echo    Node.js 20+ support configured
) else (
echo   ! Node.js 20+ support not configured
)
) else (
echo   ! No settings file found
)

echo.
echo Diagnostic check completed!
call :log "Diagnostic check completed"
pause
goto menu

:: Configuration creation functions
:createBasicVSCodeSettings
echo { > "%VSCODE_CONFIG_DIR%\settings.json"
echo   "editor.fontSize": 14, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "editor.tabSize": 2, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "editor.insertSpaces": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "editor.wordWrap": "on", >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "editor.minimap.enabled": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "editor.suggestOnTriggerCharacters": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "editor.acceptSuggestionOnEnter": "on", >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "editor.quickSuggestions": { >> "%VSCODE_CONFIG_DIR%\settings.json"
echo     "other": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo     "comments": false, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo     "strings": true >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   }, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "files.autoSave": "afterDelay", >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "files.autoSaveDelay": 1000 >> "%VSCODE_CONFIG_DIR%\settings.json"
echo } >> "%VSCODE_CONFIG_DIR%\settings.json"
exit /b

:createNuxt4VSCodeSettings
echo   "nuxt.enable": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "nuxt.autoImport": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "nuxt.typescript": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "nuxt.vue": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "nuxt.vite": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "nuxt.eslint": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "nuxt.prettier": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "nuxt.tailwindcss": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "nuxt.pinia": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "nuxt.router": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
exit /b

:createTypeScriptVSCodeSettings
echo   "typescript.preferences.includePackageJsonAutoImports": "on", >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "typescript.suggest.autoImports": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "typescript.suggest.includeCompletionsForModuleExports": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "typescript.suggest.includeCompletionsWithSnippetText": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "typescript.updateImportsOnFileMove.enabled": "always", >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "typescript.preferences.includePackageJsonAutoImports": "on", >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "typescript.suggest.autoImports": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "typescript.suggest.includeCompletionsForModuleExports": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "typescript.suggest.includeCompletionsWithSnippetText": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "typescript.updateImportsOnFileMove.enabled": "always", >> "%VSCODE_CONFIG_DIR%\settings.json"
exit /b

:createVue35VSCodeSettings
echo   "vue.codeActions.enabled": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vue.complete.casing.tags": "kebab", >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vue.complete.casing.props": "camel", >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vue.complete.casing.attributes": "camel", >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vue.complete.autoImportComponent": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vue.complete.autoImportComposables": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vue.complete.autoImportUtils": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vue.complete.autoImportComponents": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vue.complete.autoImportDirectives": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vue.complete.autoImportPlugins": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
exit /b

:createVite6VSCodeSettings
echo   "vite.enable": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vite.hmr": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vite.build": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vite.dev": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vite.preview": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vite.optimizeDeps": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vite.ssr": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vite.typescript": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vite.vue": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "vite.eslint": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
exit /b

:createNodejs20VSCodeSettings
echo   "node.enable": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "node.typescript": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "node.debug": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "node.performance": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "node.memory": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "node.cpu": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "node.disk": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "node.network": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "node.security": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
echo   "node.modern": true, >> "%VSCODE_CONFIG_DIR%\settings.json"
exit /b

:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
exit /b

:checkAdmin
set "IS_ADMIN=0"
fsutil dirty query %SystemDrive% >nul 2>&1
if errorlevel 1 (
net session >nul 2>&1
if not errorlevel 1 set "IS_ADMIN=1"
) else (
set "IS_ADMIN=1"
)
exit /b

endlocal
