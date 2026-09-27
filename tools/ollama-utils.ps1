# Ollama Utilities for DevOptimizer - REST-First with CLI Fallback
# Provides functions to discover and run prompts across all installed Ollama models

param(
    [string]$LogLevel = "INFO"
)

# Import required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath = Join-Path $scriptDir "..\modules"

# Load configuration module
. (Join-Path $modulesPath "config-loader.ps1")

# Load REST client module
. (Join-Path $modulesPath "ollama-rest.ps1")

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level.ToUpper()) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

function Get-OllamaExecutablePath {
    <#
    .SYNOPSIS
    Finds the Ollama executable path
    #>

    $possiblePaths = @(
        "$env:USERPROFILE\AppData\Local\Programs\Ollama\ollama.exe",
        "$env:PROGRAMFILES\Ollama\ollama.exe",
        "$env:PROGRAMFILES(X86)\Ollama\ollama.exe",
        "ollama.exe"  # If in PATH
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            return $path
        }
    }

    # Try to find via Get-Command
    $ollamaCmd = Get-Command "ollama" -ErrorAction SilentlyContinue
    if ($ollamaCmd) {
        return $ollamaCmd.Source
    }

    return $null
}

function Test-OllamaReady {
    <#
    .SYNOPSIS
    Tests if Ollama is installed and ready
    #>

    $ollamaPath = Get-OllamaExecutablePath
    if (-not $ollamaPath) {
        Write-Log "Ollama not found. Please install Ollama first." -Level "ERROR"
        return $false
    }

    try {
        $null = & $ollamaPath --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Ollama is ready at: $ollamaPath" -Level "INFO"
            return $true
        }
    }
    catch {
        Write-Log "Ollama found but not responding: $($_.Exception.Message)" -Level "ERROR"
    }

    return $false
}

function Get-OllamaModels {
    <#
    .SYNOPSIS
    Gets list of all installed Ollama models using REST API first, CLI fallback
    #>

    try {
        # Try REST API first
        $config = Get-Configuration
        $serverUrl = Get-ConfigValue -Path "ollama.serverUrl" -DefaultValue "http://127.0.0.1:11434"

        Write-Log "Attempting to get models via REST API: $serverUrl" -Level "INFO"

        $restModels = Get-OllamaModels -ServerUrl $serverUrl
        if ($restModels.Count -gt 0) {
            Write-Log "Retrieved $($restModels.Count) models via REST API" -Level "INFO"
            return $restModels | ForEach-Object { $_.Name }
        }
    }
    catch {
        Write-Log "REST API failed, falling back to CLI: $($_.Exception.Message)" -Level "WARN"
    }

    # Fallback to CLI
    Write-Log "Falling back to CLI method" -Level "INFO"

    if (-not (Test-OllamaReady)) {
        return @()
    }

    $ollamaPath = Get-OllamaExecutablePath

    try {
        # Try JSON output first (more reliable)
        $jsonOutput = & $ollamaPath list --json 2>$null
        if ($jsonOutput -and $LASTEXITCODE -eq 0) {
            $models = $jsonOutput | ConvertFrom-Json
            Write-Log "Retrieved $($models.Count) models via CLI JSON" -Level "INFO"
            return $models | ForEach-Object { $_.name }
        }

        # Fallback to text parsing
        $textOutput = & $ollamaPath list 2>$null
        if ($textOutput -and $LASTEXITCODE -eq 0) {
            $models = @()
            $textOutput | ForEach-Object {
                if ($_ -match '^\s*(\S+)') {
                    $modelName = $matches[1]
                    # Skip header line
                    if ($modelName -ne "NAME") {
                        $models += $modelName
                    }
                }
            }
            Write-Log "Retrieved $($models.Count) models via CLI text parsing" -Level "INFO"
            return $models
        }
    }
    catch {
        Write-Log "Error getting Ollama models via CLI: $($_.Exception.Message)" -Level "ERROR"
    }

    return @()
}

