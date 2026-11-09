$targets = @(
    @{ Path = 'D:\gdrive'; Description = 'Google Takeout ZIPs (Aug/Nov 2024)' },
    @{ Path = 'D:\tabby\models\TabbyML'; Description = 'Local LLM models (May 2026)' },
    @{ Path = 'D:\eset'; Description = 'ESET installer (Oct 2024)' }
)

$totalFreed = 0
Write-Host "=== Cleaning Stale D Drive Folders (inactive >2 months) ===" -ForegroundColor Cyan
Write-Host ""

foreach ($target in $targets) {
    if (Test-Path $target.Path) {
        $sizeBytes = (Get-ChildItem $target.Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $sizeGB = [math]::Round($sizeBytes / 1GB, 2)
        
        if ($sizeBytes -gt 0) {
            Write-Host "Removing $($target.Path) ($sizeGB GB) - $($target.Description)..." -ForegroundColor Yellow
            Remove-Item $target.Path -Recurse -Force -ErrorAction SilentlyContinue
            $totalFreed += $sizeBytes
            Write-Host "  Done." -ForegroundColor Green
        } else {
            Write-Host "Skipping $($target.Path) (already empty)" -ForegroundColor Gray
        }
    } else {
        Write-Host "Skipping $($target.Path) (does not exist)" -ForegroundColor Gray
    }
}

$totalFreedGB = [math]::Round($totalFreed / 1GB, 2)
Write-Host ""
Write-Host "Total freed: $totalFreedGB GB" -ForegroundColor Green

# Verify remaining space
$drive = Get-PSDrive D
$freeGB = [math]::Round($drive.Free / 1GB, 2)
$usedGB = [math]::Round($drive.Used / 1GB, 2)
Write-Host "D: Free: $freeGB GB, Used: $usedGB GB" -ForegroundColor Cyan