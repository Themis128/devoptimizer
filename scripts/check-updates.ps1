$session = New-Object -ComObject Microsoft.Update.Session
$searcher = $session.CreateUpdateSearcher()
$result = $searcher.Search("IsInstalled=0")
Write-Host "Pending updates: $($result.Updates.Count)"
$result.Updates | Select-Object Title, IsDownloaded, IsMandatory, RebootRequired