# DevOptimizer System - Ollama REST Client Module
# This module provides REST API integration for Ollama server with laptop optimization

param(
    [string]$ServerUrl = "http://127.0.0.1:11434",
    [int]$TimeoutSeconds = 30,
    [int]$MaxRetries = 3,
    [int]$KeepAliveSeconds = 600
)

# Global variables
$Global:OllamaServerUrl = $ServerUrl
$Global:OllamaTimeout = $TimeoutSeconds
$Global:OllamaMaxRetries = $MaxRetries

function Test-OllamaServerHealth {
    <#
    .SYNOPSIS
    Tests if the Ollama server is healthy and responsive.

    .DESCRIPTION
    Performs multiple health checks to ensure the Ollama server is working properly.

    .OUTPUTS
    PSCustomObject. Health status with details.
    #>
    param(
        [string]$ServerUrl = $Global:OllamaServerUrl,
        [int]$TimeoutSeconds = $Global:OllamaTimeout
    )

    $healthResult = @{
        IsHealthy = $false
        ServerUrl = $ServerUrl
        Checks = @{
            ApiReachable = $false
            ModelsAvailable = $false
            GenerateWorking = $false
            EmbeddingsWorking = $false
        }
        Errors = @()
        Models = @()
        ResponseTime = 0
    }

    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Check 1: API reachable
        try {
            $response = Invoke-RestMethod -Uri "$ServerUrl/api/tags" -Method GET -TimeoutSec $TimeoutSeconds
            $healthResult.Checks.ApiReachable = $true
            if ($response.models) {
                $healthResult.Models = $response.models
                $healthResult.Checks.ModelsAvailable = $healthResult.Models.Count -gt 0
            }
        } catch {
            $healthResult.Errors += "API reachable check failed: $($_.Exception.Message)"
        }

        # Check 2: Generate endpoint working (1-token probe)
        if ($healthResult.Checks.ApiReachable) {
            try {
                $testPrompt = @{
                    model = if ($healthResult.Models.Count -gt 0) { $healthResult.Models[0].name } else { "llama2:7b" }
                    prompt = "ok"
                    stream = $false
                    options = @{
                        num_predict = 1
                        temperature = 0
                    }
                }

                $generateResponse = Invoke-RestMethod -Uri "$ServerUrl/api/generate" -Method POST -Body ($testPrompt | ConvertTo-Json) -ContentType "application/json" -TimeoutSec $TimeoutSeconds
                if ($generateResponse.response) {
                    $healthResult.Checks.GenerateWorking = $true
                }
            } catch {
                $healthResult.Errors += "Generate check failed: $($_.Exception.Message)"
            }
        }

        # Check 3: Embeddings endpoint working
        if ($healthResult.Checks.ApiReachable) {
            try {
                $embeddingRequest = @{
                    model = if ($healthResult.Models.Count -gt 0) { $healthResult.Models[0].name } else { "llama2:7b" }
                    prompt = "test"
                }

                $embeddingResponse = Invoke-RestMethod -Uri "$ServerUrl/api/embeddings" -Method POST -Body ($embeddingRequest | ConvertTo-Json) -ContentType "application/json" -TimeoutSec $TimeoutSeconds
                if ($embeddingResponse.embedding -and $embeddingResponse.embedding.Count -gt 0) {
                    $healthResult.Checks.EmbeddingsWorking = $true
                }
            } catch {
                $healthResult.Errors += "Embeddings check failed: $($_.Exception.Message)"
            }
        }

        $stopwatch.Stop()
        $healthResult.ResponseTime = $stopwatch.ElapsedMilliseconds

        # Overall health assessment
        $healthResult.IsHealthy = $healthResult.Checks.ApiReachable -and $healthResult.Checks.ModelsAvailable

        Write-Log "Ollama server health check completed in $($healthResult.ResponseTime)ms" -Level "INFO" -Component "OllamaREST"
        if ($healthResult.IsHealthy) {
            Write-Log "Server is healthy with $($healthResult.Models.Count) models available" -Level "INFO" -Component "OllamaREST"
        } else {
            Write-Log "Server health issues detected: $($healthResult.Errors -join '; ')" -Level "WARN" -Component "OllamaREST"
        }

        return $healthResult

    } catch {
        $healthResult.Errors += "Health check failed: $($_.Exception.Message)"
        Write-Log "Ollama server health check failed: $($_.Exception.Message)" -Level "ERROR" -Component "OllamaREST"
        return $healthResult
    }
}

