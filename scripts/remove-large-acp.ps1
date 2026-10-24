$acpDir = Join-Path $env:APPDATA 'devin\User\acp-messages'
$largeFiles = @(
    'a3b876c1-e098-4649-811f-eccac5e74217.db',    # 388.8 MB - over 256 MB threshold
    '5e1ee798-b1d3-4252-9735-fe38ba1d02c9.db',    # 157.9 MB - large
    '23d592af-c68d-4e0a-877d-06866aabdd1f.db'     # 69.7 MB - large
)
$deleted = 0
$freed = 0
foreach ($name in $largeFiles) {
    $path = Join-Path $acpDir $name
    if (Test-Path $path) {
        $size = (Get-Item $path).Length
        Write-Host "Deleting large DB: $name ($([math]::Round($size/1MB,1)) MB)"
        Remove-Item -LiteralPath $path -Force
        # Also remove associated shm/wal
        $shm = $path -replace '\.db$', '.db-shm'
        $wal = $path -replace '\.db$', '.db-wal'
        if (Test-Path $shm) { Remove-Item -LiteralPath $shm -Force }
        if (Test-Path $wal) { Remove-Item -LiteralPath $wal -Force }
        $deleted++
        $freed += $size
    }
}
Write-Host "Deleted $deleted large DB files, freed $([math]::Round($freed/1MB,1)) MB"