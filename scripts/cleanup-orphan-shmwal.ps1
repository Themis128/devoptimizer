$acpDir = Join-Path $env:APPDATA 'devin\User\acp-messages'
$shm = Get-ChildItem -LiteralPath $acpDir -Filter '*.db-shm' -File
$wal = Get-ChildItem -LiteralPath $acpDir -Filter '*.db-wal' -File
$shmWal = $shm + $wal
$deleted = 0
foreach ($f in $shmWal) {
    $dbName = $f.BaseName -replace '\.db-shm$|\.db-wal$', ''
    $dbExists = Test-Path (Join-Path $acpDir ($dbName + '.db'))
    if (-not $dbExists) {
        Write-Host "Deleting orphan: $($f.Name)"
        Remove-Item -LiteralPath $f.FullName -Force
        $deleted++
    }
}
Write-Host "Deleted $deleted orphaned shm/wal files"