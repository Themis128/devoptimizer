$discovery = .\Discover-Scripts.ps1 -PassThru
Write-Host "Categories type: $($discovery.Categories.GetType().Name)"
Write-Host "Categories count: $($discovery.Categories.Count)"
Write-Host "Categories keys: $($discovery.Categories.Keys -join ', ')"
foreach ($key in $discovery.Categories.Keys) {
    Write-Host ("{0}: {1}" -f $key, $discovery.Categories[$key].Name)
}