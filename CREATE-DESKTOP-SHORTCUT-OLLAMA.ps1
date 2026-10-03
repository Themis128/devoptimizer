# Create Desktop Shortcut for DevOptimizer with Ollama Integration
# Creates a shortcut on the user's desktop that launches the enhanced DevOptimizer system

param(
    [string]$DesktopPath = "C:\Users\baltz\OneDrive - University of Bolton\Desktop",
    [string]$TargetPath = "D:\DevOptimizer\DEVOPTIMIZER-HUB-VERBOSE-DESCRIPTIONS.bat",
    [string]$ShortcutName = "DevOptimizer AI Hub"
)

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "                    CREATING DEVOPTIMIZER DESKTOP SHORTCUT" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Verify target file exists
    if (-not (Test-Path $TargetPath)) {
        Write-Error "Target file not found: $TargetPath"
        exit 1
    }
    
    # Verify desktop directory exists
    if (-not (Test-Path $DesktopPath)) {
        Write-Warning "Desktop directory not found: $DesktopPath"
        Write-Host "Creating desktop directory..." -ForegroundColor Yellow
        New-Item -Path $DesktopPath -ItemType Directory -Force | Out-Null
    }
    
    # Create shortcut path
    $ShortcutPath = Join-Path $DesktopPath "$ShortcutName.lnk"
    
    Write-Host "[SHORTCUT] Creating shortcut..." -ForegroundColor Green
    Write-Host "  Target: $TargetPath" -ForegroundColor Cyan
    Write-Host "  Desktop: $DesktopPath" -ForegroundColor Cyan
    Write-Host "  Shortcut: $ShortcutPath" -ForegroundColor Cyan
    Write-Host ""
    
    # Create WScript.Shell object
    $WshShell = New-Object -ComObject WScript.Shell
    
    # Create shortcut object
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    
    # Set shortcut properties
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.WorkingDirectory = "D:\DevOptimizer"
    $Shortcut.Description = "DevOptimizer AI-Powered System Hub with Ollama Integration"
    $Shortcut.IconLocation = "D:\DevOptimizer\config\devoptimizer-icon.ico"
    
    # Set to run as administrator
    $Shortcut.Arguments = ""
    
    # Save the shortcut
    $Shortcut.Save()
    
    Write-Host "[SUCCESS] Desktop shortcut created successfully!" -ForegroundColor Green
    Write-Host "  Location: $ShortcutPath" -ForegroundColor Cyan
    Write-Host ""
    
    # Create additional properties for admin execution
    Write-Host "[SHORTCUT] Setting administrator privileges..." -ForegroundColor Yellow
    
    # Read the shortcut file as bytes
    $ShortcutBytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    
    # Modify the shortcut to run as administrator
    # This is done by setting specific bytes in the .lnk file
    $ShortcutBytes[0x15] = $ShortcutBytes[0x15] -bor 0x20  # Set the "Run as administrator" flag
    
    # Write the modified bytes back
    [System.IO.File]::WriteAllBytes($ShortcutPath, $ShortcutBytes)
    
    Write-Host "[SUCCESS] Administrator privileges set!" -ForegroundColor Green
    Write-Host ""
    
    # Verify shortcut was created
    if (Test-Path $ShortcutPath) {
        $ShortcutInfo = Get-Item $ShortcutPath
        Write-Host "[VERIFICATION] Shortcut verified:" -ForegroundColor Green
        Write-Host "  Name: $($ShortcutInfo.Name)" -ForegroundColor Cyan
        Write-Host "  Size: $($ShortcutInfo.Length) bytes" -ForegroundColor Cyan
        Write-Host "  Created: $($ShortcutInfo.CreationTime)" -ForegroundColor Cyan
        Write-Host "  Modified: $($ShortcutInfo.LastWriteTime)" -ForegroundColor Cyan
    } else {
        Write-Error "Shortcut verification failed - file not found"
        exit 1
    }
    
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Green
    Write-Host "                    SHORTCUT CREATION COMPLETE" -ForegroundColor Green
    Write-Host "===============================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[INFO] You can now double-click the '$ShortcutName' shortcut on your desktop" -ForegroundColor Cyan
    Write-Host "[INFO] to launch the DevOptimizer AI Hub with Ollama integration!" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[FEATURES] The shortcut includes:" -ForegroundColor Yellow
    Write-Host "  ✓ Administrator privileges" -ForegroundColor Green
    Write-Host "  ✓ Ollama AI integration" -ForegroundColor Green
    Write-Host "  ✓ Enhanced error handling" -ForegroundColor Green
    Write-Host "  ✓ Real-time code analysis" -ForegroundColor Green
    Write-Host "  ✓ Auto-fixing capabilities" -ForegroundColor Green
    Write-Host "  ✓ Comprehensive logging" -ForegroundColor Green
    Write-Host ""
    
} catch {
    Write-Error "Failed to create desktop shortcut: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    exit 1
}

Write-Host "[COMPLETE] Desktop shortcut creation process finished!" -ForegroundColor Green
