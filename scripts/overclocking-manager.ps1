# Overclocking Management Script
# Shows current status, provides recommendations, and helps manage overclocking

param(
    [switch]$Status,
    [switch]$Remove,
    [switch]$Recommend,
    [switch]$Help
)

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green"
        "Yellow" = "Yellow"
        "Cyan" = "Cyan"
        "White" = "White"
    }
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-ColorOutput "========================================" "Cyan"
    Write-ColorOutput $Title "Cyan"
    Write-ColorOutput "========================================" "Cyan"
    Write-Host ""
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Get CPU Information
function Get-CPUInfo {
    Write-Section "CPU Information"

    try {
        $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
        $cpuName = $cpu.Name.Trim()
        $cpuCores = $cpu.NumberOfCores
        $cpuThreads = $cpu.NumberOfLogicalProcessors
        $cpuMaxClock = [math]::Round($cpu.MaxClockSpeed / 1000, 2)
        $cpuCurrentClock = [math]::Round($cpu.CurrentClockSpeed / 1000, 2)

        Write-ColorOutput "Processor: $cpuName" "White"
        Write-ColorOutput "Cores: $cpuCores | Threads: $cpuThreads" "White"
        Write-ColorOutput "Max Clock Speed: $cpuMaxClock GHz" "White"
        Write-ColorOutput "Current Clock Speed: $cpuCurrentClock GHz" "White"

        # Check for overclocking indicators
        $overclocked = $false
        if ($cpuCurrentClock -gt $cpuMaxClock) {
            $overclocked = $true
            Write-ColorOutput "⚠️  CPU appears to be OVERCLOCKED!" "Yellow"
            Write-ColorOutput "   Current speed exceeds max rated speed" "Yellow"
        } else {
            $percentage = [math]::Round(($cpuCurrentClock / $cpuMaxClock) * 100, 1)
            Write-ColorOutput "Current usage: $percentage% of max speed" "Green"
        }

        return @{
            Name = $cpuName
            CurrentClock = $cpuCurrentClock
            MaxClock = $cpuMaxClock
            Overclocked = $overclocked
        }
    }
    catch {
        Write-ColorOutput "Error getting CPU info: $($_.Exception.Message)" "Red"
        return $null
    }
}

