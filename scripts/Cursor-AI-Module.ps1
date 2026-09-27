# =====================================================
# CURSOR AI OPTIMIZATION POWERSHELL MODULE v4.0
# Advanced Cursor AI configuration and optimization
# =====================================================

<#+
.SYNOPSIS
Exposes Cursor AI configuration profiles and automation routines for DevOptimizer.

.DESCRIPTION
Wraps the DevOptimizer core logging utilities and applies Cursor AI settings, workspace tweaks, and profile-driven behaviors through a unified module entry point.

.PARAMETER ModuleOperation
Specifies which Cursor AI module action to execute (for example ApplyProfile, Analyze, or Repair).

.PARAMETER ModuleParameters
Provides a hashtable of arguments passed to the selected module operation.

.PARAMETER ModuleSilent
Suppresses non-critical output during module execution.

.PARAMETER ModuleDebugMode
Enables verbose debugging statements for troubleshooting.

.EXAMPLE
PS> .\Cursor-AI-Module.ps1 -ModuleOperation ApplyProfile -ModuleParameters @{ Profile = "AI-Focused" }
Applies the AI-Focused profile using the module automation entry point.

.EXAMPLE
PS> .\Cursor-AI-Module.ps1 -ModuleOperation Repair -ModuleSilent -ModuleDebugMode
Runs the repair workflow with minimal console noise while emitting debug diagnostics.

.NOTES
Author: DevOptimizer automation tools
#>

param(
    [Parameter(Mandatory=$false)]
    [Alias("Operation")]
    [string]$ModuleOperation,

    [Parameter(Mandatory=$false)]
    [Alias("Parameters")]
    [hashtable]$ModuleParameters = @{},

    [Parameter(Mandatory=$false)]
    [Alias("Silent")]
    [switch]$ModuleSilent,

    [Parameter(Mandatory=$false)]
    [Alias("DebugMode")]
    [switch]$ModuleDebugMode
)

# Import core module only if not already loaded
if (-not (Get-Command -Name Write-Log -ErrorAction SilentlyContinue)) {
    $coreModule = Join-Path $PSScriptRoot "DevOptimizer-Core.ps1"
    if (Test-Path $coreModule) {
        . $coreModule
    }
}

# =====================================================
# CURSOR AI CONFIGURATION FUNCTIONS
# =====================================================

