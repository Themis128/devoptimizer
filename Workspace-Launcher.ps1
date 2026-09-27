#Requires -Version 5.1
<#
.SYNOPSIS
    VS Code Workspace Quick Launcher with Auto-Profile Selection
.DESCRIPTION
    Interactive menu to launch VS Code with the right profile for each workspace.
    Heavy workspaces (Next.js, full-stack) get Heavy profile.
    Light workspaces (config editing, markdown) get Light profile.
    Auto-detects workspace characteristics if not preconfigured.
.PARAMETER Workspace
    Directly launch a workspace by name without showing the menu
#>

[CmdletBinding()]
param(
    [string]$Workspace
)

$launcherScript = "D:\DevOptimizer\Launch-VSCode-Optimized.ps1"

# ═══════════════════════════════════════════════════════════════
# Workspace Registry
# Add your workspaces here. Profile auto-detects if not set.
# ═══════════════════════════════════════════════════════════════
$workspaces = @(
    @{
        Name    = "Portfolio (Next.js)"
        Path    = "\\wsl.localhost\Ubuntu\home\tbaltzakis\my-portfolio-aws"
        Profile = "Heavy"
        Shell   = "wsl"
        Tags    = @("next.js", "react", "aws")
    },
    @{
        Name    = "DevOptimizer"
        Path    = "D:\DevOptimizer"
        Profile = "Light"
        Shell   = ""
        Tags    = @("powershell", "scripts")
    },
    @{
        Name    = "Cloudless.gr Projects"
        Path    = "D:\Projects\cloudless"
        Profile = "Balanced"
        Shell   = ""
        Tags    = @("web", "client")
    },
    @{
        Name    = "ML / Data Analytics"
        Path    = "D:\Projects\ml"
        Profile = "Heavy"
        Shell   = ""
        Tags    = @("python", "jupyter", "data")
    },
    @{
        Name    = "Cline Workspace"
        Path    = "D:\Projects\cline"
        Profile = "Heavy"
        Shell   = "cygwin"
        Tags    = @("ai", "coding")
    },
    @{
        Name    = "Scratch / Quick Edit"
        Path    = ""
        Profile = "Light"
        Shell   = ""
        Tags    = @("temp")
    }
)

function Get-AutoProfile {
    param([string]$WorkspacePath)
    if (!$WorkspacePath -or !(Test-Path $WorkspacePath -ErrorAction SilentlyContinue)) { return "Balanced" }
    
    # Check for heavy indicators
    $heavy = @('package.json', 'next.config.*', 'nuxt.config.*', 'angular.json', 'docker-compose.*', '.devcontainer')
    foreach ($h in $heavy) {
        if (Get-ChildItem $WorkspacePath -Filter $h -ErrorAction SilentlyContinue) { return "Heavy" }
    }
    
    # Check for node_modules (heavy)
    if (Test-Path "$WorkspacePath\node_modules" -ErrorAction SilentlyContinue) { return "Heavy" }
    
    # Check for light indicators
    $light = @('*.md', '*.txt', '*.ps1', '*.cfg', '*.ini')
    $allFiles = Get-ChildItem $WorkspacePath -File -ErrorAction SilentlyContinue
    if ($allFiles.Count -lt 20) { return "Light" }
    
    return "Balanced"
}

function Get-GitStatus {
    param([string]$WorkspacePath)
    if (!$WorkspacePath -or !(Test-Path "$WorkspacePath\.git" -ErrorAction SilentlyContinue)) {
        # Try WSL path
        if ($WorkspacePath -match 'wsl') {
            try {
                $result = wsl bash -c "cd '$($WorkspacePath -replace '\\\\wsl.localhost\\Ubuntu', '' -replace '\\','/')' && git status --porcelain 2>/dev/null | wc -l" 2>$null
                if ($result -match '^\d+$') {
                    $changes = [int]$result
                    $branch = (wsl bash -c "cd '$($WorkspacePath -replace '\\\\wsl.localhost\\Ubuntu', '' -replace '\\','/')' && git rev-parse --abbrev-ref HEAD 2>/dev/null" 2>$null).Trim()
                    return @{ Branch = $branch; Changes = $changes; HasGit = $true }
                }
            } catch {}
        }
        return @{ HasGit = $false }
    }
    
    try {
        Push-Location $WorkspacePath
        $branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
        $changes = @(git status --porcelain 2>$null).Count
        Pop-Location
        return @{ Branch = $branch; Changes = $changes; HasGit = $true }
    } catch {
        if ((Get-Location).Path -ne $WorkspacePath) { Pop-Location -ErrorAction SilentlyContinue }
        return @{ HasGit = $false }
    }
}

