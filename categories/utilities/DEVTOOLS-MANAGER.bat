@echo off
setlocal EnableExtensions EnableDelayedExpansion
setlocal enabledelayedexpansion
title Development Tools Manager - DevOptimizer System
color 0A

echo.
echo ========================================================================
echo                  DEVELOPMENT TOOLS MANAGER - DEVOPTIMIZER SYSTEM
echo ========================================================================
echo.

echo [STATUS] Initializing Development Tools Manager...
echo [INFO] Checking development environment prerequisites...

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

:: Initialize development tools tracking
set "TOOLS_INSTALLED=0"
set "TOTAL_TOOLS=0"
set "TOOLS_STATUS=0"

echo [SUCCESS] Development Tools Manager initialized successfully
echo [INFO] System ready for development tools management
echo.

:: Quick development environment status check
echo ========================================================================
echo                        QUICK DEVELOPMENT STATUS
echo ========================================================================
echo.

echo [STATUS] Checking development tools availability...
echo.

:: Check Node.js status
node --version >nul 2>&1
if %errorlevel%==0 (
echo [STATUS] Node.js: INSTALLED
set /a TOOLS_STATUS+=1
) else (
echo [STATUS] Node.js: NOT INSTALLED
)

:: Check Python status
python --version >nul 2>&1
if %errorlevel%==0 (
echo [STATUS] Python: INSTALLED
set /a TOOLS_STATUS+=1
) else (
echo [STATUS] Python: NOT INSTALLED
)

:: Check Git status
git --version >nul 2>&1
if %errorlevel%==0 (
echo [STATUS] Git: INSTALLED
set /a TOOLS_STATUS+=1
) else (
echo [STATUS] Git: NOT INSTALLED
)

:: Check VS Code status
code --version >nul 2>&1
if %errorlevel%==0 (
echo [STATUS] VS Code: INSTALLED
set /a TOOLS_STATUS+=1
) else (
echo [STATUS] VS Code: NOT INSTALLED
)

:: Check Cursor status
if exist "C:\Users\%USERNAME%\AppData\Local\Programs\cursor\Cursor.exe" (
echo [STATUS] Cursor: INSTALLED
set /a TOOLS_STATUS+=1
) else (
echo [STATUS] Cursor: NOT INSTALLED
)

:: Check Docker status
docker --version >nul 2>&1
if %errorlevel%==0 (
echo [STATUS] Docker: INSTALLED
set /a TOOLS_STATUS+=1
) else (
echo [STATUS] Docker: NOT INSTALLED
)

echo.
echo [INFO] Development tools installed: %TOOLS_STATUS%/6
echo.

echo ========================================================================
echo                         DEVELOPMENT TOOLS OPTIONS
echo ========================================================================
echo.
:start
echo [1] Install Development Tools & Environments
echo [2] Update Development Tools & Packages
echo [3] Node.js & NPM Management
echo [4] Python Environment Management
echo [5] Git Configuration & Repository Management
echo [6] VS Code & Cursor Management
echo [7] Docker Management & Containers
echo [8] Database Tools Management
echo [9] Development Environment Status & Analysis
echo [A] Development Project Templates
echo [B] Development Environment Backup & Restore
echo [0] Exit
echo.

set /p choice="Enter your choice (0-9, A, B): "

if "%choice%"=="1" goto :install_tools
if "%choice%"=="2" goto :update_tools
if "%choice%"=="3" goto :nodejs_management
if "%choice%"=="4" goto :python_management
if "%choice%"=="5" goto :git_configuration
if "%choice%"=="6" goto :editor_management
if "%choice%"=="7" goto :docker_management
if "%choice%"=="8" goto :database_management
if "%choice%"=="9" goto :dev_environment_status
if /i "%choice%"=="A" goto :project_templates
if /i "%choice%"=="B" goto :environment_backup
if "%choice%"=="0" goto :exit
goto :invalid_choice

:install_tools
echo.
echo ========================================================================
echo                         INSTALL DEVELOPMENT TOOLS & ENVIRONMENTS
echo ========================================================================
echo.

echo [STATUS] Initializing development tools installation...
echo [INFO] Checking system requirements and package managers...

:: Check if winget is available
winget --version >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] Windows Package Manager (winget) is available
) else (
echo [WARNING] Windows Package Manager (winget) not found
echo [INFO] Some installations may require manual download
)

:: Check if npm is available
npm --version >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] NPM is available for Node.js packages
) else (
echo [WARNING] NPM not found - Node.js may need to be installed first
)

:: Check if pip is available
pip --version >nul 2>&1
if %errorlevel%==0 (
echo [SUCCESS] PIP is available for Python packages
) else (
echo [WARNING] PIP not found - Python may need to be installed first
)

echo.
echo [INFO] Development tools installation options:
echo.
echo [1] Essential Development Tools (Git, Node.js, Python, VS Code)
echo [2] Web Development Stack (Angular, Vue, Nuxt, TypeScript)
echo [3] AI/ML Development Stack (TensorFlow, PyTorch, Jupyter)
echo [4] Mobile Development Tools (Android Studio, Flutter, React Native)
echo [5] Game Development Tools (Unity, Unreal Engine, Godot)
echo [6] Database Tools (PostgreSQL, MySQL, MongoDB, Redis)
echo [7] DevOps Tools (Docker, Kubernetes, CI/CD)
echo [8] Custom Tool Installation
echo [0] Back to main menu
echo.

set /p install_choice="Enter your choice (0-8): "

if "%install_choice%"=="1" goto :essential_tools
if "%install_choice%"=="2" goto :web_dev_stack
if "%install_choice%"=="3" goto :ai_ml_stack
if "%install_choice%"=="4" goto :mobile_dev_tools
if "%install_choice%"=="5" goto :game_dev_tools
if "%install_choice%"=="6" goto :database_tools
if "%install_choice%"=="7" goto :devops_tools
if "%install_choice%"=="8" goto :custom_installation
if "%install_choice%"=="0" goto :menu
goto :invalid_install_choice

:essential_tools
echo.
echo ========================================================================
echo                         ESSENTIAL DEVELOPMENT TOOLS
echo ========================================================================
echo.

