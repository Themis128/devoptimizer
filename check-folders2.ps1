$drive = Get-PSDrive E
$total = $drive.Used + $drive.Free
$used = $drive.Used
$free = $drive.Free

$totalGB = [math]::Round($total/1GB, 2)
$usedGB = [math]::Round($used/1GB, 2)
$freeGB = [math]::Round($free/1GB, 2)
$percentFree = [math]::Round(($free / $total) * 100, 2)
$percentUsed = [math]::Round(($used / $total) * 100, 2)

Write-Host "Drive E: Summary"
Write-Host "=================="
Write-Host "Total Size: $totalGB GB"
Write-Host "Used:       $usedGB GB ($percentUsed%)"
Write-Host "Free:       $freeGB GB ($percentFree%)"
Write-Host ""

Get-ChildItem E:\ -Recurse -ErrorAction SilentlyContinue -Directory | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue -File | Measure-Object -Property Length -Sum).Sum
    if ($size -gt 1GB) {
        $sizeGB = [math]::Round($size/1GB, 2)
        Write-Host "$($_.FullName) - $sizeGB GB"
    }
}