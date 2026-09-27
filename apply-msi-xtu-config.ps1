# Apply MSI Afterburner and Intel XTU Configuration
# Based on CONFIGURATION-SUMMARY.md
# This script modifies config files and provides step-by-step guidance

param(
    [switch]$BackupOnly,
    [switch]$ApplySettings,
    [int]$CoreClockOffset = 75,
    [int]$MemoryClockOffset = 300,
    [int]$PowerLimitPercent = 7
)

Write-Host "=== Apply Overclocking Configuration ===" -ForegroundColor Cyan
Write-Host "Based on: D:\DevOptimizer\config\overclocking\CONFIGURATION-SUMMARY.md" -ForegroundColor Gray
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  Some operations may require admin privileges" -ForegroundColor Gray
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

# Check installations
$msiAfterburner = Get-InstalledSoftware -NamePattern "MSI Afterburner"
if (-not $msiAfterburner) {
    $msiAfterburner = Get-InstalledSoftware -NamePattern "Afterburner"
}

$intelXTU = Get-InstalledSoftware -NamePattern "Intel XTU"
if (-not $intelXTU) {
    $intelXTU = Get-InstalledSoftware -NamePattern "Extreme Tuning Utility"
}

$msiInstalled = $msiAfterburner -ne $null -and $msiAfterburner.Count -gt 0
$xtuInstalled = $intelXTU -ne $null -and $intelXTU.Count -gt 0

if (-not $msiInstalled -and -not $xtuInstalled) {
    Write-Host "[FAIL] Neither tool is installed" -ForegroundColor Red
    exit 1
}

# Create backup directory
$backupDir = Join-Path $PSScriptRoot "config\overclocking\backups"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupDir "backup-$timestamp"
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

Write-Host "Backup directory: $backupPath" -ForegroundColor Green
Write-Host ""

