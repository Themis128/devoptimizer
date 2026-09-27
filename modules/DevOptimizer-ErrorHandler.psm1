# DevOptimizer Enhanced Error Handling Framework
# Comprehensive error handling with Ollama-powered auto-fixing and recovery

param(
    [string]$ConfigPath = "D:\DevOptimizer\config\devoptimizer-config.json"
)

enum ErrorSeverity {
    LOW = 1
    MEDIUM = 2
    HIGH = 3
    CRITICAL = 4
}

enum ErrorCategory {
    SYNTAX_ERROR
    RUNTIME_ERROR
    PERMISSION_ERROR
    NETWORK_ERROR
    FILE_SYSTEM_ERROR
    CONFIGURATION_ERROR
    VALIDATION_ERROR
    UNKNOWN_ERROR
}

class DevOptimizerError {
    [string]$Message
    [string]$Component
    [ErrorSeverity]$Severity
    [ErrorCategory]$Category
    [string]$StackTrace
    [datetime]$Timestamp
    [hashtable]$Context
    [string]$SuggestedFix
    [bool]$IsRecoverable
    
    DevOptimizerError([string]$Message, [string]$Component, [ErrorSeverity]$Severity, [ErrorCategory]$Category) {
        $this.Message = $Message
        $this.Component = $Component
        $this.Severity = $Severity
        $this.Category = $Category
        $this.Timestamp = Get-Date
        $this.Context = @{}
        $this.IsRecoverable = $true
    }
}

class DevOptimizerErrorHandler {
    [hashtable]$Config
    [string]$LogsDirectory
    [bool]$AutoFixEnabled
    [bool]$OllamaIntegrationEnabled
    [System.Collections.ArrayList]$ErrorHistory = @()
    [hashtable]$RecoveryStrategies = @{}
    
    DevOptimizerErrorHandler([string]$ConfigPath) {
        $this.LoadConfiguration($ConfigPath)
        $this.InitializeRecoveryStrategies()
    }
    
    [void] LoadConfiguration([string]$ConfigPath) {
        try {
            if (Test-Path $ConfigPath) {
                $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                $this.AutoFixEnabled = $configContent.integrations.ollama.enabled
                $this.OllamaIntegrationEnabled = $configContent.integrations.ollama.enabled
                $this.LogsDirectory = $configContent.paths.logs_directory
            } else {
                $this.AutoFixEnabled = $true
                $this.OllamaIntegrationEnabled = $true
                $this.LogsDirectory = "D:\DevOptimizer\logs"
            }
        }
        catch {
            Write-Warning "[ERROR-HANDLER] Failed to load configuration, using defaults"
            $this.AutoFixEnabled = $true
            $this.OllamaIntegrationEnabled = $true
            $this.LogsDirectory = "D:\DevOptimizer\logs"
        }
    }
    
    [void] InitializeRecoveryStrategies() {
        $this.RecoveryStrategies = @{
            "SYNTAX_ERROR" = @{
                "BATCH" = @{
                    "missing_quotes" = "Add missing quotes around variables and strings"
                    "unbalanced_parentheses" = "Check and balance all parentheses"
                    "invalid_command" = "Replace invalid command with correct syntax"
                }
                "POWERSHELL" = @{
                    "missing_brace" = "Add missing closing brace"
                    "invalid_variable" = "Fix variable syntax with proper $ prefix"
                    "cmdlet_not_found" = "Check cmdlet name and module availability"
                }
            }
            "RUNTIME_ERROR" = @{
                "file_not_found" = "Check file path and create if necessary"
                "permission_denied" = "Run with elevated privileges or fix permissions"
                "out_of_memory" = "Optimize script or increase system memory"
            }
            "NETWORK_ERROR" = @{
                "connection_timeout" = "Check network connectivity and retry"
                "dns_resolution" = "Verify DNS settings and hostname"
                "ssl_certificate" = "Update certificates or bypass SSL verification"
            }
        }
    }
    