function Invoke-OllamaForModel {
    param(
        [string]$ModelName,
        [string]$Prompt,
        [string]$OutputPath,
        [int]$TimeoutSeconds = 300
    )

    <#
    .SYNOPSIS
    Runs a prompt against a specific Ollama model using REST API first, CLI fallback
    #>

    Write-Log "Running prompt with model: $ModelName" -Level "INFO"

    try {
        # Create output directory if it doesn't exist
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Try REST API first
        try {
            $config = Get-Configuration
            $serverUrl = Get-ConfigValue -Path "ollama.serverUrl" -DefaultValue "http://127.0.0.1:11434"

            Write-Log "Attempting generation via REST API: $serverUrl" -Level "INFO"

            $restResult = Invoke-OllamaGenerate -Model $ModelName -Prompt $Prompt -Stream $false -ServerUrl $serverUrl -TimeoutSeconds $TimeoutSeconds

            if ($restResult -and $restResult.Response) {
                # Write REST output to file
                $restResult.Response | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Log "Model $ModelName completed successfully via REST API" -Level "INFO"
                return $true
            }
        }
        catch {
            Write-Log "REST API generation failed, falling back to CLI: $($_.Exception.Message)" -Level "WARN"
        }

        # Fallback to CLI
        Write-Log "Falling back to CLI method for model: $ModelName" -Level "INFO"

        if (-not (Test-OllamaReady)) {
            "ERROR: Ollama not ready for CLI fallback" | Out-File -FilePath $OutputPath -Encoding UTF8
            return $false
        }

        $ollamaPath = Get-OllamaExecutablePath

        # Run the model with timeout using CLI
        $job = Start-Job -ScriptBlock {
            param($ollamaPath, $modelName, $prompt)
            & $ollamaPath run $modelName $prompt
        } -ArgumentList $ollamaPath, $ModelName, $Prompt

        $result = Wait-Job -Job $job -Timeout $TimeoutSeconds

        if ($result) {
            $output = Receive-Job -Job $job
            Remove-Job -Job $job

            # Write output to file
            $output | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Log "Model $ModelName completed successfully via CLI" -Level "INFO"
            return $true
        }
        else {
            Stop-Job -Job $job
            Remove-Job -Job $job
            Write-Log "Model $ModelName timed out after $TimeoutSeconds seconds" -Level "WARN"

            # Write timeout message to file
            "TIMEOUT: Model $ModelName did not respond within $TimeoutSeconds seconds" | Out-File -FilePath $OutputPath -Encoding UTF8
            return $false
        }
    }
    catch {
        Write-Log "Error running model ${ModelName}: $($_.Exception.Message)" -Level "ERROR"

        # Write error message to file
        "ERROR: $($_.Exception.Message)" | Out-File -FilePath $OutputPath -Encoding UTF8
        return $false
    }
}

