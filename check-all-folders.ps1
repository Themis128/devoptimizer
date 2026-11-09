Get-ChildItem E:\ -ErrorAction SilentlyContinue -Directory | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue -File | Measure-Object -Property Length -Sum).Sum
    $sizeGB = [math]::Round($size/1GB, 2)
    Write-Host "$($_.FullName) - $sizeGB GB"
} | Sort-Object