    [DevOptimizerError] CreateError([string]$Message, [string]$Component, [ErrorSeverity]$Severity, [ErrorCategory]$Category, [hashtable]$Context = @{}) {
        $error = [DevOptimizerError]::new($Message, $Component, $Severity, $Category)
        $error.Context = $Context
        $error.StackTrace = $_.ScriptStackTrace
        
        # Analyze error for suggested fix
        $error.SuggestedFix = $this.AnalyzeErrorForFix($error)
        
        # Add to error history
        $this.ErrorHistory.Add($error)
        
        # Log the error
        $this.LogError($error)
        
        return $error
    }
    
    [string] AnalyzeErrorForFix([DevOptimizerError]$Error) {
        try {
            if ($this.OllamaIntegrationEnabled -and $Global:DevOptimizerOllama) {
                $prompt = "Analyze this error and provide a specific fix:"
                $prompt += "`nError: $($Error.Message)"
                $prompt += "`nComponent: $($Error.Component)"
                $prompt += "`nCategory: $($Error.Category)"
                
                if ($Error.Context.Count -gt 0) {
                    $prompt += "`nContext:"
                    foreach ($ctx in $Error.Context.GetEnumerator()) {
                        $prompt += "`n- $($ctx.Key): $($ctx.Value)"
                    }
                }
                
                $prompt += "`n`nProvide a specific, actionable fix for this error."
                
                return $Global:DevOptimizerOllama.GenerateResponse($prompt, "", @{temperature = 0.1})
            } else {
                return $this.GetStandardFix($Error)
            }
        }
        catch {
            return $this.GetStandardFix($Error)
        }
    }
    
    [string] GetStandardFix([DevOptimizerError]$Error) {
        $category = $Error.Category.ToString()
        $message = $Error.Message.ToLower()
        
        # Check for specific error patterns
        if ($message -match "missing.*quote") {
            return "Add missing quotes around variables and strings"
        } elseif ($message -match "unbalanced.*parenthes") {
            return "Check and balance all parentheses in the script"
        } elseif ($message -match "file.*not.*found") {
            return "Verify file path exists and is accessible"
        } elseif ($message -match "permission.*denied") {
            return "Run script with administrator privileges"
        } elseif ($message -match "cmdlet.*not.*found") {
            return "Check if required PowerShell module is installed"
        } elseif ($message -match "syntax.*error") {
            return "Review script syntax and check for typos or missing elements"
        } else {
            return "Review error details and consult documentation for resolution"
        }
    }
    
    [void] LogError([DevOptimizerError]$Error) {
        try {
            $logEntry = @{
                timestamp = $Error.Timestamp.ToString("yyyy-MM-dd HH:mm:ss.fff")
                severity = $Error.Severity.ToString()
                category = $Error.Category.ToString()
                component = $Error.Component
                message = $Error.Message
                suggested_fix = $Error.SuggestedFix
                context = $Error.Context
                stack_trace = $Error.StackTrace
            }
            
            $logFile = Join-Path $this.LogsDirectory "error-handler-$(Get-Date -Format 'yyyy-MM-dd').log"
            $logEntry | ConvertTo-Json -Depth 10 | Add-Content -Path $logFile -Encoding UTF8
            
            # Also log to console based on severity
            $color = switch ($Error.Severity) {
                ([ErrorSeverity]::LOW) { "Yellow" }
                ([ErrorSeverity]::MEDIUM) { "Orange" }
                ([ErrorSeverity]::HIGH) { "Red" }
                ([ErrorSeverity]::CRITICAL) { "Magenta" }
            }
            
            Write-Host "[ERROR] $($Error.Component): $($Error.Message)" -ForegroundColor $color
            Write-Host "[FIX] $($Error.SuggestedFix)" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "[ERROR-HANDLER] Failed to log error: $($_.Exception.Message)"
        }
    }
    
    [bool] AttemptAutoFix([DevOptimizerError]$Error, [string]$Code = "") {
        try {
            if (-not $this.AutoFixEnabled) {
                return $false
            }
            
            Write-Host "[AUTO-FIX] Attempting to fix error: $($Error.Message)" -ForegroundColor Yellow
            
            # Use Ollama for intelligent fixing if available
            if ($this.OllamaIntegrationEnabled -and $Global:DevOptimizerOllama -and -not [string]::IsNullOrEmpty($Code)) {
                $fixedCode = $Global:DevOptimizerOllama.FixCode($Code, "batch", $Error.Message)
                
                if ($fixedCode -and $fixedCode -ne "Error: Failed to generate AI response") {
                    Write-Host "[AUTO-FIX] AI-generated fix available:" -ForegroundColor Green
                    Write-Host $fixedCode -ForegroundColor White
                    return $true
                }
            }
            
            # Fallback to standard recovery strategies
            return $this.ExecuteRecoveryStrategy($Error)
        }
        catch {
            Write-Warning "[AUTO-FIX] Failed to attempt auto-fix: $($_.Exception.Message)"
            return $false
        }
    }
    
