Import-Module 'D:\DevOptimizer\modules\DevOptimizer-Master.psm1' -Force
Initialize-DevOptimizerMaster -ConfigPath "D:\DevOptimizer\config\devoptimizer-config.json" -LoadHub $true -LoadOllama $false -LoadLogging $false -LoadValidation $false -LoadErrorHandling $false
Write-Host "Test complete"
$status = Get-DevOptimizerStatus
Write-Host "Modules loaded: $($status.ModulesLoaded -join ', ')"
Write-Host "Initialized: $($status.Initialized)"