function Apply-CursorAIConfiguration {
    param(
        [ValidateSet("AI-Focused", "Development", "Performance", "Balanced", "Feature-Rich")]
        [string]$Profile = "AI-Focused"
    )

    Write-Log "INFO" "Applying Cursor AI configuration profile: $Profile"

    try {
        $cursorUserPath = "$env:APPDATA\Cursor\User"
        $settingsPath = "$cursorUserPath\settings.json"

        # Ensure directory exists
        if (!(Test-Path $cursorUserPath)) {
            New-Item -Path $cursorUserPath -ItemType Directory -Force | Out-Null
        }

        # Get profile-specific configuration
        $config = Get-CursorProfileConfiguration -Profile $Profile

        # Apply configuration
        $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $settingsPath -Encoding UTF8

        Write-Log "SUCCESS" "Cursor AI configuration applied: $Profile profile"
        return $true
    }
    catch {
        Write-Log "ERROR" ("Failed to apply Cursor configuration: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Get-CursorProfileConfiguration {
    param([string]$Profile)

    $baseConfig = @{
        # Core AI Features
        "cursor.ai.enableCodeGeneration" = $true
        "cursor.ai.enableInlineCompletion" = $true
        "cursor.ai.enableSmartRename" = $true
        "cursor.ai.enableContextualSuggestions" = $true
        "cursor.ai.enableMultiFileContext" = $true
        "cursor.ai.enableSemanticSearch" = $true
        "cursor.ai.enableAdvancedRefactoring" = $true
        "cursor.ai.enableErrorAnalysis" = $true

        # GitHub Copilot Integration
        "github.copilot.enable" = $true
        "github.copilot.advanced.editorPreviewFeatures" = $true
        "github.copilot.advanced.chat.agent" = $true
        "github.copilot.chat.agent.runTasks" = $true
        "github.copilot.chat.agent.available" = $true
        "github.copilot.chat.agent.editsEnabled" = $true

        # Editor Enhancements
        "editor.suggestSelection" = "first"
        "editor.tabCompletion" = "on"
        "editor.wordBasedSuggestions" = "matchingDocuments"
        "editor.suggest.insertMode" = "replace"
        "editor.suggest.preview" = $true
        "editor.suggest.showInlineDetails" = $true
        "editor.inlineSuggest.enabled" = $true
        "editor.inlineSuggest.showToolbar" = "always"
        "editor.acceptSuggestionOnCommitCharacter" = $true
        "editor.acceptSuggestionOnEnter" = "smart"

        # File Handling
        "files.autoSave" = "afterDelay"
        "files.autoSaveDelay" = 1000
        "files.trimTrailingWhitespace" = $true
        "files.insertFinalNewline" = $true
        "files.trimFinalNewlines" = $true

        # Workbench
        "workbench.colorTheme" = "One Dark Modern"
        "workbench.iconTheme" = "material-icon-theme"
        "workbench.editor.enablePreview" = $false
        "workbench.editor.enablePreviewFromQuickOpen" = $false

        # Extensions and Updates
        "update.releaseTrack" = "prerelease"
        "extensions.autoCheckUpdates" = $true
        "extensions.autoUpdate" = "onlyEnabledExtensions"

        # Security and Privacy
        "telemetry.telemetryLevel" = "error"
        "security.workspace.trust.enabled" = $true
    }

    switch ($Profile) {
        "AI-Focused" {
            $baseConfig["cursor.ai.maxContextLines"] = 20000
            $baseConfig["cursor.composer.shouldChimeAfterChatFinishes"] = $true
            $baseConfig["cursor.composer.enableAdvancedMode"] = $true
            $baseConfig["cursor.composer.enableMultiFileEdits"] = $true
            $baseConfig["cursor.composer.enableContextualAwareness"] = $true
            $baseConfig["cursor.composer.maxTokens"] = 32000
            $baseConfig["cursor.composer.temperature"] = 0.1
            $baseConfig["cursor.composer.enableCodeReview"] = $true
            $baseConfig["typescript.tsserver.maxTsServerMemory"] = 6144
            $baseConfig["github.copilot.chat.logging.level"] = "INFO"
            $baseConfig["github.copilot.logging.level"] = "INFO"
            $baseConfig["github.copilot.advanced.length"] = 1000
            $baseConfig["github.copilot.advanced.top_p"] = 0.1
            $baseConfig["github.copilot.advanced.temperature"] = 0.1
        }
        "Development" {
            $baseConfig["cursor.ai.maxContextLines"] = 10000
            $baseConfig["typescript.tsserver.maxTsServerMemory"] = 4096
            $baseConfig["editor.minimap.enabled"] = $true
            $baseConfig["editor.renderWhitespace"] = "boundary"
            $baseConfig["workbench.editor.limit.enabled"] = $true
            $baseConfig["workbench.editor.limit.value"] = 15
        }
        "Performance" {
            $baseConfig["cursor.ai.maxContextLines"] = 5000
            $baseConfig["typescript.tsserver.maxTsServerMemory"] = 2048
            $baseConfig["editor.minimap.enabled"] = $false
            $baseConfig["editor.renderWhitespace"] = "none"
            $baseConfig["workbench.editor.enablePreview"] = $true
            $baseConfig["extensions.autoUpdate"] = $false
        }
        "Balanced" {
            $baseConfig["cursor.ai.maxContextLines"] = 15000
            $baseConfig["typescript.tsserver.maxTsServerMemory"] = 4096
            $baseConfig["cursor.composer.maxTokens"] = 16000
        }
        "Feature-Rich" {
            $baseConfig["cursor.ai.maxContextLines"] = 25000
            $baseConfig["cursor.composer.maxTokens"] = 50000
            $baseConfig["typescript.tsserver.maxTsServerMemory"] = 8192
            $baseConfig["editor.minimap.enabled"] = $true
            $baseConfig["editor.bracketPairColorization.enabled"] = $true
            $baseConfig["workbench.editor.decorations.colors"] = $true
            $baseConfig["workbench.editor.decorations.badges"] = $true
        }
    }

    return $baseConfig
}

function Configure-CursorKeybindings {
    param([string]$Profile = "AI-Focused")

    Write-Log "INFO" "Configuring Cursor keybindings for profile: $Profile"

    try {
        $cursorUserPath = "$env:APPDATA\Cursor\User"
        $keybindingsPath = "$cursorUserPath\keybindings.json"

        # Ensure directory exists
        if (!(Test-Path $cursorUserPath)) {
            New-Item -Path $cursorUserPath -ItemType Directory -Force | Out-Null
        }

        $keybindings = @(
            # AI Composer Mode (Primary AI Features)
            @{
                key = "ctrl+i"
                command = "composerMode.agent"
                when = "editorTextFocus"
            },
            @{
                key = "ctrl+e"
                command = "composerMode.background"
                when = "editorTextFocus"
            },
            @{
                key = "ctrl+shift+i"
                command = "cursor.composer.showComposer"
            },
            @{
                key = "ctrl+alt+i"
                command = "cursor.composer.toggleMode"
            },

            # AI Chat and Assistance
            @{
                key = "ctrl+l"
                command = "cursor.chat.toggle"
            },
            @{
                key = "ctrl+shift+l"
                command = "cursor.chat.newConversation"
            },
            @{
                key = "ctrl+alt+l"
                command = "cursor.chat.explainCode"
                when = "editorHasSelection"
            },
            @{
                key = "ctrl+shift+alt+l"
                command = "cursor.chat.generateTests"
                when = "editorHasSelection"
            },

            # AI Code Generation
            @{
                key = "ctrl+j"
                command = "cursor.ai.generateCode"
                when = "editorTextFocus"
            },
            @{
                key = "ctrl+shift+j"
                command = "cursor.ai.generateFunction"
                when = "editorTextFocus"
            },
            @{
                key = "ctrl+alt+j"
                command = "cursor.ai.generateComment"
                when = "editorTextFocus"
            },
            @{
                key = "ctrl+shift+alt+j"
                command = "cursor.ai.generateDocumentation"
                when = "editorTextFocus"
            },

            # AI Refactoring
            @{
                key = "ctrl+r"
                command = "cursor.ai.refactor"
                when = "editorHasSelection"
            },
            @{
                key = "ctrl+shift+r"
                command = "cursor.ai.smartRename"
                when = "editorTextFocus"
            },
            @{
                key = "ctrl+alt+r"
                command = "cursor.ai.optimizeCode"
                when = "editorHasSelection"
            },

            # Inline Suggestions
            @{
                key = "tab"
                command = "editor.action.inlineSuggest.commit"
                when = "inlineSuggestionVisible && !editorTabMovesFocus"
            },
            @{
                key = "ctrl+right"
                command = "editor.action.inlineSuggest.acceptNextWord"
                when = "inlineSuggestionVisible && !editorReadonly"
            },
            @{
                key = "alt+right"
                command = "editor.action.inlineSuggest.acceptNextLine"
                when = "inlineSuggestionVisible && !editorReadonly"
            },
            @{
                key = "escape"
                command = "editor.action.inlineSuggest.hide"
                when = "inlineSuggestionVisible"
            },

            # Enhanced Editor Shortcuts
            @{
                key = "ctrl+k ctrl+f"
                command = "editor.action.formatDocument"
                when = "editorHasDocumentFormattingProvider && editorTextFocus && !editorReadonly"
            },
            @{
                key = "alt+z"
                command = "editor.action.toggleWordWrap"
            }
        )

        $keybindings | ConvertTo-Json -Depth 3 | Out-File -FilePath $keybindingsPath -Encoding UTF8

        Write-Log "SUCCESS" "Cursor keybindings configured successfully"
        return $true
    }
    catch {
        Write-Log "ERROR" ("Failed to configure keybindings: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Install-CursorExtensions {
    param([string[]]$Extensions = @())

    Write-Log "INFO" "Installing Cursor extensions"

    try {
        # Check if Cursor CLI is available
        $cursorPath = Get-Command "cursor" -ErrorAction SilentlyContinue
        if (!$cursorPath) {
            Write-Log "ERROR" "Cursor CLI not found in PATH"
            return $false
        }

        # Default essential extensions
        if ($Extensions.Count -eq 0) {
            $Extensions = @(
                "ms-vscode.vscode-typescript-next",
                "esbenp.prettier-vscode",
                "dbaeumer.vscode-eslint",
                "eamodio.gitlens",
                "usernamehw.errorlens",
                "bradlc.vscode-tailwindcss",
                "vue.volar",
                "ms-vscode.powershell",
                "ms-azuretools.vscode-docker",
                "christian-kohler.path-intellisense",
                "pkief.material-icon-theme",
                "zhuangtongfa.material-theme",
                "ms-toolsai.jupyter",
                "ms-python.python"
            )

            Write-Log "INFO" "GitHub Copilot extensions require marketplace access; install manually when available."
        }

        $installed = 0
        $failed = 0

        foreach ($extension in $Extensions) {
            Write-Log "INFO" "Installing extension: $extension"
            Write-Progress -Activity "Installing Extensions" -Status $extension -PercentComplete (($installed / $Extensions.Count) * 100)

            try {
                $result = & cursor --install-extension $extension --force 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $installed++
                    Write-Log "SUCCESS" "Installed: $extension"
                }
                else {
                    $failed++
                    Write-Log "WARNING" "Failed to install: $extension - $result"
                }
            }
            catch {
                $failed++
                Write-Log "ERROR" ("Exception installing {0}: {1}" -f $extension, $_.Exception.Message)
            }

            Start-Sleep -Milliseconds 500
        }

        Write-Progress -Activity "Installing Extensions" -Completed

        Write-Log "INFO" "Extension installation completed. Installed: $installed, Failed: $failed"
        return $installed -gt 0
    }
    catch {
        Write-Log "ERROR" ("Failed to install extensions: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Get-CursorConfiguration {
    try {
        $settingsPath = "$env:APPDATA\Cursor\User\settings.json"

        if (Test-Path $settingsPath) {
            $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            return $settings
        }
        else {
            Write-Log "WARNING" "Cursor settings file not found"
            return $null
        }
    }
    catch {
        Write-Log "ERROR" ("Failed to get Cursor configuration: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Test-CursorInstallation {
    try {
        # Check if Cursor executable exists
        $cursorPath = Get-Command "cursor" -ErrorAction SilentlyContinue
        if (!$cursorPath) {
            return @{
                Installed = $false
                Version = $null
                Path = $null
                ConfigExists = $false
            }
        }

        # Get version
        $versionOutput = & cursor --version 2>&1
        $version = if ($versionOutput -is [array]) { $versionOutput[0] } else { $versionOutput }

        # Check configuration
        $configExists = Test-Path "$env:APPDATA\Cursor\User\settings.json"

        return @{
            Installed = $true
            Version = $version
            Path = $cursorPath.Source
            ConfigExists = $configExists
        }
    }
    catch {
        Write-Log "ERROR" ("Failed to test Cursor installation: {0}" -f $_.Exception.Message)
        return @{
            Installed = $false
            Version = $null
            Path = $null
            ConfigExists = $false
        }
    }
}

function Backup-CursorConfiguration {
    param([string]$BackupName = $null)

    try {
        if (!$BackupName) {
            $BackupName = "cursor-backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        }

        $cursorUserPath = "$env:APPDATA\Cursor\User"
        $backupPath = "$script:HubPath\backups\$BackupName"

        if (Test-Path $cursorUserPath) {
            New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
            Copy-Item -Path "$cursorUserPath\*" -Destination $backupPath -Recurse -Force

            Write-Log "SUCCESS" "Cursor configuration backed up to: $backupPath"
            return $backupPath
        }
        else {
            Write-Log "WARNING" "Cursor user directory not found"
            return $null
        }
    }
    catch {
        Write-Log "ERROR" ("Failed to backup Cursor configuration: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Restore-CursorConfiguration {
    param([string]$BackupPath)

    try {
        if (!(Test-Path $BackupPath)) {
            Write-Log "ERROR" "Backup path not found: $BackupPath"
            return $false
        }

        $cursorUserPath = "$env:APPDATA\Cursor\User"

        # Create backup of current configuration
        Backup-CursorConfiguration -BackupName "pre-restore_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

        # Restore from backup
        if (Test-Path $cursorUserPath) {
            Remove-Item -Path "$cursorUserPath\*" -Recurse -Force
        }
        else {
            New-Item -Path $cursorUserPath -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path "$BackupPath\*" -Destination $cursorUserPath -Recurse -Force

        Write-Log "SUCCESS" "Cursor configuration restored from: $BackupPath"
        return $true
    }
    catch {
        Write-Log "ERROR" ("Failed to restore Cursor configuration: {0}" -f $_.Exception.Message)
        return $false
    }
}

# =====================================================
# MAIN EXECUTION LOGIC
# =====================================================

if ($ModuleOperation) {
    switch ($ModuleOperation.ToLower()) {
        "configure" {
            $profile = if ($ModuleParameters.ContainsKey("Profile")) { $ModuleParameters["Profile"] } else { "AI-Focused" }
            Apply-CursorAIConfiguration -Profile $profile
        }
        "keybindings" {
            $profile = if ($ModuleParameters.ContainsKey("Profile")) { $ModuleParameters["Profile"] } else { "AI-Focused" }
            Configure-CursorKeybindings -Profile $profile
        }
        "extensions" {
            $extensions = if ($ModuleParameters.ContainsKey("Extensions")) { $ModuleParameters["Extensions"] } else { @() }
            Install-CursorExtensions -Extensions $extensions
        }
        "test" {
            Test-CursorInstallation
        }
        "backup" {
            $name = if ($ModuleParameters.ContainsKey("Name")) { $ModuleParameters["Name"] } else { $null }
            Backup-CursorConfiguration -BackupName $name
        }
        "restore" {
            if ($ModuleParameters.ContainsKey("BackupPath")) {
                Restore-CursorConfiguration -BackupPath $ModuleParameters["BackupPath"]
            }
        }
        "getconfig" {
            Get-CursorConfiguration
        }
        default {
            Write-Log "ERROR" "Unknown operation: $ModuleOperation"
            return $false
        }
    }
}
