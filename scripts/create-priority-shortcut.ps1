<#
.SYNOPSIS
    Create a startup shortcut to run Devin priority adjustment at logon

.DESCRIPTION
    Creates a shortcut in the user's Startup folder that runs the
    lower-devin-priority.ps1 script in loop mode. This doesn't require
    admin privileges and runs as the current user.
#>

param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$scriptPath = 'D:\DevOptimizer\scripts\lower-devin-priority.ps1'
$shortcutName = 'Devin-Lower-Priority.lnk'
$startupPath = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupPath $shortcutName

if (-not (Test-Path $scriptPath)) {
    Write-Error "Script not found: $scriptPath"
    exit 1
}

$exists = Test-Path $shortcutPath
if ($exists -and -not $Force) {
    Write-Host "Shortcut already exists at: $shortcutPath" -ForegroundColor Yellow
    Write-Host "Use -Force to recreate" -ForegroundColor Yellow
    exit 0
}

# Create shortcut using COM
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = 'powershell.exe'
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Loop -Interval 30"
$shortcut.WorkingDirectory = 'D:\DevOptimizer\scripts'
$shortcut.Description = 'Lower Devin Desktop process priority to BelowNormal'
$shortcut.IconLocation = 'powershell.exe,0'
$shortcut.Save()

Write-Host "Created startup shortcut: $shortcutPath" -ForegroundColor Green
Write-Host "Will run at user logon, checking Devin priority every 30 seconds" -ForegroundColor Cyan