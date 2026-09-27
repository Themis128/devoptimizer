# DevOptimizer Master Module Loader
# Loads and initializes all DevOptimizer modules with Ollama integration and Script Hub support

# Global state
$Global:DevOptimizerModules = @{
    Config = $null
    Logger = $null
    Validator = $null
    Ollama = $null
    ErrorHandler = $null
    Path = $null
    Admin = $null
}

$Global:DevOptimizerStatus = @{
    Initialized = $false
    ModulesLoaded = @()
    Errors = @()
    StartTime = Get-Date
}

# Module paths
$Global:DevOptimizerModulePaths = @{
    ModulePath = "D:\DevOptimizer\modules"
    ConfigModule = "D:\DevOptimizer\modules\DevOptimizer-Config.psm1"
    LoggingModule = "D:\DevOptimizer\modules\DevOptimizer-Logger.psm1"
    ValidationModule = "D:\DevOptimizer\modules\DevOptimizer-Validator.psm1"
    OllamaModule = "D:\DevOptimizer\modules\DevOptimizer-Ollama.psm1"
    ErrorHandlerModule = "D:\DevOptimizer\modules\DevOptimizer-ErrorHandler.psm1"
    PathModule = "D:\DevOptimizer\modules\DevOptimizer-Path.psm1"
    AdminModule = "D:\DevOptimizer\modules\DevOptimizer-Admin.psm1"
}

