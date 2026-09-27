# Visual Studio Code Optimization Functions - CLEAN VERSION

<#
.SYNOPSIS
Optimizes a Visual Studio Code installation by applying editor settings and optional extensions.

.DESCRIPTION
Collects information about the requested VS Code edition, applies a curated settings profile, and optionally installs a set of extensions. Supports both the Stable and Insiders builds.

.PARAMETER Insiders
Targets the VS Code Insiders edition instead of the Stable build.

.PARAMETER InstallExtensions
Installs the supplied extensions (or the default set) after settings are applied.

.PARAMETER Extensions
Overrides the default extension list when -InstallExtensions is used.

.EXAMPLE
PS> .\scripts\vscode-optimization.ps1 -InstallExtensions
Applies settings and installs the default extension set for the Stable release.

.EXAMPLE
PS> .\scripts\vscode-optimization.ps1 -Insiders -InstallExtensions -Extensions ms-vscode.cpptools
Optimizes VS Code Insiders and installs the specified extension list.

.NOTES
Author: DevOptimizer automation tools
#>

[CmdletBinding()]
param(
    [switch]$Insiders,
    [switch]$InstallExtensions,
    [string[]]$Extensions = @()
)

function Get-VSCodeInfo {
    param([switch]$Insiders)

    $edition = if ($Insiders) { "Insiders" } else { "Stable" }
    Write-Host "Gathering Visual Studio Code $edition installation information..." -ForegroundColor Cyan

    $vscodeInfo = @{
        Installed = $false
        Version = $null
        InstallPath = $null
        ConfigPath = $null
        ExtensionsPath = $null
        Edition = $edition
        CommandName = if ($Insiders) { "code-insiders" } else { "code" }
    }

    # Check if VS Code is installed
    $codeExe = Get-Command $vscodeInfo.CommandName -ErrorAction SilentlyContinue
    if ($codeExe) {
        $vscodeInfo.Installed = $true
        $vscodeInfo.InstallPath = Split-Path $codeExe.Source -Parent

        # Get version
        try {
            $versionOutput = & $vscodeInfo.CommandName --version 2>&1
            if ($versionOutput -is [array] -and $versionOutput.Count -gt 0) {
                $vscodeInfo.Version = $versionOutput[0]
            }
        } catch {
            Write-Host "Could not determine VS Code version" -ForegroundColor Yellow
        }

        # Set configuration paths
        if ($Insiders) {
            $vscodeInfo.ConfigPath = "$env:APPDATA\Code - Insiders\User"
            $vscodeInfo.ExtensionsPath = "$env:USERPROFILE\.vscode-insiders\extensions"
        } else {
            $vscodeInfo.ConfigPath = "$env:APPDATA\Code\User"
            $vscodeInfo.ExtensionsPath = "$env:USERPROFILE\.vscode\extensions"
        }
    }

    return $vscodeInfo
}

function Set-VSCodeSettings {
    param([hashtable]$VSCodeInfo)

    if (-not $VSCodeInfo.Installed) {
        Write-Host "VS Code is not installed" -ForegroundColor Red
        return $false
    }

    try {
        Write-Host "Applying optimized settings..." -ForegroundColor Cyan

        $settings = @{
            "editor.fontSize" = 14
            "editor.tabSize" = 2
            "editor.insertSpaces" = $true
            "editor.formatOnSave" = $true
            "files.autoSave" = "afterDelay"
            "workbench.colorTheme" = "Dark+ (default dark)"
            "terminal.integrated.fontSize" = 14
        }

        $settingsPath = "$($VSCodeInfo.ConfigPath)\settings.json"

        # Ensure directory exists
        $configDir = Split-Path $settingsPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }

        # Save settings
        $settings | ConvertTo-Json | Out-File -FilePath $settingsPath -Encoding UTF8

        Write-Host "VS Code settings applied successfully" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Error applying settings: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Install-VSCodeExtensions {
    param(
        [hashtable]$VSCodeInfo,
        [string[]]$Extensions = @()
    )

    if (-not $VSCodeInfo.Installed) {
        Write-Host "VS Code is not installed" -ForegroundColor Red
        return $false
    }

    if ($Extensions.Count -eq 0) {
        $Extensions = @(
            "ms-vscode.powershell",
            "ms-python.python",
            "esbenp.prettier-vscode"
        )
    }

    try {
        Write-Host "Installing extensions..." -ForegroundColor Cyan

        foreach ($extension in $Extensions) {
            Write-Host "Installing $extension..." -ForegroundColor Yellow
            & $VSCodeInfo.CommandName --install-extension $extension --force 2>$null
            Write-Host "Installed $extension" -ForegroundColor Green
        }

        return $true

    } catch {
        Write-Host "Error installing extensions: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Optimize-VSCode {
    param(
        [switch]$Insiders,
        [switch]$InstallExtensions,
        [string[]]$CustomExtensions = @()
    )

    Write-Host "Running VS Code optimization..." -ForegroundColor Cyan

    $vscodeInfo = Get-VSCodeInfo -Insiders:$Insiders

    if ($vscodeInfo.Installed) {
        Write-Host "Optimizing VS Code..." -ForegroundColor Yellow

        $settingsResult = Set-VSCodeSettings -VSCodeInfo $vscodeInfo

        $extensionsResult = $true
        if ($InstallExtensions) {
            $extensionsResult = Install-VSCodeExtensions -VSCodeInfo $vscodeInfo -Extensions $CustomExtensions
        }

        $success = $settingsResult -and $extensionsResult

        if ($success) {
            Write-Host "VS Code optimization completed successfully" -ForegroundColor Green
        } else {
            Write-Host "VS Code optimization completed with warnings" -ForegroundColor Yellow
        }

        return $success
    } else {
        Write-Host "VS Code is not installed" -ForegroundColor Yellow
        return $false
    }
}

try {
    $result = Optimize-VSCode -Insiders:$Insiders -InstallExtensions:$InstallExtensions -CustomExtensions $Extensions
    if ($result) {
        Exit 0
    } else {
        Exit 1
    }
} catch {
    Write-Error "VS Code optimization failed: $($_.Exception.Message)"
    Exit 1
}
