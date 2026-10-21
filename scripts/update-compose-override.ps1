#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Update docker-compose.override.yml to convert containers to on-demand (restart=no)
#>

$overridePath = '/home/tbaltzakis/cu130-slim/docker-compose.override.yml'

# Read the file via WSL
$content = wsl -d Ubuntu-26.04 -- bash -c "cat '$overridePath'"

# Containers to convert to restart: no
$containersToConvert = @(
    'browser-novnc',
    'languagetool',
    'metabase',
    'instagram-private-api',
    'tiktok-browser-sidecar',
    'warp-proxy'
)

$lines = $content -split "`r?`n"
$inService = $false
$currentService = ''
$output = @()

foreach ($line in $lines) {
    # Check if this line starts a service definition
    if ($line -match '^\s{2}(\w[\w\-]*):\s*$') {
        $currentService = $matches[1]
        $inService = $true
    }
    
    # If we're in a service that needs conversion and see restart: always/unless-stopped
    if ($inService -and $containersToConvert -contains $currentService) {
        if ($line -match '^\s{4}restart:\s+(always|unless-stopped)\s*$') {
            $line = $line -replace 'restart:\s+(always|unless-stopped)', 'restart: no'
            Write-Host "  Converted ${currentService}: restart -> no"
        }
    }
    
    # End of service block (next service or empty line with less indent)
    if ($inService -and $line -match '^\s{2}\w') {
        $inService = $false
    }
    
    $output += $line
}

# Write back via WSL
$newContent = $output -join "`n"
wsl -d Ubuntu-26.04 -- bash -c "cat > '$overridePath' << 'EOF'
$newContent
EOF"

Write-Host "docker-compose.override.yml updated successfully" -ForegroundColor Green