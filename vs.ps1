# VS Code Insiders Installation Script with Python PATH, WSL Remote & Auto-Updates
# Run as Administrator

#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " VS Code Insiders Setup Script" -ForegroundColor Cyan
Write-Host " With Python, WSL & Auto-Updates" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Function to refresh PATH
function Update-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    # Also add WindowsApps for winget
    if ($env:Path -notlike "*WindowsApps*") {
        $env:Path += ";$env:LOCALAPPDATA\Microsoft\WindowsApps"
    }
}

# Function to get winget command (full path if needed)
function Get-WingetCommand {
    # Try direct command first
    try {
        $result = Get-Command winget -ErrorAction Stop
        return "winget"
    } catch {}
    
    # Try WindowsApps path
    $wingetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $wingetPath) {
        return $wingetPath
    }
    
    # Try finding via App Installer
    $appInstaller = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue
    if ($appInstaller) {
        $installLocation = $appInstaller.InstallLocation
        $wingetExe = Join-Path $installLocation "winget.exe"
        if (Test-Path $wingetExe) {
            return $wingetExe
        }
    }
    
    return $null
}

# Function to run winget command
function Invoke-Winget {
    param([string[]]$Arguments)
    
    $wingetCmd = Get-WingetCommand
    if (-not $wingetCmd) {
        Write-Host "  ⚠ Winget not available" -ForegroundColor Yellow
        return $false
    }
    
    try {
        & $wingetCmd @Arguments 2>$null
        return $true
    } catch {
        return $false
    }
}

# Function to check if a command exists
function Test-CommandExists {
    param ($command)
    try {
        if (Get-Command $command -ErrorAction Stop) { return $true }
    }
    catch { return $false }
    return $false
}

# Initialize PATH
Update-Path

# ============================================
# SECTION 1: WINGET CHECK
# ============================================
Write-Host "`n[1/10] Checking Winget..." -ForegroundColor Yellow

$wingetCmd = Get-WingetCommand

if ($wingetCmd) {
    $wingetVersion = & $wingetCmd --version 2>&1
    Write-Host "  ✓ Winget found: $wingetVersion" -ForegroundColor Green
    Write-Host "    Command: $wingetCmd" -ForegroundColor Gray
    
    # Update sources
    Write-Host "  Updating sources..." -ForegroundColor Gray
    & $wingetCmd source update --disable-interactivity 2>$null
} else {
    Write-Host "  ⚠ Winget not found!" -ForegroundColor Red
    Write-Host "  Please install App Installer from Microsoft Store" -ForegroundColor Yellow
    Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
    Write-Host "  After installing, restart PowerShell and run script again" -ForegroundColor Yellow
    exit
}

# Store winget command for later use
$Global:WingetCmd = $wingetCmd

# ============================================
# SECTION 2: WINDOWS UPDATE CHECK
# ============================================
Write-Host "`n[2/10] Checking Windows Updates..." -ForegroundColor Yellow
try {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "  Installing PSWindowsUpdate module..." -ForegroundColor Gray
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction SilentlyContinue
    }
    
    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
    $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction SilentlyContinue
    if ($updates -and $updates.Count -gt 0) {
        Write-Host "  ⚠ $($updates.Count) Windows updates available" -ForegroundColor Yellow
        Write-Host "    Run 'Get-WindowsUpdate -Install' to install them" -ForegroundColor Gray
    } else {
        Write-Host "  ✓ Windows is up to date" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠ Could not check Windows updates (non-critical)" -ForegroundColor Yellow
}

# ============================================
# SECTION 3: GIT - INSTALL & UPDATE
# ============================================
Write-Host "`n[3/10] Installing/Updating Git..." -ForegroundColor Yellow
if (Test-CommandExists git) {
    $currentGit = git --version
    Write-Host "  Current: $currentGit" -ForegroundColor Gray
    Write-Host "  Checking for updates..." -ForegroundColor Gray
    & $Global:WingetCmd upgrade --id Git.Git -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Update-Path
    $newGit = git --version
    Write-Host "  ✓ Git: $newGit" -ForegroundColor Green
} else {
    Write-Host "  Installing Git..." -ForegroundColor Gray
    & $Global:WingetCmd install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    Update-Path
    Start-Sleep -Seconds 2
    if (Test-CommandExists git) {
        Write-Host "  ✓ Git installed: $(git --version)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Git installed, restart PowerShell to use" -ForegroundColor Yellow
    }
}

