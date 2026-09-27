# DevOptimizer Ollama Integration Module
# Comprehensive integration with local Ollama server for AI-powered features

param(
    [string]$ConfigPath = "D:\DevOptimizer\config\devoptimizer-config.json"
)

class OllamaIntegration {
    [hashtable]$Config
    [string]$ServerUrl
    [string]$DefaultModel
    [string]$FallbackModel
    [int]$Timeout
    [bool]$AutoConnect
    [int]$RetryAttempts
    [int]$RetryDelay
    [string[]]$AvailableModels
    [bool]$IsConnected = $false
    [datetime]$LastHealthCheck = [datetime]::MinValue
    
    OllamaIntegration([string]$ConfigPath) {
        $this.LoadConfiguration($ConfigPath)
        if ($this.AutoConnect) {
            $this.Connect()
        }
    }
    
    [void] LoadConfiguration([string]$ConfigPath) {
        try {
            if (Test-Path $ConfigPath) {
                $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                $ollamaConfig = $configContent.integrations.ollama
                
                $this.ServerUrl = $ollamaConfig.server_url
                $this.DefaultModel = $ollamaConfig.default_model
                $this.FallbackModel = $ollamaConfig.fallback_model
                $this.Timeout = $ollamaConfig.timeout
                $this.AutoConnect = $ollamaConfig.auto_connect
                $this.RetryAttempts = $ollamaConfig.retry_attempts
                $this.RetryDelay = $ollamaConfig.retry_delay
                $this.AvailableModels = $ollamaConfig.available_models
                
                Write-Host "[OLLAMA] Configuration loaded successfully" -ForegroundColor Green
            } else {
                $this.SetDefaultConfiguration()
            }
        }
        catch {
            Write-Warning "[OLLAMA] Failed to load configuration, using defaults"
            $this.SetDefaultConfiguration()
        }
    }
    
    [void] SetDefaultConfiguration() {
        $this.ServerUrl = "http://localhost:11434"
        $this.DefaultModel = "qwen2.5:7b"
        $this.FallbackModel = "qwen2.5:1.5b"
        $this.Timeout = 30
        $this.AutoConnect = $true
        $this.RetryAttempts = 3
        $this.RetryDelay = 5
        $this.AvailableModels = @("qwen2.5:7b", "qwen2.5-coder:7b", "qwen2.5:1.5b")
    }
    
    [bool] Connect() {
        try {
            Write-Host "[OLLAMA] Attempting to connect to server at $($this.ServerUrl)..." -ForegroundColor Yellow
            
            $response = Invoke-RestMethod -Uri "$($this.ServerUrl)/api/tags" -Method Get -TimeoutSec $this.Timeout
            $this.IsConnected = $true
            $this.LastHealthCheck = Get-Date
            
            Write-Host "[OLLAMA] Successfully connected to Ollama server" -ForegroundColor Green
            Write-Host "[OLLAMA] Available models: $($response.models.Count)" -ForegroundColor Cyan
            
            return $true
        }
        catch {
            Write-Warning "[OLLAMA] Failed to connect to server: $($_.Exception.Message)"
            $this.IsConnected = $false
            return $false
        }
    }
    
    [bool] IsHealthy() {
        try {
            $timeSinceLastCheck = (Get-Date) - $this.LastHealthCheck
            if ($timeSinceLastCheck.TotalMinutes -lt 5) {
                return $this.IsConnected
            }
            
            $response = Invoke-RestMethod -Uri "$($this.ServerUrl)/api/tags" -Method Get -TimeoutSec 10
            $this.IsConnected = $true
            $this.LastHealthCheck = Get-Date
            return $true
        }
        catch {
            $this.IsConnected = $false
            return $false
        }
    }
    
