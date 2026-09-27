$desktop = [Environment]::GetFolderPath('Desktop')
$source = 'D:\DevOptimizer\DevOptimizer-Menu.bat'
$dest = Join-Path $desktop 'DevOptimizer-Menu.bat'

try {
    Copy-Item -Path $source -Destination $dest -Force
    Write-Host "Success! Menu file copied to: $dest" -ForegroundColor Green

    # Also try Public Desktop
    $publicDesktop = 'C:\Users\Public\Desktop'
    if (Test-Path $publicDesktop) {
        try {
            Copy-Item -Path $source -Destination (Join-Path $publicDesktop 'DevOptimizer-Menu.bat') -Force -ErrorAction Stop
            Write-Host "Also copied to Public Desktop: $publicDesktop" -ForegroundColor Green
        } catch {
            Write-Host "Could not copy to Public Desktop (may require admin): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run this script as Administrator or copy manually." -ForegroundColor Yellow
}
