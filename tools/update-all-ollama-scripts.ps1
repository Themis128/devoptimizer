<#
.SYNOPSIS
    Updates all ollama scripts.
.DESCRIPTION
    Updates all ollama scripts.
#>

# Update All Ollama Scripts to Use Multi-Model System
# PowerShell script to automatically convert hardcoded ollama run calls

param(
    [string]$ScriptPath = "."
)

Write-Host "🔄 Updating Ollama Scripts to Multi-Model System" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDir = Split-Path -Parent $scriptDir

# Find all ollama batch files
$ollamaFiles = Get-ChildItem -Path $parentDir -Filter "ollama-*.bat" -File

if ($ollamaFiles.Count -eq 0) {
    Write-Host "❌ No Ollama batch files found in: $parentDir" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($ollamaFiles.Count) Ollama batch files:" -ForegroundColor Green
foreach ($file in $ollamaFiles) {
    Write-Host "  - $($file.Name)" -ForegroundColor White
}
Write-Host ""

$updatedCount = 0
$totalCount = $ollamaFiles.Count

foreach ($file in $ollamaFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Yellow
    
    try {
        # Create backup
        $backupPath = "$($file.FullName).backup"
        Copy-Item $file.FullName $backupPath -Force
        
        # Read file content
        $content = Get-Content $file.FullName -Raw
        
        # Update headers
        $content = $content -replace "🤖 OLLAMA AI SYSTEM ANALYZER", "🤖 OLLAMA MULTI-MODEL AI SYSTEM ANALYZER"
        $content = $content -replace "📈 OLLAMA PERFORMANCE SCORER", "📈 OLLAMA MULTI-MODEL PERFORMANCE SCORER"
        $content = $content -replace "🧠 OLLAMA INTELLIGENT MONITOR", "🧠 OLLAMA MULTI-MODEL INTELLIGENT MONITOR"
        $content = $content -replace "🔧 OLLAMA INTELLIGENT OPTIMIZER", "🔧 OLLAMA MULTI-MODEL INTELLIGENT OPTIMIZER"
        $content = $content -replace "🔮 OLLAMA PREDICTIVE MAINTENANCE", "🔮 OLLAMA MULTI-MODEL PREDICTIVE MAINTENANCE"
        $content = $content -replace "📝 OLLAMA SCRIPT GENERATOR", "📝 OLLAMA MULTI-MODEL SCRIPT GENERATOR"
        
        # Update descriptions
        $content = $content -replace "Starting comprehensive AI-powered system analysis\.\.\.", "Starting comprehensive AI-powered system analysis using ALL available Ollama models..."
        $content = $content -replace "Choose scoring mode:", "Choose scoring mode (using multi-model consensus analysis):"
        
        # Replace ollama run calls with multi-model calls
        $pattern = 'ollama run qwen2\.5-coder:7b "([^"]*)" > "([^"]*)"'
        $replacement = 'call "%~dp0tools\ollama-batch-helper.bat" -prompt "$1" -output "$2"'
        $content = $content -replace $pattern, $replacement
        
        # Also handle other model patterns
        $pattern2 = 'ollama run qwen2\.5:1\.5b "([^"]*)" > "([^"]*)"'
        $content = $content -replace $pattern2, $replacement
        
        # Handle any other ollama run patterns
        $pattern3 = 'ollama run [^"]* "([^"]*)" > "([^"]*)"'
        $content = $content -replace $pattern3, $replacement
        
        # Add multi-model description if not present
        if ($content -notmatch "multi-model|Multi-Model|MULTI-MODEL") {
            $content = $content -replace "(echo Starting.*analysis\.\.\.)", "`$1`necho - Multi-model consensus analysis for enhanced accuracy"
        }
        
        # Write updated content back to file
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8
        
        Write-Host "  ✅ Updated successfully" -ForegroundColor Green
        $updatedCount++
        
    } catch {
        Write-Host "  ❌ Update failed: $($_.Exception.Message)" -ForegroundColor Red
        
        # Restore backup if update failed
        if (Test-Path $backupPath) {
            Copy-Item $backupPath $file.FullName -Force
        }
    }
    
    Write-Host ""
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "UPDATE SUMMARY" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total scripts found: $totalCount" -ForegroundColor White
Write-Host "Successfully updated: $updatedCount" -ForegroundColor Green
Write-Host "Failed updates: $($totalCount - $updatedCount)" -ForegroundColor Red
Write-Host ""

if ($updatedCount -gt 0) {
    Write-Host "✅ Multi-model system integration completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The following scripts now use ALL available Ollama models:" -ForegroundColor White
    foreach ($file in $ollamaFiles) {
        if (Test-Path "$($file.FullName).backup") {
            Write-Host "  - $($file.Name)" -ForegroundColor Cyan
        }
    }
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Test the updated scripts" -ForegroundColor White
    Write-Host "2. Delete .backup files when satisfied" -ForegroundColor White
    Write-Host "3. Enjoy enhanced multi-model analysis!" -ForegroundColor White
} else {
    Write-Host "❌ No scripts were updated. Please check for errors." -ForegroundColor Red
}

Write-Host ""