function Get-OllamaModels {
    <#
    .SYNOPSIS
    Gets the list of available Ollama models via REST API.

    .DESCRIPTION
    Retrieves all available models from the Ollama server.

    .PARAMETER ServerUrl
    URL of the Ollama server.

    .OUTPUTS
    Array. List of available models.
    #>
    param(
        [string]$ServerUrl = $Global:OllamaServerUrl,
        [int]$TimeoutSeconds = $Global:OllamaTimeout
    )

    try {
        $response = Invoke-RestMethod -Uri "$ServerUrl/api/tags" -Method GET -TimeoutSec $TimeoutSeconds
        $models = @()

        if ($response.models) {
            foreach ($model in $response.models) {
                $models += @{
                    Name = $model.name
                    Size = $model.size
                    ModifiedAt = $model.modified_at
                    Family = $model.family
                    Format = $model.format
                    Families = $model.families
                    ParameterSize = $model.parameter_size
                    QuantizationLevel = $model.quantization_level
                }
            }
        }

        Write-Log "Retrieved $($models.Count) models from Ollama server" -Level "INFO" -Component "OllamaREST"
        return $models

    } catch {
        Write-Log "Failed to retrieve models from Ollama server: $($_.Exception.Message)" -Level "ERROR" -Component "OllamaREST"
        return @()
    }
}

function Invoke-OllamaGenerate {
    <#
    .SYNOPSIS
    Generates text using Ollama REST API with streaming support.

    .DESCRIPTION
    Sends a generation request to Ollama and optionally streams the response.

    .PARAMETER Model
    Name of the model to use.

    .PARAMETER Prompt
    Text prompt for generation.

    .PARAMETER Stream
    Whether to stream the response.

    .PARAMETER Options
    Additional generation options.

    .OUTPUTS
    PSCustomObject. Generation response or streamed tokens.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Model,

        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [bool]$Stream = $false,

        [hashtable]$Options = @{},

        [string]$ServerUrl = $Global:OllamaServerUrl,
        [int]$TimeoutSeconds = $Global:OllamaTimeout,
        [int]$MaxRetries = $Global:OllamaMaxRetries
    )

    # Input validation
    if ([string]::IsNullOrWhiteSpace($Model)) {
        throw "Model name cannot be empty"
    }

    if ([string]::IsNullOrWhiteSpace($Prompt)) {
        throw "Prompt cannot be empty"
    }

    # Check prompt size (limit to 8000 chars for laptop optimization)
    if ($Prompt.Length -gt 8000) {
        Write-Log "Prompt truncated from $($Prompt.Length) to 8000 characters for laptop optimization" -Level "WARN" -Component "OllamaREST"
        $Prompt = $Prompt.Substring(0, 8000)
    }

    $requestBody = @{
        model = $Model
        prompt = $Prompt
        stream = $Stream
    }

    # Add options with laptop-optimized defaults
    $defaultOptions = @{
        temperature = 0.7
        top_p = 0.9
        top_k = 40
        repeat_penalty = 1.1
        num_predict = 512  # Limit for laptop
        num_ctx = 2048     # Smaller context window
    }

    foreach ($key in $defaultOptions.Keys) {
        if (-not $Options.ContainsKey($key)) {
            $Options[$key] = $defaultOptions[$key]
        }
    }

    $requestBody.options = $Options

    $attempt = 0
    $baseDelay = 0.5

    while ($attempt -lt $MaxRetries) {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            if ($Stream) {
                # Handle streaming response
                $response = Invoke-RestMethod -Uri "$ServerUrl/api/generate" -Method POST -Body ($requestBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec $TimeoutSeconds

                # For streaming, we'll return the raw response
                $stopwatch.Stop()
                Write-Log "Streaming generation completed for model '$Model' in $($stopwatch.ElapsedMilliseconds)ms" -Level "INFO" -Component "OllamaREST"
                return $response
            } else {
                # Handle non-streaming response
                $response = Invoke-RestMethod -Uri "$ServerUrl/api/generate" -Method POST -Body ($requestBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec $TimeoutSeconds

                $stopwatch.Stop()

                # Log metrics
                $metrics = @{
                    Model = $Model
                    PromptLength = $Prompt.Length
                    ResponseLength = if ($response.response) { $response.response.Length } else { 0 }
                    Duration = $stopwatch.ElapsedMilliseconds
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    Status = "Success"
                }

                Write-OllamaLog -Metrics $metrics
                Write-Log "Generation completed for model '$Model' in $($stopwatch.ElapsedMilliseconds)ms" -Level "INFO" -Component "OllamaREST"

                return @{
                    Response = $response.response
                    Model = $Model
                    CreatedAt = $response.created_at
                    Done = $response.done
                    Context = $response.context
                    TotalDuration = $response.total_duration
                    LoadDuration = $response.load_duration
                    PromptEvalCount = $response.prompt_eval_count
                    PromptEvalDuration = $response.prompt_eval_duration
                    EvalCount = $response.eval_count
                    EvalDuration = $response.eval_duration
                }
            }

        } catch {
            $attempt++
            $delay = $baseDelay * [Math]::Pow(2, $attempt - 1)

            Write-Log "Generation attempt $attempt failed for model '$Model': $($_.Exception.Message)" -Level "WARN" -Component "OllamaREST"

            if ($attempt -ge $MaxRetries) {
                # Log failure metrics
                $metrics = @{
                    Model = $Model
                    PromptLength = $Prompt.Length
                    ResponseLength = 0
                    Duration = 0
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    Status = "Failed"
                    Error = $_.Exception.Message
                }

                Write-OllamaLog -Metrics $metrics
                throw "Failed to generate after $MaxRetries attempts: $($_.Exception.Message)"
            }

            Write-Log "Retrying in $delay seconds..." -Level "INFO" -Component "OllamaREST"
            Start-Sleep -Seconds $delay
        }
    }
}

