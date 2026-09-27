# DevOptimizer System - Configuration Loader Module
# This module provides centralized configuration management for the DevOptimizer system

param(
    [string]$ConfigPath = "configs\system-config.json"
)

# Global configuration variable
$Global:DevOptimizerConfig = $null

function Get-ConfigPath {
    <#
    .SYNOPSIS
    Gets the full path to the configuration file.

    .DESCRIPTION
    Resolves the configuration file path relative to the script location.

    .PARAMETER ConfigPath
    Relative path to the configuration file.

    .OUTPUTS
    String. Full path to the configuration file.
    #>
    param(
        [string]$ConfigPath = "configs\system-config.json"
    )

    $scriptDir = if ($MyInvocation.MyCommand.Path) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $PWD
    }

    # Try different path resolutions
    $possiblePaths = @(
        (Join-Path $scriptDir "..\$ConfigPath"),
        (Join-Path $PWD $ConfigPath),
        "D:\DevOptimizer\$ConfigPath"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-Log "Found config file at: $path" -Level "DEBUG" -Component "Config"
            return $path
        }
    }

    # If none found, return the first attempt
    $firstPath = $possiblePaths[0]
    Write-Log "Config file not found, using: $firstPath" -Level "WARN" -Component "Config"
    return $firstPath
}

function Load-Configuration {
    <#
    .SYNOPSIS
    Loads the system configuration from JSON file.

    .DESCRIPTION
    Loads and validates the system configuration, storing it in a global variable.

    .PARAMETER ConfigPath
    Path to the configuration file.

    .OUTPUTS
    PSCustomObject. The loaded configuration object.
    #>
    param(
        [string]$ConfigPath = "configs\system-config.json"
    )

    try {
        $fullPath = Get-ConfigPath -ConfigPath $ConfigPath

        if (-not (Test-Path $fullPath)) {
            Write-Warning "Configuration file not found: $fullPath"
            Write-Warning "Creating default configuration..."
            New-DefaultConfiguration -ConfigPath $ConfigPath
        }

        $jsonContent = Get-Content -Path $fullPath -Raw -Encoding UTF8
        $config = $jsonContent | ConvertFrom-Json

        # Validate configuration structure
        $isValid = Test-Configuration -Config $config
        if (-not $isValid) {
            Write-Warning "Configuration validation failed. Using default values."
            $config = Get-DefaultConfiguration
        }

        # Store in global variable
        $Global:DevOptimizerConfig = $config

        Write-Log "Configuration loaded successfully from: $fullPath" -Level "INFO" -Component "Config"
        return $config

    } catch {
        Write-Error "Failed to load configuration: $($_.Exception.Message)"
        Write-Log "Failed to load configuration: $($_.Exception.Message)" -Level "ERROR" -Component "Config"

        # Return default configuration as fallback
        $defaultConfig = Get-DefaultConfiguration
        $Global:DevOptimizerConfig = $defaultConfig
        return $defaultConfig
    }
}

function Get-Configuration {
    <#
    .SYNOPSIS
    Gets the current system configuration.

    .DESCRIPTION
    Returns the loaded configuration object. If not loaded, loads it first.

    .OUTPUTS
    PSCustomObject. The system configuration object.
    #>

    if ($Global:DevOptimizerConfig -eq $null) {
        Load-Configuration -ConfigPath "configs\system-config.json"
    }

    # Ensure we return a single object, not an array
    if ($Global:DevOptimizerConfig -is [array]) {
        Write-Log "Configuration loaded as array, taking first element" -Level "WARN" -Component "Config"
        return $Global:DevOptimizerConfig[0]
    }

    return $Global:DevOptimizerConfig
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
    Gets a specific configuration value using dot notation.

    .DESCRIPTION
    Retrieves a configuration value using dot notation path (e.g., "ollama.concurrency").

    .PARAMETER Path
    Dot notation path to the configuration value.

    .PARAMETER DefaultValue
    Default value to return if the path is not found.

    .OUTPUTS
    Object. The configuration value or default value.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [object]$DefaultValue = $null
    )

    try {
        $config = Get-Configuration

        # Split path by dots and navigate through the object
        $pathParts = $Path -split '\.'
        $current = $config

        foreach ($part in $pathParts) {
            if ($current -and $current.PSObject.Properties.Name -contains $part) {
                $current = $current.$part
            } else {
                Write-Log "Configuration path not found: $Path" -Level "WARN" -Component "Config"
                return $DefaultValue
            }
        }

        return $current

    } catch {
        Write-Log "Error getting configuration value '$Path': $($_.Exception.Message)" -Level "ERROR" -Component "Config"
        return $DefaultValue
    }
}

