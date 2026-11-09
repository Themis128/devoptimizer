$drive = Get-PSDrive E
$total = $drive.Used + $drive.Free
$used = $drive.Used
$free = $drive.Free
$percentFree = [math]::Round(($free / $total) * 100, 2)
$percentUsed = [math]::Round(($used / $total) * 100, 2)

Write-Host "Drive E: Summary"
Write-Host "=================="
Write-Host "Total Size: [math]::Round($total/1GB, 2) GB"
Write-Host "Used:       [math]::Round($used/1GB, 2) GB ($percentUsed%)"
Write-Host "Free:       [math]::Round($free/1GB, 2) GB ($percentFree%)"
Write-Host ""

Get-ChildItem E:\ -Recurse -ErrorAction SilentlyContinue -Directory | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue -File | Measure-Object -Property Length -Sum).Sum
    if ($size -gt 1GB) {
        Write-Host "$($_.FullName) - [math]::Round($size/1GB, 2) GB"
    }
} | Sort-Object