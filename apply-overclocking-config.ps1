# Apply Overclocking Configuration Script
# This script applies conservative overclocking settings based on CONFIGURATION-SUMMARY.md
# WARNING: This modifies system settings. Use at your own risk.

param(
    [switch]$BackupOnly,
    [switch]$ApplyMSI,
    [switch]$ApplyXTU,
    [switch]$LaunchApps
)

Write-Host "=== Apply Overclocking Configuration ===" -ForegroundColor Cyan
Write-Host "Based on: D:\DevOptimizer\config\overclocking\CONFIGURATION-SUMMARY.md" -ForegroundColor Gray
Write-Host ""

# Check if running as admin (needed for some operations)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  Some configuration options may require admin privileges" -ForegroundColor Gray
    Write-Host ""
}

# Function to find installed software
function Get-InstalledSoftware {
    param([string]$NamePattern)
    
    $results = @()
    $uninstallKeys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($key in $uninstallKeys) {
        try {
            $apps = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue | 
                    Where-Object { $_.DisplayName -like "*$NamePattern*" }
            if ($apps) {
                $results += $apps
            }
        } catch {
            # Continue on error
        }
    }
    
    return $results
}

# Check for MSI Afterburner
Write-Host "Checking for MSI Afterburner..." -ForegroundColor Yellow
$msiAfterburner = Get-InstalledSoftware -NamePattern "MSI Afterburner"
if (-not $msiAfterburner) {
    $msiAfterburner = Get-InstalledSoftware -NamePattern "Afterburner"
}

$msiInstalled = $msiAfterburner -ne $null -and $msiAfterburner.Count -gt 0

# Check for Intel XTU
Write-Host "Checking for Intel XTU..." -ForegroundColor Yellow
$intelXTU = Get-InstalledSoftware -NamePattern "Intel XTU"
if (-not $intelXTU) {
    $intelXTU = Get-InstalledSoftware -NamePattern "Extreme Tuning Utility"
}

$xtuInstalled = $intelXTU -ne $null -and $intelXTU.Count -gt 0

