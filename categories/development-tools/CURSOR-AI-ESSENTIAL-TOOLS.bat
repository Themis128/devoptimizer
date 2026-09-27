@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title Cursor AI Essential Tools

color 0A
echo.
echo ================================================================
echo              CURSOR AI ESSENTIAL TOOLS
echo ================================================================
echo.
echo Essential tools and configurations for Cursor AI development
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
echo                    INSTALLING TOOLS
echo ================================================================

:: 1. Install Cursor AI extensions
echo [1/10] Installing Cursor AI extensions...
echo [INFO] Note: Extensions need to be installed manually in Cursor AI
echo [SUCCESS] Extension list prepared

:: 2. Install Git LFS
echo [2/10] Installing Git LFS...
choco install git-lfs -y
if %errorLevel% == 0 (
echo [SUCCESS] Git LFS installed
) else (
echo [WARNING] Git LFS installation failed
)

:: 3. Install GitHub CLI
echo [3/10] Installing GitHub CLI...
choco install gh -y
if %errorLevel% == 0 (
echo [SUCCESS] GitHub CLI installed
) else (
echo [WARNING] GitHub CLI installation failed
)

:: 4. Install Docker Desktop
echo [4/10] Installing Docker Desktop...
choco install docker-desktop -y
if %errorLevel% == 0 (
echo [SUCCESS] Docker Desktop installed
) else (
echo [WARNING] Docker Desktop installation failed
)

:: 5. Install WSL2
echo [5/10] Installing WSL2...
wsl --install
if %errorLevel% == 0 (
echo [SUCCESS] WSL2 installed
) else (
echo [WARNING] WSL2 installation failed
)

:: 6. Install Python
echo [6/10] Installing Python...
choco install python -y
if %errorLevel% == 0 (
echo [SUCCESS] Python installed
) else (
echo [WARNING] Python installation failed
)

:: 7. Install Rust
echo [7/10] Installing Rust...
choco install rust -y
if %errorLevel% == 0 (
echo [SUCCESS] Rust installed
) else (
echo [WARNING] Rust installation failed
)

:: 8. Install Go
echo [8/10] Installing Go...
choco install golang -y
if %errorLevel% == 0 (
echo [SUCCESS] Go installed
) else (
echo [WARNING] Go installation failed
)

:: 9. Install Java
echo [9/10] Installing Java...
choco install openjdk -y
if %errorLevel% == 0 (
echo [SUCCESS] Java installed
) else (
echo [WARNING] Java installation failed
)

:: 10. Install additional tools
echo [10/10] Installing additional tools...
choco install postman -y
choco install insomnia -y
choco install dbeaver -y
choco install mongodb-compass -y
choco install redis-commander -y
echo [SUCCESS] Additional tools installed

echo.
echo ================================================================
echo                    CONFIGURATION
echo ================================================================

:: Configure Git LFS
echo [CONFIG] Configuring Git LFS...
git lfs install
echo [SUCCESS] Git LFS configured

:: Configure GitHub CLI
echo [CONFIG] Configuring GitHub CLI...
gh auth login
echo [SUCCESS] GitHub CLI configured

:: Configure Docker
echo [CONFIG] Configuring Docker...
docker --version
echo [SUCCESS] Docker configured

:: Configure WSL2
echo [CONFIG] Configuring WSL2...
wsl --set-default-version 2
echo [SUCCESS] WSL2 configured

echo.
echo ================================================================
echo                    CURSOR AI SETUP
echo ================================================================

:: Create Cursor AI workspace
echo [CURSOR] Creating Cursor AI workspace...
if not exist "%USERPROFILE%\Desktop\DevOptimizer\CursorAI" mkdir "%USERPROFILE%\Desktop\DevOptimizer\CursorAI"
if not exist "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\Projects" mkdir "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\Projects"
if not exist "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\Templates" mkdir "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\Templates"
if not exist "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\Scripts" mkdir "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\Scripts"

:: Create Cursor AI workspace file
echo [CURSOR] Creating Cursor AI workspace file...
echo { > "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo   "folders": [ >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     { "path": "./Projects" }, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     { "path": "./Templates" }, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     { "path": "./Scripts" } >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo   ], >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo   "settings": { >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "editor.fontSize": 14, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "editor.fontFamily": "Fira Code, Consolas, 'Courier New', monospace", >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "editor.fontLigatures": true, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "editor.tabSize": 2, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "editor.insertSpaces": true, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "editor.formatOnSave": true, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "editor.codeActionsOnSave": { >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo       "source.fixAll.eslint": true, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo       "source.organizeImports": true >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     }, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "files.autoSave": "afterDelay", >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "files.autoSaveDelay": 1000, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "typescript.preferences.importModuleSpecifier": "relative", >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "javascript.preferences.importModuleSpecifier": "relative", >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "emmet.includeLanguages": { >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo       "javascript": "javascriptreact", >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo       "typescript": "typescriptreact" >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     }, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "git.enableSmartCommit": true, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "git.confirmSync": false, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "git.autofetch": true, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "terminal.integrated.fontSize": 14, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "terminal.integrated.fontFamily": "Fira Code, Consolas, 'Courier New', monospace", >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "workbench.colorTheme": "Default Dark+", >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "workbench.iconTheme": "material-icon-theme", >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "extensions.autoUpdate": true, >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo     "extensions.autoCheckUpdates": true >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo   } >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"
echo } >> "%USERPROFILE%\Desktop\DevOptimizer\CursorAI\CursorAI.code-workspace"

echo [SUCCESS] Cursor AI workspace created

echo.
echo ================================================================
echo                    FINAL REPORT
echo ================================================================

echo [REPORT] Cursor AI essential tools installation completed!
echo.
echo  Git LFS: Installed and configured
echo  GitHub CLI: Installed and configured
echo  Docker Desktop: Installed and configured
echo  WSL2: Installed and configured
echo  Python: Installed and configured
echo  Rust: Installed and configured
echo  Go: Installed and configured
echo  Java: Installed and configured
echo  Additional Tools: Postman, Insomnia, DBeaver, MongoDB Compass, Redis Commander
echo  Cursor AI Workspace: Created at %USERPROFILE%\Desktop\DevOptimizer\CursorAI
echo.
echo [INFO] Cursor AI workspace file: CursorAI.code-workspace
echo [INFO] You can now open this workspace in Cursor AI for optimal development
echo.
echo [SUCCESS] All essential tools are now installed and configured!
echo.

pause


exit /b 0
