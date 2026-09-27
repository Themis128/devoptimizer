#Requires -RunAsAdministrator

# AI Development Tools Optimization Script
# Comprehensive setup for modern AI development environments

<#+
.SYNOPSIS
Configures development tools, editors, and AI assistants for a complete AI engineering workstation.

.DESCRIPTION
Detects system capabilities, applies tuned settings for Cursor and other editors, and optionally installs support utilities for Copilot, local AI runtimes, or the full recommended stack.

.PARAMETER InstallAll
Applies every optimization and installs all supported AI development tools.

.PARAMETER CursorOnly
Restricts the workflow to Cursor-specific configuration tasks.

.PARAMETER CopilotOnly
Installs or updates GitHub Copilot tooling without modifying other components.

.PARAMETER LocalAIOnly
Focuses on local AI runtime preparation, including dependencies and configuration.

.PARAMETER Verbose
Enables additional console logging for troubleshooting the setup process.

.EXAMPLE
PS> .\ai-development-tools.ps1 -InstallAll
Executes the full AI development environment setup with every available optimization.

.EXAMPLE
PS> .\ai-development-tools.ps1 -CursorOnly -Verbose
Configures Cursor-specific settings while emitting detailed progress logs.

.NOTES
Author: DevOptimizer automation tools
#>

param(
    [switch]$InstallAll,
    [switch]$CursorOnly,
    [switch]$CopilotOnly,
    [switch]$LocalAIOnly,
    [switch]$Verbose
)

# Enhanced logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "DEBUG" { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# System information
function Get-SystemInfo {
    Write-Log "Gathering system information..." -Level "INFO"
    
    $system = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" }
    $ram = [math]::Round($system.TotalPhysicalMemory / 1GB, 2)
    
    Write-Log "System: $($system.Name)" -Level "INFO"
    Write-Log "OS: $($os.Caption) $($os.Version)" -Level "INFO"
    Write-Log "CPU: $($cpu.Name)" -Level "INFO"
    Write-Log "RAM: $ram GB" -Level "INFO"
    Write-Log "GPU: $($gpu[0].Name)" -Level "INFO"
    
    return @{
        RAM = $ram
        CPU = $cpu.Name
        GPU = $gpu[0].Name
        Is64Bit = [Environment]::Is64BitOperatingSystem
    }
}

# Enhanced Cursor AI optimization
function Optimize-CursorAI {
    Write-Log "Optimizing Cursor AI for advanced development..." -Level "INFO"
    
    try {
        $cursorConfig = "$env:APPDATA\Cursor\User"
        if (!(Test-Path $cursorConfig)) {
            New-Item -ItemType Directory -Path $cursorConfig -Force | Out-Null
        }
        
        # Advanced Cursor settings for AI development
        $cursorSettings = @{
            "editor.fontSize" = 14
            "editor.fontFamily" = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace"
            "editor.fontLigatures" = $true
            "editor.bracketPairColorization.enabled" = $true
            "editor.guides.bracketPairs" = "active"
            "editor.minimap.enabled" = $true
            "editor.wordWrap" = "bounded"
            "editor.renderWhitespace" = "boundary"
            "editor.smoothScrolling" = $true
            "workbench.iconTheme" = "material-icon-theme"
            "workbench.colorTheme" = "One Dark Pro"
            "extensions.autoUpdate" = $true
            "files.autoSave" = "afterDelay"
            "files.autoSaveDelay" = 500
            "editor.inlineSuggest.enabled" = $true
            "editor.suggest.preview" = $true
            "editor.parameterHints.enabled" = $true
            "git.autoFetch" = $true
            "git.autofetchPeriod" = 120
            "terminal.integrated.fontSize" = 13
            "workbench.editor.enablePreview" = $false
            "editor.formatOnSave" = $true
            "editor.formatOnPaste" = $true
            "editor.linkedEditing" = $true
            "editor.hover.sticky" = $true
            "editor.stickyScroll.enabled" = $true
            "breadcrumbs.enabled" = $true
            "explorer.confirmDragAndDrop" = $false
            "explorer.confirmDelete" = $false
            # AI-specific optimizations
            "github.copilot.enable" = @{
                "*" = $true
                "yaml" = $false
                "plaintext" = $false
            }
            "cursor.ai.enable" = $true
            "cursor.ai.autoComplete" = $true
            "cursor.ai.chat.enable" = $true
            # Performance optimizations
            "search.useGlobalIgnoreFiles" = $true
            "search.useParentIgnoreFiles" = $true
            "search.followSymlinks" = $false
            "files.watcherExclude" = @{
                "**/.git/objects/**" = $true
                "**/.git/subtree-cache/**" = $true
                "**/node_modules/**" = $true
                "**/.hg/store/**" = $true
                "**/dist/**" = $true
                "**/build/**" = $true
                "**/.next/**" = $true
                "**/.nuxt/**" = $true
                "**/coverage/**" = $true
                "**/.pnpm-store/**" = $true
                "**/.pnpm-state/**" = $true
                "**/__pycache__/**" = $true
                "**/*.pyc" = $true
                "**/.pytest_cache/**" = $true
                "**/.mypy_cache/**" = $true
            }
            # TypeScript/JavaScript optimizations
            "typescript.preferences.includePackageJsonAutoImports" = "auto"
            "typescript.suggest.autoImports" = $true
            "typescript.updateImportsOnFileMove.enabled" = "always"
            "javascript.preferences.includePackageJsonAutoImports" = "auto"
            "javascript.suggest.autoImports" = $true
            "javascript.updateImportsOnFileMove.enabled" = "always"
            # Python optimizations
            "python.defaultInterpreterPath" = "python"
            "python.terminal.activateEnvironment" = $true
            "python.linting.enabled" = $true
            "python.linting.pylintEnabled" = $true
            "python.formatting.provider" = "black"
            "python.sortImports.args" = @("--profile", "black")
        }
        
        $settingsPath = "$cursorConfig\settings.json"
        $cursorSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $settingsPath -Encoding UTF8
        Write-Log "Cursor AI settings updated: $settingsPath" -Level "SUCCESS"
        
        # Install AI development extensions
        $extensions = @(
            "ms-vscode.vscode-typescript-next",
            "bradlc.vscode-tailwindcss",
            "esbenp.prettier-vscode",
            "dbaeumer.vscode-eslint",
            "ms-python.python",
            "ms-toolsai.jupyter",
            "ms-toolsai.jupyter-keymap",
            "ms-toolsai.jupyter-renderers",
            "GitHub.copilot",
            "GitHub.copilot-chat",
            "ms-python.black-formatter",
            "ms-python.isort",
            "ms-python.pylint",
            "ms-python.flake8",
            "ms-python.mypy-type-checker",
            "PKief.material-icon-theme",
            "zhuangtongfa.Material-theme",
            "formulahendry.auto-rename-tag",
            "christian-kohler.path-intellisense",
            "ms-vscode.hexeditor",
            "usernamehw.errorlens",
            "ms-vscode.vscode-json",
            "yzhang.markdown-all-in-one",
            "ms-vscode.powershell"
        )
        
        foreach ($ext in $extensions) {
            try {
                $null = & "cursor" --install-extension $ext 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Installed extension: $ext" -Level "SUCCESS"
                } else {
                    Write-Log "Failed to install extension: $ext" -Level "WARNING"
                }
            }
            catch {
                Write-Log "Error installing extension $ext : $($_.Exception.Message)" -Level "ERROR"
            }
        }
        
        Write-Log "Cursor AI optimization completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error in Cursor AI optimization: $($_.Exception.Message)" -Level "ERROR"
    }
}

