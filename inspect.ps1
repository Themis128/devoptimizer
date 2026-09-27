$discovery = .\Discover-Scripts.ps1 -PassThru
$discovery.Categories.GetEnumerator() | ForEach-Object {
    "$($_.Key): $($_.Value.Name)"
}