function Invoke-OllamaForAllModels {
    param(
        [string]$Prompt,
        [string]$OutputDir,
        [int]$Concurrency = 1,
        [int]$TimeoutSeconds = 300,
        [string[]]$AllowedModels = @(),
        [string[]]$DeniedModels = @()
    )

    <#
    .SYNOPSIS
    Runs a prompt against all available Ollama models using REST-first approach
    #>

    try {
        # Load configuration for laptop-optimized defaults
        $config = Get-Configuration
        $defaultConcurrency = Get-ConfigValue -Path "ollama.concurrency" -DefaultValue 2
        $defaultTimeout = Get-ConfigValue -Path "ollama.timeoutSeconds" -DefaultValue 300

        # Use config defaults if not specified
        if ($Concurrency -eq 1) { $Concurrency = $defaultConcurrency }
        if ($TimeoutSeconds -eq 300) { $TimeoutSeconds = $defaultTimeout }

        Write-Log "Using laptop-optimized settings: Concurrency=$Concurrency, Timeout=$TimeoutSeconds" -Level "INFO"
    }
    catch {
        Write-Log "Could not load configuration, using provided defaults" -Level "WARN"
    }

    # Check if we can get models (either via REST or CLI)
    $allModels = Get-OllamaModels
    if ($allModels.Count -eq 0) {
        Write-Log "No Ollama models found. Please install some models first." -Level "WARN"
        return @{
            Success = $false
            Error = "No models found"
            Results = @()
        }
    }

    # Filter models based on allow/deny lists
    $modelsToUse = @()
    foreach ($model in $allModels) {
        $include = $true

        # Check deny list first
        if ($DeniedModels.Count -gt 0) {
            foreach ($denied in $DeniedModels) {
                if ($model -like "*$denied*") {
                    $include = $false
                    Write-Log "Skipping denied model: $model" -Level "INFO"
                    break
                }
            }
        }

        # Check allow list if specified
        if ($include -and $AllowedModels.Count -gt 0) {
            $include = $false
            foreach ($allowed in $AllowedModels) {
                if ($model -like "*$allowed*") {
                    $include = $true
                    break
                }
            }
            if (-not $include) {
                Write-Log "Skipping non-allowed model: $model" -Level "INFO"
            }
        }

        if ($include) {
            $modelsToUse += $model
        }
    }

    if ($modelsToUse.Count -eq 0) {
        Write-Log "No models match the filter criteria" -Level "WARN"
        return @{
            Success = $false
            Error = "No models match filters"
            Results = @()
        }
    }

    Write-Log "Running prompt against $($modelsToUse.Count) models: $($modelsToUse -join ', ')" -Level "INFO"

    # Create timestamped output directory
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $fullOutputDir = Join-Path $OutputDir "ollama-$timestamp"
    New-Item -ItemType Directory -Path $fullOutputDir -Force | Out-Null

    $results = @()

    if ($Concurrency -eq 1) {
        # Sequential execution
        foreach ($model in $modelsToUse) {
            $safeModelName = $model -replace '[\\/:*?"<>|]', '_'
            $outputPath = Join-Path $fullOutputDir "$safeModelName.txt"

            $success = Invoke-OllamaForModel -ModelName $model -Prompt $Prompt -OutputPath $outputPath -TimeoutSeconds $TimeoutSeconds

            $results += @{
                Model = $model
                Success = $success
                OutputPath = $outputPath
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    }
    else {
        # Parallel execution with limited concurrency
        $jobs = @()
        $maxJobs = [Math]::Min($Concurrency, $modelsToUse.Count)

        for ($i = 0; $i -lt $modelsToUse.Count; $i += $maxJobs) {
            # Start batch of jobs
            for ($j = 0; $j -lt $maxJobs -and ($i + $j) -lt $modelsToUse.Count; $j++) {
                $model = $modelsToUse[$i + $j]
                $safeModelName = $model -replace '[\\/:*?"<>|]', '_'
                $outputPath = Join-Path $fullOutputDir "$safeModelName.txt"

                $job = Start-Job -ScriptBlock {
                    param($ollamaPath, $modelName, $prompt, $outputPath, $timeout)
                    . $using:PSScriptRoot\ollama-utils.ps1
                    return Invoke-OllamaForModel -ModelName $modelName -Prompt $prompt -OutputPath $outputPath -TimeoutSeconds $timeout
                } -ArgumentList (Get-OllamaExecutablePath), $model, $Prompt, $outputPath, $TimeoutSeconds

                $jobs += @{
                    Job = $job
                    Model = $model
                    OutputPath = $outputPath
                }
            }

            # Wait for batch to complete
            foreach ($jobInfo in $jobs) {
                $null = Wait-Job -Job $jobInfo.Job -Timeout ($TimeoutSeconds + 60)
                $success = Receive-Job -Job $jobInfo.Job
                Remove-Job -Job $jobInfo.Job

                $results += @{
                    Model = $jobInfo.Model
                    Success = $success
                    OutputPath = $jobInfo.OutputPath
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }

            $jobs = @()
        }
    }

    # Create aggregate summary
    $aggregatePath = Join-Path $fullOutputDir "aggregate.md"
    $summary = @"
# Ollama Multi-Model Results
**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Prompt:** $Prompt
**Models Used:** $($modelsToUse.Count)
**Successful:** $($results | Where-Object { $_.Success } | Measure-Object | Select-Object -ExpandProperty Count)
**Failed:** $($results | Where-Object { -not $_.Success } | Measure-Object | Select-Object -ExpandProperty Count)

## Results Summary
"@

    foreach ($result in $results) {
        $status = if ($result.Success) { "✅ SUCCESS" } else { "❌ FAILED" }
        $summary += "`n- **$($result.Model)**: $status ($($result.Timestamp))"
    }

    $summary += @"

## Output Files
"@

    foreach ($result in $results) {
        $fileName = Split-Path $result.OutputPath -Leaf
        $summary += "`n- [$fileName]($fileName)"
    }

    $summary | Out-File -FilePath $aggregatePath -Encoding UTF8

    Write-Log "Completed processing $($modelsToUse.Count) models. Results saved to: $fullOutputDir" -Level "INFO"
    Write-Log "Aggregate summary: $aggregatePath" -Level "INFO"

    return @{
        Success = $true
        OutputDir = $fullOutputDir
        Results = $results
        AggregatePath = $aggregatePath
    }
}

# Export functions for use in other scripts (only if running as module)
if ($MyInvocation.MyCommand.Module) {
    Export-ModuleMember -Function Get-OllamaExecutablePath, Test-OllamaReady, Get-OllamaModels, Invoke-OllamaForModel, Invoke-OllamaForAllModels
}