if (-not $msiInstalled -and -not $xtuInstalled) {
    Write-Host "[FAIL] Neither tool is installed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Create backup directory
$backupDir = Join-Path $PSScriptRoot "config\overclocking\backups"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupDir "backup-$timestamp"

# MSI Afterburner Configuration
if ($msiInstalled -and ($ApplyMSI -or (-not $BackupOnly -and -not $ApplyXTU))) {
    Write-Host "=== MSI Afterburner Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Find MSI Afterburner config file
    $msiConfigPaths = @(
        "$env:APPDATA\MSI Afterburner\MSIAfterburner.cfg",
        "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.cfg",
        "${env:ProgramFiles}\MSI Afterburner\MSIAfterburner.cfg"
    )
    
    $msiConfigPath = $null
    foreach ($path in $msiConfigPaths) {
        if (Test-Path $path) {
            $msiConfigPath = $path
            Write-Host "Found config file: $path" -ForegroundColor Green
            break
        }
    }
    
    if ($msiConfigPath) {
        # Backup config file
        $msiBackupPath = Join-Path $backupPath "MSIAfterburner.cfg"
        New-Item -ItemType Directory -Path (Split-Path $msiBackupPath -Parent) -Force | Out-Null
        Copy-Item -Path $msiConfigPath -Destination $msiBackupPath -Force
        Write-Host "Backup created: $msiBackupPath" -ForegroundColor Green
        
        if (-not $BackupOnly) {
            Write-Host ""
            Write-Host "Applying MSI Afterburner settings..." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "NOTE: MSI Afterburner config file format is binary/proprietary." -ForegroundColor Yellow
            Write-Host "Manual configuration via GUI is recommended for safety." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Recommended Settings to Apply Manually:" -ForegroundColor Cyan
            Write-Host "  1. Launch MSI Afterburner" -ForegroundColor White
            Write-Host "  2. Click Settings (gear icon)" -ForegroundColor White
            Write-Host "  3. Enable:" -ForegroundColor White
            Write-Host "     - Unlock Voltage Control" -ForegroundColor Gray
            Write-Host "     - Unlock Voltage Monitoring" -ForegroundColor Gray
            Write-Host "     - Apply overclocking at system startup" -ForegroundColor Gray
            Write-Host "     - Start with Windows (optional)" -ForegroundColor Gray
            Write-Host "     - Minimize to tray" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  4. Conservative Overclocking Settings:" -ForegroundColor White
            Write-Host "     - Core Clock: +50 to +100 MHz" -ForegroundColor Gray
            Write-Host "     - Memory Clock: +200 to +400 MHz" -ForegroundColor Gray
            Write-Host "     - Power Limit: +5% to +10% (if available)" -ForegroundColor Gray
            Write-Host "     - Temperature Limit: 83 degrees C (default)" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host "[WARN] MSI Afterburner config file not found" -ForegroundColor Yellow
        Write-Host "  Config file will be created on first launch" -ForegroundColor Gray
    }
    
    # Find and launch MSI Afterburner
    if ($LaunchApps -or (-not $BackupOnly)) {
        $msiExePaths = @(
            "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe",
            "${env:ProgramFiles}\MSI Afterburner\MSIAfterburner.exe"
        )
        
        $msiExePath = $null
        foreach ($path in $msiExePaths) {
            if (Test-Path $path) {
                $msiExePath = $path
                break
            }
        }
        
        if ($msiExePath) {
            Write-Host "Launching MSI Afterburner for manual configuration..." -ForegroundColor Green
            try {
                Start-Process -FilePath $msiExePath
                Write-Host "  MSI Afterburner launched" -ForegroundColor Green
                Start-Sleep -Seconds 2
            } catch {
                Write-Host "  Failed to launch: $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""

# Intel XTU Configuration
if ($xtuInstalled -and ($ApplyXTU -or (-not $BackupOnly -and -not $ApplyMSI))) {
    Write-Host "=== Intel XTU Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Intel XTU stores settings in registry and application database
    $xtuRegistryPaths = @(
        "HKLM:\SOFTWARE\Intel\Extreme Tuning Utility",
        "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility"
    )
    
    Write-Host "Intel XTU stores settings in registry and application database" -ForegroundColor Gray
    Write-Host ""
    
    # Backup registry keys if they exist
    $xtuBackupCreated = $false
    foreach ($regPath in $xtuRegistryPaths) {
        if (Test-Path $regPath) {
            $regBackupPath = Join-Path $backupPath "XTU-Registry-$($regPath.Replace(':', '-').Replace('\', '-'))"
            New-Item -ItemType Directory -Path (Split-Path $regBackupPath -Parent) -Force | Out-Null
            try {
                reg export $regPath.Replace('HKLM:\', 'HKLM\').Replace('HKCU:\', 'HKCU\') "$regBackupPath.reg" /y 2>&1 | Out-Null
                if (Test-Path "$regBackupPath.reg") {
                    Write-Host "Backed up registry: $regPath" -ForegroundColor Green
                    $xtuBackupCreated = $true
                }
            } catch {
                Write-Host "Could not backup registry: $regPath" -ForegroundColor Yellow
            }
        }
    }
    
    if (-not $xtuBackupCreated) {
        Write-Host "No existing XTU registry settings found to backup" -ForegroundColor Gray
    }
    
    if (-not $BackupOnly) {
        Write-Host ""
        Write-Host "Applying Intel XTU settings..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "NOTE: Intel XTU settings are complex and CPU-specific." -ForegroundColor Yellow
        Write-Host "Manual configuration via GUI is strongly recommended for safety." -ForegroundColor Yellow
        Write-Host ""
        
        # Get CPU info
        $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
        $cpuName = $cpu.Name
        Write-Host "CPU: $cpuName" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Recommended Settings for Mobile CPU (H-series):" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Power Limits (Most Important):" -ForegroundColor White
        Write-Host "    - Turbo Boost Power Max: Increase by 5-10W if cooling allows" -ForegroundColor Gray
        Write-Host "    - Turbo Boost Short Power Max: Increase by 5-10W if cooling allows" -ForegroundColor Gray
        Write-Host "    - Monitor temperatures closely!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Core Settings (Very Conservative):" -ForegroundColor White
        Write-Host "    - Core Voltage Offset: +0.010V to +0.020V (if needed)" -ForegroundColor Gray
        Write-Host "    - Do NOT increase voltage significantly on mobile CPUs!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Turbo Boost Settings:" -ForegroundColor White
        Write-Host "    - Turbo Boost Max: Leave at default or +100-200 MHz max" -ForegroundColor Gray
        Write-Host "    - Mobile CPUs will throttle if too aggressive" -ForegroundColor Yellow
        Write-Host ""
        
        # Try to launch Intel XTU
        if ($LaunchApps) {
            Write-Host "Attempting to launch Intel XTU..." -ForegroundColor Green
            
            # Try multiple methods to launch
            $launched = $false
            
            # Method 1: Try standard paths
            $xtuExePaths = @(
                "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
                "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
            )
            
            foreach ($path in $xtuExePaths) {
                if (Test-Path $path) {
                    try {
                        Start-Process -FilePath $path
                        Write-Host "  Intel XTU launched from: $path" -ForegroundColor Green
                        $launched = $true
                        break
                    } catch {
                        # Continue to next method
                    }
                }
            }
            
            # Method 2: Try via Start Menu
            if (-not $launched) {
                try {
                    Start-Process "shell:AppsFolder" -ErrorAction SilentlyContinue
                    Write-Host "  Opened Apps folder - search for 'Intel Extreme Tuning Utility'" -ForegroundColor Yellow
                } catch {
                    Write-Host "  Please launch Intel XTU manually from Start Menu" -ForegroundColor Yellow
                }
            }
        }
    }
}

Write-Host ""
Write-Host "=== Configuration Summary ===" -ForegroundColor Cyan
Write-Host ""

if ($BackupOnly) {
    Write-Host "[OK] Backup completed" -ForegroundColor Green
    Write-Host "  Backup location: $backupPath" -ForegroundColor Gray
} else {
    Write-Host "[OK] Configuration instructions provided" -ForegroundColor Green
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Yellow
    Write-Host "  - Both tools require manual GUI configuration for safety" -ForegroundColor White
    Write-Host "  - Start with conservative settings" -ForegroundColor White
    Write-Host "  - Test stability after each change" -ForegroundColor White
    Write-Host "  - Monitor temperatures continuously" -ForegroundColor White
    Write-Host "  - Backup created at: $backupPath" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Configure MSI Afterburner using the GUI (if launched)" -ForegroundColor White
Write-Host "  2. Configure Intel XTU using the GUI (if launched)" -ForegroundColor White
Write-Host "  3. Start with conservative settings from the configuration guide" -ForegroundColor White
Write-Host "  4. Test stability thoroughly before increasing settings" -ForegroundColor White
Write-Host ""