function Set-ConfigValue {
    <#
    .SYNOPSIS
    Sets a specific configuration value using dot notation.

    .DESCRIPTION
    Updates a configuration value and saves it to the configuration file.

    .PARAMETER Path
    Dot notation path to the configuration value.

    .PARAMETER Value
    New value to set.

    .PARAMETER SaveToFile
    Whether to save the changes to the configuration file.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [object]$Value,

        [bool]$SaveToFile = $true
    )

    try {
        $config = Get-Configuration

        # Split path by dots and navigate to the parent object
        $pathParts = $Path -split '\.'
        $current = $config

        # Navigate to the parent of the target property
        for ($i = 0; $i -lt $pathParts.Length - 1; $i++) {
            $part = $pathParts[$i]
            if (-not $current.$part) {
                $current.$part = @{}
            }
            $current = $current.$part
        }

        # Set the value
        $lastPart = $pathParts[-1]
        $current.$lastPart = $Value

        # Update global config
        $Global:DevOptimizerConfig = $config

        Write-Log "Configuration value updated: $Path = $Value" -Level "INFO" -Component "Config"

        if ($SaveToFile) {
            Save-Configuration -Config $config
        }

    } catch {
        Write-Error "Failed to set configuration value '$Path': $($_.Exception.Message)"
        Write-Log "Failed to set configuration value '$Path': $($_.Exception.Message)" -Level "ERROR" -Component "Config"
    }
}

function Save-Configuration {
    <#
    .SYNOPSIS
    Saves the configuration to the JSON file.

    .DESCRIPTION
    Writes the current configuration object to the configuration file.

    .PARAMETER Config
    Configuration object to save. If not provided, uses the global config.

    .PARAMETER ConfigPath
    Path to save the configuration file.
    #>
    param(
        [object]$Config = $null,
        [string]$ConfigPath = "configs\system-config.json"
    )

    try {
        if ($Config -eq $null) {
            $Config = Get-Configuration
        }

        $fullPath = Get-ConfigPath -ConfigPath $ConfigPath

        # Ensure directory exists
        $configDir = Split-Path -Parent $fullPath
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }

        # Convert to JSON with proper formatting
        $jsonContent = $Config | ConvertTo-Json -Depth 10

        # Save to file
        Set-Content -Path $fullPath -Value $jsonContent -Encoding UTF8

        Write-Log "Configuration saved to: $fullPath" -Level "INFO" -Component "Config"

    } catch {
        Write-Error "Failed to save configuration: $($_.Exception.Message)"
        Write-Log "Failed to save configuration: $($_.Exception.Message)" -Level "ERROR" -Component "Config"
    }
}

function Test-Configuration {
    <#
    .SYNOPSIS
    Validates the configuration object structure.

    .DESCRIPTION
    Checks if the configuration object has the required properties and structure.

    .PARAMETER Config
    Configuration object to validate.

    .OUTPUTS
    Boolean. True if configuration is valid, false otherwise.
    #>
    param(
        [object]$Config
    )

    try {
        # Check for required top-level properties
        $requiredProperties = @('system', 'ollama', 'onedrive', 'cursor', 'development')

        foreach ($property in $requiredProperties) {
            if (-not $Config.PSObject.Properties.Name -contains $property) {
                Write-Log "Missing required configuration property: $property" -Level "WARN" -Component "Config"
                return $false
            }
        }

        # Check system configuration
        if (-not $Config.system.logLevel) {
            Write-Log "Missing system.logLevel configuration" -Level "WARN" -Component "Config"
            return $false
        }

        # Check ollama configuration
        if (-not $Config.ollama.concurrency -or $Config.ollama.concurrency -lt 1) {
            Write-Log "Invalid ollama.concurrency configuration" -Level "WARN" -Component "Config"
            return $false
        }

        return $true

    } catch {
        Write-Log "Configuration validation error: $($_.Exception.Message)" -Level "ERROR" -Component "Config"
        return $false
    }
}

