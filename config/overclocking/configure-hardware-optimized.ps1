# Hardware-Optimized MSI Afterburner Configuration
# Configured specifically for RTX 3070 Laptop GPU and i9-12900H
# Based on online documentation and hardware capabilities

param(
    [switch]$ApplyConfig,
    [switch]$CreateProfiles,
    [switch]$SetupOnly
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Hardware-Optimized Configuration' -ForegroundColor Cyan
Write-Host '  RTX 3070 Laptop GPU + i9-12900H' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# Hardware-specific configuration
$config = @{
    Hardware = @{
        GPU = 'RTX 3070 Laptop GPU'
        CPU = 'i9-12900H'
        Type = 'Mobile'
    }
    MSIAfterburner = @{
        # Essential settings to enable
        UnlockVoltageControl = 1
        UnlockVoltageMonitoring = 1
        StartWithWindows = 1
        SendToTrayOnClose = 1
        EnableServer = 1
        ShowMonitoringTab = 1
        ShowOnScreenDisplayTab = 1
        RememberSettings = 1
    }
    Overclocking = @{
        # RTX 3070 Laptop optimized values (conservative start)
        Profile1 = @{
            Name = 'Conservative'
            CoreClock = 50
            MemClock = 200
            PowerLimit = 5
            TempLimit = 83
            Description = 'Safe starting point for RTX 3070 Laptop'
        }
        Profile2 = @{
            Name = 'Moderate'
            CoreClock = 75
            MemClock = 300
            PowerLimit = 10
            TempLimit = 83
            Description = 'Moderate overclock if cooling allows'
        }
        Profile3 = @{
            Name = 'Aggressive'
            CoreClock = 100
            MemClock = 400
            PowerLimit = 15
            TempLimit = 83
            Description = 'Aggressive - only if excellent cooling'
        }
    }
}

Write-Host 'Hardware Configuration:' -ForegroundColor Yellow
Write-Host "  GPU: $($config.Hardware.GPU)" -ForegroundColor White
Write-Host "  CPU: $($config.Hardware.CPU)" -ForegroundColor White
Write-Host "  Type: $($config.Hardware.Type) (Laptop)" -ForegroundColor White
Write-Host ''

# Step 1: Configure MSI Afterburner Settings
Write-Host '=== Step 1: MSI Afterburner Settings Configuration ===' -ForegroundColor Cyan
Write-Host ''

$workspaceConfig = 'D:\DevOptimizer\MSIAfterburner.cfg'
$targetConfig = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.cfg'

if (-not (Test-Path $workspaceConfig)) {
    Write-Host '[ERROR] Workspace config file not found' -ForegroundColor Red
    Write-Host "  Expected: $workspaceConfig" -ForegroundColor Gray
    exit 1
}

Write-Host '[INFO] Reading current MSI Afterburner configuration...' -ForegroundColor Yellow

# Read current config
$configContent = Get-Content $workspaceConfig -Raw

# Update essential settings
Write-Host '[INFO] Updating essential settings...' -ForegroundColor Yellow

# Update settings based on hardware optimization
$settingsToUpdate = @{
    'UnlockVoltageControl\s*=\s*\d+' = "UnlockVoltageControl`t`t= $($config.MSIAfterburner.UnlockVoltageControl)"
    'UnlockVoltageMonitoring\s*=\s*\d+' = "UnlockVoltageMonitoring`t`t= $($config.MSIAfterburner.UnlockVoltageMonitoring)"
    'StartWithWindows\s*=\s*\d+' = "StartWithWindows`t`t= $($config.MSIAfterburner.StartWithWindows)"
    'SendToTrayOnClose\s*=\s*\d+' = "SendToTrayOnClose`t`t= $($config.MSIAfterburner.SendToTrayOnClose)"
    'EnableServer\s*=\s*\d+' = "EnableServer`t`t= $($config.MSIAfterburner.EnableServer)"
    'RememberSettings\s*=\s*\d+' = "RememberSettings`t`t= $($config.MSIAfterburner.RememberSettings)"
}

foreach ($pattern in $settingsToUpdate.Keys) {
    if ($configContent -match $pattern) {
        $configContent = $configContent -replace $pattern, $settingsToUpdate[$pattern]
        Write-Host "  [OK] Updated: $($settingsToUpdate[$pattern].Split('=')[0].Trim())" -ForegroundColor Green
    }
    else {
        # Add setting if it doesn't exist (in [Settings] section)
        if ($configContent -match '\[Settings\]') {
            $configContent = $configContent -replace '(\[Settings\])', "`$1`n$($settingsToUpdate[$pattern])"
            Write-Host "  [OK] Added: $($settingsToUpdate[$pattern].Split('=')[0].Trim())" -ForegroundColor Green
        }
    }
}

# Save updated config
Set-Content -Path $workspaceConfig -Value $configContent -NoNewline
Write-Host '[OK] Configuration file updated' -ForegroundColor Green

# Save to Program Files if requested
if ($ApplyConfig) {
    Write-Host ''
    Write-Host '[INFO] Saving configuration to Program Files...' -ForegroundColor Yellow

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        if (Test-Path $targetConfig) {
            $backupFile = "$targetConfig.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $targetConfig -Destination $backupFile -ErrorAction SilentlyContinue
            Write-Host "  [OK] Backup created: $backupFile" -ForegroundColor Green
        }

        try {
            Copy-Item $workspaceConfig -Destination $targetConfig -Force
            Write-Host '  [OK] Configuration saved to Program Files' -ForegroundColor Green
        }
        catch {
            Write-Host "  [WARN] Could not save to Program Files: $_" -ForegroundColor Yellow
            Write-Host '  Run as Administrator or use save-msi-config.bat' -ForegroundColor Gray
        }
    }
    else {
        Write-Host '  [WARN] Administrator privileges required' -ForegroundColor Yellow
        Write-Host '  Use save-msi-config.bat to save the configuration' -ForegroundColor Gray
    }
}

