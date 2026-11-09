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

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        $item = Get-Item $folder -Force -ErrorAction SilentlyContinue
        $lastWrite = $item.LastWriteTime
        $lastAccess = $item.LastAccessTime
        $sizeGB = "N/A"
        
        # Quick size for known folders
        if ($folder -like '*llm-dev-agent*') { $sizeGB = "43.8" }
        elseif ($folder -like '*nas-staging*20261108*') { $sizeGB = "43.6" }
        elseif ($folder -like '*gdrive*') { $sizeGB = "31.0" }
        elseif ($folder -like '*TabbyML*') { $sizeGB = "16.7" }
        elseif ($folder -like '*eset*') { $sizeGB = "4.6" }
        elseif ($folder -like '*Aomei*') { $sizeGB = "4.1" }
        
        $recentWrite = $lastWrite -gt $cutoff
        $recentAccess = $lastAccess -gt $cutoff
        $active = $recentWrite -or $recentAccess
        $status = if ($active) { "ACTIVE" } else { "INACTIVE - candidate for cleanup" }
        $color = if ($active) { "Green" } else { "Yellow" }
        
        Write-Host "$folder`t$sizeGB GB`tLastWrite: $lastWrite`tLastAccess: $lastAccess`t$status" -ForegroundColor $color
    }
}