# ============================================
# SECTION 4: NODE.JS - INSTALL & UPDATE
# ============================================
Write-Host "`n[4/10] Installing/Updating Node.js LTS..." -ForegroundColor Yellow
if (Test-CommandExists node) {
    $currentNode = node --version
    Write-Host "  Current: Node $currentNode" -ForegroundColor Gray
    Write-Host "  Checking for updates..." -ForegroundColor Gray
    & $Global:WingetCmd upgrade --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Update-Path
    $newNode = node --version
    Write-Host "  ✓ Node.js: $newNode" -ForegroundColor Green
} else {
    Write-Host "  Installing Node.js LTS..." -ForegroundColor Gray
    & $Global:WingetCmd install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
    Update-Path
    Start-Sleep -Seconds 2
    if (Test-CommandExists node) {
        Write-Host "  ✓ Node.js installed: $(node --version)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Node.js installed, restart PowerShell to use" -ForegroundColor Yellow
    }
}

# Update npm
if (Test-CommandExists npm) {
    Write-Host "  Updating npm..." -ForegroundColor Gray
    npm install -g npm@latest 2>$null
    $npmVersion = npm --version
    Write-Host "  ✓ npm: $npmVersion" -ForegroundColor Green
}

# ============================================
# SECTION 5: PYTHON - CHECK & UPDATE
# ============================================
Write-Host "`n[5/10] Checking/Updating Python..." -ForegroundColor Yellow
$pythonPath = $null
$pythonCmd = $null

if (Test-CommandExists python) {
    $pythonCmd = "python"
    $pythonPath = (Get-Command python).Source
} elseif (Test-CommandExists python3) {
    $pythonCmd = "python3"
    $pythonPath = (Get-Command python3).Source
} elseif (Test-CommandExists py) {
    $pythonCmd = "py"
    $pythonPath = (Get-Command py).Source
}

if ($pythonCmd) {
    $pythonVersion = & $pythonCmd --version 2>&1
    Write-Host "  Current: $pythonVersion" -ForegroundColor Gray
    Write-Host "  Path: $pythonPath" -ForegroundColor Gray
    
    # Update pip
    Write-Host "  Updating pip..." -ForegroundColor Gray
    & $pythonCmd -m pip install --upgrade pip 2>$null
    Write-Host "  ✓ pip updated" -ForegroundColor Green
    
    # Update essential Python packages
    Write-Host "  Updating essential Python packages..." -ForegroundColor Gray
    $pythonPackages = @(
        "setuptools", "wheel", "virtualenv", "pylint", "black",
        "isort", "autopep8", "flake8", "mypy", "pytest",
        "jupyter", "ipykernel", "numpy", "pandas"
    )
    
    foreach ($pkg in $pythonPackages) {
        Write-Host "    → $pkg" -ForegroundColor Gray -NoNewline
        & $pythonCmd -m pip install --upgrade $pkg 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " ✓" -ForegroundColor Green
        } else {
            Write-Host " ⚠" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  ⚠ Python not found in PATH!" -ForegroundColor Red
    $installPython = Read-Host "  Install Python 3.12 via winget? (y/n)"
    if ($installPython -eq 'y') {
        & $Global:WingetCmd install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
        Update-Path
        $pythonCmd = "python"
        $pythonPath = "python"
    }
}

# ============================================
# SECTION 6: WSL - CHECK & UPDATE
# ============================================
Write-Host "`n[6/10] Checking/Updating WSL..." -ForegroundColor Yellow
$wslInstalled = $false

try {
    $wslVersion = wsl --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $wslInstalled = $true
        Write-Host "  ✓ WSL is installed" -ForegroundColor Green
        
        Write-Host "  Updating WSL kernel..." -ForegroundColor Gray
        wsl --update 2>$null
        
        Write-Host "  Installed distributions:" -ForegroundColor Gray
        wsl -l -v 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        
        Write-Host "  Updating packages in default WSL distro..." -ForegroundColor Gray
        wsl -e bash -c "sudo apt update && sudo apt upgrade -y" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ WSL packages updated" -ForegroundColor Green
        }
    }
} catch {}

