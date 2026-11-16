<#
.SYNOPSIS
    Install Devin CLI on Windows (official method)
.DESCRIPTION
    Installs Devin CLI using the official Windows PowerShell installer.
    Can also install via Devin Desktop Command Palette (requires admin + team setting).
.PARAMETER Method
    'official' - Download and run official installer (default)
    'desktop'  - Instructions for Devin Desktop Command Palette install
.PARAMETER Force
    Overwrite existing installation
#>
param(
    [ValidateSet('official', 'desktop')]
    [string]$Method = 'official',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Log {
    param($msg)
    Write-Host $msg
    Add-Content -Path "D:\DevOptimizer\logs\devin-cli-install.log" -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
}

Log "=== Devin CLI Installation ($Method) ==="

if ($Method -eq 'official') {
    Log "Installing via official PowerShell installer..."
    
    # Check if already installed
    $devinCmd = Get-Command devin -ErrorAction SilentlyContinue
    if ($devinCmd -and -not $Force) {
        Log "Devin CLI already installed at: $($devinCmd.Source)"
        Log "Use -Force to reinstall"
        exit 0
    }
    
    # Official Windows installer
    $installCmd = 'irm https://static.devin.ai/cli/setup.ps1 | iex'
    Log "Running: $installCmd"
    
    try {
        Invoke-Expression $installCmd
        Log "Installer completed"
    } catch {
        Log "ERROR: Installation failed: $($_.Exception.Message)"
        exit 1
    }
    
    # Verify installation
    $devinCmd = Get-Command devin -ErrorAction SilentlyContinue
    if ($devinCmd) {
        $version = & devin --version 2>&1
        Log "SUCCESS: Devin CLI installed at: $($devinCmd.Source)"
        Log "Version: $version"
    } else {
        Log "WARNING: devin command not found in PATH. Restart terminal or add to PATH manually."
        Log "Expected location: $env:USERPROFILE\.local\bin\devin.exe or %LOCALAPPDATA%\Programs\Devin\bin\devin-desktop.cmd"
    }
    
} elseif ($Method -eq 'desktop') {
    Log "Devin Desktop Command Palette installation:"
    Log "1. Open Devin Desktop"
    Log "2. Press Ctrl+Shift+P (Command Palette)"
    Log "3. Search 'Install Devin CLI' and select it"
    Log "4. Requires: Admin rights + 'Install Devin CLI in Devin Desktop' enabled in team settings"
    Log "5. Restart terminal after installation"
}

Log "=== Installation Complete ==="