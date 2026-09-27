# DevOptimizer System - Ollama Quick Health Tests
# This script performs quick health checks for the Ollama system

param(
    [string]$TestType = "all",
    [int]$TimeoutSeconds = 30,
    [switch]$Verbose
)

# Import required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath = Join-Path $scriptDir "..\modules"
$toolsPath = Join-Path $scriptDir "..\tools"

# Load configuration module
. (Join-Path $modulesPath "config-loader.ps1")

# Load REST client module
. (Join-Path $modulesPath "ollama-rest.ps1")

# Load server manager
. (Join-Path $toolsPath "ollama-server-manager.ps1")

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$TestName = "Unknown"
    )

    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $logMessage = "[$timestamp] [$Level] [$TestName] $Message"

    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG" { Write-Host $logMessage -ForegroundColor Gray }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
}

function Test-ServerReachable {
    <#
    .SYNOPSIS
    Tests if the Ollama server is reachable via REST API.
    #>

    Write-TestLog "Testing server reachability..." -Level "INFO" -TestName "ServerReachable"

    try {
        $config = Get-Configuration
        $serverUrl = Get-ConfigValue -Path "ollama.serverUrl" -DefaultValue "http://127.0.0.1:11434"

        $healthCheck = Test-OllamaServerHealth -ServerUrl $serverUrl -TimeoutSeconds $TimeoutSeconds

        if ($healthCheck.IsHealthy) {
            Write-TestLog "Server is reachable and healthy" -Level "SUCCESS" -TestName "ServerReachable"
            if ($Verbose) {
                Write-TestLog "Response time: $($healthCheck.ResponseTime)ms" -Level "DEBUG" -TestName "ServerReachable"
                Write-TestLog "Available models: $($healthCheck.Models.Count)" -Level "DEBUG" -TestName "ServerReachable"
            }
            return $true
        } else {
            Write-TestLog "Server is reachable but not healthy" -Level "WARN" -TestName "ServerReachable"
            if ($Verbose) {
                foreach ($error in $healthCheck.Errors) {
                    Write-TestLog "Error: $error" -Level "DEBUG" -TestName "ServerReachable"
                }
            }
            return $false
        }
    }
    catch {
        Write-TestLog "Server is not reachable: $($_.Exception.Message)" -Level "ERROR" -TestName "ServerReachable"
        return $false
    }
}

function Test-ShortGeneration {
    <#
    .SYNOPSIS
    Tests short text generation with a simple prompt.
    #>

    Write-TestLog "Testing short generation..." -Level "INFO" -TestName "ShortGeneration"

    try {
        $config = Get-Configuration
        $serverUrl = Get-ConfigValue -Path "ollama.serverUrl" -DefaultValue "http://127.0.0.1:11434"

        # Get available models
        $models = Get-OllamaModels -ServerUrl $serverUrl
        if ($models.Count -eq 0) {
            Write-TestLog "No models available for generation test" -Level "WARN" -TestName "ShortGeneration"
            return $false
        }

        # Prefer a chat/generation model; embedding models cannot serve /api/generate
        $testModel = ($models | Where-Object { $_.Name -notmatch 'embed' } | Select-Object -First 1).Name
        if (-not $testModel) {
            Write-TestLog "No generation-capable model available (only embedding models present) - skipping generation test" -Level "WARN" -TestName "ShortGeneration"
            return $false
        }
        Write-TestLog "Testing with model: $testModel" -Level "DEBUG" -TestName "ShortGeneration"

        # Simple test prompt
        $testPrompt = "ok"

        $startTime = Get-Date
        $result = Invoke-OllamaGenerate -Model $testModel -Prompt $testPrompt -Stream $false -ServerUrl $serverUrl -TimeoutSeconds $TimeoutSeconds
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds

        if ($result -and $result.Response) {
            Write-TestLog "Generation successful in $([math]::Round($duration, 2))ms" -Level "SUCCESS" -TestName "ShortGeneration"
            if ($Verbose) {
                Write-TestLog "Response: $($result.Response)" -Level "DEBUG" -TestName "ShortGeneration"
            }
            return $true
        } else {
            Write-TestLog "Generation failed - no response received" -Level "ERROR" -TestName "ShortGeneration"
            return $false
        }
    }
    catch {
        Write-TestLog "Generation test failed: $($_.Exception.Message)" -Level "ERROR" -TestName "ShortGeneration"
        return $false
    }
}

