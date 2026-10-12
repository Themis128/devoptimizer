$logs = Get-ChildItem 'C:\Users\tbaltzakis\AppData\Roaming\Devin\logs' -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$files = Get-ChildItem $logs.FullName -File | Sort-Object LastWriteTime -Descending | Select-Object -First 5
foreach ($f in $files) {
    Write-Host "=== $($f.Name) ==="
    Get-Content $f.FullName -Tail 100
}