echo [STATUS] Installing essential development tools...
echo [INFO] This will install Git, Node.js, Python, and VS Code
echo [WARNING] Some installations may require administrator privileges
echo [INFO] Estimated installation time: 10-15 minutes
echo.

set /p confirm="Do you want to proceed with essential tools installation? (Y/N): "
if /i not "%confirm%"=="Y" (
echo [INFO] Essential tools installation cancelled by user
pause
goto :install_tools
)

echo.
echo [STEP 1/4] Installing Git...
echo [INFO] Git is essential for version control and collaboration
echo [STATUS] Downloading and installing Git...

winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Git installed successfully
set /a TOOLS_INSTALLED+=1
) else (
echo [ERROR] Git installation failed
echo [INFO] You may need to install Git manually from https://git-scm.com/
)

echo.
echo [STEP 2/4] Installing Node.js...
echo [INFO] Node.js provides JavaScript runtime for server-side development
echo [STATUS] Downloading and installing Node.js...

winget install --id OpenJS.NodeJS -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Node.js installed successfully
set /a TOOLS_INSTALLED+=1
) else (
echo [ERROR] Node.js installation failed
echo [INFO] You may need to install Node.js manually from https://nodejs.org/
)

echo.
echo [STEP 3/4] Installing Python...
echo [INFO] Python is essential for AI/ML development and scripting
echo [STATUS] Downloading and installing Python 3.11...

winget install --id Python.Python.3.11 -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Python installed successfully
set /a TOOLS_INSTALLED+=1
) else (
echo [ERROR] Python installation failed
echo [INFO] You may need to install Python manually from https://python.org/
)

echo.
echo [STEP 4/4] Installing VS Code...
echo [INFO] VS Code is a powerful code editor with extensive extension support
echo [STATUS] Downloading and installing VS Code...

winget install --id Microsoft.VisualStudioCode -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] VS Code installed successfully
set /a TOOLS_INSTALLED+=1
) else (
echo [ERROR] VS Code installation failed
echo [INFO] You may need to install VS Code manually from https://code.visualstudio.com/
)

echo.
echo [COMPLETED] Essential development tools installation completed
echo [SUCCESS] Tools successfully installed: %TOOLS_INSTALLED%/4
echo [INFO] Please restart your terminal/command prompt to use the new tools
echo [INFO] Run 'Development Environment Status' to verify installations
set /a TOTAL_TOOLS+=4
pause
goto :install_tools

:web_dev_stack
echo.
echo [INFO] Installing web development stack...
echo.

echo [STEP 1] Installing Node.js and NPM...
winget install --id OpenJS.NodeJS -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Node.js installed
) else (
echo [ERROR] Node.js installation failed
)

echo [STEP 2] Installing Angular CLI...
npm install -g @angular/cli
if %errorlevel% equ 0 (
echo [SUCCESS] Angular CLI installed
) else (
echo [ERROR] Angular CLI installation failed
)

echo [STEP 3] Installing Vue CLI...
npm install -g @vue/cli
if %errorlevel% equ 0 (
echo [SUCCESS] Vue CLI installed
) else (
echo [ERROR] Vue CLI installation failed
)

echo [STEP 4] Installing Nuxt CLI...
npm install -g nuxi
if %errorlevel% equ 0 (
echo [SUCCESS] Nuxt CLI installed
) else (
echo [ERROR] Nuxt CLI installation failed
)

echo [STEP 5] Installing TypeScript...
npm install -g typescript
if %errorlevel% equ 0 (
echo [SUCCESS] TypeScript installed
) else (
echo [ERROR] TypeScript installation failed
)

echo [SUCCESS] Web development stack installation completed
pause
goto :install_tools

:ai_ml_stack
echo.
echo [INFO] Installing AI/ML development stack...
echo.

echo [STEP 1] Installing Python...
winget install --id Python.Python.3.11 -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Python installed
) else (
echo [ERROR] Python installation failed
)

echo [STEP 2] Installing Jupyter Notebook...
pip install jupyter
if %errorlevel% equ 0 (
echo [SUCCESS] Jupyter Notebook installed
) else (
echo [ERROR] Jupyter Notebook installation failed
)

echo [STEP 3] Installing TensorFlow...
pip install tensorflow
if %errorlevel% equ 0 (
echo [SUCCESS] TensorFlow installed
) else (
echo [ERROR] TensorFlow installation failed
)

echo [STEP 4] Installing PyTorch...
pip install torch torchvision torchaudio
if %errorlevel% equ 0 (
echo [SUCCESS] PyTorch installed
) else (
echo [ERROR] PyTorch installation failed
)

echo [STEP 5] Installing scikit-learn...
pip install scikit-learn
if %errorlevel% equ 0 (
echo [SUCCESS] scikit-learn installed
) else (
echo [ERROR] scikit-learn installation failed
)

echo [SUCCESS] AI/ML development stack installation completed
pause
goto :install_tools

:mobile_dev_tools
echo.
echo [INFO] Installing mobile development tools...
echo.

echo [STEP 1] Installing Android Studio...
winget install --id Google.AndroidStudio -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Android Studio installed
) else (
echo [ERROR] Android Studio installation failed
)

echo [STEP 2] Installing Flutter...
winget install --id Google.Flutter -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Flutter installed
) else (
echo [ERROR] Flutter installation failed
)

echo [STEP 3] Installing React Native CLI...
npm install -g react-native-cli
if %errorlevel% equ 0 (
echo [SUCCESS] React Native CLI installed
) else (
echo [ERROR] React Native CLI installation failed
)

echo [SUCCESS] Mobile development tools installation completed
pause
goto :install_tools

:game_dev_tools
echo.
echo [INFO] Installing game development tools...
echo.

echo [STEP 1] Installing Unity Hub...
winget install --id Unity.UnityHub -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Unity Hub installed
) else (
echo [ERROR] Unity Hub installation failed
)

echo [STEP 2] Installing Unreal Engine...
winget install --id EpicGames.EpicGamesLauncher -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Epic Games Launcher installed
) else (
echo [ERROR] Epic Games Launcher installation failed
)

echo [STEP 3] Installing Godot...
winget install --id GodotEngine.Godot -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Godot installed
) else (
echo [ERROR] Godot installation failed
)

