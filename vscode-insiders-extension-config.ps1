<#
.SYNOPSIS
    Scans and configures VS Code Insiders extensions for React, Next.js, and WSL2 development.

.DESCRIPTION
    This script:
    - Scans installed VS Code Insiders extensions
    - Identifies extensions related to React, Next.js, and WSL2
    - Installs recommended extensions if missing
    - Configures optimal settings for these technologies

.AUTHOR
    Generated for Themistoklis - Cloudless.gr

.DATE
    December 2024
#>

param(
    [switch]$ScanOnly,
    [switch]$InstallMissing,
    [switch]$ConfigureSettings,
    [switch]$All
)

# Configuration
$VSCodeInsidersPath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"
$VSCodeInsidersDataPath = "$env:APPDATA\Code - Insiders"
$SettingsPath = "$VSCodeInsidersDataPath\User\settings.json"

# Colors for output
$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Header  = "Magenta"
}

# Recommended extensions for React, Next.js, and WSL2
$RecommendedExtensions = @{
    React = @(
        @{ Id = "dsznajder.es7-react-js-snippets"; Name = "ES7+ React/Redux/React-Native snippets" }
        @{ Id = "burkeholland.simple-react-snippets"; Name = "Simple React Snippets" }
        @{ Id = "rodrigovallades.es7-react-js-snippets"; Name = "ES7 React snippets" }
        @{ Id = "msjsdiag.vscode-react-native"; Name = "React Native Tools" }
        @{ Id = "styled-components.vscode-styled-components"; Name = "vscode-styled-components" }
        @{ Id = "jpoissonnier.vscode-styled-components"; Name = "Styled Components Syntax" }
    )
    NextJS = @(
        @{ Id = "pulkitgangwar.nextjs-snippets"; Name = "Next.js snippets" }
        @{ Id = "foxundermoon.next-js"; Name = "Next.js" }
        @{ Id = "prisma.prisma"; Name = "Prisma" }
        @{ Id = "bradlc.vscode-tailwindcss"; Name = "Tailwind CSS IntelliSense" }
        @{ Id = "csstools.postcss"; Name = "PostCSS Language Support" }
    )
    WSL2 = @(
        @{ Id = "ms-vscode-remote.remote-wsl"; Name = "WSL" }
        @{ Id = "ms-vscode-remote.remote-containers"; Name = "Dev Containers" }
        @{ Id = "ms-vscode-remote.vscode-remote-extensionpack"; Name = "Remote Development" }
        @{ Id = "ms-vscode.remote-explorer"; Name = "Remote Explorer" }
    )
    Essential = @(
        @{ Id = "dbaeumer.vscode-eslint"; Name = "ESLint" }
        @{ Id = "esbenp.prettier-vscode"; Name = "Prettier" }
        @{ Id = "formulahendry.auto-rename-tag"; Name = "Auto Rename Tag" }
        @{ Id = "formulahendry.auto-close-tag"; Name = "Auto Close Tag" }
        @{ Id = "christian-kohler.path-intellisense"; Name = "Path Intellisense" }
        @{ Id = "christian-kohler.npm-intellisense"; Name = "npm Intellisense" }
        @{ Id = "wix.vscode-import-cost"; Name = "Import Cost" }
        @{ Id = "naumovs.color-highlight"; Name = "Color Highlight" }
        @{ Id = "usernamehw.errorlens"; Name = "Error Lens" }
        @{ Id = "eamodio.gitlens"; Name = "GitLens" }
        @{ Id = "github.copilot"; Name = "GitHub Copilot" }
        @{ Id = "github.copilot-chat"; Name = "GitHub Copilot Chat" }
    )
}