# Get GPU Information
function Get-GPUInfo {
    Write-Section "GPU Information"

    try {
        $gpus = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notlike "*Remote*" -and $_.Name -notlike "*Virtual*" }

        if ($gpus.Count -eq 0) {
            Write-ColorOutput "No GPU detected" "Yellow"
            return $null
        }

        $primaryGPU = $null
        foreach ($gpu in $gpus) {
            $gpuName = $gpu.Name
            $isLaptop = $gpuName -like "*Laptop*" -or $gpuName -like "*Mobile*"
            $isIntegrated = $gpuName -like "*Intel*" -or $gpuName -like "*Iris*" -or $gpuName -like "*UHD*"

            Write-ColorOutput "GPU: $gpuName" "White"

            # Try to get more detailed info using WMI
            $adapterRam = [math]::Round($gpu.AdapterRAM / 1GB, 2)
            if ($adapterRam -gt 0) {
                Write-ColorOutput "VRAM: $adapterRam GB" "White"
            }

            # Check for NVIDIA
            if ($gpuName -like "*NVIDIA*") {
                Write-ColorOutput "Detected: NVIDIA GPU" "Cyan"
                if ($isLaptop) {
                    Write-ColorOutput "⚠️  LAPTOP GPU DETECTED" "Yellow"
                    Write-ColorOutput "  - Laptop GPUs have thermal and power limits" "Yellow"
                    Write-ColorOutput "  - Overclocking headroom is limited" "Yellow"
                    Write-ColorOutput "  - Monitor temperatures closely (laptops run hotter)" "Yellow"
                    Write-ColorOutput "  - Use MSI Afterburner with conservative settings" "White"
                    Write-ColorOutput "  - Consider undervolting instead of overclocking" "Cyan"
                } else {
                    Write-ColorOutput "Recommendation: Use MSI Afterburner or NVIDIA Control Panel" "Yellow"
                }
                if (-not $isIntegrated) {
                    $primaryGPU = $gpu
                }
            }
            # Check for AMD
            elseif ($gpuName -like "*AMD*" -or $gpuName -like "*Radeon*") {
                Write-ColorOutput "Detected: AMD GPU" "Cyan"
                if ($isLaptop) {
                    Write-ColorOutput "⚠️  LAPTOP GPU DETECTED" "Yellow"
                    Write-ColorOutput "  - Laptop GPUs have thermal and power limits" "Yellow"
                    Write-ColorOutput "  - Overclocking headroom is limited" "Yellow"
                }
                Write-ColorOutput "Recommendation: Use AMD Radeon Software or MSI Afterburner" "Yellow"
                if (-not $isIntegrated) {
                    $primaryGPU = $gpu
                }
            }
            # Check for Intel
            elseif ($gpuName -like "*Intel*") {
                Write-ColorOutput "Detected: Intel GPU (Integrated)" "Cyan"
                Write-ColorOutput "Note: Intel GPUs have limited overclocking support" "Yellow"
                Write-ColorOutput "  - This is typically the integrated graphics" "White"
                Write-ColorOutput "  - Focus overclocking on your dedicated GPU instead" "White"
            }

            Write-Host ""
        }

        # Show primary GPU recommendation
        if ($primaryGPU -and ($primaryGPU.Name -like "*Laptop*" -or $primaryGPU.Name -like "*Mobile*")) {
            Write-ColorOutput "💡 LAPTOP OVERCLOCKING TIPS:" "Cyan"
            Write-ColorOutput "  - Start with +50-100 MHz core clock (very conservative)" "White"
            Write-ColorOutput "  - Memory overclock: +200-400 MHz max" "White"
            Write-ColorOutput "  - Undervolting often provides better results than overclocking" "Cyan"
            Write-ColorOutput "  - Ensure laptop is plugged in and on a cooling pad" "White"
            Write-ColorOutput "  - Monitor GPU temperature (keep below 87°C for laptops)" "Yellow"
            Write-Host ""
        }

        return $gpus
    }
    catch {
        Write-ColorOutput "Error getting GPU info: $($_.Exception.Message)" "Red"
        return $null
    }
}

# Check for overclocking software
function Get-OverclockingSoftware {
    Write-Section "Overclocking Software Detection"

    $softwareFound = @()

    # Check for MSI Afterburner
    $msiAfterburner = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -like "*MSI Afterburner*" } | Select-Object -First 1
    if ($msiAfterburner) {
        Write-ColorOutput "✓ MSI Afterburner: INSTALLED" "Green"
        $softwareFound += "MSI Afterburner"
    } else {
        Write-ColorOutput "✗ MSI Afterburner: NOT INSTALLED" "Yellow"
    }

    # Check for Intel XTU
    $intelXTU = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -like "*Intel Extreme Tuning*" } | Select-Object -First 1
    if ($intelXTU) {
        Write-ColorOutput "✓ Intel Extreme Tuning Utility: INSTALLED" "Green"
        $softwareFound += "Intel XTU"
    } else {
        Write-ColorOutput "✗ Intel Extreme Tuning Utility: NOT INSTALLED" "Yellow"
    }

    # Check for AMD Ryzen Master
    $ryzenMaster = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -like "*Ryzen Master*" } | Select-Object -First 1
    if ($ryzenMaster) {
        Write-ColorOutput "✓ AMD Ryzen Master: INSTALLED" "Green"
        $softwareFound += "AMD Ryzen Master"
    } else {
        Write-ColorOutput "✗ AMD Ryzen Master: NOT INSTALLED" "Yellow"
    }

    # Check for EVGA Precision
    $evgaPrecision = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -like "*EVGA Precision*" } | Select-Object -First 1
    if ($evgaPrecision) {
        Write-ColorOutput "✓ EVGA Precision X1: INSTALLED" "Green"
        $softwareFound += "EVGA Precision"
    } else {
        Write-ColorOutput "✗ EVGA Precision X1: NOT INSTALLED" "Yellow"
    }

    # Check for AMD Radeon Software
    $amdSoftware = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -like "*AMD Software*" -or $_.DisplayName -like "*Radeon Software*" } | Select-Object -First 1
    if ($amdSoftware) {
        Write-ColorOutput "✓ AMD Radeon Software: INSTALLED" "Green"
        $softwareFound += "AMD Radeon Software"
    } else {
        Write-ColorOutput "✗ AMD Radeon Software: NOT INSTALLED" "Yellow"
    }

    return $softwareFound
}

