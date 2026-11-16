# Debug configuration loading

<#+
.SYNOPSIS
Debugs DevOptimizer configuration loading and displays key sections for verification.

.DESCRIPTION
Imports the configuration loader module, retrieves the active configuration, and prints Ollama-specific entries along with the entire structure for troubleshooting.

.EXAMPLE
PS> .\debug-config.ps1
Loads the configuration and echoes the Ollama section and overall JSON snapshot.

.NOTES
Author: DevOptimizer automation tools
#>

. ".\modules\config-loader.ps1"

Write-Host "Loading configuration..."
try {
    $config = Load-Configuration
    Write-Host "Configuration loaded successfully"

    Write-Host "`nChecking ollama section:"
    if ($config.ollama) {
        Write-Host "ollama section exists"
        Write-Host "serverUrl: $($config.ollama.serverUrl)"
        Write-Host "maxLoaded: $($config.ollama.maxLoaded)"
        Write-Host "keepAliveSec: $($config.ollama.keepAliveSec)"

        Write-Host "`nTesting Get-ConfigValue:"
        $serverUrl = Get-ConfigValue -Path "ollama.serverUrl"
        Write-Host "ollama.serverUrl: $serverUrl"

        $maxLoaded = Get-ConfigValue -Path "ollama.maxLoaded"
        Write-Host "ollama.maxLoaded: $maxLoaded"

        $keepAlive = Get-ConfigValue -Path "ollama.keepAliveSec"
        Write-Host "ollama.keepAliveSec: $keepAlive"
    } else {
        Write-Host "ollama section does not exist"
    }

    Write-Host "`nFull config structure:"
    $config | ConvertTo-Json -Depth 3

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
