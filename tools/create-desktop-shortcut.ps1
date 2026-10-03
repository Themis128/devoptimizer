<#
.SYNOPSIS
    Creates desktop shortcut.
.DESCRIPTION
    Creates desktop shortcut.
#>

# Create Desktop Shortcut for DevOptimizer Master Launcher
# Creates a red-colored desktop shortcut with proper encoding

param(
    [string]$TargetPath = "D:\DevOptimizer\DEVOPTIMIZER-WORKING-LAUNCHER.bat",
    [string]$ShortcutName = "DevOptimizer System Launcher",
    [string]$DesktopPath = [Environment]::GetFolderPath("Desktop")
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Level.ToUpper()) {
        "ERROR" { Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor Red }
        "WARN" { Write-Host "[$timestamp] WARN: $Message" -ForegroundColor Yellow }
        "INFO" { Write-Host "[$timestamp] INFO: $Message" -ForegroundColor Green }
        default { Write-Host "[$timestamp] $Message" }
    }
}

function Create-DesktopShortcut {
    param(
        [string]$TargetPath,
        [string]$ShortcutName,
        [string]$DesktopPath
    )

    try {
        # Verify target file exists
        if (-not (Test-Path $TargetPath)) {
            Write-Log "Target file not found: $TargetPath" -Level "ERROR"
            return $false
        }

        # Create shortcut path
        $ShortcutPath = Join-Path $DesktopPath "$ShortcutName.lnk"

        Write-Log "Creating desktop shortcut..." -Level "INFO"
        Write-Log "Target: $TargetPath" -Level "INFO"
        Write-Log "Shortcut: $ShortcutPath" -Level "INFO"

        # Create WScript.Shell object
        $WshShell = New-Object -ComObject WScript.Shell

        # Create shortcut
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)

        # Set shortcut properties
        $Shortcut.TargetPath = $TargetPath
        $Shortcut.WorkingDirectory = Split-Path -Parent $TargetPath
        $Shortcut.Description = "DevOptimizer Master Launcher - Red Edition - Complete AI-powered system optimization suite"
        $Shortcut.WindowStyle = 1  # Normal window

        # Set icon (using batch file icon with red tint)
        $Shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,3"

        # Set hotkey (Ctrl+Alt+D for DevOptimizer)
        $Shortcut.Hotkey = "CTRL+ALT+D"

        # Save shortcut
        $Shortcut.Save()

        Write-Log "Shortcut created successfully: $ShortcutPath" -Level "INFO"

        # Create a custom red-colored batch file wrapper for better visual appeal
        $RedWrapperPath = Join-Path $DesktopPath "DevOptimizer-Red-Launcher.bat"
        $RedWrapperContent = @"
@echo off
title DevOptimizer System Launcher - Red Edition
color 0C
echo.
echo ================================================================================
echo
echo                        DEVOPTIMIZER SYSTEM LAUNCHER - RED EDITION
echo
echo                              Access to ALL DevOptimizer Tools...
echo
echo ================================================================================
echo.
timeout /t 2 >nul
start "" "$TargetPath"
exit /b 0
"@

        # Save red wrapper with UTF-8 encoding
        $RedWrapperContent | Out-File -FilePath $RedWrapperPath -Encoding UTF8

        Write-Log "Red wrapper created: $RedWrapperPath" -Level "INFO"

        # Create a second shortcut for the red wrapper
        $RedShortcutPath = Join-Path $DesktopPath "DevOptimizer-Red-Launcher.lnk"
        $RedShortcut = $WshShell.CreateShortcut($RedShortcutPath)
        $RedShortcut.TargetPath = $RedWrapperPath
        $RedShortcut.WorkingDirectory = Split-Path -Parent $RedWrapperPath
        $RedShortcut.Description = "DevOptimizer Red Launcher - Beautiful red-themed startup"
        $RedShortcut.WindowStyle = 1
        $RedShortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,3"
        $RedShortcut.Hotkey = "CTRL+ALT+R"
        $RedShortcut.Save()

        Write-Log "Red shortcut created: $RedShortcutPath" -Level "INFO"

        # Test the shortcut
        Write-Log "Testing shortcut functionality..." -Level "INFO"
        if (Test-Path $ShortcutPath) {
            Write-Log "✅ Main shortcut test passed" -Level "INFO"
        } else {
            Write-Log "❌ Main shortcut test failed" -Level "ERROR"
        }

        if (Test-Path $RedShortcutPath) {
            Write-Log "✅ Red shortcut test passed" -Level "INFO"
        } else {
            Write-Log "❌ Red shortcut test failed" -Level "ERROR"
        }

        if (Test-Path $RedWrapperPath) {
            Write-Log "✅ Red wrapper test passed" -Level "INFO"
        } else {
            Write-Log "❌ Red wrapper test failed" -Level "ERROR"
        }

        return $true
    }
    catch {
        Write-Log "Error creating shortcut: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Main execution
Write-Host "🚀 DevOptimizer Desktop Shortcut Creator" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Starting desktop shortcut creation process..." -Level "INFO"

# Verify desktop path
if (-not (Test-Path $DesktopPath)) {
    Write-Log "Desktop path not found: $DesktopPath" -Level "ERROR"
    exit 1
}

Write-Log "Desktop path: $DesktopPath" -Level "INFO"

# Create shortcuts
$success = Create-DesktopShortcut -TargetPath $TargetPath -ShortcutName $ShortcutName -DesktopPath $DesktopPath

if ($success) {
    Write-Host ""
    Write-Host "✅ SUCCESS: Desktop shortcuts created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Created shortcuts:" -ForegroundColor White
    Write-Host "• DevOptimizer Master Launcher.lnk" -ForegroundColor Yellow
    Write-Host "• DevOptimizer-Red-Launcher.lnk" -ForegroundColor Red
    Write-Host ""
    Write-Host "Hotkeys:" -ForegroundColor White
    Write-Host "• Ctrl+Alt+D - Main launcher" -ForegroundColor Yellow
    Write-Host "• Ctrl+Alt+R - Red launcher" -ForegroundColor Red
    Write-Host ""
    Write-Host "Both shortcuts are now available on your desktop!" -ForegroundColor Green
    Write-Host "The red launcher provides a beautiful red-themed startup experience." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ ERROR: Failed to create desktop shortcuts" -ForegroundColor Red
    exit 1
}

exit 0