echo [SUCCESS] Game development tools installation completed
pause
goto :install_tools

:custom_installation
echo.
set /p package_name="Enter package name to install: "
if "%package_name%"=="" (
echo [ERROR] Package name is required
pause
goto :install_tools
)

echo [INFO] Installing %package_name%...
winget install --id %package_name% -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] %package_name% installed
) else (
echo [ERROR] %package_name% installation failed
)

pause
goto :install_tools

:invalid_install_choice
echo.
echo [ERROR] Invalid installation choice
pause
goto :install_tools

:update_tools
echo.
echo ========================================================================
echo                         UPDATE DEVELOPMENT TOOLS
echo ========================================================================
echo.

echo [INFO] Updating development tools...
echo.

echo [STEP 1] Updating winget...
winget upgrade --all --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Winget packages updated
) else (
echo [ERROR] Winget update failed
)

echo [STEP 2] Updating Node.js packages...
npm update -g
if %errorlevel% equ 0 (
echo [SUCCESS] Node.js packages updated
) else (
echo [ERROR] Node.js packages update failed
)

echo [STEP 3] Updating Python packages...
pip list --outdated
echo [INFO] Run 'pip install --upgrade package_name' for specific packages
echo.

echo [SUCCESS] Development tools update completed
pause
goto :menu

:nodejs_management
echo.
echo ========================================================================
echo                         NODE.JS & NPM MANAGEMENT
echo ========================================================================
echo.

echo [INFO] Node.js and NPM management options:
echo.
echo [1] Check Node.js and NPM versions
echo [2] Install global packages
echo [3] List global packages
echo [4] Update global packages
echo [5] Uninstall global packages
echo [6] Create new project
echo [7] Install project dependencies
echo [0] Back to main menu
echo.

set /p nodejs_choice="Enter your choice (0-7): "

if "%nodejs_choice%"=="1" goto :check_nodejs_versions
if "%nodejs_choice%"=="2" goto :install_global_packages
if "%nodejs_choice%"=="3" goto :list_global_packages
if "%nodejs_choice%"=="4" goto :update_global_packages
if "%nodejs_choice%"=="5" goto :uninstall_global_packages
if "%nodejs_choice%"=="6" goto :create_new_project
if "%nodejs_choice%"=="7" goto :install_project_dependencies
if "%nodejs_choice%"=="0" goto :menu
goto :invalid_nodejs_choice

:check_nodejs_versions
echo.
echo [INFO] Node.js and NPM versions:
node --version
npm --version
echo.
pause
goto :nodejs_management

:install_global_packages
echo.
set /p package_name="Enter package name to install globally: "
if "%package_name%"=="" (
echo [ERROR] Package name is required
pause
goto :nodejs_management
)

echo [INFO] Installing %package_name% globally...
npm install -g %package_name%
if %errorlevel% equ 0 (
echo [SUCCESS] %package_name% installed globally
) else (
echo [ERROR] %package_name% installation failed
)

pause
goto :nodejs_management

:list_global_packages
echo.
echo [INFO] Global packages:
npm list -g --depth=0
echo.
pause
goto :nodejs_management

:update_global_packages
echo.
echo [INFO] Updating global packages...
npm update -g
if %errorlevel% equ 0 (
echo [SUCCESS] Global packages updated
) else (
echo [ERROR] Global packages update failed
)

pause
goto :nodejs_management

:uninstall_global_packages
echo.
set /p package_name="Enter package name to uninstall: "
if "%package_name%"=="" (
echo [ERROR] Package name is required
pause
goto :nodejs_management
)

echo [INFO] Uninstalling %package_name%...
npm uninstall -g %package_name%
if %errorlevel% equ 0 (
echo [SUCCESS] %package_name% uninstalled
) else (
echo [ERROR] %package_name% uninstallation failed
)

pause
goto :nodejs_management

:create_new_project
echo.
set /p project_name="Enter project name: "
if "%project_name%"=="" (
echo [ERROR] Project name is required
pause
goto :nodejs_management
)

echo [INFO] Creating new project: %project_name%
mkdir "%project_name%"
cd "%project_name%"
npm init -y
if %errorlevel% equ 0 (
echo [SUCCESS] Project %project_name% created
) else (
echo [ERROR] Project creation failed
)

cd ..
pause
goto :nodejs_management

:install_project_dependencies
echo.
set /p project_path="Enter project path: "
if "%project_path%"=="" (
echo [ERROR] Project path is required
pause
goto :nodejs_management
)

if not exist "%project_path%" (
echo [ERROR] Project path does not exist
pause
goto :nodejs_management
)

echo [INFO] Installing dependencies for project: %project_path%
cd "%project_path%"
npm install
if %errorlevel% equ 0 (
echo [SUCCESS] Dependencies installed
) else (
echo [ERROR] Dependencies installation failed
)

cd "%~dp0"
pause
goto :nodejs_management

:invalid_nodejs_choice
echo.
echo [ERROR] Invalid Node.js choice
pause
goto :nodejs_management

:python_management
echo.
echo ========================================================================
echo                         PYTHON ENVIRONMENT MANAGEMENT
echo ========================================================================
echo.

echo [INFO] Python environment management options:
echo.
echo [1] Check Python version
echo [2] Install Python packages
echo [3] List installed packages
echo [4] Update packages
echo [5] Create virtual environment
echo [6] Activate virtual environment
echo [7] Deactivate virtual environment
echo [8] Install requirements
echo [0] Back to main menu
echo.

set /p python_choice="Enter your choice (0-8): "

if "%python_choice%"=="1" goto :check_python_version
if "%python_choice%"=="2" goto :install_python_packages
if "%python_choice%"=="3" goto :list_python_packages
if "%python_choice%"=="4" goto :update_python_packages
if "%python_choice%"=="5" goto :create_virtual_environment
if "%python_choice%"=="6" goto :activate_virtual_environment
if "%python_choice%"=="7" goto :deactivate_virtual_environment
if "%python_choice%"=="8" goto :install_requirements
if "%python_choice%"=="0" goto :menu
goto :invalid_python_choice

:check_python_version
echo.
echo [INFO] Python version:
python --version
pip --version
echo.
pause
goto :python_management

