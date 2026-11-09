$drive = Get-PSDrive D
$freeGB = [math]::Round($drive.Free / 1GB, 2)
$usedGB = [math]::Round($drive.Used / 1GB, 2)
Write-Host "D: Free: $freeGB GB, Used: $usedGB GB"