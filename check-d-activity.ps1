$folders = @(
    'D:\Nuxt Projects\llm-dev-agent',
    'D:\DevOptimizer\backups\nas-staging\20261108-0430',
    'D:\gdrive',
    'D:\tabby\models\TabbyML',
    'D:\eset',
    'D:\AomeiDateBackupper11213'
)

$cutoff = (Get-Date).AddMonths(-2)

Write-Host "=== Last 2 Months Activity Check (since $($cutoff.ToString('yyyy-MM-dd'))) ===" -ForegroundColor Cyan
$results = @()

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        $items = Get-ChildItem $folder -Recurse -Force -ErrorAction SilentlyContinue
        if ($items.Count -gt 0) {
            $lastWrite = ($items | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
            $lastAccess = ($items | Sort-Object LastAccessTime -Descending | Select-Object -First 1).LastAccessTime
            $sizeGB = [math]::Round(($items | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
            $recentWrite = $lastWrite -gt $cutoff
            $recentAccess = $lastAccess -gt $cutoff
            $active = $recentWrite -or $recentAccess
            
            $results += [pscustomobject]@{
                Folder = $folder
                SizeGB = $sizeGB
                LastWrite = $lastWrite
                LastAccess = $lastAccess
                RecentWrite = $recentWrite
                RecentAccess = $recentAccess
                Active = $active
            }
        }
    }
}

$results | Format-Table -AutoSize @{Expression={$_.Folder};Label="Folder";Width=55}, @{Expression={$_.SizeGB};Label="SizeGB"}, @{Expression={$_.LastWrite};Label="LastWrite"}, @{Expression={$_.LastAccess};Label="LastAccess"}, @{Expression={$_.Active};Label="Active(2mo)"}

Write-Host ""
Write-Host "=== Folders NOT active in last 2 months (candidates for cleanup) ===" -ForegroundColor Yellow
$inactive = $results | Where-Object { -not $_.Active }
if ($inactive.Count -gt 0) {
    $inactive | Format-Table -AutoSize @{Expression={$_.Folder};Label="Folder";Width=55}, @{Expression={$_.SizeGB};Label="SizeGB"}, @{Expression={$_.LastWrite};Label="LastWrite"}, @{Expression={$_.LastAccess};Label="LastAccess"}
} else {
    Write-Host "All folders show activity in last 2 months"
}