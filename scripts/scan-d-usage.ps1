# Read-only: size of D:\ top-level directories (PS 5.1 compatible)
$root = 'D:\'
$results = foreach ($dir in (Get-ChildItem $root -Directory -Force -ErrorAction SilentlyContinue)) {
    $sum = (Get-ChildItem $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    [PSCustomObject]@{ Name = $dir.Name; GB = [math]::Round($sum/1GB, 2) }
}
$results | Sort-Object GB -Descending | Select-Object -First 25 | ForEach-Object {
    Write-Host ("{0,10:N2} GB  {1}" -f $_.GB, $_.Name)
}
$loose = Get-ChildItem $root -File -Force -ErrorAction SilentlyContinue |
         Measure-Object -Property Length -Sum
if ($null -eq $loose.Sum) { $loose.Sum = 0 }
Write-Host ("{0,10:N2} GB  <loose root files ({1} files)>" -f ($loose.Sum/1GB), $loose.Count)
