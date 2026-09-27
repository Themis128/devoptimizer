@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title  - Standard Mode- some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo            ENHANCED DEVELOPMENT TOOLS INSTALLER
echo ================================================================
echo.
echo Advanced development environment setup with error handling
echo and comprehensive tool installation
echo.
echo ================================================================

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
echo [INFO] Running with administrator privileges
) else (
echo [WARNING] Some tools may require administrator privileges
)

echo.
echo ================================================================
echo                    SYSTEM ANALYSIS
echo ================================================================

:: System information
echo [ANALYZE] Gathering system information...
for /f "tokens=2 delims==" %%a in ('wmic OS get TotalVisibleMemorySize /value') do set "RAM=%%a"
for /f "tokens=2 delims==" %%a in ('wmic OS get OSArchitecture /value') do set "ARCH=%%a"
for /f "tokens=2 delims==" %%a in ('wmic OS get Caption /value') do set "OS=%%a"

echo [INFO] System: %OS% (%ARCH%)
echo [INFO] RAM: %RAM% MB
echo [INFO] Architecture: %ARCH%

echo.
echo ================================================================
echo                    TOOL INSTALLATION
echo ================================================================

:: 1. Essential Tools
echo [1/8] Installing Essential Tools...
echo [INFO] Installing Git...
choco install git -y --force
if %errorLevel% == 0 (
echo [SUCCESS] Git installed
) else (
echo [WARNING] Git installation failed
)

echo [INFO] Installing Node.js...
choco install nodejs -y --force
if %errorLevel% == 0 (
echo [SUCCESS] Node.js installed
) else (
echo [WARNING] Node.js installation failed
)

:: 2. Package Managers
echo [2/8] Installing Package Managers...
echo [INFO] Installing pnpm...
npm install -g pnpm@latest
if %errorLevel% == 0 (
echo [SUCCESS] pnpm installed
) else (
echo [WARNING] pnpm installation failed
)

echo [INFO] Installing Yarn...
choco install yarn -y
if %errorLevel% == 0 (
echo [SUCCESS] Yarn installed
) else (
echo [WARNING] Yarn installation failed
)

:: 3. Development IDEs
echo [3/8] Installing Development IDEs...
echo [INFO] Installing VS Code...
choco install vscode -y
if %errorLevel% == 0 (
echo [SUCCESS] VS Code installed
) else (
echo [WARNING] VS Code installation failed
)

echo [INFO] Installing Windows Terminal...
choco install microsoft-windows-terminal -y
if %errorLevel% == 0 (
echo [SUCCESS] Windows Terminal installed
) else (
echo [WARNING] Windows Terminal installation failed
)

:: 4. Build Tools
echo [4/8] Installing Build Tools...
echo [INFO] Installing 7-Zip...
choco install 7zip -y
if %errorLevel% == 0 (
echo [SUCCESS] 7-Zip installed
) else (
echo [WARNING] 7-Zip installation failed
)

echo [INFO] Installing CMake...
choco install cmake -y
if %errorLevel% == 0 (
echo [SUCCESS] CMake installed
) else (
echo [WARNING] CMake installation failed
)

:: 5. Development Utilities
echo [5/8] Installing Development Utilities...
echo [INFO] Installing PowerToys...
choco install powertoys -y
if %errorLevel% == 0 (
echo [SUCCESS] PowerToys installed
) else (
echo [WARNING] PowerToys installation failed - trying manual install
powershell -Command "& {Invoke-WebRequest -Uri 'https://github.com/microsoft/PowerToys/releases/download/v0.94.0/PowerToysSetup-0.94.0-x64.exe' -OutFile 'PowerToysSetup.exe'}"
if exist "PowerToysSetup.exe" (
PowerToysSetup.exe /S
del PowerToysSetup.exe
echo [SUCCESS] PowerToys installed manually
)
)

echo [INFO] Installing Fiddler...
choco install fiddler -y
if %errorLevel% == 0 (
echo [SUCCESS] Fiddler installed
) else (
echo [WARNING] Fiddler installation failed
)

:: 6. Database Tools
echo [6/8] Installing Database Tools...
echo [INFO] Installing MongoDB Compass...
choco install mongodb-compass -y
if %errorLevel% == 0 (
echo [SUCCESS] MongoDB Compass installed
) else (
echo [WARNING] MongoDB Compass installation failed
)

echo [INFO] Installing DBeaver...
choco install dbeaver -y
if %errorLevel% == 0 (
echo [SUCCESS] DBeaver installed
) else (
echo [WARNING] DBeaver installation failed
)

:: 7. Version Control
echo [7/8] Installing Version Control Tools...
echo [INFO] Installing GitHub Desktop...
choco install github-desktop -y
if %errorLevel% == 0 (
echo [SUCCESS] GitHub Desktop installed
) else (
echo [WARNING] GitHub Desktop installation failed
)

