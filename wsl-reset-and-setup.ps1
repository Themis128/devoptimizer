#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Complete WSL Reset and Ubuntu LTS Setup Script
.DESCRIPTION
    This script performs a complete cleanup of all WSL distributions and configurations,
    then installs the latest Ubuntu LTS as WSL2 and configures VS Code integration.
.NOTES
    Author: Claude for Themistoklis
    Run as Administrator
#>

param(
    [switch]$SkipConfirmation,
    [switch]$SkipVSCode
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Step { param($Message) Write-Host "`n[STEP] $Message" -ForegroundColor Cyan }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Gray }
function Write-Success { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Banner
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║          WSL Complete Reset & Ubuntu LTS Setup               ║
║                                                              ║
║  This script will:                                           ║
║  1. Unregister all WSL distributions                         ║
║  2. Remove WSL packages and features                         ║
║  3. Clean up all WSL-related files and folders               ║
║  4. Re-enable and install WSL2                               ║
║  5. Install Ubuntu LTS (latest)                              ║
║  6. Configure VS Code to use WSL as default terminal         ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Magenta

# Confirmation
if (-not $SkipConfirmation) {
    Write-Warn "This will DELETE all your WSL distributions and data!"
    $confirm = Read-Host "Are you sure you want to continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Info "Operation cancelled."
        exit 0
    }
}

# ============================================================
# PHASE 1: SHUTDOWN AND UNREGISTER ALL WSL DISTRIBUTIONS
# ============================================================
Write-Step "Phase 1: Shutting down and unregistering all WSL distributions"

# Shutdown WSL
Write-Info "Shutting down WSL..."
wsl --shutdown 2>$null
Start-Sleep -Seconds 2

# Get and unregister all distributions
$distros = wsl --list --quiet 2>$null | Where-Object { $_ -and $_.Trim() -ne "" }
if ($distros) {
    foreach ($distro in $distros) {
        $distroName = $distro.Trim() -replace '\x00', ''
        if ($distroName) {
            Write-Info "Unregistering: $distroName"
            wsl --unregister $distroName 2>$null
        }
    }
    Write-Success "All distributions unregistered"
} else {
    Write-Info "No WSL distributions found"
}

# ============================================================
# PHASE 2: REMOVE WSL PACKAGES
# ============================================================
Write-Step "Phase 2: Removing WSL-related packages"

# Remove WSL Store apps
$wslApps = @(
    "MicrosoftCorporationII.WindowsSubsystemForLinux",
    "CanonicalGroupLimited.Ubuntu*",
    "CanonicalGroupLimited.Ubuntu22.04LTS",
    "CanonicalGroupLimited.Ubuntu24.04LTS",
    "CanonicalGroupLimited.Ubuntu20.04LTS",
    "TheDebianProject.DebianGNULinux",
    "KaliLinux.KaliLinuxRolling",
    "openSUSE*",
    "SUSE*",
    "WhitewaterFoundry*"
)

foreach ($appPattern in $wslApps) {
    $apps = Get-AppxPackage -Name $appPattern -AllUsers 2>$null
    foreach ($app in $apps) {
        Write-Info "Removing package: $($app.Name)"
        try {
            Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        } catch {
            Write-Warn "Could not remove $($app.Name): $_"
        }
    }
}

Write-Success "WSL packages removed"

# ============================================================
# PHASE 3: CLEANUP FILES AND FOLDERS
# ============================================================
Write-Step "Phase 3: Cleaning up WSL files and folders"

$foldersToClean = @(
    "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited*",
    "$env:LOCALAPPDATA\Packages\TheDebianProject*",
    "$env:LOCALAPPDATA\Packages\KaliLinux*",
    "$env:LOCALAPPDATA\Packages\*Linux*",
    "$env:LOCALAPPDATA\Packages\MicrosoftCorporationII.WindowsSubsystemForLinux*",
    "$env:USERPROFILE\.wslconfig",
    "$env:USERPROFILE\.wslgconfig",
    "$env:LOCALAPPDATA\lxss",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\*Ubuntu*",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\*Debian*",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\*Kali*"
)

foreach ($pattern in $foldersToClean) {
    $items = Get-Item -Path $pattern -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        Write-Info "Removing: $($item.FullName)"
        try {
            Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warn "Could not remove $($item.FullName)"
        }
    }
}

# Clean Windows temp
Write-Info "Cleaning temp files..."
Remove-Item -Path "$env:TEMP\*wsl*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\*ubuntu*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Success "Cleanup completed"

# ============================================================
# PHASE 4: DISABLE WSL FEATURES (FOR CLEAN REINSTALL)
# ============================================================
Write-Step "Phase 4: Resetting Windows features"

Write-Info "Disabling WSL features..."
$features = @(
    "Microsoft-Windows-Subsystem-Linux",
    "VirtualMachinePlatform"
)

