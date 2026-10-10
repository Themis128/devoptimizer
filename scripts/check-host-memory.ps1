$os = Get-CimInstance Win32_OperatingSystem
$freeGB = [math]::Round($os.FreePhysicalMemory/1MB,1)
$totalGB = [math]::Round($os.TotalVisibleMemorySize/1MB,1)
Write-Host "Host Memory: Free=$freeGB GB / Total=$totalGB GB"