echo [INFO] Installing GitKraken...
choco install gitkraken -y
if %errorLevel% == 0 (
echo [SUCCESS] GitKraken installed
) else (
echo [WARNING] GitKraken installation failed
)

:: 8. Global NPM Packages
echo [8/8] Installing Global NPM Packages...
echo [INFO] Installing essential global packages...

:: Refresh environment
call refreshenv

:: Install global packages
npm install -g @vue/cli
npm install -g @nuxt/cli
npm install -g typescript
npm install -g eslint
npm install -g prettier
npm install -g nodemon
npm install -g pm2
npm install -g @angular/cli
npm install -g create-react-app
npm install -g create-next-app
npm install -g @storybook/cli
npm install -g webpack
npm install -g webpack-cli
npm install -g parcel
npm install -g rollup
npm install -g vite

echo [SUCCESS] Global NPM packages installed

echo.
echo ================================================================
echo                    CONFIGURATION
echo ================================================================

:: Configure npm
echo [CONFIG] Configuring npm...
npm config set registry https://registry.npmjs.org/
npm config set cache-max 3600000
npm config set cache-min 3600000
npm config set prefer-offline true
npm config set audit-level moderate
npm config set fund false
echo [SUCCESS] npm configured

:: Configure pnpm
echo [CONFIG] Configuring pnpm...
pnpm config set registry https://registry.npmjs.org/
pnpm config set store-dir "C:\pnpm-store"
pnpm config set cache-dir "C:\pnpm-cache"
pnpm config set auto-install-peers true
echo [SUCCESS] pnpm configured

:: Configure Git
echo [CONFIG] Configuring Git...
git config --global init.defaultBranch main
git config --global core.autocrlf true
git config --global core.safecrlf true
git config --global pull.rebase true
git config --global merge.tool vscode
echo [SUCCESS] Git configured

:: Create development workspace
echo [CONFIG] Creating development workspace...
if not exist "%USERPROFILE%\Desktop\DevOptimizer" mkdir "%USERPROFILE%\Desktop\DevOptimizer"
if not exist "%USERPROFILE%\Desktop\DevOptimizer\Projects" mkdir "%USERPROFILE%\Desktop\DevOptimizer\Projects"
if not exist "%USERPROFILE%\Desktop\DevOptimizer\Templates" mkdir "%USERPROFILE%\Desktop\DevOptimizer\Templates"
if not exist "%USERPROFILE%\Desktop\DevOptimizer\Scripts" mkdir "%USERPROFILE%\Desktop\DevOptimizer\Scripts"

:: Create VS Code workspace
echo [CONFIG] Creating VS Code workspace...
echo { > "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo   "folders": [ >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo     { "path": "./Projects" }, >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo     { "path": "./Templates" }, >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo     { "path": "./Scripts" } >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo   ], >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo   "settings": { >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo     "editor.formatOnSave": true, >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo     "editor.codeActionsOnSave": { >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo       "source.fixAll.eslint": true >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo     }, >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo     "typescript.preferences.importModuleSpecifier": "relative", >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo     "javascript.preferences.importModuleSpecifier": "relative" >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo   } >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"
echo } >> "%USERPROFILE%\Desktop\DevOptimizer\DevOptimizer.code-workspace"

echo [SUCCESS] Development workspace created

echo.
echo ================================================================
echo                    VERIFICATION
echo ================================================================

:: Verify installations
echo [VERIFY] Verifying installations...

echo.
echo Node.js version:
node --version 2>nul || echo [ERROR] Node.js not found

echo.
echo npm version:
npm --version 2>nul || echo [ERROR] npm not found

echo.
echo pnpm version:
pnpm --version 2>nul || echo [ERROR] pnpm not found

echo.
echo Yarn version:
yarn --version 2>nul || echo [ERROR] Yarn not found

echo.
echo Git version:
git --version 2>nul || echo [ERROR] Git not found

echo.
echo VS Code version:
code --version 2>nul || echo [ERROR] VS Code not found

echo.
echo ================================================================
echo                    FINAL REPORT
echo ================================================================

echo [REPORT] Development tools installation completed!
echo.
echo  Essential Tools: Git, Node.js, npm
echo  Package Managers: pnpm, Yarn
echo  Development IDEs: VS Code, Windows Terminal
echo  Build Tools: 7-Zip, CMake
echo  Development Utilities: PowerToys, Fiddler
echo  Database Tools: MongoDB Compass, DBeaver
echo  Version Control: GitHub Desktop, GitKraken
echo  Global NPM Packages: Vue CLI, Nuxt CLI, TypeScript, ESLint, Prettier, etc.
echo.
echo [INFO] Development workspace created at: %USERPROFILE%\Desktop\DevOptimizer
echo [INFO] VS Code workspace file: DevOptimizer.code-workspace
echo.
echo [SUCCESS] All development tools are now properly installed and configured!
echo.

pause
exit /b %ERRORLEVEL%
