$acpDir = Join-Path $env:APPDATA 'devin\User\acp-messages'
$cutoff = (Get-Date).AddDays(-14)
$files = Get-ChildItem -LiteralPath $acpDir -Filter '*.db' -File | Where-Object { $_.LastWriteTime -lt $cutoff }
$files | ForEach-Object { 
    Write-Host "Deleting: $($_.Name) ($([math]::Round($_.Length/1MB,1)) MB) from $($_.LastWriteTime)"
    Remove-Item -LiteralPath $_.FullName -Force 
}
$shmWal = Get-ChildItem -LiteralPath $acpDir -Filter '*.db-shm','*.db-wal' -File | Where-Object { $_.LastWriteTime -lt $cutoff }
$shmWal | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
Write-Host "Deleted $($files.Count) DB files and $($shmWal.Count) shm/wal files older than 14 days"