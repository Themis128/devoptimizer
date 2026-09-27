$files = Get-ChildItem -Path $env:TEMP -File -ErrorAction SilentlyContinue
$size = ($files | Measure-Object -Property Length -Sum).Sum
Write-Host ("Temp: {0} files, {1:N2} MB" -f $files.Count, ($size/1MB))

$files = Get-ChildItem -Path "$env:WINDIR\Temp" -File -ErrorAction SilentlyContinue
$size = ($files | Measure-Object -Property Length -Sum).Sum
Write-Host ("Windows Temp: {0} files, {1:N2} MB" -f $files.Count, ($size/1MB))