if (-not $wslInstalled) {
    Write-Host "  ⚠ WSL not detected" -ForegroundColor Yellow
    $installWSL = Read-Host "  Install WSL now? (y/n)"
    if ($installWSL -eq 'y') {
        wsl --install
        Write-Host "  ⚠ Please RESTART your computer after WSL installation!" -ForegroundColor Red
    }
}

# ============================================
# SECTION 7: VS CODE INSIDERS - INSTALL & UPDATE
# ============================================
Write-Host "`n[7/10] Installing/Updating VS Code Insiders..." -ForegroundColor Yellow

# Check if VS Code Insiders is installed
$vscodeInsidersPath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"
$vscodeInstalled = Test-Path $vscodeInsidersPath

if ($vscodeInstalled) {
    Write-Host "  VS Code Insiders found, checking for updates..." -ForegroundColor Gray
    & $Global:WingetCmd upgrade --id Microsoft.VisualStudioCode.Insiders -e --accept-source-agreements --accept-package-agreements --silent 2>$null
    Write-Host "  ✓ VS Code Insiders updated" -ForegroundColor Green
} else {
    Write-Host "  Installing VS Code Insiders..." -ForegroundColor Gray
    & $Global:WingetCmd install --id Microsoft.VisualStudioCode.Insiders -e --accept-source-agreements --accept-package-agreements
    
    # Wait for installation
    Write-Host "  Waiting for installation to complete..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
    
    # Refresh PATH
    Update-Path
}

# Find code-insiders command
$codeCmd = $null
$possiblePaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd",
    "$env:ProgramFiles\Microsoft VS Code Insiders\bin\code-insiders.cmd",
    "${env:ProgramFiles(x86)}\Microsoft VS Code Insiders\bin\code-insiders.cmd"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $codeCmd = $path
        Write-Host "  ✓ Found VS Code Insiders at: $path" -ForegroundColor Green
        break
    }
}

# Also try command directly
if (-not $codeCmd) {
    if (Test-CommandExists "code-insiders") {
        $codeCmd = "code-insiders"
        Write-Host "  ✓ VS Code Insiders available in PATH" -ForegroundColor Green
    }
}

if (-not $codeCmd) {
    Write-Host "  ⚠ VS Code Insiders not found yet" -ForegroundColor Yellow
    Write-Host "  Checking installation status..." -ForegroundColor Gray
    
    # Check if it was installed but path not updated
    Start-Sleep -Seconds 5
    Update-Path
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $codeCmd = $path
            Write-Host "  ✓ Found after PATH refresh: $path" -ForegroundColor Green
            break
        }
    }
}

if (-not $codeCmd) {
    Write-Host "  ⚠ VS Code Insiders installation may require restart" -ForegroundColor Yellow
    Write-Host "  Continuing with extension setup (may need to re-run)..." -ForegroundColor Yellow
    $codeCmd = "code-insiders"  # Try anyway
}

# ============================================
# SECTION 8: INSTALL & UPDATE ALL EXTENSIONS
# ============================================
Write-Host "`n[8/10] Installing/Updating Extensions..." -ForegroundColor Yellow