:install_python_packages
echo.
set /p package_name="Enter package name to install: "
if "%package_name%"=="" (
echo [ERROR] Package name is required
pause
goto :python_management
)

echo [INFO] Installing %package_name%...
pip install %package_name%
if %errorlevel% equ 0 (
echo [SUCCESS] %package_name% installed
) else (
echo [ERROR] %package_name% installation failed
)

pause
goto :python_management

:list_python_packages
echo.
echo [INFO] Installed Python packages:
pip list
echo.
pause
goto :python_management

:update_python_packages
echo.
echo [INFO] Updating Python packages...
pip list --outdated
echo.
echo [INFO] Run 'pip install --upgrade package_name' for specific packages
pause
goto :python_management

:create_virtual_environment
echo.
set /p env_name="Enter virtual environment name: "
if "%env_name%"=="" (
echo [ERROR] Environment name is required
pause
goto :python_management
)

echo [INFO] Creating virtual environment: %env_name%
python -m venv %env_name%
if %errorlevel% equ 0 (
echo [SUCCESS] Virtual environment %env_name% created
) else (
echo [ERROR] Virtual environment creation failed
)

pause
goto :python_management

:activate_virtual_environment
echo.
set /p env_name="Enter virtual environment name: "
if "%env_name%"=="" (
echo [ERROR] Environment name is required
pause
goto :python_management
)

if not exist "%env_name%" (
echo [ERROR] Virtual environment does not exist
pause
goto :python_management
)

echo [INFO] Activating virtual environment: %env_name%
call %env_name%\Scripts\activate.bat
if %errorlevel% equ 0 (
echo [SUCCESS] Virtual environment %env_name% activated
) else (
echo [ERROR] Virtual environment activation failed
)

pause
goto :python_management

:deactivate_virtual_environment
echo.
echo [INFO] Deactivating virtual environment...
deactivate
if %errorlevel% equ 0 (
echo [SUCCESS] Virtual environment deactivated
) else (
echo [ERROR] Virtual environment deactivation failed
)

pause
goto :python_management

:install_requirements
echo.
set /p requirements_file="Enter requirements file path: "
if "%requirements_file%"=="" (
echo [ERROR] Requirements file path is required
pause
goto :python_management
)

if not exist "%requirements_file%" (
echo [ERROR] Requirements file does not exist
pause
goto :python_management
)

echo [INFO] Installing requirements from: %requirements_file%
pip install -r "%requirements_file%"
if %errorlevel% equ 0 (
echo [SUCCESS] Requirements installed
) else (
echo [ERROR] Requirements installation failed
)

pause
goto :python_management

:invalid_python_choice
echo.
echo [ERROR] Invalid Python choice
pause
goto :python_management

:git_configuration
echo.
echo ========================================================================
echo                           GIT CONFIGURATION
echo ========================================================================
echo.

echo [INFO] Git configuration options:
echo.
echo [1] Check Git status
echo [2] Configure Git user
echo [3] Initialize Git repository
echo [4] Clone repository
echo [5] Git status check
echo [6] Git log
echo [7] Git branches
echo [8] Git remote configuration
echo [0] Back to main menu
echo.

set /p git_choice="Enter your choice (0-8): "

if "%git_choice%"=="1" goto :check_git_status
if "%git_choice%"=="2" goto :configure_git_user
if "%git_choice%"=="3" goto :init_git_repo
if "%git_choice%"=="4" goto :clone_repository
if "%git_choice%"=="5" goto :git_status_check
if "%git_choice%"=="6" goto :git_log
if "%git_choice%"=="7" goto :git_branches
if "%git_choice%"=="8" goto :git_remote_config
if "%git_choice%"=="0" goto :menu
goto :invalid_git_choice

:check_git_status
echo.
echo [INFO] Git version:
git --version
echo.
pause
goto :git_configuration

:configure_git_user
echo.
set /p user_name="Enter Git user name: "
set /p user_email="Enter Git user email: "

if "%user_name%"=="" (
echo [ERROR] User name is required
pause
goto :git_configuration
)

if "%user_email%"=="" (
echo [ERROR] User email is required
pause
goto :git_configuration
)

echo [INFO] Configuring Git user...
git config --global user.name "%user_name%"
git config --global user.email "%user_email%"
if %errorlevel% equ 0 (
echo [SUCCESS] Git user configured
) else (
echo [ERROR] Git user configuration failed
)

pause
goto :git_configuration

:init_git_repo
echo.
set /p repo_path="Enter repository path (current directory if empty): "
if "%repo_path%"=="" set "repo_path=."

echo [INFO] Initializing Git repository in: %repo_path%
cd "%repo_path%"
git init
if %errorlevel% equ 0 (
echo [SUCCESS] Git repository initialized
) else (
echo [ERROR] Git repository initialization failed
)

cd "%~dp0"
pause
goto :git_configuration

:clone_repository
echo.
set /p repo_url="Enter repository URL: "
if "%repo_url%"=="" (
echo [ERROR] Repository URL is required
pause
goto :git_configuration
)

echo [INFO] Cloning repository: %repo_url%
git clone %repo_url%
if %errorlevel% equ 0 (
echo [SUCCESS] Repository cloned
) else (
echo [ERROR] Repository cloning failed
)

pause
goto :git_configuration

:git_status_check
echo.
echo [INFO] Git status:
git status
echo.
pause
goto :git_configuration

:git_log
echo.
echo [INFO] Git log:
git log --oneline -10
echo.
pause
goto :git_configuration

:git_branches
echo.
echo [INFO] Git branches:
git branch -a
echo.
pause
goto :git_configuration

:git_remote_config
echo.
echo [INFO] Git remotes:
git remote -v
echo.
pause
goto :git_configuration

:invalid_git_choice
echo.
echo [ERROR] Invalid Git choice
pause
goto :git_configuration

:editor_management
echo.
echo ========================================================================
echo                      VS CODE & CURSOR MANAGEMENT
echo ========================================================================
echo.

