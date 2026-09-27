# Cursor AI Optimization Functions - Latest 2024/2025 Best Practices

<#+
.SYNOPSIS
Provides reusable functions for auditing and optimizing Cursor AI installations.

.DESCRIPTION
Includes routines to detect Cursor AI paths, reset caches, apply configuration profiles, install recommended extensions, and run end-to-end optimization flows used by the DevOptimizer suite.

.EXAMPLE
PS> . "$(Join-Path $PSScriptRoot 'cursor-ai-optimization.ps1')"
PS> Optimize-CursorAIComplete -Profile "Balanced"
Dot sources the module and runs the full optimization pipeline with the Balanced profile.

.NOTES
Author: DevOptimizer automation tools
#>

function Get-CursorAIInfo {
    Write-Log "Gathering Cursor AI installation information..." -Level "INFO"
    
    try {
        $cursorInfo = @{
            Installed = $false
            Version = $null
            InstallPath = $null
            ConfigPath = $null
            ExtensionsPath = $null
            UserDataPath = $null
            WorkspacePath = $null
            Settings = @{}
        }
        
        # Check if Cursor is installed
        $cursorExe = Get-Command "cursor" -ErrorAction SilentlyContinue
        if ($cursorExe) {
            $cursorInfo.Installed = $true
            $cursorInfo.InstallPath = Split-Path $cursorExe.Source -Parent
            
            # Get version
            try {
                $versionOutput = & cursor --version 2>&1
                if ($versionOutput -match "(\d+\.\d+\.\d+)") {
                    $cursorInfo.Version = $matches[1]
                }
            } catch {
                Write-Log "Could not determine Cursor version" -Level "WARN"
            }
        } else {
            # Check common installation locations
            $commonPaths = @(
                "$env:LOCALAPPDATA\Programs\cursor\cursor.exe",
                "$env:PROGRAMFILES\Cursor\cursor.exe",
                "$env:PROGRAMFILES(X86)\Cursor\cursor.exe"
            )
            
            foreach ($path in $commonPaths) {
                if (Test-Path $path) {
                    $cursorInfo.Installed = $true
                    $cursorInfo.InstallPath = Split-Path $path -Parent
                    break
                }
            }
        }
        
        if ($cursorInfo.Installed) {
            # Set configuration paths
            $cursorInfo.ConfigPath = "$env:APPDATA\Cursor\User"
            $cursorInfo.ExtensionsPath = "$env:USERPROFILE\.cursor\extensions"
            $cursorInfo.UserDataPath = "$env:APPDATA\Cursor"
            $cursorInfo.WorkspacePath = "$env:APPDATA\Cursor\User\workspaceStorage"
            
            # Load current settings
            $settingsFile = "$($cursorInfo.ConfigPath)\settings.json"
            if (Test-Path $settingsFile) {
                try {
                    $settingsContent = Get-Content $settingsFile -Raw | ConvertFrom-Json
                    $cursorInfo.Settings = $settingsContent
                } catch {
                    Write-Log "Could not parse existing settings.json" -Level "WARN"
                }
            }
            
            Write-Log "Cursor AI found: Version $($cursorInfo.Version)" -Level "SUCCESS"
            Write-Log "Install Path: $($cursorInfo.InstallPath)" -Level "INFO"
            Write-Log "Config Path: $($cursorInfo.ConfigPath)" -Level "INFO"
        } else {
            Write-Log "Cursor AI not found on this system" -Level "WARN"
        }
        
        return $cursorInfo
    }
    catch {
        Write-Log "Error gathering Cursor AI info: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Optimize-CursorAISettings {
    param(
        [ValidateSet("Performance", "Balanced", "Feature-Rich", "AI-Focused", "Development")]
        [string]$ProfileName = "AI-Focused"
    )
    
    Write-Log "Optimizing Cursor AI settings for profile: $ProfileName" -Level "INFO"
    
    try {
        $cursorInfo = Get-CursorAIInfo
        if (-not $cursorInfo.Installed) {
            Write-Log "Cursor AI is not installed. Cannot optimize settings." -Level "ERROR"
            return $false
        }
        
        # Ensure config directory exists
        if (!(Test-Path $cursorInfo.ConfigPath)) {
            New-Item -ItemType Directory -Path $cursorInfo.ConfigPath -Force | Out-Null
        }
        
        # Latest 2024/2025 Cursor AI optimized settings
        $optimizedSettings = @{
            Performance = @{
                # Performance-focused settings
                "editor.fontSize" = 14
                "editor.fontFamily" = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace"
                "editor.minimap.enabled" = $false
                "editor.wordWrap" = "off"
                "editor.renderWhitespace" = "none"
                "editor.renderControlCharacters" = $false
                "editor.smoothScrolling" = $false
                "editor.cursorSmoothCaretAnimation" = "off"
                "workbench.reduceMotion" = "on"
                "extensions.autoUpdate" = $false
                "telemetry.telemetryLevel" = "off"
                "workbench.enableExperiments" = $false
                "search.searchOnType" = $false
                "files.autoSave" = "onFocusChange"
                "editor.quickSuggestions" = @{
                    "other" = $true
                    "comments" = $false
                    "strings" = $false
                }
                # AI settings for performance
                "cursor.ai.enabled" = $true
                "cursor.ai.autoComplete" = $false
                "cursor.ai.codeGeneration" = $true
                "cursor.ai.contextLimit" = 4000
            }
            Balanced = @{
                # Balanced performance and features
                "editor.fontSize" = 14
                "editor.fontFamily" = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace"
                "editor.fontLigatures" = $true
                "editor.minimap.enabled" = $true
                "editor.minimap.maxColumn" = 80
                "editor.wordWrap" = "on"
                "editor.renderWhitespace" = "selection"
                "editor.smoothScrolling" = $true
                "editor.cursorSmoothCaretAnimation" = "on"
                "workbench.iconTheme" = "material-icon-theme"
                "workbench.colorTheme" = "One Dark Pro"
                "extensions.autoUpdate" = $true
                "telemetry.telemetryLevel" = "error"
                "files.autoSave" = "afterDelay"
                "files.autoSaveDelay" = 1000
                # AI settings
                "cursor.ai.enabled" = $true
                "cursor.ai.autoComplete" = $true
                "cursor.ai.codeGeneration" = $true
                "cursor.ai.contextLimit" = 8000
                "cursor.ai.modelSelection" = "gpt-4"
                "cursor.ai.enhancedSuggestions" = $true
            }
            "Feature-Rich" = @{
                # All features enabled
                "editor.fontSize" = 15
                "editor.fontFamily" = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace"
                "editor.fontLigatures" = $true
                "editor.bracketPairColorization.enabled" = $true
                "editor.guides.bracketPairs" = "active"
                "editor.minimap.enabled" = $true
                "editor.wordWrap" = "on"
                "editor.renderWhitespace" = "all"
                "editor.smoothScrolling" = $true
                "editor.cursorSmoothCaretAnimation" = "on"
                "workbench.iconTheme" = "material-icon-theme"
                "workbench.colorTheme" = "One Dark Pro"
                "workbench.tree.renderIndentGuides" = "always"
                "extensions.autoUpdate" = $true
                "files.autoSave" = "afterDelay"
                "files.autoSaveDelay" = 500
                "editor.inlineSuggest.enabled" = $true
                "editor.suggest.preview" = $true
                "breadcrumbs.enabled" = $true
                # AI settings
                "cursor.ai.enabled" = $true
                "cursor.ai.autoComplete" = $true
                "cursor.ai.codeGeneration" = $true
                "cursor.ai.contextLimit" = 16000
                "cursor.ai.modelSelection" = "gpt-4"
                "cursor.ai.enhancedSuggestions" = $true
                "cursor.ai.codeReview" = $true
                "cursor.ai.explanations" = $true
            }
            "AI-Focused" = @{
                # Optimized for AI development and assistance
                "editor.fontSize" = 14
                "editor.fontFamily" = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace"
                "editor.fontLigatures" = $true
                "editor.minimap.enabled" = $true
                "editor.minimap.renderCharacters" = $false
                "editor.wordWrap" = "bounded"
                "editor.wordWrapColumn" = 100
                "editor.rulers" = @(80, 100)
                "editor.smoothScrolling" = $true
                "workbench.colorTheme" = "One Dark Pro"
                "workbench.iconTheme" = "material-icon-theme"
                "files.autoSave" = "afterDelay"
                "files.autoSaveDelay" = 1000
                "editor.formatOnSave" = $true
                "editor.formatOnPaste" = $true
                "editor.codeActionsOnSave" = @{
                    "source.fixAll.eslint" = "explicit"
                    "source.organizeImports" = "explicit"
                }
                # Advanced AI settings
                "cursor.ai.enabled" = $true
                "cursor.ai.autoComplete" = $true
                "cursor.ai.codeGeneration" = $true
                "cursor.ai.contextLimit" = 20000
                "cursor.ai.modelSelection" = "gpt-4"
                "cursor.ai.enhancedSuggestions" = $true
                "cursor.ai.codeReview" = $true
                "cursor.ai.explanations" = $true
                "cursor.ai.refactoring" = $true
                "cursor.ai.documentation" = $true
                "cursor.ai.testGeneration" = $true
                "cursor.ai.errorAnalysis" = $true
                "cursor.ai.performanceOptimization" = $true
                # Chat and collaboration
                "cursor.chat.enabled" = $true
                "cursor.chat.contextAware" = $true
                "cursor.chat.codebaseIndexing" = $true
                "cursor.composer.enabled" = $true
                "cursor.composer.autoApply" = $false
                # Performance optimizations for AI
                "search.useGlobalIgnoreFiles" = $true
                "search.useParentIgnoreFiles" = $true
                "files.watcherExclude" = @{
                    "**/.git/objects/**" = $true
                    "**/.git/subtree-cache/**" = $true
                    "**/node_modules/**" = $true
                    "**/.next/**" = $true
                    "**/.nuxt/**" = $true
                    "**/dist/**" = $true
                    "**/build/**" = $true
                    "**/.pnpm-store/**" = $true
                }
            }
            Development = @{
                # Optimized for general development work
                "editor.fontSize" = 14
                "editor.fontFamily" = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace"
                "editor.fontLigatures" = $true
                "editor.minimap.enabled" = $true
                "editor.wordWrap" = "on"
                "editor.bracketPairColorization.enabled" = $true
                "editor.guides.bracketPairs" = "active"
                "workbench.colorTheme" = "One Dark Pro"
                "workbench.iconTheme" = "material-icon-theme"
                "files.autoSave" = "afterDelay"
                "files.autoSaveDelay" = 1000
                "editor.formatOnSave" = $true
                "editor.codeActionsOnSave" = @{
                    "source.fixAll.eslint" = "explicit"
                    "source.organizeImports" = "explicit"
                }
                # Git integration
                "git.autoFetch" = $true
                "git.confirmSync" = $false
                "git.enableSmartCommit" = $true
                # Terminal
                "terminal.integrated.fontSize" = 13
                "terminal.integrated.fontFamily" = "Cascadia Code"
                "terminal.integrated.defaultProfile.windows" = "PowerShell"
                # AI settings for development
                "cursor.ai.enabled" = $true
                "cursor.ai.autoComplete" = $true
                "cursor.ai.codeGeneration" = $true
                "cursor.ai.contextLimit" = 12000
                "cursor.ai.modelSelection" = "gpt-4"
                "cursor.ai.enhancedSuggestions" = $true
                "cursor.ai.codeReview" = $true
                # Language specific
                "typescript.preferences.includePackageJsonAutoImports" = "auto"
                "typescript.suggest.autoImports" = $true
                "typescript.updateImportsOnFileMove.enabled" = "always"
                "javascript.preferences.includePackageJsonAutoImports" = "auto"
                "javascript.suggest.autoImports" = $true
                "javascript.updateImportsOnFileMove.enabled" = "always"
                # Extensions
                "extensions.ignoreRecommendations" = $false
                "extensions.showRecommendationsOnlyOnDemand" = $false
            }
        }
        
        # Apply the selected profile settings
        $settings = $optimizedSettings[$Profile]
        $settingsPath = "$($cursorInfo.ConfigPath)\settings.json"
        
        # Merge with existing settings if they exist
        if ($cursorInfo.Settings) {
            foreach ($key in $settings.Keys) {
                $cursorInfo.Settings.$key = $settings[$key]
            }
            $finalSettings = $cursorInfo.Settings
        } else {
            $finalSettings = $settings
        }
        
        # Save settings
        $finalSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $settingsPath -Encoding UTF8
        Write-Log "Cursor AI settings optimized for $Profile profile" -Level "SUCCESS"
        
        # Create keybindings for AI features
        $keybindings = @(
            @{
                "key" = "ctrl+shift+i"
                "command" = "cursor.ai.generateCode"
                "when" = "editorTextFocus"
            },
            @{
                "key" = "ctrl+shift+e"
                "command" = "cursor.ai.explainCode"
                "when" = "editorHasSelection"
            },
            @{
                "key" = "ctrl+shift+r"
                "command" = "cursor.ai.refactorCode"
                "when" = "editorHasSelection"
            },
            @{
                "key" = "ctrl+shift+t"
                "command" = "cursor.ai.generateTests"
                "when" = "editorTextFocus"
            },
            @{
                "key" = "ctrl+shift+d"
                "command" = "cursor.ai.generateDocs"
                "when" = "editorTextFocus"
            },
            @{
                "key" = "ctrl+shift+c"
                "command" = "cursor.chat.open"
            },
            @{
                "key" = "ctrl+k ctrl+i"
                "command" = "cursor.composer.open"
            }
        )
        
        $keybindingsPath = "$($cursorInfo.ConfigPath)\keybindings.json"
        $keybindings | ConvertTo-Json -Depth 10 | Out-File -FilePath $keybindingsPath -Encoding UTF8
        Write-Log "AI-optimized keybindings configured" -Level "SUCCESS"
        
        return $true
    }
    catch {
        Write-Log "Error optimizing Cursor AI settings: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Install-CursorAIExtensions {
    param([switch]$EssentialOnly)
    
    Write-Log "Installing essential Cursor AI extensions..." -Level "INFO"
    
    try {
        $cursorInfo = Get-CursorAIInfo
        if (-not $cursorInfo.Installed) {
            Write-Log "Cursor AI is not installed. Cannot install extensions." -Level "ERROR"
            return $false
        }
        
        # Essential extensions for AI development
        $essentialExtensions = @(
            "ms-vscode.vscode-typescript-next",
            "bradlc.vscode-tailwindcss", 
            "esbenp.prettier-vscode",
            "dbaeumer.vscode-eslint",
            "ms-vscode.vscode-json",
            "PKief.material-icon-theme",
            "zhuangtongfa.Material-theme",
            "formulahendry.auto-rename-tag",
            "christian-kohler.path-intellisense",
            "usernamehw.errorlens",
            "ms-vscode.hexeditor"
        )
        
        # Additional extensions for full development
        $additionalExtensions = @(
            "yzhang.markdown-all-in-one",
            "ms-vscode.powershell",
            "ms-python.python",
            "ms-toolsai.jupyter",
            "ms-vscode.remote-wsl",
            "ms-vscode-remote.remote-containers",
            "GitHub.vscode-pull-request-github",
            "eamodio.gitlens",
            "ritwickdey.LiveServer",
            "ms-vscode.vscode-docker",
            "bradlc.vscode-tailwindcss",
            "Vue.volar",
            "johnsoncodehk.vscode-typescript-vue-plugin"
        )
        
        $extensionsToInstall = $essentialExtensions
        if (-not $EssentialOnly) {
            $extensionsToInstall += $additionalExtensions
        }
        
        $installedCount = 0
        $failedCount = 0
        
        foreach ($extension in $extensionsToInstall) {
            try {
                Write-Log "Installing extension: $extension" -Level "INFO"
                $result = & cursor --install-extension $extension --force 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Successfully installed: $extension" -Level "SUCCESS"
                    $installedCount++
                } else {
                    Write-Log "Failed to install: $extension" -Level "WARN"
                    $failedCount++
                }
            }
            catch {
                Write-Log "Error installing extension $extension : $($_.Exception.Message)" -Level "ERROR"
                $failedCount++
            }
        }
        
        Write-Log "Extension installation completed: $installedCount installed, $failedCount failed" -Level "SUCCESS"
        return $installedCount
    }
    catch {
        Write-Log "Error installing Cursor AI extensions: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Clear-CursorAICache {
    Write-Log "Clearing Cursor AI cache and temporary files..." -Level "INFO"
    
    try {
        $cursorInfo = Get-CursorAIInfo
        if (-not $cursorInfo.Installed) {
            Write-Log "Cursor AI is not installed. Cannot clear cache." -Level "ERROR"
            return $false
        }
        
        $totalCleaned = 0
        
        # Cache directories to clean
        $cachePaths = @(
            "$($cursorInfo.UserDataPath)\logs",
            "$($cursorInfo.UserDataPath)\CachedExtensions",
            "$($cursorInfo.UserDataPath)\CachedData",
            "$($cursorInfo.WorkspacePath)",
            "$env:APPDATA\Cursor\User\workspaceStorage",
            "$env:APPDATA\Cursor\User\History",
            "$env:TEMP\cursor-*"
        )
        
        foreach ($cachePath in $cachePaths) {
            if (Test-Path $cachePath) {
                try {
                    $sizeBefore = (Get-ChildItem $cachePath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    Remove-Item "$cachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $sizeAfter = (Get-ChildItem $cachePath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    $cleaned = $sizeBefore - $sizeAfter
                    $totalCleaned += $cleaned
                    
                    if ($cleaned -gt 0) {
                        Write-Log "Cleaned cache: $([math]::Round($cleaned / 1MB, 2)) MB from $cachePath" -Level "SUCCESS"
                    }
                } catch {
                    Write-Log "Could not clean cache: $cachePath" -Level "WARN"
                }
            }
        }
        
        Write-Log "Cursor AI cache cleanup completed: $([math]::Round($totalCleaned / 1MB, 2)) MB freed" -Level "SUCCESS"
        return $totalCleaned
    }
    catch {
        Write-Log "Error clearing Cursor AI cache: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Update-CursorAI {
    Write-Log "Checking for Cursor AI updates..." -Level "INFO"
    
    try {
        $cursorInfo = Get-CursorAIInfo
        if (-not $cursorInfo.Installed) {
            Write-Log "Cursor AI is not installed. Cannot check for updates." -Level "ERROR"
            return $false
        }
        
        # Try to update via Cursor's built-in updater
        try {
            Write-Log "Attempting to update Cursor AI..." -Level "INFO"
            $updateResult = & cursor --update 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Cursor AI update initiated successfully" -Level "SUCCESS"
                return $true
            } else {
                Write-Log "Cursor AI update command failed or no updates available" -Level "INFO"
            }
        } catch {
            Write-Log "Could not run update command: $($_.Exception.Message)" -Level "WARN"
        }
        
        # Alternative: Check for manual update
        Write-Log "You can manually check for updates in Cursor: Help > Check for Updates" -Level "INFO"
        return $false
    }
    catch {
        Write-Log "Error updating Cursor AI: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Optimize-CursorAIComplete {
    param(
        [ValidateSet("Performance", "Balanced", "Feature-Rich", "AI-Focused", "Development")]
        [string]$Profile = "AI-Focused"
    )
    
    Write-Log "Running complete Cursor AI optimization..." -Level "INFO"
    
    try {
        # Get system info for optimization decisions
        $ramGB = $script:Config.Performance.MaxMemoryUsage
        $cpuCores = $script:Config.Performance.CPUCores
        
        # Adjust profile based on system specs if needed
        if ($Profile -eq "AI-Focused" -and $ramGB -lt 16) {
            Write-Log "System has limited RAM ($ramGB GB), adjusting to Balanced profile" -Level "INFO"
            $Profile = "Balanced"
        } elseif ($Profile -eq "Feature-Rich" -and $ramGB -lt 8) {
            Write-Log "System has limited RAM ($ramGB GB), adjusting to Performance profile" -Level "INFO"
            $Profile = "Performance"
        }
        
        # Clear cache first
        Clear-CursorAICache
        
        # Check for updates
        Update-CursorAI
        
        # Optimize settings
        $settingsResult = Optimize-CursorAISettings -Profile $Profile
        
        # Install extensions
        $extensionsResult = Install-CursorAIExtensions
        
        if ($settingsResult -and $extensionsResult -gt 0) {
            Write-Log "Complete Cursor AI optimization finished successfully!" -Level "SUCCESS"
            Write-Log "Profile applied: $Profile" -Level "INFO"
            Write-Log "Extensions installed: $extensionsResult" -Level "INFO"
            Write-Log "RECOMMENDATION: Restart Cursor AI to apply all changes" -Level "WARN"
            return $true
        } else {
            Write-Log "Cursor AI optimization completed with some issues" -Level "WARN"
            return $false
        }
    }
    catch {
        Write-Log "Error in complete Cursor AI optimization: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}