function New-DefaultConfiguration {
    <#
    .SYNOPSIS
    Creates a new default configuration file.

    .DESCRIPTION
    Creates a configuration file with default values if none exists.

    .PARAMETER ConfigPath
    Path where to create the configuration file.
    #>
    param(
        [string]$ConfigPath = "configs\system-config.json"
    )

    try {
        $defaultConfig = Get-DefaultConfiguration
        Save-Configuration -Config $defaultConfig -ConfigPath $ConfigPath
        Write-Log "Default configuration created: $ConfigPath" -Level "INFO" -Component "Config"
    } catch {
        Write-Error "Failed to create default configuration: $($_.Exception.Message)"
    }
}

function Get-DefaultConfiguration {
    <#
    .SYNOPSIS
    Gets the default configuration object.

    .DESCRIPTION
    Returns a configuration object with default values.

    .OUTPUTS
    PSCustomObject. Default configuration object.
    #>

    return @{
        system = @{
            name = "DevOptimizer System"
            version = "2.0.0"
            logLevel = "INFO"
            backupLocation = "D:\DevOptimizer\backups"
            logsLocation = "D:\DevOptimizer\logs"
            maxLogFiles = 10
            maxLogSize = "10MB"
            autoCleanup = $true
            cleanupDays = 30
        }
        ollama = @{
            serverUrl = "http://127.0.0.1:11434"
            port = 11434
            autoPort = $true
            maxPorts = 10
            host = "127.0.0.1"
            defaultModels = @("qwen2.5-coder:7b", "llama2:7b", "codellama:7b")
            preferredModels = @("qwen2.5-coder:7b", "llama2:7b")
            concurrency = 2
            maxLoaded = 2
            timeoutSeconds = 300
            keepAliveSec = 600
            retryAttempts = 3
            backoffDelay = 0.5
            enableMultiModel = $true
            enableStreaming = $true
            maxPromptLength = 8000
            maxResponseLength = 512
            maxContextLength = 2048
            laptopOptimization = $true
            autoStart = $true
            healthCheckInterval = 60
            logLevel = "INFO"
            metricsEnabled = $true
            metricsLogPath = "logs/ollama"
        }
        onedrive = @{
            accounts = @(
                @{ name = "Personal"; path = "C:\Users\$env:USERNAME\OneDrive" }
            )
            syncInterval = 300
            backupEnabled = $true
        }
        cursor = @{
            installPath = "C:\Users\$env:USERNAME\AppData\Local\Programs\cursor"
            settingsPath = "$env:USERPROFILE\.cursor"
            autoUpdate = $true
            backupSettings = $true
        }
        development = @{
            nodejs = @{
                version = "18.x"
                globalPackages = @("@angular/cli", "@vue/cli", "typescript")
            }
            python = @{
                version = "3.11"
                globalPackages = @("jupyter", "tensorflow")
            }
        }
        security = @{
            enableFirewall = $true
            enableDefender = $true
            scanInterval = 86400
        }
        user = @{
            preferences = @{
                theme = "dark"
                language = "en"
                notifications = $true
            }
        }
    } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
}

function Reset-Configuration {
    <#
    .SYNOPSIS
    Resets the configuration to default values.

    .DESCRIPTION
    Replaces the current configuration with default values and saves it.
    #>

    try {
        $defaultConfig = Get-DefaultConfiguration
        $Global:DevOptimizerConfig = $defaultConfig
        Save-Configuration -Config $defaultConfig

        Write-Log "Configuration reset to default values" -Level "INFO" -Component "Config"
    } catch {
        Write-Error "Failed to reset configuration: $($_.Exception.Message)"
    }
}

# Helper function for logging (if not already defined)
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "Unknown"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [$Component] $Message"

    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG" { Write-Host $logMessage -ForegroundColor Gray }
        default { Write-Host $logMessage }
    }
}

# Export functions for use in other scripts
if ($MyInvocation.MyCommand.Module) {
    Export-ModuleMember -Function Load-Configuration, Get-Configuration, Get-ConfigValue, Set-ConfigValue, Save-Configuration, Test-Configuration, New-DefaultConfiguration, Get-DefaultConfiguration, Reset-Configuration
}