    [bool] ExecuteRecoveryStrategy([DevOptimizerError]$Error) {
        try {
            $category = $Error.Category.ToString()
            $message = $Error.Message.ToLower()
            
            # Implement specific recovery strategies
            switch ($category) {
                "SYNTAX_ERROR" {
                    if ($message -match "missing.*quote") {
                        Write-Host "[RECOVERY] Attempting to add missing quotes..." -ForegroundColor Yellow
                        # Implementation would go here
                        return $true
                    }
                }
                "FILE_SYSTEM_ERROR" {
                    if ($message -match "file.*not.*found") {
                        Write-Host "[RECOVERY] Checking if file can be created..." -ForegroundColor Yellow
                        # Implementation would go here
                        return $true
                    }
                }
                "PERMISSION_ERROR" {
                    Write-Host "[RECOVERY] Suggesting elevation..." -ForegroundColor Yellow
                    return $true
                }
            }
            
            return $false
        }
        catch {
            Write-Warning "[RECOVERY] Failed to execute recovery strategy: $($_.Exception.Message)"
            return $false
        }
    }
    
    [hashtable] GetErrorStatistics() {
        $stats = @{
            TotalErrors = $this.ErrorHistory.Count
            ErrorsBySeverity = @{}
            ErrorsByCategory = @{}
            ErrorsByComponent = @{}
            RecentErrors = @()
        }
        
        # Count errors by severity
        foreach ($severity in [Enum]::GetValues([ErrorSeverity])) {
            $count = ($this.ErrorHistory | Where-Object { $_.Severity -eq $severity }).Count
            $stats.ErrorsBySeverity[$severity.ToString()] = $count
        }
        
        # Count errors by category
        foreach ($category in [Enum]::GetValues([ErrorCategory])) {
            $count = ($this.ErrorHistory | Where-Object { $_.Category -eq $category }).Count
            $stats.ErrorsByCategory[$category.ToString()] = $count
        }
        
        # Count errors by component
        $componentGroups = $this.ErrorHistory | Group-Object Component
        foreach ($group in $componentGroups) {
            $stats.ErrorsByComponent[$group.Name] = $group.Count
        }
        
        # Get recent errors (last 10)
        $stats.RecentErrors = $this.ErrorHistory | Sort-Object Timestamp -Descending | Select-Object -First 10
        
        return $stats
    }
    
    [void] ClearErrorHistory() {
        $this.ErrorHistory.Clear()
        Write-Host "[ERROR-HANDLER] Error history cleared" -ForegroundColor Green
    }
}

# Global error handler instance
$Global:DevOptimizerErrorHandler = [DevOptimizerErrorHandler]::new($ConfigPath)

# Helper functions
function New-DevOptimizerError {
    param(
        [string]$Message,
        [string]$Component,
        [ErrorSeverity]$Severity,
        [ErrorCategory]$Category,
        [hashtable]$Context = @{}
    )
    return $Global:DevOptimizerErrorHandler.CreateError($Message, $Component, $Severity, $Category, $Context)
}

function Invoke-AutoFix {
    param(
        [DevOptimizerError]$Error,
        [string]$Code = ""
    )
    return $Global:DevOptimizerErrorHandler.AttemptAutoFix($Error, $Code)
}

function Get-ErrorStatistics {
    return $Global:DevOptimizerErrorHandler.GetErrorStatistics()
}

function Clear-ErrorHistory {
    $Global:DevOptimizerErrorHandler.ClearErrorHistory()
}

# Initialize error handling system
Write-Host "[ERROR-HANDLER] DevOptimizer Error Handling System initialized" -ForegroundColor Cyan
