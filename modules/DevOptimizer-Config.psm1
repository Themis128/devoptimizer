# DevOptimizer Configuration Manager
# Handles centralized configuration loading and management

param(
    [string]$ConfigPath = "D:\DevOptimizer\config\devoptimizer-config.json"
)

class DevOptimizerConfig {
    [hashtable]$Config = @{}
    [string]$ConfigPath = ""
    [datetime]$LastLoaded = [datetime]::MinValue
    
    DevOptimizerConfig([string]$Path) {
        $this.ConfigPath = $Path
        $this.LoadConfig()
    }
    
    [void] LoadConfig() {
        try {
            if (Test-Path $this.ConfigPath) {
                $jsonContent = Get-Content $this.ConfigPath -Raw -Encoding UTF8
                $jsonObj = $jsonContent | ConvertFrom-Json
                $this.Config = @{}
                $jsonObj.PSObject.Properties | ForEach-Object { $this.Config[$_.Name] = $_.Value }
                $this.LastLoaded = Get-Date
                Write-Host "[CONFIG] Configuration loaded successfully from $($this.ConfigPath)" -ForegroundColor Green
            } else {
                Write-Warning "[CONFIG] Configuration file not found: $($this.ConfigPath)"
                $this.CreateDefaultConfig()
            }
        }
        catch {
            Write-Error "[CONFIG] Failed to load configuration: $($_.Exception.Message)"
            $this.CreateDefaultConfig()
        }
    }
    
    [void] CreateDefaultConfig() {
        Write-Host "[CONFIG] Creating default configuration..." -ForegroundColor Yellow
        $this.Config = @{
            system = @{
                name = "DevOptimizer"
                version = "2.0.0"
                environment = "production"
                debug_mode = $false
                log_level = "INFO"
            }
            logging = @{
                enabled = $true
                log_levels = @("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")
                max_log_size = "10MB"
                max_log_files = 10
                console_output = $true
                file_output = $true
            }
            performance = @{
                timeout_default = 300
                timeout_long = 600
                parallel_execution = $true
                max_concurrent_tasks = 4
            }
            security = @{
                input_validation = $true
                path_sanitization = $true
                admin_required = $false
            }
        }
        $this.SaveConfig()
    }
    
    [void] SaveConfig() {
        try {
            $jsonContent = $this.Config | ConvertTo-Json -Depth 10
            $jsonContent | Out-File -FilePath $this.ConfigPath -Encoding UTF8 -Force
            Write-Host "[CONFIG] Configuration saved to $($this.ConfigPath)" -ForegroundColor Green
        }
        catch {
            Write-Error "[CONFIG] Failed to save configuration: $($_.Exception.Message)"
        }
    }
    
    [object] GetValue([string]$Path) {
        $keys = $Path.Split('.')
        $current = $this.Config
        
        foreach ($key in $keys) {
            if ($current -is [hashtable] -and $current.ContainsKey($key)) {
                $current = $current[$key]
            } else {
                return $null
            }
        }
        return $current
    }
    
    [void] SetValue([string]$Path, [object]$Value) {
        $keys = $Path.Split('.')
        $current = $this.Config
        
        for ($i = 0; $i -lt $keys.Length - 1; $i++) {
            $key = $keys[$i]
            if (-not $current.ContainsKey($key)) {
                $current[$key] = @{}
            }
            $current = $current[$key]
        }
        
        $current[$keys[-1]] = $Value
    }
    
    [bool] IsDebugMode() {
        return $this.GetValue("system.debug_mode") -eq $true
    }
    
    [string] GetLogLevel() {
        return $this.GetValue("system.log_level")
    }
    
    [int] GetTimeout([string]$Type = "default") {
        $timeoutKey = "performance.timeout_$Type"
        return $this.GetValue($timeoutKey)
    }
    
    [bool] IsLoggingEnabled() {
        return $this.GetValue("logging.enabled") -eq $true
    }
    
    [bool] IsInputValidationEnabled() {
        return $this.GetValue("security.input_validation") -eq $true
    }
    
    [string] GetRootDirectory() {
        return $this.GetValue("paths.root_directory")
    }
    
    [string] GetLogsDirectory() {
        return $this.GetValue("paths.logs_directory")
    }
}

# Export the configuration manager
$Global:DevOptimizerConfig = [DevOptimizerConfig]::new($ConfigPath)

# Helper functions for easy access
function Get-DevOptimizerConfig {
    return $Global:DevOptimizerConfig
}

function Get-ConfigValue {
    param([string]$Path)
    return $Global:DevOptimizerConfig.GetValue($Path)
}