    [string] GenerateResponse([string]$Prompt, [string]$Model = "", [hashtable]$Options = @{}) {
        if (-not $this.IsHealthy()) {
            if (-not $this.Connect()) {
                return "Error: Unable to connect to Ollama server"
            }
        }
        
        try {
            $modelToUse = if ([string]::IsNullOrEmpty($Model)) { $this.DefaultModel } else { $Model }
            
            # Validate model is available
            if ($modelToUse -notin $this.AvailableModels) {
                Write-Warning "[OLLAMA] Model $modelToUse not in available models, using fallback: $($this.FallbackModel)"
                $modelToUse = $this.FallbackModel
            }
            
            $requestBody = @{
                model = $modelToUse
                prompt = $Prompt
                stream = $false
            }
            
            # Add any additional options
            foreach ($option in $Options.GetEnumerator()) {
                $requestBody[$option.Key] = $option.Value
            }
            
            $jsonBody = $requestBody | ConvertTo-Json -Depth 10
            
            Write-Host "[OLLAMA] Sending request to model: $modelToUse" -ForegroundColor Cyan
            
            $response = Invoke-RestMethod -Uri "$($this.ServerUrl)/api/generate" -Method Post -Body $jsonBody -ContentType "application/json" -TimeoutSec $this.Timeout
            
            return $response.response
        }
        catch {
            Write-Error "[OLLAMA] Failed to generate response: $($_.Exception.Message)"
            return "Error: Failed to generate AI response"
        }
    }
    
    [string] AnalyzeCode([string]$Code, [string]$Language = "batch", [string]$AnalysisType = "general") {
        $prompt = switch ($AnalysisType.ToLower()) {
            "syntax" { 
                "Analyze this $Language code for syntax errors, missing quotes, unbalanced parentheses, and other structural issues. Provide specific line numbers and fixes:"
            }
            "optimization" { 
                "Analyze this $Language code for performance optimizations, best practices, and improvements. Focus on efficiency and maintainability:"
            }
            "security" { 
                "Analyze this $Language code for security vulnerabilities, input validation issues, and potential exploits:"
            }
            "error_handling" { 
                "Analyze this $Language code for error handling improvements, exception management, and robustness enhancements:"
            }
            default { 
                "Analyze this $Language code and provide general feedback on structure, best practices, and potential improvements:"
            }
        }
        
        $fullPrompt = "$prompt`n`n```$Language`n$Code`n```"
        return $this.GenerateResponse($fullPrompt, "", @{temperature = 0.1})
    }
    
    [string] FixCode([string]$Code, [string]$Language = "batch", [string]$ErrorDescription = "") {
        $prompt = "Fix the following $Language code. "
        
        if (-not [string]::IsNullOrEmpty($ErrorDescription)) {
            $prompt += "Error description: $ErrorDescription. "
        }
        
        $prompt += "Provide the corrected code with explanations of what was fixed:"
        $fullPrompt = "$prompt`n`n```$Language`n$Code`n```"
        
        return $this.GenerateResponse($fullPrompt, "", @{temperature = 0.1})
    }
    
    [string] GenerateScript([string]$Description, [string]$Language = "batch", [hashtable]$Requirements = @{}) {
        $prompt = "Generate a $Language script based on the following description: $Description"
        
        if ($Requirements.Count -gt 0) {
            $prompt += "`n`nRequirements:"
            foreach ($req in $Requirements.GetEnumerator()) {
                $prompt += "`n- $($req.Key): $($req.Value)"
            }
        }
        
        $prompt += "`n`nProvide a complete, working script with proper error handling and comments."
        
        return $this.GenerateResponse($prompt, "", @{temperature = 0.3})
    }
    
    [string] ExplainError([string]$ErrorMessage, [string]$Context = "") {
        $prompt = "Explain this error message and provide solutions: $ErrorMessage"
        
        if (-not [string]::IsNullOrEmpty($Context)) {
            $prompt += "`n`nContext: $Context"
        }
        
        $prompt += "`n`nProvide clear explanations and step-by-step solutions."
        
        return $this.GenerateResponse($prompt, "", @{temperature = 0.2})
    }
    
