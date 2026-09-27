<#
.SYNOPSIS
    Verify Cline Extension Configuration & Health
.DESCRIPTION
    Checks Cline extension installation, settings, storage paths, and provides
    optimization recommendations for NVIDIA NIM free tier.
#>

$ErrorActionPreference = "Continue"

Write-Host "`n=== Cline Extension Verification ===" -ForegroundColor Magenta

# ─── Find Cline Storage Paths ─────────────────────────────────────
Write-Host "Storage Paths:" -ForegroundColor Cyan

$Paths = @(
    "$env:APPDATA\Code\User\globalStorage\saoudrizwan.claude-dev",
    "$env:APPDATA\Code - Insiders\User\globalStorage\saoudrizwan.claude-dev"
)

$FoundAny = $false
foreach ($path in $Paths) {
    if (Test-Path $path) {
        $FoundAny = $true
        $sizeMB = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "  OK $path" -ForegroundColor Green
        Write-Host "    Size: $([math]::Round($sizeMB,2)) MB" -ForegroundColor Gray
        
        # Check subfolders
        Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $subSize = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum / 1MB
            Write-Host "    $($_.Name): $([math]::Round($subSize,2)) MB" -ForegroundColor Gray
        }
    }
}

if (-not $FoundAny) {
    Write-Host "  No Cline storage found (extension not installed or never run)" -ForegroundColor Red
}

# ─── Check VS Code Settings ───────────────────────────────────────
Write-Host "`nVS Code Settings:" -ForegroundColor Cyan

$SettingsPaths = @(
    "$env:APPDATA\Code\User\settings.json",
    "$env:APPDATA\Code - Insiders\User\settings.json"
)

foreach ($settingsPath in $SettingsPaths) {
    if (Test-Path $settingsPath) {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($settings) {
            $clineKeys = $settings.PSObject.Properties.Name | Where-Object { $_ -like "cline.*" }
            if ($clineKeys) {
                Write-Host "  Found in: $settingsPath" -ForegroundColor Green
                foreach ($key in $clineKeys) {
                    $val = $settings.$key
                    if ($key -like "*apiKey*" -or $key -like "*key*") {
                        $val = "***HIDDEN***"
                    }
                    Write-Host "    $key = $val" -ForegroundColor Gray
                }
            } else {
                Write-Host "  No Cline settings in: $settingsPath" -ForegroundColor Yellow
            }
        }
    }
}

# ─── Check .clineignore ───────────────────────────────────────────
Write-Host "`n.clineignore:" -ForegroundColor Cyan

$ProjectRoots = @(
    "D:\DevOptimizer",
    "D:\DevOptimizer\scripts",
    "$env:USERPROFILE\DevOptimizer",
    "$env:USERPROFILE\projects",
    "$env:USERPROFILE\code",
    "/home/tbaltzakis/ComfyUI-Docker/cu130-slim",
    "/mnt/d/DevOptimizer",
    "/mnt/d/DevOptimizer/scripts"
)

foreach ($root in $ProjectRoots) {
    $ignorePath = Join-Path $root ".clineignore"
    if (Test-Path $ignorePath) {
        $lines = (Get-Content $ignorePath).Count
        Write-Host "  OK $ignorePath ($lines lines)" -ForegroundColor Green
    }
}

# ─── Check .clinerules / custom instructions ──────────────────────
Write-Host "`nCustom Instructions:" -ForegroundColor Cyan

foreach ($root in $ProjectRoots) {
    foreach ($file in @(".clinerules", ".cline-instructions.md", "CLINE_INSTRUCTIONS.md")) {
        $path = Join-Path $root $file
        if (Test-Path $path) {
            Write-Host "  OK $path" -ForegroundColor Green
        }
    }
}

# ─── Rate Limit Optimization Checklist ────────────────────────────
Write-Host "`nNVIDIA NIM Free Tier Optimization Checklist:" -ForegroundColor Cyan

$Checks = @(
    @{ Name = "Plan/Act separate models enabled"; Desc = "Use ultra for Plan, nano for Act"; Critical = $true },
    @{ Name = "Reasoning effort = medium"; Desc = "Not high - saves approx 40% tokens"; Critical = $true },
    @{ Name = "Prompt caching enabled"; Desc = "Reuses system prompts on follow-ups"; Critical = $true },
    @{ Name = ".clineignore in project root"; Desc = "Excludes node_modules, build, media, etc."; Critical = $true },
    @{ Name = "Custom instructions configured"; Desc = "Guides Cline behavior, reduces clarification tokens"; Critical = $false },
    @{ Name = "Model: nemotron-3-ultra-550b (Plan)"; Desc = "Strong reasoning for architecture"; Critical = $true },
    @{ Name = "Model: nemotron-3-nano-30b (Act)"; Desc = "Cheaper, faster for implementation"; Critical = $true },
    @{ Name = "Context window <= 128K"; Desc = "Matches NIM free tier limits"; Critical = $true },
    @{ Name = "Max tokens <= 8192"; Desc = "Prevents runaway generations"; Critical = $true }
)

foreach ($check in $Checks) {
    $icon = if ($check.Critical) { "[CRITICAL]" } else { "[OPTIONAL]" }
    Write-Host "  $icon $($check.Name)" -ForegroundColor White
    Write-Host "      $($check.Desc)" -ForegroundColor Gray
}

# ─── Quick Token Estimation ───────────────────────────────────────
Write-Host "`nToken Usage Estimation (per task):" -ForegroundColor Cyan
Write-Host "  Plan mode (ultra):     ~2,000-5,000 tokens" -ForegroundColor Gray
Write-Host "  Act mode (nano):       ~1,000-3,000 tokens" -ForegroundColor Gray
Write-Host "  With prompt caching:   -30-50% on follow-ups" -ForegroundColor Green
Write-Host "  With .clineignore:     -50-80% context tokens" -ForegroundColor Green
Write-Host "  -----------------------------------" -ForegroundColor Gray
Write-Host "  Estimated per task:    ~1,500-4,000 tokens (optimized)" -ForegroundColor Cyan
Write-Host "  Free tier (~100 RPM):  ~15-40 tasks/minute theoretical" -ForegroundColor Yellow

Write-Host "`n=== Verification Complete ===" -ForegroundColor Magenta