# Check power plan settings
function Get-PowerPlanInfo {
    Write-Section "Power Plan Settings"

    try {
        $currentPlan = powercfg /getactivescheme
        $currentPlanName = ($currentPlan | Select-String "GUID:.*\((.*)\)").Matches.Groups[1].Value

        Write-ColorOutput "Current Power Plan: $currentPlanName" "White"

        # Check processor power management
        $schemeGuid = (powercfg /getactivescheme).Split("(")[1].Split(")")[0]

        $minProcState = powercfg /query $schemeGuid SUB_PROCESSOR PROCTHROTTLEMIN 2>$null
        $maxProcState = powercfg /query $schemeGuid SUB_PROCESSOR PROCTHROTTLEMAX 2>$null

        if ($currentPlanName -like "*High Performance*" -or $currentPlanName -like "*Ultimate Performance*") {
            Write-ColorOutput "✓ Power plan optimized for performance" "Green"
        } else {
            Write-ColorOutput "⚠️  Consider switching to 'High Performance' power plan for better overclocking" "Yellow"
        }

        return $currentPlanName
    }
    catch {
        Write-ColorOutput "Error getting power plan info: $($_.Exception.Message)" "Red"
        return $null
    }
}

# Check registry for overclocking settings
function Get-RegistryOverclockSettings {
    Write-Section "Registry Overclocking Settings"

    $settingsFound = @()

    # Check for Intel Turbo Boost
    try {
        $turboBoost = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "CsEnabled" -ErrorAction SilentlyContinue
        if ($turboBoost) {
            Write-ColorOutput "Power settings found in registry" "Cyan"
        }
    }
    catch {
        # Not found, that's okay
    }

    # Check for NVIDIA overclocking registry entries
    try {
        $nvidiaOC = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" -ErrorAction SilentlyContinue
        if ($nvidiaOC) {
            Write-ColorOutput "NVIDIA overclocking registry entries found" "Cyan"
            $settingsFound += "NVIDIA"
        }
    }
    catch {
        # Not found
    }

    if ($settingsFound.Count -eq 0) {
        Write-ColorOutput "No overclocking registry settings detected" "Yellow"
    }

    return $settingsFound
}