function Set-ConfigValue {
    param(
        [string]$Path,
        [object]$Value
    )
    $Global:DevOptimizerConfig.SetValue($Path, $Value)
}

function Save-DevOptimizerConfig {
    $Global:DevOptimizerConfig.SaveConfig()
}

# Initialize configuration on module load
Write-Host "[CONFIG] DevOptimizer Configuration Manager initialized" -ForegroundColor Cyan

# Merge-HubConfig function for deep merge of base + overlay configs
function Merge-HubConfig {
    <#
    .SYNOPSIS
        Merges a base configuration with an overlay configuration using deep merge semantics.
        Objects are merged recursively, arrays are replaced entirely, overlay values win on conflicts.

    .DESCRIPTION
        This function implements the config merge logic for DevOptimizer Script Hub.
        Base config (devoptimizer-config.json) + Overlay config (hub-config.json) = Merged config
        
        Merge rules:
        - If both values are hashtables (objects): recurse and merge
        - If both values are arrays: overlay completely replaces base
        - Otherwise: overlay value wins
        - Keys only in base are preserved
        - Keys only in overlay are added

    .PARAMETER BaseConfigPath
        Path to the base configuration JSON file (e.g., devoptimizer-config.json)

    .PARAMETER OverlayConfigPath
        Path to the overlay configuration JSON file (e.g., hub-config.json)

    .PARAMETER OutputPath
        Optional path to write the merged configuration as JSON

    .PARAMETER PassThru
        If specified, outputs the merged hashtable to the pipeline

    .EXAMPLE
        Merge-HubConfig -BaseConfigPath "config\devoptimizer-config.json" -OverlayConfigPath "config\hub-config.json" -OutputPath "config\merged-config.json"

    .EXAMPLE
        $merged = Merge-HubConfig -BaseConfigPath "config\devoptimizer-config.json" -OverlayConfigPath "config\hub-config.json" -PassThru
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseConfigPath,

        [Parameter(Mandatory=$true, Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]$OverlayConfigPath,

        [Parameter(Position=2)]
        [string]$OutputPath,

        [Parameter()]
        [switch]$PassThru
    )

    function Merge-Hashtable {
        param(
            [hashtable]$Base,
            [hashtable]$Overlay
        )

        $result = @{}
        
        # Copy all base keys first
        foreach ($key in $Base.Keys) {
            $result[$key] = $Base[$key]
        }
        
        # Merge overlay keys
        foreach ($key in $Overlay.Keys) {
            $baseValue = $Base[$key]
            $overlayValue = $Overlay[$key]
            
            if ($null -ne $baseValue -and $baseValue -is [hashtable] -and $overlayValue -is [hashtable]) {
                # Both are objects - deep merge recursively
                $result[$key] = Merge-Hashtable -Base $baseValue -Overlay $overlayValue
            }
            elseif ($baseValue -is [array] -and $overlayValue -is [array]) {
                # Both are arrays - overlay replaces entirely
                $result[$key] = $overlayValue
            }
            else {
                # Any other case - overlay wins
                $result[$key] = $overlayValue
            }
        }
        
        return $result
    }

    # Read and parse base config
    $basePath = Resolve-Path -Path $BaseConfigPath -ErrorAction Stop
    $baseJson = Get-Content -Path $basePath -Raw -Encoding UTF8
    $baseObj = $baseJson | ConvertFrom-Json
    $baseConfig = @{}
    $baseObj.PSObject.Properties | ForEach-Object { $baseConfig[$_.Name] = $_.Value }

    # Read and parse overlay config
    $overlayPath = Resolve-Path -Path $OverlayConfigPath -ErrorAction Stop
    $overlayJson = Get-Content -Path $overlayPath -Raw -Encoding UTF8
    $overlayObj = $overlayJson | ConvertFrom-Json
    $overlayConfig = @{}
    $overlayObj.PSObject.Properties | ForEach-Object { $overlayConfig[$_.Name] = $_.Value }

    # Perform deep merge
    $merged = Merge-Hashtable -Base $baseConfig -Overlay $overlayConfig

    # Write to output file if specified
    if ($OutputPath) {
        $mergedJson = $merged | ConvertTo-Json -Depth 10 -Compress
        $mergedJson | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Host "[CONFIG] Merged configuration written to: $OutputPath" -ForegroundColor Green
    }

    # Output to pipeline if requested
    if ($PassThru) {
        return $merged
    }

    # Default: output as JSON to stdout
    $merged | ConvertTo-Json -Depth 10 -Compress
}

Export-ModuleMember -Function Merge-HubConfig, Get-DevOptimizerConfig, Get-ConfigValue, Set-ConfigValue, Save-DevOptimizerConfig