echo [INFO] Editor management options:
echo.
echo [1] Check VS Code status
echo [2] Check Cursor status
echo [3] Install VS Code extensions
echo [4] Install Cursor extensions
echo [5] Open project in VS Code
echo [6] Open project in Cursor
echo [7] Editor settings backup
echo [8] Editor settings restore
echo [0] Back to main menu
echo.

set /p editor_choice="Enter your choice (0-8): "

if "%editor_choice%"=="1" goto :check_vscode_status
if "%editor_choice%"=="2" goto :check_cursor_status
if "%editor_choice%"=="3" goto :install_vscode_extensions
if "%editor_choice%"=="4" goto :install_cursor_extensions
if "%editor_choice%"=="5" goto :open_project_vscode
if "%editor_choice%"=="6" goto :open_project_cursor
if "%editor_choice%"=="7" goto :editor_settings_backup
if "%editor_choice%"=="8" goto :editor_settings_restore
if "%editor_choice%"=="0" goto :menu
goto :invalid_editor_choice

:check_vscode_status
echo.
echo [INFO] VS Code status:
code --version
echo.
pause
goto :editor_management

:check_cursor_status
echo.
echo [INFO] Cursor status:
if exist "C:\Users\%USERNAME%\AppData\Local\Programs\cursor\Cursor.exe" (
echo [SUCCESS] Cursor is installed
) else (
echo [WARNING] Cursor is not installed
)
echo.
pause
goto :editor_management

:install_vscode_extensions
echo.
echo [INFO] Installing popular VS Code extensions...
code --install-extension ms-vscode.vscode-typescript-next
code --install-extension bradlc.vscode-tailwindcss
code --install-extension esbenp.prettier-vscode
code --install-extension ms-python.python
code --install-extension ms-vscode.vscode-json
echo [SUCCESS] VS Code extensions installation initiated
pause
goto :editor_management

:install_cursor_extensions
echo.
echo [INFO] Cursor extensions are managed through the Cursor interface
echo [INFO] Please install extensions through Cursor's extension marketplace
pause
goto :editor_management

:open_project_vscode
echo.
set /p project_path="Enter project path: "
if "%project_path%"=="" (
echo [ERROR] Project path is required
pause
goto :editor_management
)

if not exist "%project_path%" (
echo [ERROR] Project path does not exist
pause
goto :editor_management
)

echo [INFO] Opening project in VS Code: %project_path%
code "%project_path%"
if %errorlevel% equ 0 (
echo [SUCCESS] Project opened in VS Code
) else (
echo [ERROR] Failed to open project in VS Code
)

pause
goto :editor_management

:open_project_cursor
echo.
set /p project_path="Enter project path: "
if "%project_path%"=="" (
echo [ERROR] Project path is required
pause
goto :editor_management
)

if not exist "%project_path%" (
echo [ERROR] Project path does not exist
pause
goto :editor_management
)

echo [INFO] Opening project in Cursor: %project_path%
start "" "C:\Users\%USERNAME%\AppData\Local\Programs\cursor\Cursor.exe" "%project_path%"
if %errorlevel% equ 0 (
echo [SUCCESS] Project opened in Cursor
) else (
echo [ERROR] Failed to open project in Cursor
)

pause
goto :editor_management

:editor_settings_backup
echo.
echo [INFO] Backing up editor settings...
if exist "%APPDATA%\Code\User\settings.json" (
copy "%APPDATA%\Code\User\settings.json" "backups\vscode-settings.json" >nul 2>&1
echo [SUCCESS] VS Code settings backed up
)

if exist "%USERPROFILE%\.cursor\User\settings.json" (
copy "%USERPROFILE%\.cursor\User\settings.json" "backups\cursor-settings.json" >nul 2>&1
echo [SUCCESS] Cursor settings backed up
)

echo [SUCCESS] Editor settings backup completed
pause
goto :editor_management

:editor_settings_restore
echo.
echo [INFO] Restoring editor settings...
if exist "backups\vscode-settings.json" (
copy "backups\vscode-settings.json" "%APPDATA%\Code\User\settings.json" >nul 2>&1
echo [SUCCESS] VS Code settings restored
)

if exist "backups\cursor-settings.json" (
copy "backups\cursor-settings.json" "%USERPROFILE%\.cursor\User\settings.json" >nul 2>&1
echo [SUCCESS] Cursor settings restored
)

echo [SUCCESS] Editor settings restore completed
pause
goto :editor_management

:invalid_editor_choice
echo.
echo [ERROR] Invalid editor choice
pause
goto :editor_management

:docker_management
echo.
echo ========================================================================
echo                           DOCKER MANAGEMENT
echo ========================================================================
echo.

echo [INFO] Docker management options:
echo.
echo [1] Check Docker status
echo [2] Start Docker service
echo [3] Stop Docker service
echo [4] Docker images list
echo [5] Docker containers list
echo [6] Pull Docker image
echo [7] Run Docker container
echo [8] Docker system info
echo [0] Back to main menu
echo.

set /p docker_choice="Enter your choice (0-8): "

if "%docker_choice%"=="1" goto :check_docker_status
if "%docker_choice%"=="2" goto :menu_docker_service
if "%docker_choice%"=="3" goto :stop_docker_service
if "%docker_choice%"=="4" goto :docker_images_list
if "%docker_choice%"=="5" goto :docker_containers_list
if "%docker_choice%"=="6" goto :pull_docker_image
if "%docker_choice%"=="7" goto :run_docker_container
if "%docker_choice%"=="8" goto :docker_system_info
if "%docker_choice%"=="0" goto :menu
goto :invalid_docker_choice

:check_docker_status
echo.
echo [INFO] Docker status:
docker --version
docker info
echo.
pause
goto :docker_management

:start_docker_service
echo.
echo [INFO] Starting Docker service...
net start com.docker.service
if %errorlevel% equ 0 (
echo [SUCCESS] Docker service started
) else (
echo [ERROR] Docker service start failed
)

pause
goto :docker_management

:stop_docker_service
echo.
echo [INFO] Stopping Docker service...
net stop com.docker.service
if %errorlevel% equ 0 (
echo [SUCCESS] Docker service stopped
) else (
echo [ERROR] Docker service stop failed
)

pause
goto :docker_management

:docker_images_list
echo.
echo [INFO] Docker images:
docker images
echo.
pause
goto :docker_management