# Optimal settings for React/Next.js/WSL2 development
$OptimalSettings = @{
    # Editor settings
    "editor.formatOnSave" = $true
    "editor.defaultFormatter" = "esbenp.prettier-vscode"
    "editor.codeActionsOnSave" = @{
        "source.fixAll.eslint" = "explicit"
        "source.organizeImports" = "explicit"
    }
    "editor.tabSize" = 2
    "editor.wordWrap" = "on"
    "editor.bracketPairColorization.enabled" = $true
    "editor.guides.bracketPairs" = $true
    "editor.linkedEditing" = $true
    "editor.suggest.insertMode" = "replace"
    
    # Emmet for JSX
    "emmet.includeLanguages" = @{
        "javascript" = "javascriptreact"
        "typescript" = "typescriptreact"
    }
    "emmet.triggerExpansionOnTab" = $true
    
    # JavaScript/TypeScript settings
    "javascript.updateImportsOnFileMove.enabled" = "always"
    "typescript.updateImportsOnFileMove.enabled" = "always"
    "javascript.suggest.autoImports" = $true
    "typescript.suggest.autoImports" = $true
    "typescript.preferences.importModuleSpecifier" = "relative"
    "javascript.preferences.importModuleSpecifier" = "relative"
    
    # ESLint settings
    "eslint.validate" = @(
        "javascript"
        "javascriptreact"
        "typescript"
        "typescriptreact"
    )
    "eslint.workingDirectories" = @(
        @{ "mode" = "auto" }
    )
    
    # Prettier settings
    "prettier.singleQuote" = $true
    "prettier.semi" = $true
    "prettier.trailingComma" = "es5"
    "prettier.jsxSingleQuote" = $false
    
    # File associations
    "[javascript]" = @{
        "editor.defaultFormatter" = "esbenp.prettier-vscode"
    }
    "[javascriptreact]" = @{
        "editor.defaultFormatter" = "esbenp.prettier-vscode"
    }
    "[typescript]" = @{
        "editor.defaultFormatter" = "esbenp.prettier-vscode"
    }
    "[typescriptreact]" = @{
        "editor.defaultFormatter" = "esbenp.prettier-vscode"
    }
    "[json]" = @{
        "editor.defaultFormatter" = "esbenp.prettier-vscode"
    }
    "[jsonc]" = @{
        "editor.defaultFormatter" = "esbenp.prettier-vscode"
    }
    
    # Tailwind CSS
    "tailwindCSS.includeLanguages" = @{
        "javascript" = "javascript"
        "javascriptreact" = "javascript"
        "typescript" = "javascript"
        "typescriptreact" = "javascript"
    }
    "tailwindCSS.emmetCompletions" = $true
    "files.associations" = @{
        "*.css" = "tailwindcss"
    }
    
    # WSL2 settings
    "remote.WSL.debug" = $false
    "remote.WSL.fileWatcher.polling" = $false
    "remote.WSL.useShellEnvironment" = $true
    
    # Terminal settings for WSL
    "terminal.integrated.defaultProfile.windows" = "Ubuntu (WSL)"
    "terminal.integrated.profiles.windows" = @{
        "Ubuntu (WSL)" = @{
            "path" = "wsl.exe"
            "args" = @("-d", "Ubuntu")
        }
        "PowerShell" = @{
            "source" = "PowerShell"
            "icon" = "terminal-powershell"
        }
    }
    
    # File exclusions for better performance
    "files.watcherExclude" = @{
        "**/.git/objects/**" = $true
        "**/.git/subtree-cache/**" = $true
        "**/node_modules/**" = $true
        "**/.hg/store/**" = $true
        "**/.next/**" = $true
        "**/dist/**" = $true
        "**/build/**" = $true
    }
    "search.exclude" = @{
        "**/node_modules" = $true
        "**/bower_components" = $true
        "**/.next" = $true
        "**/dist" = $true
        "**/build" = $true
        "**/.git" = $true
    }
    
    # Git settings
    "git.autofetch" = $true
    "git.confirmSync" = $false
    "git.enableSmartCommit" = $true
}