function Invoke-OllamaEmbeddings {
    <#
    .SYNOPSIS
    Generates embeddings using Ollama REST API.

    .DESCRIPTION
    Creates embeddings for the given text prompt.

    .PARAMETER Model
    Name of the model to use for embeddings.

    .PARAMETER Prompt
    Text to create embeddings for.

    .OUTPUTS
    Array. Embedding vector.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Model,

        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [string]$ServerUrl = $Global:OllamaServerUrl,
        [int]$TimeoutSeconds = $Global:OllamaTimeout
    )

    try {
        $requestBody = @{
            model = $Model
            prompt = $Prompt
        }

        $response = Invoke-RestMethod -Uri "$ServerUrl/api/embeddings" -Method POST -Body ($requestBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec $TimeoutSeconds

        Write-Log "Generated embeddings for model '$Model' (vector length: $($response.embedding.Count))" -Level "INFO" -Component "OllamaREST"

        return @{
            Embedding = $response.embedding
            Model = $Model
        }

    } catch {
        Write-Log "Failed to generate embeddings for model '$Model': $($_.Exception.Message)" -Level "ERROR" -Component "OllamaREST"
        throw "Failed to generate embeddings: $($_.Exception.Message)"
    }
}

function Find-OpenPort {
    <#
    .SYNOPSIS
    Finds an open port starting from a base port.

    .DESCRIPTION
    Scans ports starting from the base port to find an available one.

    .PARAMETER BasePort
    Starting port number.

    .PARAMETER MaxAttempts
    Maximum number of ports to check.

    .OUTPUTS
    Integer. First available port number, or null if none found.
    #>
    param(
        [int]$BasePort = 11434,
        [int]$MaxAttempts = 10
    )

    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        $port = $BasePort + $i
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
            $listener.Start()
            $listener.Stop()
            Write-Log "Found open port: $port" -Level "INFO" -Component "OllamaREST"
            return $port
        } catch {
            # Port is in use, try next one
            continue
        }
    }

    Write-Log "No open ports found in range $BasePort to $($BasePort + $MaxAttempts - 1)" -Level "WARN" -Component "OllamaREST"
    return $null
}

function Write-OllamaLog {
    <#
    .SYNOPSIS
    Writes structured logs for Ollama operations.

    .DESCRIPTION
    Creates JSONL logs for monitoring and analysis.

    .PARAMETER Metrics
    Hashtable of metrics to log.
    #>
    param(
        [hashtable]$Metrics
    )

    try {
        $logDir = "logs\ollama"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        $logFile = Join-Path $logDir "ollama-$(Get-Date -Format 'yyyy-MM-dd').jsonl"
        $logEntry = $Metrics | ConvertTo-Json -Compress
        Add-Content -Path $logFile -Value $logEntry -Encoding UTF8

    } catch {
        Write-Log "Failed to write Ollama log: $($_.Exception.Message)" -Level "ERROR" -Component "OllamaREST"
    }
}

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
    Export-ModuleMember -Function Test-OllamaServerHealth, Get-OllamaModels, Invoke-OllamaGenerate, Invoke-OllamaEmbeddings, Find-OpenPort, Write-OllamaLog
}