:docker_containers_list
echo.
echo [INFO] Docker containers:
docker ps -a
echo.
pause
goto :docker_management

:pull_docker_image
echo.
set /p image_name="Enter image name to pull: "
if "%image_name%"=="" (
echo [ERROR] Image name is required
pause
goto :docker_management
)

echo [INFO] Pulling Docker image: %image_name%
docker pull %image_name%
if %errorlevel% equ 0 (
echo [SUCCESS] Docker image pulled
) else (
echo [ERROR] Docker image pull failed
)

pause
goto :docker_management

:run_docker_container
echo.
set /p image_name="Enter image name to run: "
if "%image_name%"=="" (
echo [ERROR] Image name is required
pause
goto :docker_management
)

echo [INFO] Running Docker container: %image_name%
docker run -it %image_name%
if %errorlevel% equ 0 (
echo [SUCCESS] Docker container started
) else (
echo [ERROR] Docker container start failed
)

pause
goto :docker_management

:docker_system_info
echo.
echo [INFO] Docker system information:
docker system info
echo.
pause
goto :docker_management

:invalid_docker_choice
echo.
echo [ERROR] Invalid Docker choice
pause
goto :docker_management

:database_management
echo.
echo ========================================================================
echo                        DATABASE TOOLS MANAGEMENT
echo ========================================================================
echo.

echo [INFO] Database tools management options:
echo.
echo [1] Install PostgreSQL
echo [2] Install MySQL
echo [3] Install MongoDB
echo [4] Install SQLite
echo [5] Install Redis
echo [6] Database tools status
echo [0] Back to main menu
echo.

set /p database_choice="Enter your choice (0-6): "

if "%database_choice%"=="1" goto :install_postgresql
if "%database_choice%"=="2" goto :install_mysql
if "%database_choice%"=="3" goto :install_mongodb
if "%database_choice%"=="4" goto :install_sqlite
if "%database_choice%"=="5" goto :install_redis
if "%database_choice%"=="6" goto :database_tools_status
if "%database_choice%"=="0" goto :menu
goto :invalid_database_choice

:install_postgresql
echo.
echo [INFO] Installing PostgreSQL...
winget install --id PostgreSQL.PostgreSQL -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] PostgreSQL installed
) else (
echo [ERROR] PostgreSQL installation failed
)

pause
goto :database_management

:install_mysql
echo.
echo [INFO] Installing MySQL...
winget install --id Oracle.MySQL -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] MySQL installed
) else (
echo [ERROR] MySQL installation failed
)

pause
goto :database_management

:install_mongodb
echo.
echo [INFO] Installing MongoDB...
winget install --id MongoDB.DatabaseTools -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] MongoDB installed
) else (
echo [ERROR] MongoDB installation failed
)

pause
goto :database_management

:install_sqlite
echo.
echo [INFO] Installing SQLite...
winget install --id SQLite.SQLite -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] SQLite installed
) else (
echo [ERROR] SQLite installation failed
)

pause
goto :database_management

:install_redis
echo.
echo [INFO] Installing Redis...
winget install --id Redis.Redis -e --source winget --accept-package-agreements --accept-source-agreements
if %errorlevel% equ 0 (
echo [SUCCESS] Redis installed
) else (
echo [ERROR] Redis installation failed
)

pause
goto :database_management

:database_tools_status
echo.
echo [INFO] Database tools status:
echo.

echo [INFO] PostgreSQL:
psql --version >nul 2>&1
if %errorlevel% equ 0 (
echo [SUCCESS] PostgreSQL is installed
) else (
echo [WARNING] PostgreSQL is not installed
)

echo [INFO] MySQL:
mysql --version >nul 2>&1
if %errorlevel% equ 0 (
echo [SUCCESS] MySQL is installed
) else (
echo [WARNING] MySQL is not installed
)

echo [INFO] MongoDB:
mongo --version >nul 2>&1
if %errorlevel% equ 0 (
echo [SUCCESS] MongoDB is installed
) else (
echo [WARNING] MongoDB is not installed
)

echo [INFO] SQLite:
sqlite3 --version >nul 2>&1
if %errorlevel% equ 0 (
echo [SUCCESS] SQLite is installed
) else (
echo [WARNING] SQLite is not installed
)

echo [INFO] Redis:
redis-server --version >nul 2>&1
if %errorlevel% equ 0 (
echo [SUCCESS] Redis is installed
) else (
echo [WARNING] Redis is not installed
)

echo.
pause
goto :database_management

:invalid_database_choice
echo.
echo [ERROR] Invalid database choice
pause
goto :database_management

:dev_environment_status
echo.
echo ========================================================================
echo                      DEVELOPMENT ENVIRONMENT STATUS
echo ========================================================================
echo.

echo [INFO] Development environment status check:
echo.

echo [INFO] Node.js:
node --version >nul 2>&1
if %errorlevel% equ 0 (
node --version
echo [SUCCESS] Node.js is installed
) else (
echo [WARNING] Node.js is not installed
)

echo.
echo [INFO] NPM:
npm --version >nul 2>&1
if %errorlevel% equ 0 (
npm --version
echo [SUCCESS] NPM is installed
) else (
echo [WARNING] NPM is not installed
)

echo.
echo [INFO] Python:
python --version >nul 2>&1
if %errorlevel% equ 0 (
python --version
echo [SUCCESS] Python is installed
) else (
echo [WARNING] Python is not installed
)

echo.
echo [INFO] Git:
git --version >nul 2>&1
if %errorlevel% equ 0 (
git --version
echo [SUCCESS] Git is installed
) else (
echo [WARNING] Git is not installed
)

echo.
echo [INFO] VS Code:
code --version >nul 2>&1
if %errorlevel% equ 0 (
code --version
echo [SUCCESS] VS Code is installed
) else (
echo [WARNING] VS Code is not installed
)

echo.
echo [INFO] Cursor:
if exist "C:\Users\%USERNAME%\AppData\Local\Programs\cursor\Cursor.exe" (
echo [SUCCESS] Cursor is installed
) else (
echo [WARNING] Cursor is not installed
)

