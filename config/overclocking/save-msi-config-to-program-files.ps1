# Save MSI Afterburner config to Program Files location
# This script requires administrator privileges

$ErrorActionPreference = "Stop"

$sourceFile = "D:\DevOptimizer\MSIAfterburner.cfg"
$targetFile = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.cfg"
$targetDir = "C:\Program Files (x86)\MSI Afterburner"

Write-Host ""
Write-Host "=== Save MSI Afterburner Config ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[ERROR] This script requires administrator privileges" -ForegroundColor Red
    Write-Host ""
    Write-Host "To run this script:" -ForegroundColor Yellow
    Write-Host "  1. Right-click PowerShell" -ForegroundColor White
    Write-Host "  2. Select 'Run as Administrator'" -ForegroundColor White
    Write-Host "  3. Navigate to: D:\DevOptimizer\config\overclocking" -ForegroundColor White
    Write-Host "  4. Run: .\save-msi-config-to-program-files.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Or use the batch file: save-msi-config.bat" -ForegroundColor Gray
    exit 1
}

# Check if source file exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "[ERROR] Source file not found: $sourceFile" -ForegroundColor Red
    exit 1
}

# Check if target directory exists
if (-not (Test-Path $targetDir)) {
    Write-Host "[ERROR] Target directory not found: $targetDir" -ForegroundColor Red
    exit 1
}

# Create backup of original file
if (Test-Path $targetFile) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFile = "$targetFile.backup_$timestamp"

    try {
        Copy-Item $targetFile -Destination $backupFile -Force
        Write-Host "[OK] Backup created: $backupFile" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Could not create backup: $_" -ForegroundColor Yellow
    }
}

# Copy the file
try {
    Copy-Item $sourceFile -Destination $targetFile -Force
    Write-Host "[OK] Config file saved successfully!" -ForegroundColor Green
    Write-Host "  Source: $sourceFile" -ForegroundColor Gray
    Write-Host "  Target: $targetFile" -ForegroundColor Gray
    Write-Host ""
    Write-Host "You may need to restart MSI Afterburner for changes to take effect" -ForegroundColor Yellow
} catch {
    Write-Host "[ERROR] Failed to save config file: $_" -ForegroundColor Red
    exit 1
}
