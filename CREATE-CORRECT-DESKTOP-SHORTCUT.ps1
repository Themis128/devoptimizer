# ========================================================================
#                    CREATE CORRECT DESKTOP SHORTCUT
#                    Points to DEVOPTIMIZER-HUB-VERBOSE-DESCRIPTIONS.bat
# ========================================================================

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "                    CREATE CORRECT DESKTOP SHORTCUT" -ForegroundColor Cyan
Write-Host "                    Points to Verbose Descriptions Hub" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""

# Set up paths
$devOptimizerPath = "D:\DevOptimizer"
$targetFile = Join-Path $devOptimizerPath "DEVOPTIMIZER-HUB-VERBOSE-DESCRIPTIONS.bat"
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "DevOptimizer BAT Hub (Verbose).lnk"

Write-Host "[STATUS] Creating desktop shortcut..." -ForegroundColor Green
Write-Host "[INFO] Target: $targetFile" -ForegroundColor Yellow
Write-Host "[INFO] Shortcut: $shortcutPath" -ForegroundColor Yellow
Write-Host ""

# Check if target file exists
if (-not (Test-Path $targetFile)) {
    Write-Host "[ERROR] Target file not found: $targetFile" -ForegroundColor Red
    Write-Host "[INFO] Please ensure the verbose descriptions hub file exists" -ForegroundColor Yellow
    exit 1
}

Write-Host "[SUCCESS] Target file found: $targetFile" -ForegroundColor Green

# Create the shortcut
try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)

    # Set shortcut properties
    $shortcut.TargetPath = $targetFile
    $shortcut.WorkingDirectory = $devOptimizerPath
    $shortcut.Description = "DevOptimizer BAT Hub with Verbose Descriptions - Enhanced launcher with detailed tool descriptions"
    $shortcut.IconLocation = "%SystemRoot%\System32\shell32.dll,257"  # Admin shield icon

    # Save the shortcut
    $shortcut.Save()

    Write-Host "[SUCCESS] Desktop shortcut created successfully!" -ForegroundColor Green
    Write-Host ""

    # Set 'Run as administrator' property
    Write-Host "[STATUS] Setting administrator privileges..." -ForegroundColor Cyan
    $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20  # Set the 32nd bit (run as admin)
    [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)

    Write-Host "[SUCCESS] Administrator privileges enabled!" -ForegroundColor Green
    Write-Host ""

    # Display shortcut information
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host "                    SHORTCUT CREATED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[SHORTCUT DETAILS]" -ForegroundColor White
    Write-Host "  - Name: DevOptimizer BAT Hub (Verbose)" -ForegroundColor Yellow
    Write-Host "  - Location: $desktopPath" -ForegroundColor Gray
    Write-Host "  - Target: $targetFile" -ForegroundColor Gray
    Write-Host "  - Working Directory: $devOptimizerPath" -ForegroundColor Gray
    Write-Host "  - Admin Privileges: ENABLED" -ForegroundColor Green
    Write-Host "  - Description: Enhanced launcher with verbose tool descriptions" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[FEATURES]" -ForegroundColor White
    Write-Host "  - Verbose descriptions for all 116+ BAT tools" -ForegroundColor Cyan
    Write-Host "  - Categorized organization (Ollama, Cursor AI, M365, System, etc.)" -ForegroundColor Cyan
    Write-Host "  - System status checking" -ForegroundColor Cyan
    Write-Host "  - Auto-detection of all BAT files" -ForegroundColor Cyan
    Write-Host "  - Administrator privileges for system tools" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[SUCCESS] You can now access your DevOptimizer BAT Hub from the desktop!" -ForegroundColor Green
    Write-Host "[INFO] The shortcut will launch the verbose descriptions version" -ForegroundColor Yellow
    Write-Host "[INFO] All duplicate files have been cleaned up" -ForegroundColor Yellow
    Write-Host ""

} catch {
    Write-Host "[ERROR] Failed to create shortcut: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
