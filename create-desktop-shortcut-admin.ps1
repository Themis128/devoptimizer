# Create Admin Desktop Shortcut for DevOptimizer Hub
$devOptimizerPath = "D:\DevOptimizer"
$hubLauncherPath = "$devOptimizerPath\DEVOPTIMIZER-HUB.bat"
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktopPath\DevOptimizer BAT Hub (Admin).lnk"

Write-Host "Creating Admin Desktop Shortcut for DevOptimizer Hub..." -ForegroundColor Cyan

# Check if the hub launcher exists
if (-not (Test-Path $hubLauncherPath)) {
    Write-Host "ERROR: Hub launcher not found at: $hubLauncherPath" -ForegroundColor Red
    exit 1
}

try {
    # Create WScript.Shell object
    $shell = New-Object -ComObject WScript.Shell

    # Create shortcut
    $shortcut = $shell.CreateShortcut($shortcutPath)

    # Set shortcut properties
    $shortcut.TargetPath = $hubLauncherPath
    $shortcut.WorkingDirectory = $devOptimizerPath
    $shortcut.Description = "DevOptimizer BAT Hub - Auto-detecting launcher with admin privileges"
    $shortcut.IconLocation = "shell32.dll,1"  # Admin shield icon

    # Set to run as administrator
    $shortcut.Save()

    # Use PowerShell to modify the shortcut to run as administrator
    $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20  # Set the bit flag for "Run as Administrator"
    [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)

    Write-Host "SUCCESS: Admin desktop shortcut created!" -ForegroundColor Green
    Write-Host "Shortcut location: $shortcutPath" -ForegroundColor White
    Write-Host "Target: $hubLauncherPath" -ForegroundColor White
    Write-Host "Working Directory: $devOptimizerPath" -ForegroundColor White
    Write-Host "Admin privileges: ENABLED" -ForegroundColor Yellow

} catch {
    Write-Host "ERROR: Failed to create shortcut: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nDesktop shortcut created successfully!" -ForegroundColor Green
Write-Host "You can now access your DevOptimizer BAT Hub from the desktop." -ForegroundColor White