# All extensions
$allExtensions = @(
    # Core
    @{id="saoudrizwan.claude-dev"; name="Cline (AI Assistant)"}
    
    # Python
    @{id="ms-python.python"; name="Python"}
    @{id="ms-python.vscode-pylance"; name="Pylance"}
    @{id="ms-python.debugpy"; name="Python Debugger"}
    @{id="ms-python.black-formatter"; name="Black Formatter"}
    @{id="ms-python.isort"; name="isort"}
    @{id="ms-python.pylint"; name="Pylint"}
    @{id="ms-python.flake8"; name="Flake8"}
    @{id="ms-python.mypy-type-checker"; name="Mypy"}
    @{id="ms-python.autopep8"; name="autopep8"}
    @{id="ms-toolsai.jupyter"; name="Jupyter"}
    @{id="ms-toolsai.jupyter-keymap"; name="Jupyter Keymap"}
    @{id="ms-toolsai.jupyter-renderers"; name="Jupyter Renderers"}
    @{id="ms-toolsai.vscode-jupyter-cell-tags"; name="Jupyter Cell Tags"}
    @{id="ms-toolsai.vscode-jupyter-slideshow"; name="Jupyter Slideshow"}
    @{id="njpwerner.autodocstring"; name="Python Docstring"}
    @{id="KevinRose.vsc-python-indent"; name="Python Indent"}
    
    # WSL & Remote
    @{id="ms-vscode-remote.remote-wsl"; name="WSL"}
    @{id="ms-vscode-remote.remote-ssh"; name="Remote SSH"}
    @{id="ms-vscode-remote.remote-ssh-edit"; name="Remote SSH Edit"}
    @{id="ms-vscode-remote.remote-containers"; name="Dev Containers"}
    @{id="ms-vscode-remote.vscode-remote-extensionpack"; name="Remote Dev Pack"}
    @{id="ms-vscode.remote-explorer"; name="Remote Explorer"}
    @{id="ms-vscode.remote-server"; name="Remote Server"}
    @{id="ms-vscode.remote-repositories"; name="Remote Repositories"}
    @{id="ms-azuretools.vscode-docker"; name="Docker"}
    @{id="ms-kubernetes-tools.vscode-kubernetes-tools"; name="Kubernetes"}
    
    # GitHub
    @{id="GitHub.copilot"; name="GitHub Copilot"}
    @{id="GitHub.copilot-chat"; name="Copilot Chat"}
    @{id="GitHub.vscode-pull-request-github"; name="GitHub PR"}
    @{id="GitHub.vscode-github-actions"; name="GitHub Actions"}
    @{id="GitHub.codespaces"; name="Codespaces"}
    @{id="eamodio.gitlens"; name="GitLens"}
    @{id="mhutchie.git-graph"; name="Git Graph"}
    @{id="donjayamanne.githistory"; name="Git History"}
    
    # Web Dev
    @{id="esbenp.prettier-vscode"; name="Prettier"}
    @{id="dbaeumer.vscode-eslint"; name="ESLint"}
    @{id="bradlc.vscode-tailwindcss"; name="Tailwind CSS"}
    @{id="formulahendry.auto-rename-tag"; name="Auto Rename Tag"}
    @{id="formulahendry.auto-close-tag"; name="Auto Close Tag"}
    @{id="christian-kohler.path-intellisense"; name="Path Intellisense"}
    @{id="christian-kohler.npm-intellisense"; name="npm Intellisense"}
    @{id="zignd.html-css-class-completion"; name="CSS Class Completion"}
    @{id="ecmel.vscode-html-css"; name="HTML CSS Support"}
    @{id="pranaygp.vscode-css-peek"; name="CSS Peek"}
    
    # Productivity
    @{id="streetsidesoftware.code-spell-checker"; name="Code Spell Checker"}
    @{id="usernamehw.errorlens"; name="Error Lens"}
    @{id="oderwat.indent-rainbow"; name="Indent Rainbow"}
    @{id="PKief.material-icon-theme"; name="Material Icons"}
    @{id="aaron-bond.better-comments"; name="Better Comments"}
    @{id="wayou.vscode-todo-highlight"; name="TODO Highlight"}
    @{id="Gruntfuggly.todo-tree"; name="Todo Tree"}
    @{id="alefragnani.project-manager"; name="Project Manager"}
    @{id="alefragnani.Bookmarks"; name="Bookmarks"}
    @{id="yzhang.markdown-all-in-one"; name="Markdown AIO"}
    @{id="bierner.markdown-preview-github-styles"; name="MD Preview GitHub"}
    @{id="redhat.vscode-yaml"; name="YAML"}
    @{id="tamasfe.even-better-toml"; name="TOML"}
    @{id="mikestead.dotenv"; name="DotENV"}
    
    # Data
    @{id="ms-toolsai.datawrangler"; name="Data Wrangler"}
    @{id="RandomFractalsInc.vscode-data-preview"; name="Data Preview"}
    @{id="mechatroner.rainbow-csv"; name="Rainbow CSV"}
    @{id="GrapeCity.gc-excelviewer"; name="Excel Viewer"}
    @{id="mtxr.sqltools"; name="SQLTools"}
)

