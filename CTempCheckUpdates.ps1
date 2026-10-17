$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
Write-Host "Searching for updates..."
$result = $updateSearcher.Search("IsInstalled=0")
Write-Host "Found $($result.Updates.Count) updates"
foreach ($update in $result.Updates) {
    if ($update.Title -match "NVIDIA") {
        Write-Host "Found NVIDIA update: $($update.Title)"
    }
}