function Write-Header {
    param([string]$Text)
    Write-Host "`n$("=" * 60)" -ForegroundColor $Colors.Header
    Write-Host " $Text" -ForegroundColor $Colors.Header
    Write-Host "$("=" * 60)`n" -ForegroundColor $Colors.Header
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    $icon = switch ($Type) {
        "Success" { "[✓]" }
        "Warning" { "[!]" }
        "Error"   { "[✗]" }
        default   { "[i]" }
    }
    Write-Host "$icon $Message" -ForegroundColor $Colors[$Type]
}

function Test-VSCodeInsiders {
    if (Test-Path $VSCodeInsidersPath) {
        Write-Status "VS Code Insiders found at: $VSCodeInsidersPath" "Success"
        return $true
    }
    
    # Try alternative locations
    $altPaths = @(
        "${env:ProgramFiles}\Microsoft VS Code Insiders\bin\code-insiders.cmd"
        "${env:ProgramFiles(x86)}\Microsoft VS Code Insiders\bin\code-insiders.cmd"
    )
    
    foreach ($path in $altPaths) {
        if (Test-Path $path) {
            $script:VSCodeInsidersPath = $path
            Write-Status "VS Code Insiders found at: $path" "Success"
            return $true
        }
    }
    
    # Check if code-insiders is in PATH
    $inPath = Get-Command "code-insiders" -ErrorAction SilentlyContinue
    if ($inPath) {
        $script:VSCodeInsidersPath = "code-insiders"
        Write-Status "VS Code Insiders found in PATH" "Success"
        return $true
    }
    
    Write-Status "VS Code Insiders not found!" "Error"
    return $false
}

function Get-InstalledExtensions {
    Write-Status "Scanning installed extensions..." "Info"
    
    try {
        $extensions = & $VSCodeInsidersPath --list-extensions 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to list extensions"
        }
        return $extensions
    }
    catch {
        Write-Status "Error listing extensions: $_" "Error"
        return @()
    }
}

function Get-ExtensionDetails {
    param([string]$ExtensionId)
    
    try {
        $output = & $VSCodeInsidersPath --show-versions --list-extensions 2>$null | Where-Object { $_ -match "^$ExtensionId@" }
        if ($output) {
            $version = $output -replace "^$ExtensionId@", ""
            return @{ Id = $ExtensionId; Version = $version; Installed = $true }
        }
    }
    catch {}
    
    return @{ Id = $ExtensionId; Version = "Unknown"; Installed = $false }
}

function Find-RelevantExtensions {
    param([array]$InstalledExtensions)
    
    $relevant = @{
        React = @()
        NextJS = @()
        WSL2 = @()
        Essential = @()
        Other = @()
    }
    
    # Keywords to identify relevant extensions
    $keywords = @{
        React = @("react", "jsx", "redux", "styled-components", "emotion")
        NextJS = @("next", "nextjs", "prisma", "tailwind", "postcss", "vercel")
        WSL2 = @("wsl", "remote", "ssh", "container", "dev-container")
    }
    
    foreach ($ext in $InstalledExtensions) {
        $extLower = $ext.ToLower()
        $categorized = $false
        
        # Check recommended lists first
        foreach ($category in $RecommendedExtensions.Keys) {
            $recommended = $RecommendedExtensions[$category] | Where-Object { $_.Id -eq $ext }
            if ($recommended) {
                $relevant[$category] += @{ Id = $ext; Name = $recommended.Name; Recommended = $true }
                $categorized = $true
                break
            }
        }
        
        if (-not $categorized) {
            # Check by keywords
            foreach ($category in $keywords.Keys) {
                foreach ($keyword in $keywords[$category]) {
                    if ($extLower -match $keyword) {
                        $relevant[$category] += @{ Id = $ext; Name = $ext; Recommended = $false }
                        $categorized = $true
                        break
                    }
                }
                if ($categorized) { break }
            }
        }
        
        if (-not $categorized) {
            $relevant.Other += @{ Id = $ext; Name = $ext; Recommended = $false }
        }
    }
    
    return $relevant
}