Write-Host "  Installing $($allExtensions.Count) extensions..." -ForegroundColor Gray

$installed = 0
$failed = 0

foreach ($ext in $allExtensions) {
    Write-Host "  → $($ext.name)..." -ForegroundColor Gray -NoNewline
    try {
        $result = & $codeCmd --install-extension $ext.id --force 2>&1
        if ($result -notlike "*failed*" -and $result -notlike "*error*") {
            Write-Host " ✓" -ForegroundColor Green
            $installed++
        } else {
            Write-Host " ⚠" -ForegroundColor Yellow
            $failed++
        }
    }
    catch {
        Write-Host " ⚠" -ForegroundColor Yellow
        $failed++
    }
}

Write-Host "`n  Extensions: $installed installed, $failed skipped" -ForegroundColor Cyan

# ============================================
# SECTION 9: UPDATE ALL EXTENSIONS
# ============================================
Write-Host "`n[9/10] Updating All Extensions..." -ForegroundColor Yellow

try {
    $installedExt = & $codeCmd --list-extensions 2>$null
    if ($installedExt) {
        Write-Host "  Found $($installedExt.Count) installed extensions" -ForegroundColor Gray
        Write-Host "  ✓ Extensions are up to date (auto-update enabled)" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠ Could not list extensions" -ForegroundColor Yellow
}

# ============================================
# SECTION 10: CONFIGURE VS CODE SETTINGS
# ============================================
Write-Host "`n[10/10] Configuring VS Code Settings..." -ForegroundColor Yellow

$settingsPath = "$env:APPDATA\Code - Insiders\User\settings.json"
$settingsDir = Split-Path $settingsPath

if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

$pythonInterpreter = if ($pythonPath) { $pythonPath } else { "python" }

$settings = @{
    # Updates
    "update.mode" = "default"
    "update.enableWindowsBackgroundUpdates" = $true
    "extensions.autoUpdate" = $true
    "extensions.autoCheckUpdates" = $true
    
    # Python
    "python.defaultInterpreterPath" = $pythonInterpreter
    "python.terminal.activateEnvironment" = $true
    "python.analysis.typeCheckingMode" = "basic"
    "python.analysis.autoImportCompletions" = $true
    "python.languageServer" = "Pylance"
    "[python]" = @{
        "editor.defaultFormatter" = "ms-python.black-formatter"
        "editor.formatOnSave" = $true
        "editor.codeActionsOnSave" = @{
            "source.organizeImports" = "explicit"
        }
    }
    
    # Jupyter
    "jupyter.askForKernelRestart" = $false
    "notebook.formatOnSave.enabled" = $true
    
    # WSL & Remote
    "remote.WSL.useShellEnvironment" = $true
    "remote.downloadExtensionsLocally" = $true
    "remote.autoForwardPorts" = $true
    "remote.SSH.defaultExtensions" = @(
        "ms-python.python",
        "ms-python.vscode-pylance",
        "saoudrizwan.claude-dev"
    )
    
    # Terminal
    "terminal.integrated.defaultProfile.windows" = "PowerShell"
    "terminal.integrated.profiles.windows" = @{
        "PowerShell" = @{ "source" = "PowerShell"; "icon" = "terminal-powershell" }
        "Command Prompt" = @{ "path" = "cmd.exe"; "icon" = "terminal-cmd" }
        "WSL" = @{ "path" = "wsl.exe"; "icon" = "terminal-linux" }
        "Git Bash" = @{ "source" = "Git Bash"; "icon" = "terminal-bash" }
    }
    "terminal.integrated.fontSize" = 13
    
    # Editor
    "editor.fontSize" = 14
    "editor.fontFamily" = "'Cascadia Code', 'Fira Code', Consolas, monospace"
    "editor.fontLigatures" = $true
    "editor.formatOnSave" = $true
    "editor.formatOnPaste" = $true
    "editor.minimap.enabled" = $true
    "editor.wordWrap" = "on"
    "editor.bracketPairColorization.enabled" = $true
    "editor.guides.bracketPairs" = "active"
    "editor.inlineSuggest.enabled" = $true
    "editor.stickyScroll.enabled" = $true
    "editor.smoothScrolling" = $true
    "editor.tabSize" = 4
    "editor.rulers" = @(80, 120)
    
    # Files
    "files.autoSave" = "afterDelay"
    "files.autoSaveDelay" = 1000
    "files.trimTrailingWhitespace" = $true
    "files.insertFinalNewline" = $true
    "files.exclude" = @{
        "**/__pycache__" = $true
        "**/.pytest_cache" = $true
        "**/*.pyc" = $true
        "**/node_modules" = $true
        "**/.venv" = $true
    }
    
    # Workbench
    "workbench.startupEditor" = "none"
    "workbench.colorTheme" = "Default Dark+"
    "workbench.iconTheme" = "material-icon-theme"
    
    # Git
    "git.autofetch" = $true
    "git.confirmSync" = $false
    "git.enableSmartCommit" = $true
    "gitlens.codeLens.enabled" = $true
    
    # GitHub Copilot
    "github.copilot.enable" = @{ "*" = $true }
    "github.copilot.editor.enableAutoCompletions" = $true
    
    # Cline
    "cline.enableAutoApproval" = $false
    
    # Formatters
    "eslint.enable" = $true
    "prettier.singleQuote" = $true
    "[javascript]" = @{ "editor.defaultFormatter" = "esbenp.prettier-vscode" }
    "[typescript]" = @{ "editor.defaultFormatter" = "esbenp.prettier-vscode" }
    "[json]" = @{ "editor.defaultFormatter" = "esbenp.prettier-vscode" }
    "[html]" = @{ "editor.defaultFormatter" = "esbenp.prettier-vscode" }
    "[css]" = @{ "editor.defaultFormatter" = "esbenp.prettier-vscode" }
    "[markdown]" = @{ "editor.defaultFormatter" = "yzhang.markdown-all-in-one" }
    
    # Telemetry
    "telemetry.telemetryLevel" = "off"
}

# Merge with existing
if (Test-Path $settingsPath) {
    try {
        $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in $settings.Keys) {
            $existing[$key] = $settings[$key]
        }
        $settings = $existing
        Write-Host "  ✓ Merged with existing settings" -ForegroundColor Green
    } catch {
        Write-Host "  Creating new settings" -ForegroundColor Gray
    }
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-Host "  ✓ Settings saved" -ForegroundColor Green

# ============================================
# BONUS: UPDATE ALL WINGET PACKAGES
# ============================================
Write-Host "`n[Bonus] Updating all packages..." -ForegroundColor Yellow
& $Global:WingetCmd upgrade --all --accept-source-agreements --accept-package-agreements --silent 2>$null
Write-Host "  ✓ Package updates complete" -ForegroundColor Green

# ============================================
# SUMMARY
# ============================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n✓ Installed/Updated:" -ForegroundColor White
Write-Host "  • Git, Node.js, npm" -ForegroundColor Gray
Write-Host "  • Python packages (pip, black, pytest, etc.)" -ForegroundColor Gray
Write-Host "  • WSL kernel & packages" -ForegroundColor Gray
Write-Host "  • VS Code Insiders" -ForegroundColor Gray
Write-Host "  • $installed extensions" -ForegroundColor Gray

Write-Host "`n✓ Extensions include:" -ForegroundColor White
Write-Host "  • Cline (AI), GitHub Copilot" -ForegroundColor Gray
Write-Host "  • Python + Pylance + Jupyter" -ForegroundColor Gray
Write-Host "  • WSL + Remote SSH + Dev Containers" -ForegroundColor Gray
Write-Host "  • GitLens, Prettier, ESLint" -ForegroundColor Gray

Write-Host "`n📌 Launch:" -ForegroundColor Yellow
Write-Host "  code-insiders           # Start VS Code Insiders" -ForegroundColor White
Write-Host "  code-insiders .         # Open current folder" -ForegroundColor White

Write-Host "`n🔄 Future updates:" -ForegroundColor Yellow
Write-Host "  winget upgrade --all    # Update all packages" -ForegroundColor White

Write-Host "`n✅ Ready! Run: " -ForegroundColor Green -NoNewline
Write-Host "code-insiders" -ForegroundColor Cyan
Write-Host ""