$needsReboot = $false

foreach ($feature in $features) {
    $state = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
    if ($state -and $state.State -eq "Enabled") {
        Write-Info "Disabling: $feature"
        $result = Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue
        if ($result.RestartNeeded) { $needsReboot = $true }
    }
}

# ============================================================
# PHASE 5: RE-ENABLE WSL2 FEATURES
# ============================================================
Write-Step "Phase 5: Enabling WSL2 features"

foreach ($feature in $features) {
    Write-Info "Enabling: $feature"
    $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue
    if ($result.RestartNeeded) { $needsReboot = $true }
}

Write-Success "Windows features configured"

# ============================================================
# PHASE 6: UPDATE WSL AND SET DEFAULT VERSION
# ============================================================
Write-Step "Phase 6: Installing/Updating WSL"

Write-Info "Updating WSL to latest version..."
wsl --update --web-download 2>$null

Write-Info "Setting WSL 2 as default..."
wsl --set-default-version 2

Write-Success "WSL2 configured as default"

# ============================================================
# PHASE 7: INSTALL UBUNTU LTS
# ============================================================
Write-Step "Phase 7: Installing Ubuntu LTS"

Write-Info "Installing Ubuntu (latest LTS)..."
Write-Info "This may take several minutes..."

# Install Ubuntu
wsl --install -d Ubuntu --web-download

Write-Success "Ubuntu LTS installation initiated"

# ============================================================
# PHASE 8: CONFIGURE VS CODE
# ============================================================
if (-not $SkipVSCode) {
    Write-Step "Phase 8: Configuring VS Code"
    
    $vscodePaths = @(
        "$env:APPDATA\Code\User\settings.json",
        "$env:APPDATA\Code - Insiders\User\settings.json"
    )
    
    foreach ($settingsPath in $vscodePaths) {
        $settingsDir = Split-Path -Parent $settingsPath
        
        if (Test-Path $settingsDir) {
            Write-Info "Configuring: $settingsPath"
            
            $settings = @{}
            if (Test-Path $settingsPath) {
                try {
                    $content = Get-Content -Path $settingsPath -Raw
                    if ($content) {
                        $settings = $content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
                        if (-not $settings) { $settings = @{} }
                    }
                } catch {
                    $settings = @{}
                }
            }
            
            # Add WSL settings
            $settings["terminal.integrated.defaultProfile.windows"] = "Ubuntu (WSL)"
            $settings["terminal.integrated.profiles.windows"] = @{
                "Ubuntu (WSL)" = @{
                    "path" = "wsl.exe"
                    "args" = @("-d", "Ubuntu")
                    "icon" = "terminal-ubuntu"
                }
                "PowerShell" = @{
                    "source" = "PowerShell"
                    "icon" = "terminal-powershell"
                }
                "Command Prompt" = @{
                    "path" = @("$env:windir\System32\cmd.exe")
                    "icon" = "terminal-cmd"
                }
            }
            
            # Ensure Remote WSL extension settings
            $settings["remote.WSL.debug"] = $false
            
            # Save settings
            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
            Write-Success "VS Code settings updated: $settingsPath"
        }
    }
    
    # Check for WSL extension
    $codePath = Get-Command code -ErrorAction SilentlyContinue
    if ($codePath) {
        Write-Info "Installing VS Code Remote - WSL extension..."
        & code --install-extension ms-vscode-remote.remote-wsl 2>$null
        Write-Success "WSL extension installed"
    } else {
        Write-Warn "VS Code CLI not found in PATH. Please install the 'Remote - WSL' extension manually."
    }
}

# ============================================================
# FINAL SUMMARY
# ============================================================
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                    SETUP COMPLETE!                           ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. A reboot may be required for all changes to take effect" -ForegroundColor White
Write-Host "2. After reboot, open Ubuntu from Start Menu to complete initial setup" -ForegroundColor White
Write-Host "3. Create your Unix username and password when prompted" -ForegroundColor White
Write-Host "4. VS Code will use Ubuntu WSL as the default terminal" -ForegroundColor White
Write-Host ""

if ($needsReboot) {
    Write-Warn "A REBOOT IS REQUIRED!"
    $rebootNow = Read-Host "Would you like to reboot now? (yes/no)"
    if ($rebootNow -eq "yes") {
        Write-Info "Rebooting in 10 seconds... Press Ctrl+C to cancel"
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
}

Write-Host "`nUseful commands:" -ForegroundColor Cyan
Write-Host "  wsl --list --verbose     # List installed distributions"
Write-Host "  wsl --status             # Show WSL status"
Write-Host "  wsl                      # Start default distribution"
Write-Host "  code .                   # Open VS Code in current directory"
Write-Host ""