function Show-ExtensionReport {
    param([hashtable]$RelevantExtensions, [array]$InstalledExtensions)
    
    Write-Header "EXTENSION SCAN REPORT"
    
    Write-Host "Total installed extensions: $($InstalledExtensions.Count)`n" -ForegroundColor $Colors.Info
    
    foreach ($category in @("React", "NextJS", "WSL2", "Essential")) {
        Write-Host "`n[$category Extensions]" -ForegroundColor $Colors.Header
        
        $installed = $RelevantExtensions[$category]
        $recommended = $RecommendedExtensions[$category]
        
        if ($installed.Count -gt 0) {
            Write-Host "  Installed:" -ForegroundColor $Colors.Success
            foreach ($ext in $installed) {
                $star = if ($ext.Recommended) { " ★" } else { "" }
                Write-Host "    • $($ext.Id)$star" -ForegroundColor $Colors.Success
            }
        }
        
        # Find missing recommended
        $missing = $recommended | Where-Object { $_.Id -notin $InstalledExtensions }
        if ($missing.Count -gt 0) {
            Write-Host "  Missing (Recommended):" -ForegroundColor $Colors.Warning
            foreach ($ext in $missing) {
                Write-Host "    • $($ext.Id) - $($ext.Name)" -ForegroundColor $Colors.Warning
            }
        }
    }
    
    # Summary
    Write-Host "`n" + ("-" * 50) -ForegroundColor $Colors.Info
    $totalRelevant = ($RelevantExtensions.React.Count + $RelevantExtensions.NextJS.Count + 
                     $RelevantExtensions.WSL2.Count + $RelevantExtensions.Essential.Count)
    Write-Host "Relevant extensions found: $totalRelevant" -ForegroundColor $Colors.Info
    Write-Host "Other extensions: $($RelevantExtensions.Other.Count)" -ForegroundColor $Colors.Info
}

function Install-MissingExtensions {
    param([array]$InstalledExtensions)
    
    Write-Header "INSTALLING MISSING EXTENSIONS"
    
    $toInstall = @()
    
    foreach ($category in $RecommendedExtensions.Keys) {
        foreach ($ext in $RecommendedExtensions[$category]) {
            if ($ext.Id -notin $InstalledExtensions) {
                $toInstall += $ext
            }
        }
    }
    
    if ($toInstall.Count -eq 0) {
        Write-Status "All recommended extensions are already installed!" "Success"
        return
    }
    
    Write-Status "Found $($toInstall.Count) extensions to install" "Info"
    
    foreach ($ext in $toInstall) {
        Write-Host "`nInstalling: $($ext.Name) ($($ext.Id))" -ForegroundColor $Colors.Info
        
        try {
            $result = & $VSCodeInsidersPath --install-extension $ext.Id --force 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Status "Successfully installed $($ext.Name)" "Success"
            }
            else {
                Write-Status "Failed to install $($ext.Name): $result" "Warning"
            }
        }
        catch {
            Write-Status "Error installing $($ext.Name): $_" "Error"
        }
    }
}

function Update-VSCodeSettings {
    Write-Header "CONFIGURING SETTINGS"
    
    # Ensure settings directory exists
    $settingsDir = Split-Path $SettingsPath -Parent
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        Write-Status "Created settings directory" "Info"
    }
    
    # Load existing settings or create new
    $currentSettings = @{}
    if (Test-Path $SettingsPath) {
        try {
            $content = Get-Content $SettingsPath -Raw -ErrorAction Stop
            if ($content) {
                $currentSettings = $content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            }
            Write-Status "Loaded existing settings" "Success"
        }
        catch {
            Write-Status "Could not parse existing settings, creating backup" "Warning"
            $backupPath = "$SettingsPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $SettingsPath $backupPath -Force
            Write-Status "Backup created at: $backupPath" "Info"
            $currentSettings = @{}
        }
    }
    
    # Merge settings (optimal settings take precedence)
    $updatedCount = 0
    foreach ($key in $OptimalSettings.Keys) {
        $newValue = $OptimalSettings[$key]
        $existingValue = $currentSettings[$key]
        
        # Deep merge for nested objects
        if ($existingValue -is [hashtable] -and $newValue -is [hashtable]) {
            foreach ($nestedKey in $newValue.Keys) {
                if (-not $existingValue.ContainsKey($nestedKey) -or 
                    ($existingValue[$nestedKey] -ne $newValue[$nestedKey])) {
                    $existingValue[$nestedKey] = $newValue[$nestedKey]
                    $updatedCount++
                }
            }
            $currentSettings[$key] = $existingValue
        }
        elseif ($existingValue -ne $newValue) {
            $currentSettings[$key] = $newValue
            $updatedCount++
            Write-Host "  Setting: $key" -ForegroundColor $Colors.Info
        }
    }
    
    # Save settings
    try {
        $jsonSettings = $currentSettings | ConvertTo-Json -Depth 10
        $jsonSettings | Set-Content $SettingsPath -Encoding UTF8
        Write-Status "Settings saved successfully ($updatedCount updates)" "Success"
    }
    catch {
        Write-Status "Error saving settings: $_" "Error"
    }
}

