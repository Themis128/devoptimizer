$folders = Get-ChildItem 'D:\DevOptimizer\backups\nas-staging' -Directory -Force -ErrorAction SilentlyContinue
$results = @()
foreach ($folder in $folders) {
    $sizeBytes = (Get-ChildItem $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $sizeGB = [math]::Round($sizeBytes / 1GB, 2)
    $results += [pscustomobject]@{ Name = $folder.Name; SizeGB = $sizeGB }
}
$results | Sort-Object Name | Format-Table -AutoSize