function Initialize-DevOptimizerMaster {
    param(
        [string]$ConfigPath = "D:\DevOptimizer\config\devoptimizer-config.json",
        [bool]$LoadOllama = $true,
        [bool]$LoadLogging = $true,
        [bool]$LoadValidation = $true,
        [bool]$LoadErrorHandling = $true,
        [bool]$LoadHub = $false
    )

    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                    DEVOPTIMIZER MODULE LOADER" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Reset status
    $Global:DevOptimizerStatus = @{
        Initialized = $false
        ModulesLoaded = @()
        Errors = @()
        StartTime = Get-Date
    }

    try {
        Write-Host "[LOADER] Starting DevOptimizer module initialization..." -ForegroundColor Yellow
        
        # Load Configuration Module
        if (Test-Path $Global:DevOptimizerModulePaths.ConfigModule) {
            Write-Host "[LOADER] Loading Configuration Module..." -ForegroundColor Green
            Import-Module $Global:DevOptimizerModulePaths.ConfigModule -Force -ArgumentList $ConfigPath
            $Global:DevOptimizerModules.Config = $Global:DevOptimizerConfig
            $Global:DevOptimizerStatus.ModulesLoaded += "Config"
            Write-Host "[LOADER] Configuration Module loaded successfully" -ForegroundColor Green
        } else {
            Write-Warning "[LOADER] Configuration Module not found"
            $Global:DevOptimizerStatus.Errors += "Configuration Module not found"
        }
        
        # Load Logging Module
        if ($LoadLogging) {
            if (Test-Path $Global:DevOptimizerModulePaths.LoggingModule) {
                Write-Host "[LOADER] Loading Logging Module..." -ForegroundColor Green
                Import-Module $Global:DevOptimizerModulePaths.LoggingModule -Force
                $Global:DevOptimizerModules.Logger = $Global:DevOptimizerLogger
                $Global:DevOptimizerStatus.ModulesLoaded += "Logger"
                Write-Host "[LOADER] Logging Module loaded successfully" -ForegroundColor Green
            } else {
                Write-Warning "[LOADER] Logging Module not found"
                $Global:DevOptimizerStatus.Errors += "Logging Module not found"
            }
        }
        
        # Load Validation Module
        if ($LoadValidation) {
            if (Test-Path $Global:DevOptimizerModulePaths.ValidationModule) {
                Write-Host "[LOADER] Loading Validation Module..." -ForegroundColor Green
                Import-Module $Global:DevOptimizerModulePaths.ValidationModule -Force
                $Global:DevOptimizerModules.Validator = $Global:DevOptimizerValidator
                $Global:DevOptimizerStatus.ModulesLoaded += "Validator"
                Write-Host "[LOADER] Validation Module loaded successfully" -ForegroundColor Green
            } else {
                Write-Warning "[LOADER] Validation Module not found"
                $Global:DevOptimizerStatus.Errors += "Validation Module not found"
            }
        }
        
        # Load Ollama Module
        if ($LoadOllama) {
            if (Test-Path $Global:DevOptimizerModulePaths.OllamaModule) {
                Write-Host "[LOADER] Loading Ollama Integration Module..." -ForegroundColor Green
                Import-Module $Global:DevOptimizerModulePaths.OllamaModule -Force
                $Global:DevOptimizerModules.Ollama = $Global:DevOptimizerOllama
                $Global:DevOptimizerStatus.ModulesLoaded += "Ollama"
                Write-Host "[LOADER] Ollama Integration Module loaded successfully" -ForegroundColor Green
                
                # Test Ollama connection
                Write-Host "[LOADER] Testing Ollama connection..." -ForegroundColor Yellow
                if (Get-Command Test-OllamaConnection -ErrorAction SilentlyContinue) {
                    $connectionTest = Test-OllamaConnection
                    if ($connectionTest.IsConnected) {
                        Write-Host "[LOADER] Ollama server connected successfully" -ForegroundColor Green
                        Write-Host "[LOADER] Response time: $($connectionTest.ResponseTime)ms" -ForegroundColor Cyan
                        Write-Host "[LOADER] Available models: $($connectionTest.AvailableModels.Count)" -ForegroundColor Cyan
                    } else {
                        Write-Warning "[LOADER] Ollama server connection failed: $($connectionTest.ErrorMessage)"
                        $Global:DevOptimizerStatus.Errors += "Ollama connection failed"
                    }
                }
            } else {
                Write-Warning "[LOADER] Ollama Module not found"
                $Global:DevOptimizerStatus.Errors += "Ollama Module not found"
            }
        }
        
        # Load Error Handler Module
        if ($LoadErrorHandling) {
            if (Test-Path $Global:DevOptimizerModulePaths.ErrorHandlerModule) {
                Write-Host "[LOADER] Loading Error Handler Module..." -ForegroundColor Green
                Import-Module $Global:DevOptimizerModulePaths.ErrorHandlerModule -Force
                $Global:DevOptimizerModules.ErrorHandler = $Global:DevOptimizerErrorHandler
                $Global:DevOptimizerStatus.ModulesLoaded += "ErrorHandler"
                Write-Host "[LOADER] Error Handler Module loaded successfully" -ForegroundColor Green
            } else {
                Write-Warning "[LOADER] Error Handler Module not found"
                $Global:DevOptimizerStatus.Errors += "Error Handler Module not found"
            }
        }
        
        # Load Script Hub modules (Path, Admin) and Hub Config
        if ($LoadHub) {
            Write-Host "[LOADER] Loading Script Hub modules..." -ForegroundColor Green
            
            # Load merged hub configuration
            $hubConfigPath = "D:\DevOptimizer\config\hub-config.json"
            $baseConfigPath = $ConfigPath
            if ((Test-Path $hubConfigPath) -and (Test-Path $baseConfigPath)) {
                Write-Host "[LOADER] Loading merged Hub configuration..." -ForegroundColor Yellow
                $mergedConfig = Merge-HubConfig -BaseConfigPath $baseConfigPath -OverlayConfigPath $hubConfigPath -PassThru
                $Global:DevOptimizerModules.Config = $mergedConfig
                Write-Host "[LOADER] Hub configuration merged successfully" -ForegroundColor Green
            } else {
                Write-Warning "[LOADER] Hub config files not found, using base config only"
            }
            
            # Load Path Module
            if (Test-Path $Global:DevOptimizerModulePaths.PathModule) {
                Write-Host "[LOADER] Loading Path Module..." -ForegroundColor Green
                Import-Module $Global:DevOptimizerModulePaths.PathModule -Force -ArgumentList @{ConfigPath=$ConfigPath}
                $Global:DevOptimizerModules.Path = $Global:DevOptimizerPath
                $Global:DevOptimizerStatus.ModulesLoaded += "Path"
                Write-Host "[LOADER] Path Module loaded successfully" -ForegroundColor Green
            } else {
                Write-Warning "[LOADER] Path Module not found"
                $Global:DevOptimizerStatus.Errors += "Path Module not found"
            }
            
            # Load Admin Module
            if (Test-Path $Global:DevOptimizerModulePaths.AdminModule) {
                Write-Host "[LOADER] Loading Admin Module..." -ForegroundColor Green
                Import-Module $Global:DevOptimizerModulePaths.AdminModule -Force
                $Global:DevOptimizerModules.Admin = $Global:DevOptimizerAdmin
                $Global:DevOptimizerStatus.ModulesLoaded += "Admin"
                Write-Host "[LOADER] Admin Module loaded successfully" -ForegroundColor Green
            } else {
                Write-Warning "[LOADER] Admin Module not found"
                $Global:DevOptimizerStatus.Errors += "Admin Module not found"
            }
        }
        
        # Mark as initialized
        $Global:DevOptimizerStatus.Initialized = $true
        
        Write-Host ""
        Write-Host "===============================================================================" -ForegroundColor Green
        Write-Host "                    MODULE LOADING COMPLETE" -ForegroundColor Green
        Write-Host "===============================================================================" -ForegroundColor Green
        Write-Host ""
        
        # Display status summary
        Write-Host "[STATUS] Modules loaded: $($Global:DevOptimizerStatus.ModulesLoaded.Count)" -ForegroundColor Cyan
        Write-Host "[STATUS] Loaded modules: $($Global:DevOptimizerStatus.ModulesLoaded -join ', ')" -ForegroundColor Cyan
        
        if ($Global:DevOptimizerStatus.Errors.Count -gt 0) {
            Write-Host "[STATUS] Errors encountered: $($Global:DevOptimizerStatus.Errors.Count)" -ForegroundColor Yellow
            foreach ($error in $Global:DevOptimizerStatus.Errors) {
                Write-Host "  - $error" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[STATUS] No errors encountered" -ForegroundColor Green
        }
        
        $loadTime = (Get-Date) - $Global:DevOptimizerStatus.StartTime
        Write-Host "[STATUS] Total load time: $($loadTime.TotalMilliseconds)ms" -ForegroundColor Cyan
        
        Write-Host ""
        Write-Host "[READY] DevOptimizer system is ready for use!" -ForegroundColor Green
        
    } catch {
        Write-Error "[LOADER] Critical error during module loading: $($_.Exception.Message)"
        $Global:DevOptimizerStatus.Errors += "Critical loading error: $($_.Exception.Message)"
    }
}

# Export helper functions
function Get-DevOptimizerStatus {
    return $Global:DevOptimizerStatus
}

function Test-DevOptimizerModules {
    $status = @{
        AllLoaded = $Global:DevOptimizerStatus.Initialized
        ModuleCount = $Global:DevOptimizerStatus.ModulesLoaded.Count
        Errors = $Global:DevOptimizerStatus.Errors.Count
        Modules = $Global:DevOptimizerStatus.ModulesLoaded
    }
    return $status
}

function Restart-DevOptimizerModules {
    param(
        [string]$ConfigPath = "D:\DevOptimizer\config\devoptimizer-config.json",
        [bool]$LoadOllama = $true,
        [bool]$LoadLogging = $true,
        [bool]$LoadValidation = $true,
        [bool]$LoadErrorHandling = $true,
        [bool]$LoadHub = $false
    )
    Write-Host "[RESTART] Restarting DevOptimizer modules..." -ForegroundColor Yellow
    
    # Clear global variables
    $Global:DevOptimizerModules = @{
        Config = $null
        Logger = $null
        Validator = $null
        Ollama = $null
        ErrorHandler = $null
        Path = $null
        Admin = $null
    }
    
    # Reload modules
    Initialize-DevOptimizerMaster -ConfigPath $ConfigPath -LoadOllama $LoadOllama -LoadLogging $LoadLogging -LoadValidation $LoadValidation -LoadErrorHandling $LoadErrorHandling -LoadHub $LoadHub
}

Export-ModuleMember -Function Initialize-DevOptimizerMaster, Get-DevOptimizerStatus, Test-DevOptimizerModules, Restart-DevOptimizerModules

Write-Host "[INIT] DevOptimizer Master Module Loader initialized" -ForegroundColor Cyan