$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
Write-Host "Searching for updates..."
$result = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
Write-Host "Found $($result.Updates.Count) updates"

if ($result.Updates.Count -gt 0) {
    Write-Host "Updates found:"
    foreach ($update in $result.Updates) {
        Write-Host "- $($update.Title)"
        if ($update.Title -match "NVIDIA|Display|Graphics") {
            Write-Host "  -> This appears to be a graphics/NVIDIA update"
        }
    }
} else {
    Write-Host "No updates found"
}