# ═══════════════════════════════════════════════════════════════
# Direct Launch Mode
# ═══════════════════════════════════════════════════════════════
if ($Workspace) {
    $match = $workspaces | Where-Object { $_.Name -like "*$Workspace*" } | Select-Object -First 1
    if ($match) {
        $profile = if ($match.Profile) { $match.Profile } else { Get-AutoProfile $match.Path }
        $args = @("-Profile", $profile)
        if ($match.Path) { $args += @("-WorkspacePath", $match.Path) }
        if ($match.Shell) { $args += @("-Shell", $match.Shell) }
        & $launcherScript @args
        return
    }
    Write-Host "❌ No workspace matching '$Workspace'" -ForegroundColor Red
    return
}

# ═══════════════════════════════════════════════════════════════
# Interactive Menu
# ═══════════════════════════════════════════════════════════════
Clear-Host
Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   VS Code Workspace Quick Launcher                           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

for ($i = 0; $i -lt $workspaces.Count; $i++) {
    $ws = $workspaces[$i]
    $profile = if ($ws.Profile) { $ws.Profile } else { Get-AutoProfile $ws.Path }
    $profileColor = switch ($profile) {
        "Heavy"    { "Red" }
        "Balanced" { "Yellow" }
        "Light"    { "Green" }
    }
    
    # Git status
    $gitStr = ""
    if ($ws.Path -and (Test-Path $ws.Path -ErrorAction SilentlyContinue)) {
        $git = Get-GitStatus $ws.Path
        if ($git.HasGit) {
            $gitStr = " [git: $($git.Branch)"
            if ($git.Changes -gt 0) { $gitStr += ", $($git.Changes) changes" }
            $gitStr += "]"
        }
    }
    
    $exists = if ($ws.Path -and !(Test-Path $ws.Path -ErrorAction SilentlyContinue)) { " (❌ path not found)" } else { "" }
    $shellStr = if ($ws.Shell) { " 🐚$($ws.Shell)" } else { "" }
    
    Write-Host "  [$($i + 1)] " -ForegroundColor White -NoNewline
    Write-Host "$($ws.Name)" -ForegroundColor Cyan -NoNewline
    Write-Host " (" -NoNewline
    Write-Host $profile -ForegroundColor $profileColor -NoNewline
    Write-Host ")$shellStr$gitStr$exists" -ForegroundColor Gray
    
    if ($ws.Path) {
        Write-Host "      $($ws.Path)" -ForegroundColor DarkGray
    }
}

Write-Host "`n  [C] Custom path" -ForegroundColor Gray
Write-Host "  [D] Dashboard (live process monitor)" -ForegroundColor Gray
Write-Host "  [Q] Quit`n" -ForegroundColor Gray

$choice = Read-Host "Select workspace"

switch ($choice.ToUpper()) {
    'Q' { return }
    'C' {
        $customPath = Read-Host "Enter workspace path"
        if ($customPath -and (Test-Path $customPath)) {
            $autoProfile = Get-AutoProfile $customPath
            Write-Host "Auto-detected profile: $autoProfile" -ForegroundColor Cyan
            & $launcherScript -Profile $autoProfile -WorkspacePath $customPath
        } else {
            Write-Host "❌ Invalid path" -ForegroundColor Red
        }
        return
    }
    'D' {
        & "D:\DevOptimizer\Dashboard-Live.ps1"
        return
    }
    default {
        $idx = 0
        if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $workspaces.Count) {
            $ws = $workspaces[$idx - 1]
            $profile = if ($ws.Profile) { $ws.Profile } else { Get-AutoProfile $ws.Path }
            
            $launchArgs = @("-Profile", $profile)
            if ($ws.Path -and (Test-Path $ws.Path -ErrorAction SilentlyContinue)) {
                $launchArgs += @("-WorkspacePath", $ws.Path)
            }
            if ($ws.Shell) { $launchArgs += @("-Shell", $ws.Shell) }
            
            & $launcherScript @launchArgs
        } else {
            Write-Host "❌ Invalid selection" -ForegroundColor Red
        }
    }
}
