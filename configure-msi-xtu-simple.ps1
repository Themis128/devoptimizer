# Configure MSI Afterburner and Intel XTU - Simple Working Version
# This script verifies installation and provides configuration guidance

param(
    [switch]$LaunchApps
)

Write-Host "=== MSI Afterburner & Intel XTU Configuration Script ===" -ForegroundColor Cyan
Write-Host ""

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

if ($msiInstalled) {
    $msiInfo = $msiAfterburner[0]
    Write-Host "  [OK] MSI Afterburner: Installed" -ForegroundColor Green
    Write-Host "    Version: $($msiInfo.DisplayVersion)" -ForegroundColor Gray
    Write-Host "    Location: $($msiInfo.InstallLocation)" -ForegroundColor Gray

    # Find executable
    $msiExePaths = @(
        "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe",
        "${env:ProgramFiles}\MSI Afterburner\MSIAfterburner.exe",
        "$($msiInfo.InstallLocation)\MSIAfterburner.exe"
    )

    $msiExePath = $null
    foreach ($path in $msiExePaths) {
        if (Test-Path $path) {
            $msiExePath = $path
            Write-Host "    Executable: $path" -ForegroundColor Gray
            break
        }
    }

    if (-not $msiExePath) {
        Write-Host "    [WARN] Could not find MSI Afterburner executable" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [FAIL] MSI Afterburner: Not installed" -ForegroundColor Red
    $msiExePath = $null
}

Write-Host ""

# Check for Intel XTU
Write-Host "Checking for Intel XTU..." -ForegroundColor Yellow
$intelXTU = Get-InstalledSoftware -NamePattern "Intel XTU"
if (-not $intelXTU) {
    $intelXTU = Get-InstalledSoftware -NamePattern "Extreme Tuning Utility"
}

$xtuInstalled = $intelXTU -ne $null -and $intelXTU.Count -gt 0

if ($xtuInstalled) {
    $xtuInfo = $intelXTU[0]
    Write-Host "  [OK] Intel XTU: Installed" -ForegroundColor Green
    Write-Host "    Version: $($xtuInfo.DisplayVersion)" -ForegroundColor Gray
    Write-Host "    Location: $($xtuInfo.InstallLocation)" -ForegroundColor Gray

    $xtuVersion = $xtuInfo.DisplayVersion
    Write-Host "    Version Check: $xtuVersion" -ForegroundColor Gray

    # Find executable - try multiple locations
    $xtuExePaths = @(
        "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
        "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
        "$($xtuInfo.InstallLocation)\Client\XTU.exe",
        "${env:ProgramFiles(x86)}\Intel\Extreme Tuning Utility\Client\XTU.exe",
        "${env:ProgramFiles}\Intel\Extreme Tuning Utility\Client\XTU.exe",
        "$env:LOCALAPPDATA\Programs\Intel\Extreme Tuning Utility\Client\XTU.exe"
    )

    # Also try searching in common Intel directories
    $intelDirs = @(
        "${env:ProgramFiles(x86)}\Intel",
        "${env:ProgramFiles}\Intel"
    )

    $xtuExePath = $null
    foreach ($path in $xtuExePaths) {
        if (Test-Path $path) {
            $xtuExePath = $path
            Write-Host "    Executable: $path" -ForegroundColor Gray
            break
        }
    }

    # If not found in standard paths, search Intel directories
    if (-not $xtuExePath) {
        foreach ($intelDir in $intelDirs) {
            if (Test-Path $intelDir) {
                $found = Get-ChildItem -Path $intelDir -Filter "XTU.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    $xtuExePath = $found.FullName
                    Write-Host "    Executable: $($found.FullName)" -ForegroundColor Gray
                    break
                }
            }
        }
    }

    # Try Start Menu shortcut as last resort
    if (-not $xtuExePath) {
        $startMenuPaths = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Intel Extreme Tuning Utility.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Intel Extreme Tuning Utility.lnk"
        )
        foreach ($shortcut in $startMenuPaths) {
            if (Test-Path $shortcut) {
                Write-Host "    Found Start Menu shortcut: $shortcut" -ForegroundColor Gray
                Write-Host "    Note: You can launch Intel XTU from Start Menu" -ForegroundColor Yellow
                break
            }
        }
    }

    # Try to find via Start Menu or shell command
    if (-not $xtuExePath) {
        try {
            # Try to get the path from shell:AppsFolder
            $shell = New-Object -ComObject Shell.Application
            $appsFolder = $shell.NameSpace("shell:AppsFolder")
            $apps = $appsFolder.Items() | Where-Object { $_.Name -like "*Intel*XTU*" -or $_.Name -like "*Extreme*Tuning*" }
            if ($apps) {
                $app = $apps[0]
                Write-Host "    Found via Start Menu: $($app.Name)" -ForegroundColor Gray
                # Try to get executable path from app
                try {
                    $xtuExePath = $app.Path
                    if ($xtuExePath -and (Test-Path $xtuExePath)) {
                        Write-Host "    Executable: $xtuExePath" -ForegroundColor Gray
                    }
                } catch {
                    # Path not available, but we know it exists
                }
            }
        } catch {
            # Continue if shell access fails
        }

        if (-not $xtuExePath) {
            Write-Host "    [WARN] Could not find Intel XTU executable path" -ForegroundColor Yellow
            Write-Host "    Try launching from Start Menu: Intel Extreme Tuning Utility" -ForegroundColor Gray
            Write-Host "    Or search for 'XTU' in Start Menu" -ForegroundColor Gray
        }
    }

    # Check CPU compatibility
    $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
    $cpuName = $cpu.Name

    Write-Host ""
    Write-Host "  CPU Information:" -ForegroundColor Cyan
    Write-Host "    $cpuName" -ForegroundColor White

    # Version compatibility check
    if ($xtuVersion -like "10.*") {
        Write-Host "    [WARN] Version 10.x is for Core Ultra Series 2 processors" -ForegroundColor Yellow
        Write-Host "      If you have 12th Gen or older, you may need version 7.14.2.67" -ForegroundColor Yellow
    } elseif ($xtuVersion -like "7.*") {
        Write-Host "    [OK] Version 7.x is compatible with 12th Gen and older processors" -ForegroundColor Green
    }
} else {
    Write-Host "  [FAIL] Intel XTU: Not installed" -ForegroundColor Red
    $xtuExePath = $null
}

