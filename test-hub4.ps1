Import-Module 'D:\DevOptimizer\modules\DevOptimizer-Master.psm1' -Force
Write-Host "Module loaded, calling function..."
Initialize-DevOptimizerMaster -ConfigPath "D:\DevOptimizer\config\devoptimizer-config.json" -LoadHub $true -LoadOllama $false -LoadLogging $false -LoadValidation $false -LoadErrorHandling $false
Write-Host "Function returned"
$status = Get-DevOptimizerStatus
Write-Host "Modules loaded: $($status.ModulesLoaded -join ', ')"
Write-Host "Initialized: $($status.Initialized)"