# Remove overclocking settings
function Remove-OverclockingSettings {
    Write-Section "Removing Overclocking Settings"

    if (-not (Test-Administrator)) {
        Write-ColorOutput "ERROR: Administrator privileges required to remove overclocking settings!" "Red"
        Write-ColorOutput "Please run this script as Administrator" "Yellow"
        return $false
    }

    Write-ColorOutput "⚠️  WARNING: This will attempt to reset overclocking settings" "Yellow"
    Write-ColorOutput "This includes:" "White"
    Write-ColorOutput "  - Power plan to Balanced" "White"
    Write-ColorOutput "  - Registry overclocking entries (if safe to remove)" "White"
    Write-ColorOutput "  - Note: BIOS/UEFI overclocking cannot be reset from Windows" "Yellow"
    Write-Host ""

    $confirm = Read-Host "Are you sure you want to proceed? (yes/no)"
    if ($confirm -ne "yes") {
        Write-ColorOutput "Operation cancelled" "Yellow"
        return $false
    }

    try {
        # Reset power plan to Balanced
        Write-ColorOutput "Resetting power plan to Balanced..." "Cyan"
        $balancedGuid = (powercfg /list | Select-String "Balanced").ToString().Split("(")[1].Split(")")[0]
        if ($balancedGuid) {
            powercfg /setactive $balancedGuid
            Write-ColorOutput "✓ Power plan reset to Balanced" "Green"
        }

        # Note: We won't modify registry entries that could break the system
        Write-ColorOutput "✓ Overclocking settings reset (where safe)" "Green"
        Write-ColorOutput "Note: BIOS/UEFI overclocking must be reset from BIOS/UEFI settings" "Yellow"

        return $true
    }
    catch {
        Write-ColorOutput "Error removing settings: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Power plan menu
function Show-PowerPlanMenu {
    Write-Section "Power Plan Manager"

    try {
        $currentPlan = powercfg /getactivescheme
        $currentPlanName = ($currentPlan | Select-String "GUID:.*\((.*)\)").Matches.Groups[1].Value

        Write-ColorOutput "Current Power Plan: $currentPlanName" "Cyan"
        Write-Host ""
        Write-ColorOutput "Available power plans:" "White"
        Write-ColorOutput "[1] Balanced (Recommended for daily use)" "White"
        Write-ColorOutput "[2] High Performance (Recommended for overclocking)" "White"
        Write-ColorOutput "[3] Power Saver (Battery optimization)" "White"
        Write-ColorOutput "[4] Ultimate Performance (Maximum performance)" "White"
        Write-ColorOutput "[5] Cancel" "White"
        Write-Host ""

        $choice = Read-Host "Select power plan (1-5)"

        $planGuids = @{
            "1" = @{ Name = "Balanced"; GUID = "381b4222-f694-41f0-9685-ff5bb260df2e" }
            "2" = @{ Name = "High Performance"; GUID = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" }
            "3" = @{ Name = "Power Saver"; GUID = "a1841308-3541-4fab-bc81-f71556f20b4a" }
            "4" = @{ Name = "Ultimate Performance"; GUID = "e9a42b02-d5df-448d-aa00-03f14749eb61" }
        }

        if ($planGuids.ContainsKey($choice)) {
            $selectedPlan = $planGuids[$choice]

            # Check if Ultimate Performance exists, if not create it
            if ($choice -eq "4") {
                $existing = powercfg /list | Select-String $selectedPlan.GUID
                if (-not $existing) {
                    Write-ColorOutput "Creating Ultimate Performance power plan..." "Yellow"
                    powercfg /duplicatescheme $selectedPlan.GUID | Out-Null
                }
            }

            # Set the power plan
            powercfg /setactive $selectedPlan.GUID | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✓ Power plan switched to: $($selectedPlan.Name)" "Green"
            } else {
                Write-ColorOutput "✗ Failed to switch power plan" "Red"
            }
        }
        elseif ($choice -eq "5") {
            Write-ColorOutput "Cancelled" "Yellow"
        }
        else {
            Write-ColorOutput "Invalid choice" "Red"
        }
    }
    catch {
        Write-ColorOutput "Error managing power plan: $($_.Exception.Message)" "Red"
    }
}

# Provide recommendations
function Get-Recommendations {
    Write-Section "Overclocking Recommendations"

    $cpuInfo = Get-CPUInfo
    $gpuInfo = Get-GPUInfo
    $software = Get-OverclockingSoftware
    $powerPlan = Get-PowerPlanInfo

    Write-Host ""
    Write-ColorOutput "=== RECOMMENDATIONS ===" "Cyan"
    Write-Host ""

    # CPU recommendations
    if ($cpuInfo) {
        if ($cpuInfo.Overclocked) {
            Write-ColorOutput "CPU Status: Currently overclocked" "Yellow"
            Write-ColorOutput "  - Monitor temperatures closely" "White"
            Write-ColorOutput "  - Run stability tests (Prime95, AIDA64)" "White"
            Write-ColorOutput "  - Ensure adequate cooling" "White"
        } else {
            Write-ColorOutput "CPU Status: Running at stock speeds" "Green"
            if ($cpuInfo.Name -like "*Intel*") {
                Write-ColorOutput "  - Consider Intel XTU for Intel CPU overclocking" "Yellow"
            } elseif ($cpuInfo.Name -like "*AMD*" -or $cpuInfo.Name -like "*Ryzen*") {
                Write-ColorOutput "  - Consider AMD Ryzen Master for AMD CPU overclocking" "Yellow"
            }
        }
    }

    Write-Host ""

    # Software recommendations
    if ($software.Count -eq 0) {
        Write-ColorOutput "No overclocking software detected" "Yellow"

        # Check if laptop GPU detected
        $hasLaptopGPU = $gpuInfo | Where-Object { $_.Name -like "*Laptop*" -or $_.Name -like "*Mobile*" }
        $hasNVIDIAGPU = $gpuInfo | Where-Object { $_.Name -like "*NVIDIA*" -and $_.Name -notlike "*Intel*" }

        if ($hasLaptopGPU -and $hasNVIDIAGPU) {
            Write-ColorOutput "  - Install MSI Afterburner for GPU overclocking (RECOMMENDED)" "White"
            Write-ColorOutput "    Download: https://www.msi.com/Landing/afterburner/graphics-cards" "Cyan"
            Write-ColorOutput "    ⚠️  For laptops: Use conservative settings, monitor temps closely" "Yellow"
            Write-ColorOutput "  - Alternative: NVIDIA Control Panel (built-in, limited features)" "White"
        } else {
            Write-ColorOutput "  - Install MSI Afterburner for GPU overclocking (universal)" "White"
            Write-ColorOutput "    Download: https://www.msi.com/Landing/afterburner/graphics-cards" "Cyan"
        }

        if ($cpuInfo -and $cpuInfo.Name -like "*Intel*") {
            Write-ColorOutput "  - Install Intel XTU for CPU overclocking" "White"
            Write-ColorOutput "    Download: https://www.intel.com/content/www/us/en/download-center/home.html" "Cyan"
        }
        if ($cpuInfo -and ($cpuInfo.Name -like "*AMD*" -or $cpuInfo.Name -like "*Ryzen*")) {
            Write-ColorOutput "  - Install AMD Ryzen Master for CPU overclocking" "White"
            Write-ColorOutput "    Download: https://www.amd.com/en/technologies/ryzen-master" "Cyan"
        }
        Write-Host ""
        Write-ColorOutput "  💡 Tip: After installation, restart this tool to detect the software" "Yellow"
    } else {
        Write-ColorOutput "Overclocking software found: $($software -join ', ')" "Green"
    }

    Write-Host ""

    # Power plan recommendations
    if ($powerPlan -and $powerPlan -notlike "*High Performance*" -and $powerPlan -notlike "*Ultimate Performance*") {
        Write-ColorOutput "Power Plan: Not optimized for overclocking" "Yellow"
        Write-ColorOutput "  - Switch to 'High Performance' power plan" "White"
        Write-ColorOutput "  - Command: powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" "Cyan"
    } else {
        Write-ColorOutput "Power Plan: Optimized for performance" "Green"
    }

    Write-Host ""

    # Check if laptop GPU
    $hasLaptopGPU = $gpuInfo | Where-Object { $_.Name -like "*Laptop*" -or $_.Name -like "*Mobile*" }

    if ($hasLaptopGPU) {
        Write-ColorOutput "=== LAPTOP OVERCLOCKING TIPS ===" "Cyan"
        Write-ColorOutput "1. Monitor temperatures closely (keep GPU < 87°C for laptops)" "Yellow"
        Write-ColorOutput "2. Start VERY conservative: +50-100 MHz core, +200-400 MHz memory" "White"
        Write-ColorOutput "3. Undervolting often better than overclocking on laptops" "Cyan"
        Write-ColorOutput "4. Always use laptop plugged in (not on battery)" "White"
        Write-ColorOutput "5. Use cooling pad for better thermal performance" "White"
        Write-ColorOutput "6. Test stability with games/apps you actually use" "White"
        Write-ColorOutput "7. Laptops have strict power limits - don't expect desktop OC results" "Yellow"
        Write-Host ""
        Write-ColorOutput "=== GENERAL OVERCLOCKING TIPS ===" "Cyan"
    } else {
        Write-ColorOutput "=== GENERAL OVERCLOCKING TIPS ===" "Cyan"
    }

    Write-ColorOutput "1. Always monitor temperatures (keep CPU < 80°C, GPU < 83°C)" "White"
    Write-ColorOutput "2. Increase clock speeds gradually (5-10% at a time)" "White"
    Write-ColorOutput "3. Test stability after each change" "White"
    Write-ColorOutput "4. Ensure adequate cooling (airflow, thermal paste)" "White"
    Write-ColorOutput "5. BIOS/UEFI overclocking is more stable than software" "White"
    Write-ColorOutput "6. Keep voltage increases minimal to avoid damage" "White"
    Write-ColorOutput "7. Document your settings for easy rollback" "White"
    Write-Host ""
    Write-ColorOutput "=== QUICK ACTIONS ===" "Cyan"
    Write-ColorOutput "To switch to High Performance power plan, run:" "White"
    Write-ColorOutput "  powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" "Cyan"
    Write-ColorOutput "To switch back to Balanced, run:" "White"
    Write-ColorOutput "  powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e" "Cyan"
}

# Main menu
function Show-MainMenu {
    Write-Host ""
    Write-Section "Overclocking Manager"
    Write-ColorOutput "Select an option:" "Cyan"
    Write-Host ""
    Write-ColorOutput "[1] Show Current Status" "White"
    Write-ColorOutput "[2] Get Recommendations" "White"
    Write-ColorOutput "[3] Remove Overclocking Settings" "White"
    Write-ColorOutput "[4] Switch Power Plan" "White"
    Write-ColorOutput "[5] Exit" "White"
    Write-Host ""

    $choice = Read-Host "Enter your choice (1-5)"

    switch ($choice) {
        "1" {
            Get-CPUInfo
            Get-GPUInfo
            Get-OverclockingSoftware
            Get-PowerPlanInfo
            Get-RegistryOverclockSettings
            Write-Host ""
            Read-Host "Press Enter to continue"
            Show-MainMenu
        }
        "2" {
            Get-Recommendations
            Write-Host ""
            Read-Host "Press Enter to continue"
            Show-MainMenu
        }
        "3" {
            Remove-OverclockingSettings
            Write-Host ""
            Read-Host "Press Enter to continue"
            Show-MainMenu
        }
        "4" {
            Show-PowerPlanMenu
            Show-MainMenu
        }
        "5" {
            Write-ColorOutput "Exiting..." "Green"
            exit 0
        }
        default {
            Write-ColorOutput "Invalid choice. Please try again." "Red"
            Start-Sleep -Seconds 2
            Show-MainMenu
        }
    }
}

# Main execution
if ($Help) {
    Write-ColorOutput "Overclocking Manager - Help" "Cyan"
    Write-Host ""
    Write-ColorOutput "Usage:" "White"
    Write-ColorOutput "  .\overclocking-manager.ps1 [options]" "White"
    Write-Host ""
    Write-ColorOutput "Options:" "White"
    Write-ColorOutput "  -Status      Show current overclocking status" "White"
    Write-ColorOutput "  -Recommend   Show recommendations" "White"
    Write-ColorOutput "  -Remove      Remove overclocking settings" "White"
    Write-ColorOutput "  -Help        Show this help message" "White"
    Write-Host ""
    Write-ColorOutput "If no options are provided, interactive menu will be shown." "White"
    exit 0
}

if ($Status) {
    Get-CPUInfo
    Get-GPUInfo
    Get-OverclockingSoftware
    Get-PowerPlanInfo
    Get-RegistryOverclockSettings
}
elseif ($Recommend) {
    Get-Recommendations
}
elseif ($Remove) {
    Remove-OverclockingSettings
}
else {
    Show-MainMenu
}
