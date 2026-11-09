$drive = Get-PSDrive D
$freeGB = [math]::Round($drive.Free/1GB, 2)
$usedGB = [math]::Round($drive.Used/1GB, 2)
$totalGB = [math]::Round(($drive.Used + $drive.Free)/1GB, 2)
Write-Host "Drive: $($drive.Name)"
Write-Host "Free: $freeGB GB"
Write-Host "Used: $usedGB GB"
Write-Host "Total: $totalGB GB"