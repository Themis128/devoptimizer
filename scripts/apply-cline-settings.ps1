<#
.SYNOPSIS
    Apply Optimal Cline Settings for NVIDIA NIM Free Tier
.DESCRIPTION
    Merges recommended Cline configuration into VS Code settings.json
#>

$ErrorActionPreference = "Stop"

$SettingsPath = "$env:APPDATA\Code\User\settings.json"
$BackupPath = "$env:APPDATA\Code\User\settings.json.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "Applying Cline settings to: $SettingsPath" -ForegroundColor Cyan

# Backup
Copy-Item $SettingsPath $BackupPath -Force
Write-Host "Backup created: $BackupPath" -ForegroundColor Gray

# Read current settings
$jsonText = Get-Content $SettingsPath -Raw
$json = $jsonText | ConvertFrom-Json

# Convert to hashtable for easy property addition
$hash = @{}
foreach ($prop in $json.PSObject.Properties) {
    $hash[$prop.Name] = $prop.Value
}

# Optimal Cline settings for NVIDIA NIM free tier
$ClineSettings = @{
    # API Configuration
    "cline.apiProvider" = "openai"
    "cline.openAiBaseUrl" = "https://integrate.api.nvidia.com/v1"
    "cline.openAiModelId" = "nvidia/nemotron-3-ultra-550b-a55b"
    # "cline.openAiApiKey" = "YOUR_API_KEY_HERE"  # Set this manually in VS Code
    
    # Plan/Act Mode - separate models for cost optimization
    "cline.usePlanActSeparateModels" = $true
    "cline.planModeModelId" = "nvidia/nemotron-3-ultra-550b-a55b"
    "cline.actModeModelId" = "nvidia/nemotron-3-nano-30b-a3b-reasoning"
    
    # Token optimization
    "cline.reasoningEffort" = "medium"
    "cline.promptCachingEnabled" = $true
    
    # Advanced
    "cline.customHeaders" = @()
    "cline.useAzureOpenAI" = $false
    "cline.azureApiVersion" = ""
    "cline.useAzureIdentityAuth" = $false
    
    # Context & tokens
    "cline.contextWindow" = 128000
    "cline.maxTokens" = 8192
    
    # Behavior
    "cline.autoApproveEnabled" = $false
    "cline.diffEnabled" = $true
    "cline.showRooCodeIgnoreFiles" = $true
    
    # Experiments
    "cline.experiments" = @{
        "usePlanActSeparateModels" = $true
    }
}

# Merge settings
foreach ($key in $ClineSettings.Keys) {
    $hash[$key] = $ClineSettings[$key]
    Write-Host "  Set: $key" -ForegroundColor Green
}

# Convert back and write
$hash | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8

Write-Host "`nSettings applied successfully!" -ForegroundColor Green
Write-Host "`nIMPORTANT: You still need to set your API key in VS Code:" -ForegroundColor Yellow
Write-Host "  1. Open VS Code Settings (Ctrl+,)" -ForegroundColor Gray
Write-Host "  2. Search for 'cline.openAiApiKey'" -ForegroundColor Gray
Write-Host "  3. Paste your NVIDIA NIM API key" -ForegroundColor Gray
Write-Host "  4. Or use Cline's settings UI (click Cline icon → Settings)" -ForegroundColor Gray

Write-Host "`nAlso verify these NVIDIA NIM specific settings:" -ForegroundColor Yellow
Write-Host "  nvidia-nim.reasoning.mode = medium (was: high)" -ForegroundColor Gray
Write-Host "  nvidia-nim.reasoning.showInChat = true" -ForegroundColor Gray