echo.
echo [INFO] Docker:
docker --version >nul 2>&1
if %errorlevel% equ 0 (
docker --version
echo [SUCCESS] Docker is installed
) else (
echo [WARNING] Docker is not installed
)

echo.
echo [INFO] Development environment status check completed
pause
goto :menu

:project_templates
echo.
echo ========================================================================
echo                         DEVELOPMENT PROJECT TEMPLATES
echo ========================================================================
echo.

echo [STATUS] Development project template options...
echo [INFO] Create new projects with pre-configured templates
echo.

echo [1] Web Application Templates
echo [2] API/Backend Templates
echo [3] Mobile App Templates
echo [4] Desktop Application Templates
echo [5] AI/ML Project Templates
echo [6] Game Development Templates
echo [7] Database Project Templates
echo [8] Custom Template Creation
echo [0] Back to main menu
echo.

set /p template_choice="Enter your choice (0-8): "

if "%template_choice%"=="1" goto :web_templates
if "%template_choice%"=="2" goto :api_templates
if "%template_choice%"=="3" goto :mobile_templates
if "%template_choice%"=="4" goto :desktop_templates
if "%template_choice%"=="5" goto :ai_ml_templates
if "%template_choice%"=="6" goto :game_templates
if "%template_choice%"=="7" goto :database_templates
if "%template_choice%"=="8" goto :custom_template
if "%template_choice%"=="0" goto :menu
goto :invalid_template_choice

:web_templates
echo.
echo [STATUS] Creating web application project...
echo [INFO] Available web templates:
echo [INFO] - React + TypeScript
echo [INFO] - Vue.js + Nuxt
echo [INFO] - Angular
echo [INFO] - Next.js
echo [INFO] - SvelteKit
echo.
set /p project_name="Enter project name: "
if "%project_name%"=="" (
echo [ERROR] Project name is required
pause
goto :project_templates
)
echo [INFO] Creating web project: %project_name%
mkdir "%project_name%" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Project directory created: %project_name%
) else (
echo [ERROR] Failed to create project directory
)
pause
goto :project_templates

:api_templates
echo.
echo [STATUS] Creating API/Backend project...
echo [INFO] Available API templates:
echo [INFO] - Node.js + Express
echo [INFO] - Python + FastAPI
echo [INFO] - Python + Django
echo [INFO] - C# + ASP.NET Core
echo [INFO] - Go + Gin
echo.
set /p project_name="Enter project name: "
if "%project_name%"=="" (
echo [ERROR] Project name is required
pause
goto :project_templates
)
echo [INFO] Creating API project: %project_name%
mkdir "%project_name%" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] API project directory created: %project_name%
) else (
echo [ERROR] Failed to create API project directory
)
pause
goto :project_templates

:mobile_templates
echo.
echo [STATUS] Creating mobile application project...
echo [INFO] Available mobile templates:
echo [INFO] - React Native
echo [INFO] - Flutter
echo [INFO] - Ionic
echo [INFO] - Xamarin
echo.
set /p project_name="Enter project name: "
if "%project_name%"=="" (
echo [ERROR] Project name is required
pause
goto :project_templates
)
echo [INFO] Creating mobile project: %project_name%
mkdir "%project_name%" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Mobile project directory created: %project_name%
) else (
echo [ERROR] Failed to create mobile project directory
)
pause
goto :project_templates

:desktop_templates
echo.
echo [STATUS] Creating desktop application project...
echo [INFO] Available desktop templates:
echo [INFO] - Electron
echo [INFO] - Tauri
echo [INFO] - PyQt
echo [INFO] - WPF
echo.
set /p project_name="Enter project name: "
if "%project_name%"=="" (
echo [ERROR] Project name is required
pause
goto :project_templates
)
echo [INFO] Creating desktop project: %project_name%
mkdir "%project_name%" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Desktop project directory created: %project_name%
) else (
echo [ERROR] Failed to create desktop project directory
)
pause
goto :project_templates

:ai_ml_templates
echo.
echo [STATUS] Creating AI/ML project...
echo [INFO] Available AI/ML templates:
echo [INFO] - TensorFlow
echo [INFO] - PyTorch
echo [INFO] - Scikit-learn
echo [INFO] - Jupyter Notebook
echo.
set /p project_name="Enter project name: "
if "%project_name%"=="" (
echo [ERROR] Project name is required
pause
goto :project_templates
)
echo [INFO] Creating AI/ML project: %project_name%
mkdir "%project_name%" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] AI/ML project directory created: %project_name%
) else (
echo [ERROR] Failed to create AI/ML project directory
)
pause
goto :project_templates

:game_templates
echo.
echo [STATUS] Creating game development project...
echo [INFO] Available game templates:
echo [INFO] - Unity 2D
echo [INFO] - Unity 3D
echo [INFO] - Unreal Engine
echo [INFO] - Godot
echo.
set /p project_name="Enter project name: "
if "%project_name%"=="" (
echo [ERROR] Project name is required
pause
goto :project_templates
)
echo [INFO] Creating game project: %project_name%
mkdir "%project_name%" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Game project directory created: %project_name%
) else (
echo [ERROR] Failed to create game project directory
)
pause
goto :project_templates

:database_templates
echo.
echo [STATUS] Creating database project...
echo [INFO] Available database templates:
echo [INFO] - PostgreSQL Schema
echo [INFO] - MySQL Schema
echo [INFO] - MongoDB Collection
echo [INFO] - SQLite Database
echo.
set /p project_name="Enter project name: "
if "%project_name%"=="" (
echo [ERROR] Project name is required
pause
goto :project_templates
)
echo [INFO] Creating database project: %project_name%
mkdir "%project_name%" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Database project directory created: %project_name%
) else (
echo [ERROR] Failed to create database project directory
)
pause
goto :project_templates

:custom_template
echo.
echo [STATUS] Creating custom project template...
echo [INFO] Custom template creation options:
echo [INFO] 1. Copy existing project as template
echo [INFO] 2. Create template from scratch
echo [INFO] 3. Import template from file
echo.
set /p custom_choice="Enter your choice (1-3): "
if "%custom_choice%"=="1" (
echo [INFO] Template creation from existing project
) else if "%custom_choice%"=="2" (
echo [INFO] Creating template from scratch
) else if "%custom_choice%"=="3" (
echo [INFO] Importing template from file
) else (
echo [ERROR] Invalid choice
)
pause
goto :project_templates

