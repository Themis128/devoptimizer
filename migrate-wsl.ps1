# WSL Ubuntu-24.04 Migration Script
# Moves Ubuntu-24.04 from E:\WSL to C:\WSL (72 GB free on C:)

$ErrorActionPreference = "Stop"

Write-Host "=== WSL Ubuntu-24.04 Migration from E: to C: ===" -ForegroundColor Cyan

# 1. Shutdown WSL
Write-Host "`n1. Shutting down WSL..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 3

# 2. Verify stopped
Write-Host "`n2. Verifying distributions are stopped..." -ForegroundColor Yellow
$distros = wsl -l -v
Write-Host $distros

# 3. Export Ubuntu-24.04 to tar
$exportPath = "C:\WSL\Ubuntu-24.04-export.tar"
$exportDir = "C:\WSL"
if (-not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

Write-Host "`n3. Exporting Ubuntu-24.04 to $exportPath..." -ForegroundColor Yellow
Write-Host "This may take several minutes for 35GB..." -ForegroundColor Gray
$startTime = Get-Date
wsl --export Ubuntu-24.04 $exportPath
$elapsed = (Get-Date) - $startTime
Write-Host "Export completed in $([math]::Round($elapsed.TotalMinutes, 1)) minutes" -ForegroundColor Green

# 4. Unregister the old distribution
Write-Host "`n4. Unregistering old Ubuntu-24.04 from E:..." -ForegroundColor Yellow
wsl --unregister Ubuntu-24.04

# 5. Import to new location on C:
$importPath = "C:\WSL\Ubuntu-24.04"
Write-Host "`n5. Importing Ubuntu-24.04 to $importPath..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray
$startTime = Get-Date
wsl --import Ubuntu-24.04 $importPath $exportPath --version 2
$elapsed = (Get-Date) - $startTime
Write-Host "Import completed in $([math]::Round($elapsed.TotalMinutes, 1)) minutes" -ForegroundColor Green

# 6. Clean up export file
Write-Host "`n6. Cleaning up export file..." -ForegroundColor Yellow
Remove-Item $exportPath -Force -ErrorAction SilentlyContinue
Write-Host "Export file removed" -ForegroundColor Green

# 7. Verify new installation
Write-Host "`n7. Verifying new installation..." -ForegroundColor Yellow
wsl -l -v

# 8. Start the distribution
Write-Host "`n8. Starting Ubuntu-24.04..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -e whoami

Write-Host "`n=== Migration Complete ===" -ForegroundColor Cyan
Write-Host "Ubuntu-24.04 is now on C:\WSL\Ubuntu-24.04" -ForegroundColor Green
Write-Host "E:\WSL\Ubuntu-24.04 can be manually removed if desired" -ForegroundColor Gray