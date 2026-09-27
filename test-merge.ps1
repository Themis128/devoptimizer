Import-Module 'D:\DevOptimizer\modules\DevOptimizer-Config.psm1' -Force
$merged = Merge-HubConfig -BaseConfigPath 'D:\DevOptimizer\config\devoptimizer-config.json' -OverlayConfigPath 'D:\DevOptimizer\config\hub-config.json' -PassThru
Write-Host "Merged keys: $($merged.Keys -join ', ')"