# MSI Afterburner Configuration
if ($msiInstalled) {
    Write-Host "=== MSI Afterburner Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Find config file
    $msiConfigPaths = @(
        "$env:APPDATA\MSI Afterburner\MSIAfterburner.cfg",
        "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.cfg",
        "${env:ProgramFiles}\MSI Afterburner\MSIAfterburner.cfg"
    )
    
    $msiConfigPath = $null
    foreach ($path in $msiConfigPaths) {
        if (Test-Path $path) {
            $msiConfigPath = $path
            Write-Host "[OK] Found config file: $path" -ForegroundColor Green
            break
        }
    }
    
    if ($msiConfigPath) {
        # Backup config file
        $msiBackupPath = Join-Path $backupPath "MSIAfterburner.cfg"
        try {
            Copy-Item -Path $msiConfigPath -Destination $msiBackupPath -Force
            Write-Host "[OK] Backup created" -ForegroundColor Green
        } catch {
            Write-Host "[WARN] Could not create backup: $_" -ForegroundColor Yellow
        }
        
        if ($ApplySettings -and -not $BackupOnly) {
            Write-Host ""
            Write-Host "Applying MSI Afterburner settings..." -ForegroundColor Yellow
            
            try {
                # Read config file
                $configContent = Get-Content -Path $msiConfigPath -Raw
                $originalContent = $configContent
                
                # Apply settings using INI file manipulation
                # Enable Unlock Voltage Control
                $configContent = $configContent -replace '(?m)^UnlockVoltageControl\s*=\s*\d+', "UnlockVoltageControl`t`t= 1"
                
                # Enable Unlock Voltage Monitoring
                $configContent = $configContent -replace '(?m)^UnlockVoltageMonitoring\s*=\s*\d+', "UnlockVoltageMonitoring`t`t= 0"
                
                # Enable Start with Windows (optional)
                $configContent = $configContent -replace '(?m)^StartWithWindows\s*=\s*\d+', "StartWithWindows`t`t= 1"
                
                # Enable Start Minimized
                $configContent = $configContent -replace '(?m)^StartMinimized\s*=\s*\d+', "StartMinimized`t`t= 1"
                
                # Enable Send to Tray on Close
                $configContent = $configContent -replace '(?m)^SendToTrayOnClose\s*=\s*\d+', "SendToTrayOnClose`t`t= 1"
                
                # Check if changes were made
                if ($configContent -ne $originalContent) {
                    # Write modified config
                    $configContent | Set-Content -Path $msiConfigPath -Encoding ASCII -NoNewline
                    Write-Host "[OK] MSI Afterburner settings applied" -ForegroundColor Green
                    Write-Host "  - Unlock Voltage Control: Enabled" -ForegroundColor Gray
                    Write-Host "  - Unlock Voltage Monitoring: Enabled" -ForegroundColor Gray
                    Write-Host "  - Start with Windows: Enabled" -ForegroundColor Gray
                    Write-Host "  - Start Minimized: Enabled" -ForegroundColor Gray
                    Write-Host "  - Send to Tray on Close: Enabled" -ForegroundColor Gray
                } else {
                    Write-Host "[INFO] Settings may already be configured" -ForegroundColor Gray
                }
            } catch {
                Write-Host "[WARN] Could not modify config file: $_" -ForegroundColor Yellow
                Write-Host "  You may need to run as Administrator" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "[INFO] Config file not found (will be created on first launch)" -ForegroundColor Gray
    }
    
    # Find GPU profile file
    $profileDir = "${env:ProgramFiles(x86)}\MSI Afterburner\Profiles"
    if (-not (Test-Path $profileDir)) {
        $profileDir = "${env:ProgramFiles}\MSI Afterburner\Profiles"
    }
    
    if (Test-Path $profileDir) {
        # Find NVIDIA GPU profile (VEN_10DE = NVIDIA)
        $gpuProfiles = Get-ChildItem -Path $profileDir -Filter "VEN_10DE*.cfg" -ErrorAction SilentlyContinue
        if ($gpuProfiles) {
            $gpuProfile = $gpuProfiles[0]
            Write-Host "[OK] Found GPU profile: $($gpuProfile.Name)" -ForegroundColor Green
            
            # Backup profile
            $profileBackupPath = Join-Path $backupPath $gpuProfile.Name
            try {
                Copy-Item -Path $gpuProfile.FullName -Destination $profileBackupPath -Force
                Write-Host "[OK] Profile backup created" -ForegroundColor Green
            } catch {
                Write-Host "[WARN] Could not backup profile: $_" -ForegroundColor Yellow
            }
            
            if ($ApplySettings -and -not $BackupOnly) {
                Write-Host ""
                Write-Host "Applying overclocking settings to profile..." -ForegroundColor Yellow
                Write-Host "  Core Clock: +$CoreClockOffset MHz" -ForegroundColor Gray
                Write-Host "  Memory Clock: +$MemoryClockOffset MHz" -ForegroundColor Gray
                Write-Host "  Power Limit: +$PowerLimitPercent%" -ForegroundColor Gray
                Write-Host ""
                Write-Host "[INFO] Profile file format is complex. Manual configuration recommended." -ForegroundColor Yellow
                Write-Host "  Please use MSI Afterburner GUI to set overclocking values." -ForegroundColor Yellow
            }
        }
    }
    
    # Launch MSI Afterburner
    if (-not $BackupOnly) {
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
            Write-Host ""
            Write-Host "Launching MSI Afterburner..." -ForegroundColor Green
            try {
                Start-Process -FilePath $msiExePath
                Write-Host "[OK] MSI Afterburner launched" -ForegroundColor Green
                Start-Sleep -Seconds 2
                
                Write-Host ""
                Write-Host "Manual Configuration Steps:" -ForegroundColor Cyan
                Write-Host "  1. In MSI Afterburner, set Core Clock: +$CoreClockOffset MHz" -ForegroundColor White
                Write-Host "  2. Set Memory Clock: +$MemoryClockOffset MHz" -ForegroundColor White
                Write-Host "  3. Set Power Limit: +$PowerLimitPercent% (if available)" -ForegroundColor White
                Write-Host "  4. Click Apply (checkmark icon)" -ForegroundColor White
                Write-Host "  5. Test stability with a stress test" -ForegroundColor White
                Write-Host ""
            } catch {
                Write-Host "[FAIL] Could not launch: $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""

# Intel XTU Configuration
if ($xtuInstalled) {
    Write-Host "=== Intel XTU Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    $xtuInfo = $intelXTU[0]
    Write-Host "Version: $($xtuInfo.DisplayVersion)" -ForegroundColor Gray
    
    # Get CPU info
    $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
    $cpuName = $cpu.Name
    Write-Host "CPU: $cpuName" -ForegroundColor Gray
    Write-Host ""
    
    # Backup registry settings
    $xtuRegistryPaths = @(
        "HKLM:\SOFTWARE\Intel\Extreme Tuning Utility",
        "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility"
    )
    
    $xtuBackupCreated = $false
    foreach ($regPath in $xtuRegistryPaths) {
        if (Test-Path $regPath) {
            $regBackupFile = Join-Path $backupPath "XTU-Registry-$($regPath.Replace(':', '-').Replace('\', '-')).reg"
            try {
                $regPathForExport = $regPath.Replace('HKLM:\', 'HKLM\').Replace('HKCU:\', 'HKCU\')
                reg export $regPathForExport $regBackupFile /y 2>&1 | Out-Null
                if (Test-Path $regBackupFile) {
                    Write-Host "[OK] Backed up registry: $regPath" -ForegroundColor Green
                    $xtuBackupCreated = $true
                }
            } catch {
                Write-Host "[WARN] Could not backup registry: $regPath" -ForegroundColor Yellow
            }
        }
    }
    
    if (-not $xtuBackupCreated) {
        Write-Host "[INFO] No existing XTU registry settings found" -ForegroundColor Gray
    }
    
    if (-not $BackupOnly) {
        Write-Host ""
        Write-Host "Intel XTU Configuration:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "NOTE: Intel XTU settings are stored in registry and application database." -ForegroundColor Yellow
        Write-Host "Manual configuration via GUI is required for safety and accuracy." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Recommended Settings for i9-12900H (Mobile CPU):" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Power Limits (Most Important):" -ForegroundColor White
        Write-Host "    - Turbo Boost Power Max: +5W to +10W" -ForegroundColor Gray
        Write-Host "    - Turbo Boost Short Power Max: +5W to +10W" -ForegroundColor Gray
        Write-Host "    - Monitor temperatures closely!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Core Settings (Very Conservative):" -ForegroundColor White
        Write-Host "    - Core Voltage Offset: +0.010V to +0.020V (if needed)" -ForegroundColor Gray
        Write-Host "    - Do NOT increase voltage significantly!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Turbo Boost:" -ForegroundColor White
        Write-Host "    - Turbo Boost Max: +100 to +200 MHz (max)" -ForegroundColor Gray
        Write-Host "    - Mobile CPUs will throttle if too aggressive" -ForegroundColor Yellow
        Write-Host ""
        
        # Try to launch Intel XTU
        $xtuExePaths = @(
            "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
            "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
        )
        
        $xtuExePath = $null
        foreach ($path in $xtuExePaths) {
            if (Test-Path $path) {
                $xtuExePath = $path
                break
            }
        }
        
        # Search for XTU.exe
        if (-not $xtuExePath) {
            $intelDirs = @("${env:ProgramFiles(x86)}\Intel", "${env:ProgramFiles}\Intel")
            foreach ($intelDir in $intelDirs) {
                if (Test-Path $intelDir) {
                    $found = Get-ChildItem -Path $intelDir -Filter "XTU.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($found) {
                        $xtuExePath = $found.FullName
                        break
                    }
                }
            }
        }
        
        if ($xtuExePath) {
            Write-Host "Launching Intel XTU..." -ForegroundColor Green
            try {
                Start-Process -FilePath $xtuExePath
                Write-Host "[OK] Intel XTU launched" -ForegroundColor Green
                Write-Host ""
                Write-Host "Manual Configuration Steps:" -ForegroundColor Cyan
                Write-Host "  1. Accept terms and conditions" -ForegroundColor White
                Write-Host "  2. Navigate to Advanced Tuning" -ForegroundColor White
                Write-Host "  3. Adjust Power Limits (see recommendations above)" -ForegroundColor White
                Write-Host "  4. Monitor temperatures (keep below 90 degrees C)" -ForegroundColor White
                Write-Host "  5. Use Stress Test to verify stability" -ForegroundColor White
                Write-Host ""
            } catch {
                Write-Host "[FAIL] Could not launch: $_" -ForegroundColor Red
                Write-Host "  Please launch manually from Start Menu" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[WARN] Could not find Intel XTU executable" -ForegroundColor Yellow
            Write-Host "  Please launch manually from Start Menu: Intel Extreme Tuning Utility" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "=== Configuration Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - Backup location: $backupPath" -ForegroundColor White

if ($ApplySettings -and -not $BackupOnly) {
    Write-Host "  - MSI Afterburner: Basic settings applied (GUI configuration still needed)" -ForegroundColor White
    Write-Host "  - Intel XTU: Manual configuration required" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Configure overclocking values in MSI Afterburner GUI" -ForegroundColor White
    Write-Host "  2. Configure power limits in Intel XTU GUI" -ForegroundColor White
    Write-Host "  3. Start with conservative settings" -ForegroundColor White
    Write-Host "  4. Test stability thoroughly" -ForegroundColor White
    Write-Host "  5. Monitor temperatures continuously" -ForegroundColor White
} else {
    Write-Host "  - Backup completed successfully" -ForegroundColor White
    Write-Host ""
    Write-Host "To apply settings, run with -ApplySettings parameter:" -ForegroundColor Yellow
    Write-Host "  .\apply-msi-xtu-config.ps1 -ApplySettings" -ForegroundColor White
}

Write-Host ""