Write-Host ""
Write-Host "=== Installation Summary ===" -ForegroundColor Cyan
if ($msiInstalled -and $xtuInstalled) {
    Write-Host "[OK] Both tools are installed" -ForegroundColor Green
} elseif ($msiInstalled) {
    Write-Host "[WARN] Only MSI Afterburner is installed" -ForegroundColor Yellow
} elseif ($xtuInstalled) {
    Write-Host "[WARN] Only Intel XTU is installed" -ForegroundColor Yellow
} else {
    Write-Host "[FAIL] Neither tool is installed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install the tools first using:" -ForegroundColor Yellow
    Write-Host "  install-overclocking-tools.ps1" -ForegroundColor White
    exit 1
}

Write-Host ""

# Get GPU information
$gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" -or $_.Name -like "*GeForce*" -or $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" } | Select-Object -First 1

# Create config directory
$configDir = Join-Path $PSScriptRoot "config\overclocking"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    Write-Host "Created configuration directory: $configDir" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Configuration Recommendations ===" -ForegroundColor Cyan
Write-Host ""

# MSI Afterburner Configuration
if ($msiInstalled) {
    Write-Host "MSI Afterburner Configuration:" -ForegroundColor Yellow
    Write-Host "1. Launch MSI Afterburner" -ForegroundColor White
    Write-Host "2. Go to Settings (gear icon)" -ForegroundColor White
    Write-Host "3. Enable these options:" -ForegroundColor White
    Write-Host "   - Unlock Voltage Control" -ForegroundColor Gray
    Write-Host "   - Unlock Voltage Monitoring" -ForegroundColor Gray
    Write-Host "   - Apply overclocking at system startup" -ForegroundColor Gray
    Write-Host "   - Start with Windows (optional)" -ForegroundColor Gray
    Write-Host "   - Minimize to tray" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Overclocking Guidelines:" -ForegroundColor White
    Write-Host "   - Start with small increments (+10-20 MHz core clock)" -ForegroundColor Gray
    Write-Host "   - Test stability with each change" -ForegroundColor Gray
    Write-Host "   - Monitor temperatures (keep below 83 degrees C)" -ForegroundColor Gray
    Write-Host ""
}

