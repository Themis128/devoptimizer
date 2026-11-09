$targets = @(
    'D:\DevOptimizer\backups\nas-staging\20261103-0430',
    'D:\DevOptimizer\backups\nas-staging\20261104-0430',
    'D:\DevOptimizer\backups\nas-staging\20261105-0430',
    'D:\DevOptimizer\backups\nas-staging\20261106-0430',
    'D:\DevOptimizer\backups\nas-staging\20261107-0430',
    'D:\uv-cache',
    'D:\.pnpm-store',
    'D:\Temp',
    'D:\tmp',
    'D:\DevOptimizer\Temp',
    'D:\DevOptimizer\tmp'
)
$totalFreed = 0
foreach ($target in $targets) {
    if (Test-Path $target) {
        $sizeBytes = (Get-ChildItem $target -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
        if ($sizeBytes -gt 0) {
            Write-Host "Removing $target ($sizeMB MB)..." -ForegroundColor Yellow
            Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue
            $totalFreed += $sizeBytes
        } else {
            Write-Host "Skipping $target (already empty)" -ForegroundColor Gray
        }
    } else {
        Write-Host "Skipping $target (does not exist)" -ForegroundColor Gray
    }
}
$totalFreedGB = [math]::Round($totalFreed / 1GB, 2)
Write-Host "Total freed: $totalFreedGB GB" -ForegroundColor Green