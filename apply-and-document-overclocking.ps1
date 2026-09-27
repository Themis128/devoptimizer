# Apply and Document Overclocking Configuration
# This script applies settings from CONFIGURATION-SUMMARY.md and documents all changes
# WARNING: This modifies system settings. Use at your own risk.

param(
    [switch]$ApplySettings,
    [switch]$BackupOnly,
    [switch]$LaunchApps
)

$ErrorActionPreference = "Continue"

Write-Host "=== Apply and Document Overclocking Configuration ===" -ForegroundColor Cyan
Write-Host "Based on: D:\DevOptimizer\config\overclocking\CONFIGURATION-SUMMARY.md" -ForegroundColor Gray
Write-Host ""

# Check if running as admin
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

# Create backup and documentation directories
$configDir = Join-Path $PSScriptRoot "config\overclocking"
$backupDir = Join-Path $configDir "backups"
$docDir = Join-Path $configDir "documentation"

if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}
if (-not (Test-Path $docDir)) {
    New-Item -ItemType Directory -Path $docDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupDir "backup-$timestamp"
$docPath = Join-Path $docDir "applied-configuration-$timestamp.md"

# Initialize documentation
$docContent = @"
# Applied Overclocking Configuration Documentation

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Script:** apply-and-document-overclocking.ps1
**Source:** CONFIGURATION-SUMMARY.md

## Summary

This document records all configuration changes applied to MSI Afterburner and Intel XTU based on the configuration summary guide.

---

## MSI Afterburner Configuration

"@

# MSI Afterburner Configuration
if ($msiInstalled) {
    Write-Host "=== MSI Afterburner Configuration ===" -ForegroundColor Cyan
    Write-Host ""

    $msiInfo = $msiAfterburner[0]
    $msiVersion = $msiInfo.DisplayVersion
    $msiLocation = $msiInfo.InstallLocation

    Write-Host "Version: $msiVersion" -ForegroundColor Gray
    Write-Host "Location: $msiLocation" -ForegroundColor Gray
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

        # Read current config
        $configContent = Get-Content -Path $msiConfigPath -Raw

        # Track changes
        $changes = @()
        $originalSettings = @{}
        $newSettings = @{}

        # Settings to apply from CONFIGURATION-SUMMARY.md
        $settingsToApply = @{
            "UnlockVoltageControl" = "1"
            "UnlockVoltageMonitoring" = "1"
            "StartWithWindows" = "1"
            "SendToTrayOnClose" = "1"
            "ForceConstantVoltage" = "0"  # Keep at 0 for safety, can be enabled manually if needed
        }

        # Apply settings
        if ($ApplySettings -and -not $BackupOnly) {
            Write-Host ""
            Write-Host "Applying MSI Afterburner settings..." -ForegroundColor Yellow

            foreach ($setting in $settingsToApply.Keys) {
                $newValue = $settingsToApply[$setting]

                # Find current value
                $pattern = "($setting\s*=\s*)(\d+)"
                if ($configContent -match $pattern) {
                    $originalValue = $matches[2]
                    $originalSettings[$setting] = $originalValue

                    if ($originalValue -ne $newValue) {
                        $configContent = $configContent -replace $pattern, "`$1$newValue"
                        $changes += "Changed $setting from $originalValue to $newValue"
                        $newSettings[$setting] = $newValue
                        Write-Host "  [CHANGED] $setting : $originalValue -> $newValue" -ForegroundColor Green
                    } else {
                        $newSettings[$setting] = $originalValue
                        Write-Host "  [OK] $setting : Already set to $newValue" -ForegroundColor Gray
                    }
                } else {
                    # Setting not found, add it
                    if ($configContent -match "\[Settings\]") {
                        $configContent = $configContent -replace "(\[Settings\])", "`$1`r`n$setting`t`t= $newValue"
                        $changes += "Added $setting = $newValue"
                        $newSettings[$setting] = $newValue
                        Write-Host "  [ADDED] $setting = $newValue" -ForegroundColor Green
                    }
                }
            }

            # Write updated config
            if ($changes.Count -gt 0) {
                try {
                    Set-Content -Path $msiConfigPath -Value $configContent -NoNewline
                    Write-Host ""
                    Write-Host "[OK] Configuration file updated successfully" -ForegroundColor Green
                } catch {
                    Write-Host "[FAIL] Failed to write config file: $_" -ForegroundColor Red
                }
            } else {
                Write-Host ""
                Write-Host "[OK] All settings already configured correctly" -ForegroundColor Green
            }
        } else {
            # Just read current values for documentation
            foreach ($setting in $settingsToApply.Keys) {
                $pattern = "($setting\s*=\s*)(\d+)"
                if ($configContent -match $pattern) {
                    $originalValue = $matches[2]
                    $originalSettings[$setting] = $originalValue
                } else {
                    $originalSettings[$setting] = "Not found"
                }
            }
        }

        # Add to documentation
        $docContent += @"

**Version:** $msiVersion
**Config File:** $msiConfigPath
**Backup Location:** $msiBackupPath

### Settings Applied

| Setting | Original Value | New Value | Status |
|---------|---------------|-----------|--------|
"@

        foreach ($setting in $settingsToApply.Keys) {
            $original = if ($originalSettings.ContainsKey($setting)) { $originalSettings[$setting] } else { "Not found" }
            $new = if ($newSettings.ContainsKey($setting)) { $newSettings[$setting] } else { $original }
            $status = if ($original -ne $new) { "Changed" } elseif ($original -eq $new -and $original -ne "Not found") { "Already Set" } else { "Not Found" }

            $docContent += "| $setting | $original | $new | $status |`r`n"
        }

        if ($changes.Count -gt 0) {
            $docContent += @"

### Changes Made

"@
            foreach ($change in $changes) {
                $docContent += "- $change`r`n"
            }
        } else {
            $docContent += @"

### Status

All recommended settings were already configured correctly.

"@
        }

        # Add recommended overclocking values (not applied automatically for safety)
        $docContent += @"

### Recommended Overclocking Values (Manual Configuration Required)

These values should be set manually in MSI Afterburner GUI for safety:

- **Core Clock:** +50 to +100 MHz (start low)
- **Memory Clock:** +200 to +400 MHz (start low)
- **Power Limit:** +5% to +10% (if available)
- **Temperature Limit:** 83°C (default - don't increase)

**Note:** These overclocking values are NOT applied automatically. They require manual configuration through the MSI Afterburner GUI to ensure proper testing and stability.

"@
    } else {
        Write-Host "[WARN] MSI Afterburner config file not found" -ForegroundColor Yellow
        Write-Host "  Config file will be created on first launch" -ForegroundColor Gray

        $docContent += @"

**Status:** Config file not found (will be created on first launch)
**Note:** Settings will need to be applied after first launch of MSI Afterburner.

"@
    }

    # Find executable for launching
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

    if ($LaunchApps -and $msiExePath) {
        Write-Host ""
        Write-Host "Launching MSI Afterburner..." -ForegroundColor Green
        try {
            Start-Process -FilePath $msiExePath
            Write-Host "  MSI Afterburner launched" -ForegroundColor Green
            Start-Sleep -Seconds 2
        } catch {
            Write-Host "  Failed to launch: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""

# Intel XTU Configuration
if ($xtuInstalled) {
    Write-Host "=== Intel XTU Configuration ===" -ForegroundColor Cyan
    Write-Host ""

    $xtuInfo = $intelXTU[0]
    $xtuVersion = $xtuInfo.DisplayVersion

    # Get CPU info
    $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
    $cpuName = $cpu.Name

    Write-Host "Version: $xtuVersion" -ForegroundColor Gray
    Write-Host "CPU: $cpuName" -ForegroundColor Gray
    Write-Host ""

    # Intel XTU stores settings in registry and application database
    $xtuRegistryPaths = @(
        "HKLM:\SOFTWARE\Intel\Extreme Tuning Utility",
        "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility"
    )

    # Backup registry keys if they exist
    $xtuBackupCreated = $false
    foreach ($regPath in $xtuRegistryPaths) {
        if (Test-Path $regPath) {
            $regBackupPath = Join-Path $backupPath "XTU-Registry-$($regPath.Replace(':', '-').Replace('\', '-'))"
            New-Item -ItemType Directory -Path (Split-Path $regBackupPath -Parent) -Force | Out-Null
            try {
                $regPathForExport = $regPath.Replace('HKLM:\', 'HKLM\').Replace('HKCU:\', 'HKCU\')
                reg export $regPathForExport "$regBackupPath.reg" /y 2>&1 | Out-Null
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
        Write-Host "[INFO] No existing XTU registry settings found to backup" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Intel XTU Configuration:" -ForegroundColor Yellow
    Write-Host "  NOTE: Intel XTU settings are complex and CPU-specific." -ForegroundColor Yellow
    Write-Host "  Manual configuration via GUI is strongly recommended for safety." -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Recommended Settings for Mobile CPU (i9-12900H):" -ForegroundColor Cyan
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

    # Add to documentation
    $docContent += @"

---

## Intel XTU Configuration

**Version:** $xtuVersion
**CPU:** $cpuName
**Status:** Manual Configuration Required

### Important Notes

Intel XTU settings are complex and CPU-specific. Manual configuration via GUI is **strongly recommended** for safety and proper testing.

### Recommended Settings for i9-12900H (Mobile CPU - H-series)

#### Power Limits (Most Important)
- **Turbo Boost Power Max:** Increase by 5-10W if cooling allows
- **Turbo Boost Short Power Max:** Increase by 5-10W if cooling allows
- ⚠️ **Monitor temperatures closely!**

#### Core Settings (Very Conservative)
- **Core Voltage Offset:** +0.010V to +0.020V (if needed for stability)
- ⚠️ **Do NOT increase voltage significantly on mobile CPUs!**

#### Turbo Boost Settings
- **Turbo Boost Max:** Leave at default or increase by 100-200 MHz max
- ⚠️ **Mobile CPUs will throttle if too aggressive**

### Testing Procedure

1. Use XTU's built-in **Stress Test**
2. Monitor **Core Temperature** (keep below 90°C)
3. Monitor **Package Temperature** (keep below 95°C)
4. Test for at least 15-30 minutes
5. If throttling occurs, reduce settings

### Backup Information

"@

    if ($xtuBackupCreated) {
        $docContent += "Registry settings backed up to: $backupPath`r`n"
    } else {
        $docContent += "No existing registry settings found to backup.`r`n"
    }

    # Try to launch Intel XTU
    if ($LaunchApps) {
        Write-Host "Attempting to launch Intel XTU..." -ForegroundColor Green

        $xtuExePaths = @(
            "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
            "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
        )

        $launched = $false
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

        if (-not $launched) {
            try {
                Start-Process "shell:AppsFolder"
                Write-Host "  Opened Apps folder - search for 'Intel Extreme Tuning Utility'" -ForegroundColor Yellow
            } catch {
                Write-Host "  Please launch Intel XTU manually from Start Menu" -ForegroundColor Yellow
            }
        }
    }
}

# Finalize documentation
$docContent += @"

---

## Safety Guidelines

1. **Start Conservative:** Always start with small changes
2. **Test Thoroughly:** Run stress tests after each change
3. **Monitor Temperatures:**
   - CPU: Keep below 90°C
   - GPU: Keep below 83°C
4. **Watch for Throttling:** Mobile systems will throttle if too hot
5. **Document Settings:** Save profiles for easy rollback
6. **Know How to Reset:** Both tools have "Reset" or "Default" buttons

## Backup Information

**Backup Location:** $backupPath
**Backup Created:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

All original configuration files and registry settings have been backed up to the above location.

## Next Steps

1. Review the applied settings above
2. For MSI Afterburner: Verify settings in the GUI (if launched)
3. For Intel XTU: Configure settings manually through the GUI
4. Start with conservative overclocking values
5. Test stability thoroughly before increasing settings
6. Monitor temperatures continuously

## Important Reminders

- **Stability > Performance:** A stable system is better than a crashed one
- **Mobile CPUs have limited overclocking capability**
- **Focus on power management and thermal optimization, not aggressive overclocking**
- **Always test after each change**
- **Keep backups of working configurations**

---

**End of Documentation**

"@

# Write documentation file
try {
    Set-Content -Path $docPath -Value $docContent
    Write-Host ""
    Write-Host "=== Documentation Created ===" -ForegroundColor Cyan
    Write-Host "Documentation saved to: $docPath" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Failed to write documentation: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Configuration Summary ===" -ForegroundColor Cyan
Write-Host ""

if ($BackupOnly) {
    Write-Host "[OK] Backup completed" -ForegroundColor Green
    Write-Host "  Backup location: $backupPath" -ForegroundColor Gray
} elseif ($ApplySettings) {
    Write-Host "[OK] Configuration applied and documented" -ForegroundColor Green
    Write-Host "  Backup location: $backupPath" -ForegroundColor Gray
    Write-Host "  Documentation: $docPath" -ForegroundColor Gray
} else {
    Write-Host "[INFO] Configuration analyzed (use -ApplySettings to apply changes)" -ForegroundColor Yellow
    Write-Host "  Backup location: $backupPath" -ForegroundColor Gray
    Write-Host "  Documentation: $docPath" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review the documentation file" -ForegroundColor White
Write-Host "  2. Verify MSI Afterburner settings (if applied)" -ForegroundColor White
Write-Host "  3. Configure Intel XTU manually through GUI" -ForegroundColor White
Write-Host "  4. Start with conservative settings and test thoroughly" -ForegroundColor White
Write-Host ""