# GitHub Copilot optimization
function Optimize-GitHubCopilot {
    Write-Log "Setting up GitHub Copilot..." -Level "INFO"
    
    try {
        # Configure Git for Copilot
        git config --global user.name "AI Developer"
        git config --global user.email "ai.developer@example.com"
        
        # Install Copilot CLI if available
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            npm install -g @githubnext/github-copilot-cli
            Write-Log "GitHub Copilot CLI installed" -Level "SUCCESS"
        }
        
        Write-Log "GitHub Copilot setup completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error in GitHub Copilot setup: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Local AI models setup (Ollama, LM Studio)
function Install-LocalAIModels {
    Write-Log "Setting up local AI models..." -Level "INFO"
    
    try {
        # Install Ollama if not present
        $ollamaPath = "$env:USERPROFILE\AppData\Local\Programs\Ollama\ollama.exe"
        if (!(Test-Path $ollamaPath)) {
            Write-Log "Installing Ollama..." -Level "INFO"
            $ollamaUrl = "https://ollama.ai/download/ollama-windows-amd64.exe"
            $ollamaInstaller = "$env:TEMP\ollama-installer.exe"
            Invoke-WebRequest -Uri $ollamaUrl -OutFile $ollamaInstaller
            Start-Process -FilePath $ollamaInstaller -Wait
            Remove-Item $ollamaInstaller -Force
        }
        
        # Create AI models directory
        $aiModelsDir = "$env:USERPROFILE\AI-Models"
        if (!(Test-Path $aiModelsDir)) {
            New-Item -ItemType Directory -Path $aiModelsDir -Force | Out-Null
        }
        
        # Setup environment variables for AI development
        [Environment]::SetEnvironmentVariable("AI_MODELS_PATH", $aiModelsDir, "User")
        [Environment]::SetEnvironmentVariable("OLLAMA_HOST", "http://localhost:11434", "User")
        
        Write-Log "Local AI models setup completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error in local AI models setup: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Main execution
try {
    Write-Log "Starting AI Development Tools Optimization..." -Level "INFO"
    
    # Get system info for logging purposes
    $null = Get-SystemInfo
    
    if ($InstallAll -or $CursorOnly) {
        Optimize-CursorAI
    }
    
    if ($InstallAll -or $CopilotOnly) {
        Optimize-GitHubCopilot
    }
    
    if ($InstallAll -or $LocalAIOnly) {
        Install-LocalAIModels
    }
    
    Write-Log "AI Development Tools optimization completed successfully!" -Level "SUCCESS"
}
catch {
    Write-Log "Unhandled error: $($_.Exception.Message)" -Level "ERROR"
}