function Show-ConfigurationSummary {
    Write-Header "CONFIGURATION SUMMARY"
    
    $summary = @"
The following configurations have been applied:

[Editor]
  • Format on save enabled
  • Default formatter: Prettier
  • ESLint auto-fix on save
  • Tab size: 2 spaces
  • Bracket pair colorization enabled
  • Linked editing for tags enabled

[React/JSX]
  • Emmet support for JSX files
  • Auto-import updates on file move
  • ESLint validation for React files

[Next.js/Tailwind]
  • Tailwind CSS IntelliSense configured
  • PostCSS file associations
  • Build folder exclusions for performance

[WSL2]
  • Default terminal: Ubuntu (WSL)
  • Shell environment enabled
  • File polling disabled for better performance

[Performance]
  • node_modules excluded from file watcher
  • .next, dist, build folders excluded
  • Git auto-fetch enabled

"@
    
    Write-Host $summary -ForegroundColor $Colors.Info
}

function Export-ExtensionList {
    param([array]$InstalledExtensions)
    
    $exportPath = "$PSScriptRoot\vscode-insiders-extensions-$(Get-Date -Format 'yyyyMMdd').txt"
    $InstalledExtensions | Out-File $exportPath -Encoding UTF8
    Write-Status "Extension list exported to: $exportPath" "Success"
}

# Main execution
Clear-Host
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║     VS Code Insiders Extension Scanner & Configurator        ║
║         React | Next.js | WSL2 Development Setup             ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor $Colors.Header

# Determine mode
if (-not ($ScanOnly -or $InstallMissing -or $ConfigureSettings -or $All)) {
    $All = $true  # Default to running all operations
}

# Verify VS Code Insiders
if (-not (Test-VSCodeInsiders)) {
    Write-Status "Please install VS Code Insiders and try again." "Error"
    exit 1
}

# Get installed extensions
$installedExtensions = Get-InstalledExtensions
if ($installedExtensions.Count -eq 0) {
    Write-Status "No extensions found or unable to list extensions." "Warning"
}

# Scan and categorize extensions
$relevantExtensions = Find-RelevantExtensions -InstalledExtensions $installedExtensions

# Show report
if ($ScanOnly -or $All) {
    Show-ExtensionReport -RelevantExtensions $relevantExtensions -InstalledExtensions $installedExtensions
}

# Install missing extensions
if ($InstallMissing -or $All) {
    Install-MissingExtensions -InstalledExtensions $installedExtensions
}

# Configure settings
if ($ConfigureSettings -or $All) {
    Update-VSCodeSettings
    Show-ConfigurationSummary
}

# Export extension list
Export-ExtensionList -InstalledExtensions $installedExtensions

Write-Host "`n" + ("=" * 60) -ForegroundColor $Colors.Header
Write-Status "Operation completed!" "Success"
Write-Host "Restart VS Code Insiders for all changes to take effect.`n" -ForegroundColor $Colors.Info