    [hashtable] GetSystemRecommendations([hashtable]$SystemInfo) {
        $prompt = "Based on the following system information, provide optimization recommendations:"
        $prompt += "`n`nSystem Info:"
        foreach ($info in $SystemInfo.GetEnumerator()) {
            $prompt += "`n- $($info.Key): $($info.Value)"
        }
        $prompt += "`n`nProvide specific, actionable recommendations for system optimization."
        
        $response = $this.GenerateResponse($prompt, "", @{temperature = 0.2})
        
        return @{
            recommendations = $response
            timestamp = Get-Date
            model_used = $this.DefaultModel
        }
    }
    
    [string[]] GetAvailableModels() {
        try {
            if (-not $this.IsHealthy()) {
                return $this.AvailableModels
            }
            
            $response = Invoke-RestMethod -Uri "$($this.ServerUrl)/api/tags" -Method Get -TimeoutSec 10
            $models = @()
            
            foreach ($model in $response.models) {
                $models += $model.name
            }
            
            return $models
        }
        catch {
            Write-Warning "[OLLAMA] Failed to get available models: $($_.Exception.Message)"
            return $this.AvailableModels
        }
    }
    
    [bool] PullModel([string]$ModelName) {
        try {
            Write-Host "[OLLAMA] Pulling model: $ModelName" -ForegroundColor Yellow
            
            $requestBody = @{
                name = $ModelName
                stream = $false
            }
            
            $jsonBody = $requestBody | ConvertTo-Json
            
            $response = Invoke-RestMethod -Uri "$($this.ServerUrl)/api/pull" -Method Post -Body $jsonBody -ContentType "application/json" -TimeoutSec 300
            
            Write-Host "[OLLAMA] Successfully pulled model: $ModelName" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Error "[OLLAMA] Failed to pull model $ModelName : $($_.Exception.Message)"
            return $false
        }
    }
    
    [hashtable] TestConnection() {
        $result = @{
            IsConnected = $false
            ServerUrl = $this.ServerUrl
            ResponseTime = 0
            AvailableModels = @()
            ErrorMessage = ""
        }
        
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-RestMethod -Uri "$($this.ServerUrl)/api/tags" -Method Get -TimeoutSec 10
            $stopwatch.Stop()
            
            $result.IsConnected = $true
            $result.ResponseTime = $stopwatch.ElapsedMilliseconds
            $result.AvailableModels = $response.models | ForEach-Object { $_.name }
            
            $this.IsConnected = $true
            $this.LastHealthCheck = Get-Date
        }
        catch {
            $result.ErrorMessage = $_.Exception.Message
            $this.IsConnected = $false
        }
        
        return $result
    }
}

# Global Ollama integration instance
$Global:DevOptimizerOllama = [OllamaIntegration]::new($ConfigPath)

# Helper functions
function Invoke-OllamaAnalysis {
    param(
        [string]$Code,
        [string]$Language = "batch",
        [string]$AnalysisType = "general"
    )
    return $Global:DevOptimizerOllama.AnalyzeCode($Code, $Language, $AnalysisType)
}

function Invoke-OllamaFix {
    param(
        [string]$Code,
        [string]$Language = "batch",
        [string]$ErrorDescription = ""
    )
    return $Global:DevOptimizerOllama.FixCode($Code, $Language, $ErrorDescription)
}

function Invoke-OllamaGenerate {
    param(
        [string]$Description,
        [string]$Language = "batch",
        [hashtable]$Requirements = @{}
    )
    return $Global:DevOptimizerOllama.GenerateScript($Description, $Language, $Requirements)
}

function Test-OllamaConnection {
    return $Global:DevOptimizerOllama.TestConnection()
}

function Get-OllamaModels {
    return $Global:DevOptimizerOllama.GetAvailableModels()
}

function Invoke-OllamaQuery {
    param(
        [string]$Prompt,
        [string]$Model = "",
        [hashtable]$Options = @{}
    )
    return $Global:DevOptimizerOllama.GenerateResponse($Prompt, $Model, $Options)
}

# Initialize Ollama integration
Write-Host "[OLLAMA] DevOptimizer Ollama Integration initialized" -ForegroundColor Cyan
