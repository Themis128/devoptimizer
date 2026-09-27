# Script to save MSI Afterburner config with admin privileges
# This script must be run as Administrator

$sourceFile = "D:\DevOptimizer\MSIAfterburner.cfg"
$targetFile = "c:\Program Files (x86)\MSI Afterburner\MSIAfterburner.cfg"
$targetDir = "c:\Program Files (x86)\MSI Afterburner"

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
    exit 1
}

# Check if source file exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "Source file not found: $sourceFile" -ForegroundColor Red
    exit 1
}

# Create backup of original file
if (Test-Path $targetFile) {
    $backupFile = "$targetFile.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $targetFile -Destination $backupFile
    Write-Host "Backup created: $backupFile" -ForegroundColor Green
}

# Copy the file
try {
    Copy-Item $sourceFile -Destination $targetFile -Force
    Write-Host "Successfully saved MSI Afterburner config!" -ForegroundColor Green
} catch {
    Write-Host "Error copying file: $_" -ForegroundColor Red
    exit 1
}