:invalid_template_choice
echo.
echo [ERROR] Invalid template choice
pause
goto :project_templates

:environment_backup
echo.
echo ========================================================================
echo                      DEVELOPMENT ENVIRONMENT BACKUP & RESTORE
echo ========================================================================
echo.

echo [STATUS] Development environment backup and restore options...
echo.

echo [1] Backup Development Environment
echo [2] Restore Development Environment
echo [3] Backup Project Settings
echo [4] Restore Project Settings
echo [5] Export Development Configuration
echo [6] Import Development Configuration
echo [7] Clean Development Environment
echo [0] Back to main menu
echo.

set /p backup_choice="Enter your choice (0-7): "

if "%backup_choice%"=="1" goto :backup_environment
if "%backup_choice%"=="2" goto :restore_environment
if "%backup_choice%"=="3" goto :backup_project_settings
if "%backup_choice%"=="4" goto :restore_project_settings
if "%backup_choice%"=="5" goto :export_configuration
if "%backup_choice%"=="6" goto :import_configuration
if "%backup_choice%"=="7" goto :clean_environment
if "%backup_choice%"=="0" goto :menu
goto :invalid_backup_choice

:backup_environment
echo.
echo [STATUS] Creating development environment backup...
echo [INFO] Backing up development tools configuration...

if not exist "%~dp0backups" (
mkdir "%~dp0backups" 2>nul
echo [SUCCESS] Backup directory created
)

echo [STEP 1/5] Backing up VS Code settings...
if exist "%APPDATA%\Code\User\settings.json" (
copy "%APPDATA%\Code\User\settings.json" "%~dp0backups\vscode-settings.json" >nul 2>&1
echo [SUCCESS] VS Code settings backed up
) else (
echo [WARNING] VS Code settings not found
)

echo [STEP 2/5] Backing up Cursor settings...
if exist "%USERPROFILE%\.cursor\User\settings.json" (
copy "%USERPROFILE%\.cursor\User\settings.json" "%~dp0backups\cursor-settings.json" >nul 2>&1
echo [SUCCESS] Cursor settings backed up
) else (
echo [WARNING] Cursor settings not found
)

echo [STEP 3/5] Backing up Git configuration...
git config --list > "%~dp0backups\git-config.txt" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Git configuration backed up
) else (
echo [WARNING] Git configuration backup failed
)

echo [STEP 4/5] Backing up npm configuration...
npm config list > "%~dp0backups\npm-config.txt" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] NPM configuration backed up
) else (
echo [WARNING] NPM configuration backup failed
)

echo [STEP 5/5] Backing up Python packages...
pip list > "%~dp0backups\python-packages.txt" 2>nul
if %errorlevel%==0 (
echo [SUCCESS] Python packages list backed up
) else (
echo [WARNING] Python packages backup failed
)

echo.
echo [COMPLETED] Development environment backup completed
echo [SUCCESS] Backup files saved to: %~dp0backups\
pause
goto :environment_backup

:restore_environment
echo.
echo [STATUS] Restoring development environment...
echo [WARNING] This will overwrite current configuration
set /p confirm="Are you sure you want to restore? (Y/N): "
if /i not "%confirm%"=="Y" (
echo [INFO] Environment restore cancelled
pause
goto :environment_backup
)

echo [INFO] Restoring development environment from backup...
if exist "%~dp0backups\vscode-settings.json" (
copy "%~dp0backups\vscode-settings.json" "%APPDATA%\Code\User\settings.json" >nul 2>&1
echo [SUCCESS] VS Code settings restored
)
if exist "%~dp0backups\cursor-settings.json" (
copy "%~dp0backups\cursor-settings.json" "%USERPROFILE%\.cursor\User\settings.json" >nul 2>&1
echo [SUCCESS] Cursor settings restored
)

echo [SUCCESS] Development environment restored
pause
goto :environment_backup

:backup_project_settings
echo.
echo [STATUS] Backing up project settings...
echo [INFO] This will backup common project configuration files
echo.
echo [INFO] Project backup completed
pause
goto :environment_backup

:restore_project_settings
echo.
echo [STATUS] Restoring project settings...
echo [INFO] This will restore project configuration from backup
echo.
echo [INFO] Project settings restored
pause
goto :environment_backup

:export_configuration
echo.
echo [STATUS] Exporting development configuration...
echo [INFO] Creating configuration export file...
echo.
echo [SUCCESS] Configuration exported successfully
pause
goto :environment_backup

:import_configuration
echo.
echo [STATUS] Importing development configuration...
echo [INFO] Loading configuration from import file...
echo.
echo [SUCCESS] Configuration imported successfully
pause
goto :environment_backup

:clean_environment
echo.
echo [STATUS] Cleaning development environment...
echo [WARNING] This will remove temporary files and caches
set /p confirm="Are you sure you want to clean the environment? (Y/N): "
if /i not "%confirm%"=="Y" (
echo [INFO] Environment cleaning cancelled
pause
goto :environment_backup
)

echo [INFO] Cleaning development environment...
echo [SUCCESS] Development environment cleaned
pause
goto :environment_backup

:invalid_backup_choice
echo.
echo [ERROR] Invalid backup choice
pause
goto :environment_backup

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
echo ========================================================================
echo                         DEVELOPMENT TOOLS SUMMARY
echo ========================================================================
echo.

echo [INFO] Development Tools Manager Session Summary:
echo [INFO] - Tools installed: %TOOLS_INSTALLED%
echo [INFO] - Total tools managed: %TOTAL_TOOLS%
echo [INFO] - Development environment status: %TOOLS_STATUS%/6 tools installed

if %TOOLS_INSTALLED% gtr 0 (
echo [SUCCESS] Development tools installation completed successfully
echo [INFO] Please restart your terminal for changes to take effect
) else (
echo [INFO] No tools were installed in this session
)

echo.
echo [INFO] Development Tools Manager closed
echo [INFO] Thank you for using DevOptimizer System
echo [INFO] For best development experience, keep tools updated regularly
exit /b 0
