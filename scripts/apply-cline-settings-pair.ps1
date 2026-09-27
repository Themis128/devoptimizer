<#
.SYNOPSIS
    Apply Cline Settings for NVIDIA PAIR (local router on 127.0.0.1:11434)
.DESCRIPTION
    Merges PAIR-specific Cline configuration into VS Code settings.json,
    preserving all existing settings. Backs up settings.json first.
#>

$ErrorActionPreference = "Stop"

$SettingsPath = "$env:APPDATA\Code\User\settings.json"
$BackupPath = "$env:APPDATA\Code\User\settings.json.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

if (-not (Test-Path $SettingsPath)) {
    Write-Host "settings.json not found at $SettingsPath - nothing to merge." -ForegroundColor Red
    exit 1
}

Copy-Item $SettingsPath $BackupPath -Force
Write-Host "Backup created: $BackupPath" -ForegroundColor Gray

$json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
$hash = @{}
foreach ($prop in $json.PSObject.Properties) { $hash[$prop.Name] = $prop.Value }

# NVIDIA PAIR (Personal AI Router) - local Ollama-compatible proxy, OpenAI-shaped
$ClineSettings = @{
    "cline.apiProvider" = "openai"
    "cline.openAiBaseUrl" = "http://127.0.0.1:11434/v1"
    "cline.openAiModelId" = "qwen2.5-coder:7b"
    "cline.openAiApiKey" = "local-pair"

    "cline.usePlanActSeparateModels" = $true
    "cline.planModeModelId" = "qwen3:4b"
    "cline.actModeModelId" = "qwen2.5-coder:7b"

    "cline.reasoningEffort" = "medium"
    "cline.promptCachingEnabled" = $true

    "cline.customHeaders" = @()
    "cline.useAzureOpenAI" = $false
    "cline.azureApiVersion" = ""
    "cline.useAzureIdentityAuth" = $false

    # 8GB VRAM RTX 3070 Laptop: 32k is the realistic served window
    "cline.contextWindow" = 32768
    "cline.maxTokens" = 8192

    "cline.autoApproveEnabled" = $false
    "cline.diffEnabled" = $true
    "cline.showRooCodeIgnoreFiles" = $true

    "cline.experiments" = @{
        "usePlanActSeparateModels" = $true
    }
}

foreach ($key in $ClineSettings.Keys) {
    $hash[$key] = $ClineSettings[$key]
    Write-Host "  Set: $key = $($ClineSettings[$key])" -ForegroundColor Green
}

$hash | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
Write-Host "`nCline now points at NVIDIA PAIR: http://127.0.0.1:11434/v1" -ForegroundColor Cyan
Write-Host "Restart VS Code (or Reload Window) for changes to take effect." -ForegroundColor Yellow
