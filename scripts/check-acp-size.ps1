$acpDir = Join-Path $env:APPDATA 'devin\User\acp-messages'
$total = (Get-ChildItem -LiteralPath $acpDir -Filter '*.db' -File | Measure-Object -Property Length -Sum).Sum
$count = (Get-ChildItem -LiteralPath $acpDir -Filter '*.db' -File).Count
Write-Host "ACP messages: $count DB files, $([math]::Round($total/1MB,1)) MB total"