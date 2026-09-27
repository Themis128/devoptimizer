# Create DevOptimizer Desktop Shortcut
# This script creates a proper desktop shortcut

$scriptPath = "D:\DevOptimizer\devoptimizer.ps1"
$iconPath = "D:\DevOptimizer\icon.ico"

# Create icon if not exists
if (-not (Test-Path $iconPath)) {
    # Use a system icon as fallback
    $iconPath = "C:\Windows\System32\shell32.dll"
}

# Try user desktop first, then public desktop
$desktopPaths = @(
    [Environment]::GetFolderPath("Desktop"),
    [Environment]::GetFolderPath("CommonDesktopDirectory")
)

$shortcutCreated = $false

foreach ($desktop in $desktopPaths) {
    if ($desktop -and (Test-Path $desktop)) {
        $shortcutPath = Join-Path $desktop "DevOptimizer.lnk"
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = "powershell.exe"
            $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`" -Menu"
            $shortcut.WorkingDirectory = "D:\DevOptimizer"
            $shortcut.Description = "DevOptimizer Script Hub - Unified CLI"
            if ($iconPath) {
                $shortcut.IconLocation = "$iconPath,0"
            }
            $shortcut.Save()
            Write-Host "Desktop shortcut created at: $shortcutPath" -ForegroundColor Green
            $shortcutCreated = $true
            break
        } catch {
            $errMsg = $_.Exception.Message
            Write-Warning "Failed to create shortcut at ${shortcutPath}: $errMsg"
        }
    }
}

if (-not $shortcutCreated) {
    Write-Error "Could not create desktop shortcut on any available desktop"
    # Create a .bat file on the user desktop as fallback
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ($desktop -and (Test-Path $desktop)) {
        $batPath = Join-Path $desktop "DevOptimizer.bat"
        $batContent = '@echo off
	if "%~1"=="" (
	    powershell.exe -ExecutionPolicy Bypass -File "D:\DevOptimizer\devoptimizer.ps1" -Menu
	) else (
	    powershell.exe -ExecutionPolicy Bypass -File "D:\DevOptimizer\devoptimizer.ps1" %*
	)'
        [IO.File]::WriteAllText($batPath, $batContent)
        Write-Host "Created batch file on desktop as fallback: $batPath" -ForegroundColor Yellow
    } else {
        Write-Error "No desktop directory found"
    }
    # Do not exit here; continue to try Start Menu shortcut
}

# Also create a batch wrapper for convenience
	$batchPath = Join-Path (Split-Path $scriptPath -Parent) "DevOptimizer.bat"
	$batchContent = '@echo off
	if "%~1"=="" (
	    powershell.exe -ExecutionPolicy Bypass -File "D:\DevOptimizer\devoptimizer.ps1" -Menu
	) else (
	    powershell.exe -ExecutionPolicy Bypass -File "D:\DevOptimizer\devoptimizer.ps1" %*
	)'
	[IO.File]::WriteAllText($batchPath, $batchContent)
	Write-Host "Batch wrapper created at: $batchPath" -ForegroundColor Green

# Create Start Menu shortcut too
$startMenu = [Environment]::GetFolderPath("CommonPrograms")
if (Test-Path $startMenu) {
    $startMenuPath = Join-Path $startMenu "DevOptimizer.lnk"
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startMenuPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`" -Menu"
        $shortcut.WorkingDirectory = "D:\DevOptimizer"
        $shortcut.Description = "DevOptimizer Script Hub - Unified CLI"
        if ($iconPath) {
            $shortcut.IconLocation = "$iconPath,0"
        }
        $shortcut.Save()
        Write-Host "Start Menu shortcut created at: $startMenuPath" -ForegroundColor Green
    } catch {
        $errMsg = $_.Exception.Message
        Write-Warning "Failed to create Start Menu shortcut: $errMsg"
    }
}

Write-Host ""
Write-Host "DevOptimizer is now accessible from:" -ForegroundColor Cyan
Write-Host "  - Desktop: DevOptimizer.lnk" -ForegroundColor White
Write-Host "  - Start Menu: DevOptimizer" -ForegroundColor White
Write-Host "  - Command line: DevOptimizer.bat (in D:\DevOptimizer)" -ForegroundColor White
Write-Host ""
Write-Host "To add to PATH, run this in PowerShell as Admin:" -ForegroundColor Yellow
Write-Host '  [Environment]::SetEnvironmentVariable("Path", $env:Path + ";D:\DevOptimizer", "Machine")' -ForegroundColor White