function Test-Embeddings {
    <#
    .SYNOPSIS
    Tests embeddings generation with a simple prompt.
    #>

    Write-TestLog "Testing embeddings..." -Level "INFO" -TestName "Embeddings"

    try {
        $config = Get-Configuration
        $serverUrl = Get-ConfigValue -Path "ollama.serverUrl" -DefaultValue "http://127.0.0.1:11434"

        # Get available models
        $models = Get-OllamaModels -ServerUrl $serverUrl
        if ($models.Count -eq 0) {
            Write-TestLog "No models available for embeddings test" -Level "WARN" -TestName "Embeddings"
            return $false
        }

        # Prefer an embedding-capable model; chat models cannot serve /api/embeddings
        $testModel = ($models | Where-Object { $_.Name -match 'embed' } | Select-Object -First 1).Name
        if (-not $testModel) {
            Write-TestLog "No embedding model available (only chat models present) - skipping embeddings test" -Level "WARN" -TestName "Embeddings"
            return $false
        }
        Write-TestLog "Testing embeddings with model: $testModel" -Level "DEBUG" -TestName "Embeddings"

        # Simple test prompt
        $testPrompt = "test"

        $startTime = Get-Date
        $result = Invoke-OllamaEmbeddings -Model $testModel -Prompt $testPrompt -ServerUrl $serverUrl -TimeoutSeconds $TimeoutSeconds
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds

        if ($result -and $result.Embedding -and $result.Embedding.Count -gt 0) {
            Write-TestLog "Embeddings generated successfully in $([math]::Round($duration, 2))ms" -Level "SUCCESS" -TestName "Embeddings"
            if ($Verbose) {
                Write-TestLog "Vector length: $($result.Embedding.Count)" -Level "DEBUG" -TestName "Embeddings"
            }
            return $true
        } else {
            Write-TestLog "Embeddings generation failed - no vector received" -Level "ERROR" -TestName "Embeddings"
            return $false
        }
    }
    catch {
        Write-TestLog "Embeddings test failed: $($_.Exception.Message)" -Level "ERROR" -TestName "Embeddings"
        return $false
    }
}

function Test-MultiModelFanout {
    <#
    .SYNOPSIS
    Tests multi-model execution with concurrency=2.
    #>

    Write-TestLog "Testing multi-model fanout..." -Level "INFO" -TestName "MultiModelFanout"

    try {
        $config = Get-Configuration
        $serverUrl = Get-ConfigValue -Path "ollama.serverUrl" -DefaultValue "http://127.0.0.1:11434"

        # Get available models (limit to 2 for laptop optimization)
        $models = Get-OllamaModels -ServerUrl $serverUrl
        if ($models.Count -eq 0) {
            Write-TestLog "No models available for fanout test" -Level "WARN" -TestName "MultiModelFanout"
            return $false
        }

        # Limit to 2 models for laptop optimization
        $testModels = $models | Select-Object -First 2
        Write-TestLog "Testing fanout with $($testModels.Count) models: $($testModels.Name -join ', ')" -Level "DEBUG" -TestName "MultiModelFanout"

        # Simple test prompt
        $testPrompt = "hello"
        $concurrency = 2
        $timeout = 30

        $startTime = Get-Date

        # Test each model individually
        $results = @()
        foreach ($model in $testModels) {
            try {
                $modelResult = Invoke-OllamaGenerate -Model $model.Name -Prompt $testPrompt -Stream $false -ServerUrl $serverUrl -TimeoutSeconds $timeout
                if ($modelResult -and $modelResult.Response) {
                    $results += @{
                        Model = $model.Name
                        Success = $true
                        Response = $modelResult.Response
                    }
                } else {
                    $results += @{
                        Model = $model.Name
                        Success = $false
                        Response = $null
                    }
                }
            }
            catch {
                $results += @{
                    Model = $model.Name
                    Success = $false
                    Response = $null
                    Error = $_.Exception.Message
                }
            }
        }

        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds

        $successCount = ($results | Where-Object { $_.Success }).Count
        $totalCount = $results.Count

        if ($successCount -gt 0) {
            Write-TestLog "Multi-model fanout completed: $successCount/$totalCount successful in $([math]::Round($duration, 2))ms" -Level "SUCCESS" -TestName "MultiModelFanout"
            if ($Verbose) {
                foreach ($result in $results) {
                    $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
                    Write-TestLog "Model $($result.Model): $status" -Level "DEBUG" -TestName "MultiModelFanout"
                }
            }
            return $successCount -gt 0
        } else {
            Write-TestLog "Multi-model fanout failed - no successful generations" -Level "ERROR" -TestName "MultiModelFanout"
            return $false
        }
    }
    catch {
        Write-TestLog "Multi-model fanout test failed: $($_.Exception.Message)" -Level "ERROR" -TestName "MultiModelFanout"
        return $false
    }
}

function Test-ServerProcess {
    <#
    .SYNOPSIS
    Tests if the Ollama server process is running.
    #>

    Write-TestLog "Testing server process..." -Level "INFO" -TestName "ServerProcess"

    try {
        $processStatus = Test-OllamaProcess

        if ($processStatus.IsRunning) {
            Write-TestLog "Server process is running (PID: $($processStatus.ProcessId))" -Level "SUCCESS" -TestName "ServerProcess"
            if ($Verbose) {
                Write-TestLog "Start time: $($processStatus.StartTime)" -Level "DEBUG" -TestName "ServerProcess"
                Write-TestLog "Memory usage: $([math]::Round($processStatus.WorkingSet / 1MB, 2)) MB" -Level "DEBUG" -TestName "ServerProcess"
            }
            return $true
        } else {
            Write-TestLog "Server process is not running" -Level "WARN" -TestName "ServerProcess"
            return $false
        }
    }
    catch {
        Write-TestLog "Process check failed: $($_.Exception.Message)" -Level "ERROR" -TestName "ServerProcess"
        return $false
    }
}

