<#
.SYNOPSIS
    Runs ollama all.
.DESCRIPTION
    Runs ollama all.
#>

# Ollama Multi-Model Runner for DevOptimizer - REST-First with Laptop Optimization
# Executable script to run prompts across all installed Ollama models

param(
    [Parameter(Mandatory=$false)]
    [string]$Prompt,

    [Parameter(Mandatory=$false)]
    [string]$PromptFile,

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "logs",

    [Parameter(Mandatory=$false)]
    [int]$Concurrency = 2,

    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "configs/system-config.json",

    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds = 300,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# Import required modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath = Join-Path $scriptDir "..\modules"

# Load configuration module
. (Join-Path $modulesPath "config-loader.ps1")

# Load REST client module
. (Join-Path $modulesPath "ollama-rest.ps1")

# Load ollama utilities
. (Join-Path $scriptDir "ollama-utils.ps1")

# Show help if requested
if ($Help) {
    Write-Host @"
Ollama Multi-Model Runner for DevOptimizer

USAGE:
    pwsh -File run-ollama-all.ps1 -Prompt "Your prompt here"
    pwsh -File run-ollama-all.ps1 -PromptFile "path/to/prompt.txt"
    pwsh -File run-ollama-all.ps1 -Prompt "Test prompt" -Concurrency 2 -OutputDir "custom/output"

PARAMETERS:
    -Prompt        Direct prompt text to run across all models
    -PromptFile    Path to file containing prompt text
    -OutputDir     Output directory (default: logs)
    -Concurrency   Max parallel models (default: 2, laptop optimized)
    -ConfigFile    Path to config file (default: configs/system-config.json)
    -TimeoutSeconds Timeout per model in seconds (default: 300)
    -Help          Show this help message

EXAMPLES:
    # Simple test
    pwsh -File run-ollama-all.ps1 -Prompt "Hello, how are you?"

    # From file with parallel execution
    pwsh -File run-ollama-all.ps1 -PromptFile "analysis-prompt.txt" -Concurrency 2

    # Custom output location
    pwsh -File run-ollama-all.ps1 -Prompt "System analysis" -OutputDir "reports"

CONFIG FILE:
    Optional JSON file to control model filtering:
    {
        "allow": ["qwen", "llama"],     // Only use models containing these strings
        "deny": ["test", "temp"],       // Skip models containing these strings
        "concurrency": 2                // Override default concurrency
    }
    Empty arrays mean use all models.

OUTPUT:
    Creates timestamped folder in OutputDir with:
    - Individual model outputs: <model-name>.txt
    - Aggregate summary: aggregate.md
"@
    exit 0
}

# Load the utilities
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\ollama-utils.ps1"

# Validate input
if ([string]::IsNullOrWhiteSpace($Prompt) -and [string]::IsNullOrWhiteSpace($PromptFile)) {
    Write-Log "Error: Either -Prompt or -PromptFile must be specified" -Level "ERROR"
    Write-Log "Use -Help for usage information" -Level "INFO"
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($Prompt) -and -not [string]::IsNullOrWhiteSpace($PromptFile)) {
    Write-Log "Error: Cannot specify both -Prompt and -PromptFile" -Level "ERROR"
    exit 1
}

# Get prompt text
$promptText = ""
if (-not [string]::IsNullOrWhiteSpace($PromptFile)) {
    if (-not (Test-Path $PromptFile)) {
        Write-Log "Error: Prompt file not found: $PromptFile" -Level "ERROR"
        exit 1
    }
    $promptText = Get-Content -Path $PromptFile -Raw
    Write-Log "Loaded prompt from file: $PromptFile" -Level "INFO"
}
else {
    $promptText = $Prompt
    Write-Log "Using provided prompt text" -Level "INFO"
}

if ([string]::IsNullOrWhiteSpace($promptText)) {
    Write-Log "Error: Prompt is empty" -Level "ERROR"
    exit 1
}

# Load config if it exists
$allowedModels = @()
$deniedModels = @()
$configConcurrency = $Concurrency

if (Test-Path $ConfigFile) {
    try {
        $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        if ($config.allow) { $allowedModels = $config.allow }
        if ($config.deny) { $deniedModels = $config.deny }
        if ($config.concurrency -and $config.concurrency -gt 0) { $configConcurrency = $config.concurrency }
        Write-Log "Loaded config from: $ConfigFile" -Level "INFO"
    }
    catch {
        Write-Log "Warning: Could not parse config file $ConfigFile : $($_.Exception.Message)" -Level "WARN"
    }
}

# Use config concurrency if no explicit concurrency was set
if ($Concurrency -eq 1 -and $configConcurrency -ne 1) {
    $Concurrency = $configConcurrency
}

Write-Log "Starting Ollama multi-model execution" -Level "INFO"
Write-Log "Prompt length: $($promptText.Length) characters" -Level "INFO"
Write-Log "Concurrency: $Concurrency" -Level "INFO"
Write-Log "Allowed models: $($allowedModels -join ', ')" -Level "INFO"
Write-Log "Denied models: $($deniedModels -join ', ')" -Level "INFO"

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Log "Created output directory: $OutputDir" -Level "INFO"
}

# Run the models
$result = Invoke-OllamaForAllModels -Prompt $promptText -OutputDir $OutputDir -Concurrency $Concurrency -TimeoutSeconds $TimeoutSeconds -AllowedModels $allowedModels -DeniedModels $deniedModels

if (-not $result.Success) {
    Write-Log "Execution failed: $($result.Error)" -Level "ERROR"
    exit 1
}

# Print summary
$successCount = ($result.Results | Where-Object { $_.Success }).Count
$totalCount = $result.Results.Count

Write-Log "Execution completed successfully" -Level "INFO"
Write-Log "Results: $successCount/$totalCount models completed successfully" -Level "INFO"
Write-Log "Output directory: $($result.OutputDir)" -Level "INFO"
Write-Log "Aggregate summary: $($result.AggregatePath)" -Level "INFO"

# Exit with appropriate code
if ($successCount -eq 0) {
    exit 3  # No models succeeded
}
elseif ($successCount -lt $totalCount) {
    exit 2  # Some models failed
}
else {
    exit 0  # All models succeeded
}
