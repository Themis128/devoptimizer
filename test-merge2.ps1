Import-Module 'D:\DevOptimizer\modules\DevOptimizer-Config.psm1' -Force
$merged = Merge-HubConfig -BaseConfigPath 'D:\DevOptimizer\config\devoptimizer-config.json' -OverlayConfigPath 'D:\DevOptimizer\config\hub-config.json' -PassThru

# Check hub-specific values
Write-Host "system.name: $($merged.system.name)"
Write-Host "system.version: $($merged.system.version)"
Write-Host "telemetryEnabled: $($merged.telemetryEnabled)"
Write-Host "logLevel: $($merged.logLevel)"
Write-Host "categoriesPath: $($merged.categoriesPath)"
Write-Host "registryPath: $($merged.registryPath)"
Write-Host "pythonBridge: $($merged.pythonBridge)"
Write-Host "autoDiscover: $($merged.autoDiscover)"
Write-Host "mergeStrategy: $($merged.mergeStrategy)"

# Check base config values preserved
Write-Host "logging.enabled: $($merged.logging.enabled)"
Write-Host "performance.timeout_default: $($merged.performance.timeout_default)"
Write-Host "security.input_validation: $($merged.security.input_validation)"