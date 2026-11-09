$drive = Get-PSDrive E
$freeBytes = $drive.Free
$freeGB = [math]::Round($freeBytes/1GB, 2)
$usedGB = [math]::Round($drive.Used/1GB, 2)
$totalGB = [math]::Round(($drive.Used + $drive.Free)/1GB, 2)
Write-Host "Drive: $($drive.Name)"
Write-Host "Free: $freeGB GB ($freeBytes bytes)"
Write-Host "Used: $usedGB GB"
Write-Host "Total: $totalGB GB"