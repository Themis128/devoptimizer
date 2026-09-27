# Automated Overclocking Configuration Script
# Applies conservative settings based on CONFIGURATION-SUMMARY.md
# Creates backups and provides step-by-step configuration

param(
    [switch]$BackupOnly,
    [switch]$Interactive,
    [int]$CoreClockOffset = 75,
    [int]$MemoryClockOffset = 300,
    [int]$PowerLimitPercent = 7
)

Write-Host "=== Automated Overclocking Configuration ===" -ForegroundColor Cyan
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
Write-Host "Checking installations..." -ForegroundColor Yellow
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

Write-Host ""

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
    
    $msiInfo = $msiAfterburner[0]
    Write-Host "Version: $($msiInfo.DisplayVersion)" -ForegroundColor Gray
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
            
            # Backup config file
            $msiBackupPath = Join-Path $backupPath "MSIAfterburner.cfg"
            try {
                Copy-Item -Path $msiConfigPath -Destination $msiBackupPath -Force
                Write-Host "[OK] Backup created: $msiBackupPath" -ForegroundColor Green
            } catch {
                Write-Host "[WARN] Could not create backup: $_" -ForegroundColor Yellow
            }
            break
        }
    }
    
    if (-not $msiConfigPath) {
        Write-Host "[INFO] Config file not found (will be created on first launch)" -ForegroundColor Gray
    }
    
    # Find executable
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
    
    if (-not $BackupOnly) {
        Write-Host ""
        Write-Host "Configuration Settings to Apply:" -ForegroundColor Yellow
        Write-Host "  Core Clock Offset: +$CoreClockOffset MHz" -ForegroundColor White
        Write-Host "  Memory Clock Offset: +$MemoryClockOffset MHz" -ForegroundColor White
        Write-Host "  Power Limit: +$PowerLimitPercent%" -ForegroundColor White
        Write-Host ""
        
        if ($Interactive) {
            Write-Host "Would you like to apply these settings? (Y/N)" -ForegroundColor Cyan
            $response = Read-Host
            if ($response -ne 'Y' -and $response -ne 'y') {
                Write-Host "Skipping MSI Afterburner configuration" -ForegroundColor Yellow
            } else {
                Write-Host ""
                Write-Host "NOTE: MSI Afterburner config file is binary/proprietary format." -ForegroundColor Yellow
                Write-Host "Manual configuration via GUI is required for safety." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Launching MSI Afterburner for manual configuration..." -ForegroundColor Green
                
                if ($msiExePath) {
                    try {
                        Start-Process -FilePath $msiExePath
                        Write-Host "[OK] MSI Afterburner launched" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "Please configure manually:" -ForegroundColor Cyan
                        Write-Host "  1. Click Settings (gear icon)" -ForegroundColor White
                        Write-Host "  2. Enable: Unlock Voltage Control, Unlock Voltage Monitoring" -ForegroundColor White
                        Write-Host "  3. Enable: Apply overclocking at system startup" -ForegroundColor White
                        Write-Host "  4. Set Core Clock: +$CoreClockOffset MHz" -ForegroundColor White
                        Write-Host "  5. Set Memory Clock: +$MemoryClockOffset MHz" -ForegroundColor White
                        Write-Host "  6. Set Power Limit: +$PowerLimitPercent% (if available)" -ForegroundColor White
                        Write-Host "  7. Click Apply (checkmark)" -ForegroundColor White
                        Write-Host ""
                    } catch {
                        Write-Host "[FAIL] Could not launch: $_" -ForegroundColor Red
                    }
                } else {
                    Write-Host "[WARN] Could not find MSI Afterburner executable" -ForegroundColor Yellow
                }
            }
        } else {
            if ($msiExePath) {
                Write-Host "Launching MSI Afterburner..." -ForegroundColor Green
                try {
                    Start-Process -FilePath $msiExePath
                    Write-Host "[OK] MSI Afterburner launched" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "Manual Configuration Required:" -ForegroundColor Cyan
                    Write-Host "  Apply the settings shown above in MSI Afterburner GUI" -ForegroundColor White
                } catch {
                    Write-Host "[FAIL] Could not launch: $_" -ForegroundColor Red
                }
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
        Write-Host "Recommended Settings for Mobile CPU (i9-12900H):" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Power Limits (Conservative):" -ForegroundColor White
        Write-Host "    - Turbo Boost Power Max: +5W to +10W" -ForegroundColor Gray
        Write-Host "    - Turbo Boost Short Power Max: +5W to +10W" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Core Settings (Very Conservative):" -ForegroundColor White
        Write-Host "    - Core Voltage Offset: +0.010V to +0.020V (if needed)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Turbo Boost:" -ForegroundColor White
        Write-Host "    - Turbo Boost Max: +100 to +200 MHz (max)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  WARNING: Mobile CPUs have limited overclocking capability!" -ForegroundColor Yellow
        Write-Host "  Focus on power management, not aggressive overclocking." -ForegroundColor Yellow
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
        
        # Search for XTU.exe in Intel directories
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
                Write-Host "Manual Configuration Required:" -ForegroundColor Cyan
                Write-Host "  1. Accept terms and conditions" -ForegroundColor White
                Write-Host "  2. Navigate to Advanced Tuning" -ForegroundColor White
                Write-Host "  3. Adjust Power Limits carefully (see recommendations above)" -ForegroundColor White
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

if (-not $BackupOnly) {
    Write-Host "  - Configuration instructions provided above" -ForegroundColor White
    Write-Host "  - Both tools require manual GUI configuration" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Configure MSI Afterburner (if launched)" -ForegroundColor White
    Write-Host "  2. Configure Intel XTU (if launched)" -ForegroundColor White
    Write-Host "  3. Start with conservative settings" -ForegroundColor White
    Write-Host "  4. Test stability thoroughly" -ForegroundColor White
    Write-Host "  5. Monitor temperatures continuously" -ForegroundColor White
}

Write-Host ""

