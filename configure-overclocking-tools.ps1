# Configure Overclocking Tools Script
# This script configures MSI Afterburner and Intel XTU with optimal settings

Write-Host "=== Overclocking Tools Configuration Script ===" -ForegroundColor Cyan
Write-Host ""

# Check if tools are installed
$msiAfterburner = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like "*MSI Afterburner*" -or $_.DisplayName -like "*Afterburner*" }
$intelXTU = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like "*Intel XTU*" -or $_.DisplayName -like "*Extreme Tuning Utility*" }

$msiInstalled = $msiAfterburner -ne $null
$xtuInstalled = $intelXTU -ne $null

Write-Host "Installation Status:" -ForegroundColor Yellow
if ($msiInstalled) {
    Write-Host "  ✓ MSI Afterburner: Installed (Version: $($msiAfterburner.DisplayVersion))" -ForegroundColor Green
} else {
    Write-Host "  ✗ MSI Afterburner: Not installed" -ForegroundColor Red
}

if ($xtuInstalled) {
    Write-Host "  ✓ Intel XTU: Installed (Version: $($intelXTU.DisplayVersion))" -ForegroundColor Green
} else {
    Write-Host "  ✗ Intel XTU: Not installed" -ForegroundColor Red
}

Write-Host ""

if (-not $msiInstalled -or -not $xtuInstalled) {
    Write-Host "Please install the missing tools first by running:" -ForegroundColor Yellow
    Write-Host "  install-overclocking-tools.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "=== Configuration Recommendations ===" -ForegroundColor Cyan
Write-Host ""

# MSI Afterburner Configuration
Write-Host "MSI Afterburner Configuration:" -ForegroundColor Yellow
Write-Host "1. Launch MSI Afterburner" -ForegroundColor White
Write-Host "2. Recommended Settings:" -ForegroundColor White
Write-Host "   - Enable 'Unlock Voltage Control' in settings (if available)" -ForegroundColor Gray
Write-Host "   - Enable 'Unlock Voltage Monitoring' in settings" -ForegroundColor Gray
Write-Host "   - Set Power Limit to maximum (if supported by your GPU)" -ForegroundColor Gray
Write-Host "   - Enable 'Apply overclocking at system startup'" -ForegroundColor Gray
Write-Host "   - Enable 'Start with Windows' (optional)" -ForegroundColor Gray
Write-Host "   - Enable 'Minimize to tray'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Overclocking Guidelines:" -ForegroundColor White
Write-Host "   - Start with small increments (+10-20 MHz core clock)" -ForegroundColor Gray
Write-Host "   - Test stability with each change" -ForegroundColor Gray
Write-Host "   - Monitor temperatures (keep below 83°C)" -ForegroundColor Gray
Write-Host "   - Increase memory clock separately from core clock" -ForegroundColor Gray
Write-Host ""

# Intel XTU Configuration
Write-Host "Intel XTU Configuration:" -ForegroundColor Yellow
Write-Host "1. Launch Intel XTU" -ForegroundColor White
Write-Host "2. Recommended Settings for i9-12900H:" -ForegroundColor White
Write-Host "   - Note: i9-12900H is a mobile processor with limited overclocking" -ForegroundColor Gray
Write-Host "   - Focus on optimizing power limits and thermal management" -ForegroundColor Gray
Write-Host "   - Adjust 'Turbo Boost Power Max' if available" -ForegroundColor Gray
Write-Host "   - Monitor 'Core Temperature' and 'Package Temperature'" -ForegroundColor Gray
Write-Host "   - Use 'Stress Test' feature to verify stability" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Important Notes:" -ForegroundColor White
Write-Host "   - Mobile CPUs (H-series) have limited overclocking capability" -ForegroundColor Yellow
Write-Host "   - Focus on power management and thermal optimization" -ForegroundColor Yellow
Write-Host "   - Ensure adequate cooling before making changes" -ForegroundColor Yellow
Write-Host "   - Always test stability after changes" -ForegroundColor Yellow
Write-Host ""

# Create configuration files location
$configDir = Join-Path $PSScriptRoot "config\overclocking"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

# Create a settings template
$settingsTemplate = @"
# Overclocking Tools Configuration Template
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## MSI Afterburner Settings
# Location: %ProgramFiles(x86)%\MSI Afterburner\MSIAfterburner.cfg
# Or: %AppData%\MSI Afterburner\MSIAfterburner.cfg

## Intel XTU Settings
# Location: %ProgramData%\Intel\Intel Extreme Tuning Utility\
# Settings are stored in registry and application database

## Recommended Monitoring
- GPU Temperature: Keep below 83°C under load
- CPU Temperature: Keep below 90°C under load
- Power Consumption: Monitor for stability
- Clock Speeds: Monitor for throttling

## Safety Guidelines
1. Make incremental changes
2. Test stability after each change
3. Monitor temperatures continuously
4. Keep backups of stable configurations
5. Know how to reset to defaults
"@

$templatePath = Join-Path $configDir "settings-template.txt"
$settingsTemplate | Out-File -FilePath $templatePath -Encoding UTF8
Write-Host "Created configuration template: $templatePath" -ForegroundColor Green
Write-Host ""

# Try to launch the applications
Write-Host "Would you like to launch the applications now? (Y/N)" -ForegroundColor Cyan
$response = Read-Host

if ($response -eq 'Y' -or $response -eq 'y') {
    # Try to find and launch MSI Afterburner
    $msiPaths = @(
        "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe",
        "${env:ProgramFiles}\MSI Afterburner\MSIAfterburner.exe",
        "$env:LOCALAPPDATA\MSI Afterburner\MSIAfterburner.exe"
    )
    
    foreach ($path in $msiPaths) {
        if (Test-Path $path) {
            Write-Host "Launching MSI Afterburner..." -ForegroundColor Green
            Start-Process $path
            break
        }
    }
    
    # Try to find and launch Intel XTU
    $xtuPaths = @(
        "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe",
        "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTU.exe"
    )
    
    foreach ($path in $xtuPaths) {
        if (Test-Path $path) {
            Write-Host "Launching Intel XTU..." -ForegroundColor Green
            Start-Process $path
            break
        }
    }
}

Write-Host ""
Write-Host "Configuration guide complete!" -ForegroundColor Green
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