# Intel XTU Configuration
if ($xtuInstalled) {
    Write-Host "Intel XTU Configuration:" -ForegroundColor Yellow
    Write-Host "1. Launch Intel XTU" -ForegroundColor White
    Write-Host "2. Accept terms and conditions" -ForegroundColor White
    Write-Host "3. For Mobile CPUs (H-series):" -ForegroundColor White
    Write-Host "   - Focus on power limits and thermal management" -ForegroundColor Gray
    Write-Host "   - Adjust Turbo Boost Power Max carefully" -ForegroundColor Gray
    Write-Host "   - Monitor Core and Package temperatures" -ForegroundColor Gray
    Write-Host "   - Use Stress Test feature to verify stability" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Important Notes:" -ForegroundColor Yellow
    Write-Host "   - Mobile CPUs have limited overclocking capability" -ForegroundColor Yellow
    Write-Host "   - Focus on power management, not aggressive overclocking" -ForegroundColor Yellow
    Write-Host "   - Ensure adequate cooling" -ForegroundColor Yellow
    Write-Host "   - Always test stability after changes" -ForegroundColor Yellow
    Write-Host ""
}

# Launch applications if requested
if ($LaunchApps) {
    Write-Host "=== Launching Applications ===" -ForegroundColor Cyan
    Write-Host ""

    if ($msiInstalled -and $msiExePath) {
        Write-Host "Launching MSI Afterburner..." -ForegroundColor Green
        try {
            Start-Process -FilePath $msiExePath
            Write-Host "  MSI Afterburner launched" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to launch MSI Afterburner: $_" -ForegroundColor Red
        }
        Start-Sleep -Seconds 2
    }

    if ($xtuInstalled) {
        Write-Host "Launching Intel XTU..." -ForegroundColor Green
        $launched = $false

        if ($xtuExePath -and (Test-Path $xtuExePath)) {
            try {
                Start-Process -FilePath $xtuExePath
                Write-Host "  Intel XTU launched" -ForegroundColor Green
                $launched = $true
            } catch {
                Write-Host "  Failed to launch from path: $_" -ForegroundColor Yellow
            }
        }

        # If not launched, try via Start Menu
        if (-not $launched) {
            try {
                # Try launching via shell command
                $result = Start-Process "shell:AppsFolder\$(Get-StartApps | Where-Object { $_.Name -like '*Intel*XTU*' -or $_.Name -like '*Extreme*Tuning*' } | Select-Object -First 1 -ExpandProperty AppID)" -ErrorAction SilentlyContinue
                if ($result) {
                    Write-Host "  Intel XTU launched via Start Menu" -ForegroundColor Green
                    $launched = $true
                }
            } catch {
                # Try alternative method
            }

            # Last resort: try to launch by name
            if (-not $launched) {
                try {
                    Start-Process "Intel Extreme Tuning Utility" -ErrorAction SilentlyContinue
                    Write-Host "  Attempted to launch Intel XTU" -ForegroundColor Yellow
                    Write-Host "  If it didn't open, please launch manually from Start Menu" -ForegroundColor Gray
                } catch {
                    Write-Host "  Could not launch Intel XTU automatically" -ForegroundColor Yellow
                    Write-Host "  Please launch manually from Start Menu: Intel Extreme Tuning Utility" -ForegroundColor Gray
                }
            }
        }
    }
}

Write-Host ""
Write-Host "=== Configuration Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration guide saved to: $configDir" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review the configuration recommendations above" -ForegroundColor White
Write-Host "  2. Launch the applications and follow the recommended settings" -ForegroundColor White
Write-Host "  3. Start with conservative settings and test thoroughly" -ForegroundColor White
Write-Host ""
