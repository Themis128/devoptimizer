param(
    [int]$Days = 14
)

$acpDir = Join-Path $env:APPDATA 'devin\User\acp-messages'
$cutoff = (Get-Date).AddDays(-$Days)
$files = Get-ChildItem -LiteralPath $acpDir -Filter '*.db' -File | Where-Object { $_.LastWriteTime -lt $cutoff }
$files | ForEach-Object { 
    Write-Host "Deleting: $($_.Name) ($([math]::Round($_.Length/1MB,1)) MB) from $($_.LastWriteTime)"
    Remove-Item -LiteralPath $_.FullName -Force 
}
$shm = Get-ChildItem -LiteralPath $acpDir -Filter '*.db-shm' -File | Where-Object { $_.LastWriteTime -lt $cutoff }
$wal = Get-ChildItem -LiteralPath $acpDir -Filter '*.db-wal' -File | Where-Object { $_.LastWriteTime -lt $cutoff }
$shm | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
$wal | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
$shmWalCount = $shm.Count + $wal.Count
Write-Host "Deleted $($files.Count) DB files and $shmWalCount shm/wal files older than $Days days"