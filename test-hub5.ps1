$ErrorActionPreference = "Stop"
Import-Module 'D:\DevOptimizer\modules\DevOptimizer-Master.psm1' -Force
Write-Host "Module loaded, calling function..."
try {
    Initialize-DevOptimizerMaster -ConfigPath "D:\DevOptimizer\config\devoptimizer-config.json" -LoadHub $true -LoadOllama $false -LoadLogging $false -LoadValidation $false -LoadErrorHandling $false
    Write-Host "Function returned successfully"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Write-Host "Stack: $($_.ScriptStackTrace)"
}
$status = Get-DevOptimizerStatus
Write-Host "Modules loaded: $($status.ModulesLoaded -join ', ')"
Write-Host "Initialized: $($status.Initialized)"