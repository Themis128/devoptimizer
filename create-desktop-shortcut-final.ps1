# Create DevOptimizer Desktop Shortcut - Final Version
# Run this script as Administrator for Public Desktop, or normal for User Desktop

$scriptPath = "D:\DevOptimizer\devoptimizer.ps1"
$batchPath = "D:\DevOptimizer\DevOptimizer.bat"

# Get the actual desktop path
$desktop = [Environment]::GetFolderPath("Desktop")
Write-Host "Desktop path: $desktop" -ForegroundColor Cyan

# Create the batch launcher on desktop
$desktopBatch = Join-Path $desktop "DevOptimizer.bat"
$batchContent = '@echo off
powershell.exe -ExecutionPolicy Bypass -File "D:\DevOptimizer\devoptimizer.ps1" -Menu %*'
[IO.File]::WriteAllText($desktopBatch, $batchContent)
Write-Host "Created desktop launcher: $desktopBatch" -ForegroundColor Green

# Create a proper .lnk shortcut using WScript.Shell
try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcutPath = Join-Path $desktop "DevOptimizer.lnk"
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "cmd.exe"
    $shortcut.Arguments = "/c `"$desktopBatch`""
    $shortcut.WorkingDirectory = "D:\DevOptimizer"
    $shortcut.Description = "DevOptimizer Script Hub - Unified CLI"
    $shortcut.IconLocation = "C:\Windows\System32\shell32.dll,0"
    $shortcut.Save()
    Write-Host "Created desktop shortcut: $shortcutPath" -ForegroundColor Green
} catch {
    $err = $_.Exception.Message
    Write-Warning "Could not create .lnk shortcut: $err"
    Write-Host "The .bat file on desktop will work as a launcher." -ForegroundColor Yellow
}

# Also create Start Menu shortcut if possible
$startMenu = [Environment]::GetFolderPath("CommonPrograms")
if (Test-Path $startMenu) {
    try {
        $shell = New-Object -ComObject WScript.Shell
        $startMenuPath = Join-Path $startMenu "DevOptimizer.lnk"
        $shortcut = $shell.CreateShortcut($startMenuPath)
        $shortcut.TargetPath = "cmd.exe"
        $shortcut.Arguments = "/c `"$batchPath`""
        $shortcut.WorkingDirectory = "D:\DevOptimizer"
        $shortcut.Description = "DevOptimizer Script Hub - Unified CLI"
        $shortcut.IconLocation = "C:\Windows\System32\shell32.dll,0"
        $shortcut.Save()
        Write-Host "Created Start Menu shortcut: $startMenuPath" -ForegroundColor Green
    } catch {
        $err = $_.Exception.Message
        Write-Warning "Could not create Start Menu shortcut (need admin): $err"
    }
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "DevOptimizer is now accessible from:" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "1. Desktop: DevOptimizer.bat (double-click to launch)" -ForegroundColor White
Write-Host "2. Desktop: DevOptimizer.lnk (if created successfully)" -ForegroundColor White
Write-Host "3. Start Menu: DevOptimizer (if admin)" -ForegroundColor White
Write-Host "4. Command line: devoptimizer.ps1 -Menu (from D:\DevOptimizer)" -ForegroundColor White
Write-Host ""
Write-Host "To add D:\DevOptimizer to PATH permanently:" -ForegroundColor Yellow
Write-Host '  Run PowerShell as Admin and execute:' -ForegroundColor White
Write-Host '  [Environment]::SetEnvironmentVariable("Path", $env:Path + ";D:\DevOptimizer", "Machine")' -ForegroundColor White