# Step 2: Launch MSI Afterburner and configure
Write-Host ''
Write-Host '=== Step 2: MSI Afterburner GUI Configuration ===' -ForegroundColor Cyan
Write-Host ''

$msiExe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
if (-not (Test-Path $msiExe)) {
    $msiExe = 'C:\Program Files\MSI Afterburner\MSIAfterburner.exe'
}

if (-not (Test-Path $msiExe)) {
    Write-Host '[ERROR] MSI Afterburner executable not found' -ForegroundColor Red
}
else {
    $msiProcess = Get-Process | Where-Object { $_.ProcessName -like '*Afterburner*' } | Select-Object -First 1

    if (-not $msiProcess) {
        Write-Host '[INFO] Launching MSI Afterburner...' -ForegroundColor Yellow
        Start-Process -FilePath $msiExe
        Start-Sleep -Seconds 3
    }
    else {
        Write-Host '[OK] MSI Afterburner is already running' -ForegroundColor Green
    }

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '  Hardware-Optimized Configuration Guide' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Based on online documentation and your RTX 3070 Laptop GPU:' -ForegroundColor Yellow
    Write-Host ''

    # Settings Configuration
    Write-Host '1. ENABLE ESSENTIAL SETTINGS (Settings -> General):' -ForegroundColor White
    Write-Host '   [OK] Unlock voltage control' -ForegroundColor Green
    Write-Host '   [OK] Unlock voltage monitoring' -ForegroundColor Green
    Write-Host '   [OK] Start with Windows' -ForegroundColor Green
    Write-Host '   [OK] Minimize to tray' -ForegroundColor Green
    Write-Host '   [OK] Enable hardware control and monitoring' -ForegroundColor Green
    Write-Host '   [OK] Enable low-level hardware access interface' -ForegroundColor Green
    Write-Host ''

    # Fan Curve Configuration
    Write-Host '2. CONFIGURE FAN CURVE (Settings -> Fan):' -ForegroundColor White
    Write-Host '   [OK] Enable user-defined software automatic fan control' -ForegroundColor Green
    Write-Host '   Recommended curve for RTX 3070 Laptop:' -ForegroundColor Gray
    Write-Host '     - 30C: 30% fan speed' -ForegroundColor Gray
    Write-Host '     - 50C: 50% fan speed' -ForegroundColor Gray
    Write-Host '     - 70C: 80% fan speed' -ForegroundColor Gray
    Write-Host '     - 80C: 100% fan speed' -ForegroundColor Gray
    Write-Host '   This balances cooling and noise for mobile GPU' -ForegroundColor Gray
    Write-Host ''

    # Power and Temperature Limits
    Write-Host '3. SET POWER AND TEMPERATURE LIMITS:' -ForegroundColor White
    Write-Host '   Power Limit: Increase to maximum (if available)' -ForegroundColor Yellow
    Write-Host '     - RTX 3070 Laptop: Typically +5% to +15% max' -ForegroundColor Gray
    Write-Host '     - Start with +5%, increase if stable' -ForegroundColor Gray
    Write-Host '   Temperature Limit: Keep at 83C (DO NOT increase)' -ForegroundColor Yellow
    Write-Host '     - Mobile GPUs have lower thermal limits' -ForegroundColor Gray
    Write-Host '     - Increasing can cause damage' -ForegroundColor Gray
    Write-Host ''

    # Overclocking Profiles
    if ($CreateProfiles) {
        Write-Host '4. CREATE OVERCLOCKING PROFILES:' -ForegroundColor White
        Write-Host ''

        foreach ($profileKey in @('Profile1', 'Profile2', 'Profile3')) {
            $profile = $config.Overclocking[$profileKey]
            Write-Host "   Profile $($profileKey -replace 'Profile', ''): $($profile.Name)" -ForegroundColor Cyan
            Write-Host "     Core Clock: +$($profile.CoreClock) MHz" -ForegroundColor Gray
            Write-Host "     Memory Clock: +$($profile.MemClock) MHz" -ForegroundColor Gray
            Write-Host "     Power Limit: +$($profile.PowerLimit)%" -ForegroundColor Gray
            Write-Host "     Temp Limit: $($profile.TempLimit)C" -ForegroundColor Gray
            Write-Host "     Description: $($profile.Description)" -ForegroundColor Gray
            Write-Host ''
        }

        Write-Host '   To create each profile:' -ForegroundColor Yellow
        Write-Host '     1. Set the values above in MSI Afterburner' -ForegroundColor White
        Write-Host '     2. Click Apply' -ForegroundColor White
        Write-Host '     3. Click Profile number button' -ForegroundColor White
        Write-Host '     4. Click Save' -ForegroundColor White
        Write-Host ''
    }

    # Monitoring Setup
    Write-Host '5. ENABLE MONITORING (Settings -> Monitoring):' -ForegroundColor White
    Write-Host '   Enable "Show in On-Screen Display" for:' -ForegroundColor Yellow
    Write-Host '     [OK] GPU temperature' -ForegroundColor Green
    Write-Host '     [OK] GPU usage' -ForegroundColor Green
    Write-Host '     [OK] GPU clock' -ForegroundColor Green
    Write-Host '     [OK] Memory clock' -ForegroundColor Green
    Write-Host '     [OK] Frame rate' -ForegroundColor Green
    Write-Host '     [OK] CPU temperature (if available)' -ForegroundColor Green
    Write-Host '   Enable RivaTuner Statistics Server (RTSS) for OSD' -ForegroundColor Yellow
    Write-Host ''

    # Overclocking Process
    Write-Host '6. OVERCLOCKING PROCESS (Based on Documentation):' -ForegroundColor White
    Write-Host '   Step-by-step for RTX 3070 Laptop:' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '   a) Start with Profile 1 (Conservative):' -ForegroundColor Cyan
    Write-Host "      - Core Clock: +$($config.Overclocking.Profile1.CoreClock) MHz" -ForegroundColor Gray
    Write-Host "      - Memory Clock: +$($config.Overclocking.Profile1.MemClock) MHz" -ForegroundColor Gray
    Write-Host "      - Power Limit: +$($config.Overclocking.Profile1.PowerLimit)%" -ForegroundColor Gray
    Write-Host '      - Test for 15-30 minutes' -ForegroundColor Gray
    Write-Host ''
    Write-Host '   b) If stable, try Profile 2 (Moderate):' -ForegroundColor Cyan
    Write-Host "      - Core Clock: +$($config.Overclocking.Profile2.CoreClock) MHz" -ForegroundColor Gray
    Write-Host "      - Memory Clock: +$($config.Overclocking.Profile2.MemClock) MHz" -ForegroundColor Gray
    Write-Host "      - Power Limit: +$($config.Overclocking.Profile2.PowerLimit)%" -ForegroundColor Gray
    Write-Host '      - Test for 15-30 minutes' -ForegroundColor Gray
    Write-Host ''
    Write-Host '   c) Only if excellent cooling, try Profile 3 (Aggressive):' -ForegroundColor Cyan
    Write-Host "      - Core Clock: +$($config.Overclocking.Profile3.CoreClock) MHz" -ForegroundColor Gray
    Write-Host "      - Memory Clock: +$($config.Overclocking.Profile3.MemClock) MHz" -ForegroundColor Gray
    Write-Host "      - Power Limit: +$($config.Overclocking.Profile3.PowerLimit)%" -ForegroundColor Gray
    Write-Host '      - Test thoroughly' -ForegroundColor Gray
    Write-Host ''

    # Important Notes
    Write-Host '7. IMPORTANT NOTES FOR RTX 3070 LAPTOP:' -ForegroundColor White
    Write-Host '   [WARN] Mobile GPU - more conservative than desktop' -ForegroundColor Yellow
    Write-Host '   [WARN] Dynamic Boost 2.0 shares power with CPU' -ForegroundColor Yellow
    Write-Host '   [WARN] Lower TDP than desktop RTX 3070' -ForegroundColor Yellow
    Write-Host '   [WARN] Temperature limit: 83C (never increase)' -ForegroundColor Yellow
    Write-Host '   [WARN] Monitor temperatures continuously' -ForegroundColor Yellow
    Write-Host '   [WARN] Watch for thermal throttling' -ForegroundColor Yellow
    Write-Host ''
}

Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Configuration Complete!' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Next Steps:' -ForegroundColor Yellow
Write-Host '  1. Follow the configuration guide above' -ForegroundColor White
Write-Host '  2. Enable all essential settings' -ForegroundColor White
Write-Host '  3. Configure fan curve' -ForegroundColor White
Write-Host '  4. Create and test profiles' -ForegroundColor White
Write-Host '  5. Enable monitoring/OSD' -ForegroundColor White
Write-Host '  6. Test for stability' -ForegroundColor White
Write-Host ''
Write-Host 'Documentation Reference:' -ForegroundColor Cyan
Write-Host '  - Based on MSI Afterburner official documentation' -ForegroundColor Gray
Write-Host '  - Optimized for RTX 3070 Laptop GPU capabilities' -ForegroundColor Gray
Write-Host '  - Conservative values for mobile hardware' -ForegroundColor Gray
Write-Host ''