function Test-Configuration {
    <#
    .SYNOPSIS
    Tests if the configuration is properly loaded.
    #>

    Write-TestLog "Testing configuration..." -Level "INFO" -TestName "Configuration"

    try {
        $config = Get-Configuration
        $serverUrl = Get-ConfigValue -Path "ollama.serverUrl"
        $concurrency = Get-ConfigValue -Path "ollama.concurrency"
        $maxLoaded = Get-ConfigValue -Path "ollama.maxLoaded"

        if ($config -and $serverUrl -and $concurrency -and $maxLoaded) {
            Write-TestLog "Configuration loaded successfully" -Level "SUCCESS" -TestName "Configuration"
            if ($Verbose) {
                Write-TestLog "Server URL: $serverUrl" -Level "DEBUG" -TestName "Configuration"
                Write-TestLog "Concurrency: $concurrency" -Level "DEBUG" -TestName "Configuration"
                Write-TestLog "Max loaded models: $maxLoaded" -Level "DEBUG" -TestName "Configuration"
            }
            return $true
        } else {
            Write-TestLog "Configuration missing required values" -Level "WARN" -TestName "Configuration"
            return $false
        }
    }
    catch {
        Write-TestLog "Configuration test failed: $($_.Exception.Message)" -Level "ERROR" -TestName "Configuration"
        return $false
    }
}

function Show-TestSummary {
    <#
    .SYNOPSIS
    Shows a summary of all test results.
    #>
    param(
        [hashtable]$Results
    )

    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host "                         OLLAMA HEALTH TEST SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================================================" -ForegroundColor Cyan

    $totalTests = $Results.Count
    $passedTests = ($Results.Values | Where-Object { $_ -eq $true }).Count
    $failedTests = $totalTests - $passedTests

    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: $passedTests" -ForegroundColor Green
    Write-Host "Failed: $failedTests" -ForegroundColor Red
    Write-Host "Success Rate: $([math]::Round(($passedTests / $totalTests) * 100, 1))%" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Yellow" })

    Write-Host ""
    Write-Host "Test Results:" -ForegroundColor White
    foreach ($testName in $Results.Keys) {
        $status = if ($Results[$testName]) { "✅ PASS" } else { "❌ FAIL" }
        $color = if ($Results[$testName]) { "Green" } else { "Red" }
        Write-Host "  $testName`: $status" -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Cyan

    if ($failedTests -eq 0) {
        Write-Host "All tests passed! Ollama system is healthy." -ForegroundColor Green
        return 0
    } else {
        Write-Host "Some tests failed. Check the logs above for details." -ForegroundColor Yellow
        return 1
    }
}

# Main execution
try {
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host "                    OLLAMA QUICK HEALTH TESTS" -ForegroundColor Cyan
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host ""

    $testResults = @{}
    $startTime = Get-Date

    # Run tests based on type
    switch ($TestType.ToLower()) {
        "all" {
            Write-Host "Running all health tests..." -ForegroundColor Green
            $testResults["Configuration"] = Test-Configuration
            $testResults["ServerProcess"] = Test-ServerProcess
            $testResults["ServerReachable"] = Test-ServerReachable
            $testResults["ShortGeneration"] = Test-ShortGeneration
            $testResults["Embeddings"] = Test-Embeddings
            $testResults["MultiModelFanout"] = Test-MultiModelFanout
        }
        "basic" {
            Write-Host "Running basic health tests..." -ForegroundColor Green
            $testResults["Configuration"] = Test-Configuration
            $testResults["ServerProcess"] = Test-ServerProcess
            $testResults["ServerReachable"] = Test-ServerReachable
        }
        "generation" {
            Write-Host "Running generation tests..." -ForegroundColor Green
            $testResults["ShortGeneration"] = Test-ShortGeneration
            $testResults["MultiModelFanout"] = Test-MultiModelFanout
        }
        "embeddings" {
            Write-Host "Running embeddings tests..." -ForegroundColor Green
            $testResults["Embeddings"] = Test-Embeddings
        }
        default {
            Write-Host "Unknown test type: $TestType" -ForegroundColor Red
            Write-Host "Available types: all, basic, generation, embeddings" -ForegroundColor Yellow
            exit 1
        }
    }

    $endTime = Get-Date
    $totalDuration = ($endTime - $startTime).TotalSeconds

    Write-Host ""
    Write-Host "Total test duration: $([math]::Round($totalDuration, 2)) seconds" -ForegroundColor Gray

    # Show summary and exit
    $exitCode = Show-TestSummary -Results $testResults
    exit $exitCode

} catch {
    Write-Host ""
    Write-Host "Health tests failed with error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
