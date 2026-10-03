<#
.SYNOPSIS
    Execute the full 4-group commit plan for DevOptimizer (2026-10-03).
    Run this ONCE in an elevated PowerShell terminal.
    Mimosa L3 gate blocks agent commits -- this script runs in YOUR session.

.DESCRIPTION
    Groups:
    1. Security hardening (4 app files + tests) -- 78 xUnit green
    2. Untrack 516 build intermediates + .gitignore bin/obj rules
    3. Description sweep (317 scripts) + Discover-Scripts regex fix + regenerated registry (354 cmds)
    4. New features: WSL checks, VHDX compaction, Devin scripts, py CLI guard, journal-stress tests, hammer docs
    5. Push to origin/main

.NOTES
    Execute-Command.ps1 is modified but NOT in this plan.
    After this runs, optionally:
      git add Execute-Command.ps1
      git commit -m "fix(execute-command): elevated branch - hidden console, output forwarding, dedicated log subdir"
      git push origin main
#>

param(
    [switch]$DryRun,
    [switch]$SkipPush
)

$ErrorActionPreference = 'Stop'
$repoRoot = 'D:\DevOptimizer'
Set-Location $repoRoot

function Invoke-Git {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string[]]$Args,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$Description
    )
    Write-Host "`n=== $Description ===" -ForegroundColor Cyan
    Write-Host "git $($Args -join ' ')" -ForegroundColor Gray
    if (-not $DryRun) {
        $result = git $Args
        if ($LASTEXITCODE -ne 0) { throw "git $($Args[0]) failed: $result" }
        Write-Host $result
    }
}

# --- Group 1: Security hardening ---
Invoke-Git -Args @('reset') -Description 'Reset staging area'
Invoke-Git -Args @('add', 'app/launcher/Program.cs', 'app/DevOptimizer.App/Services/CommandRunnerService.cs', 'app/DevOptimizer.App.Tests/CommandRunnerServiceTests.cs', 'app/DevOptimizer.App.Tests/RegistryServiceTests.cs') -Description 'Stage Group 1 (security)'
Invoke-Git -Args @('commit', '-m', 'fix(security): harden process launches - absolute system interpreters, shell-metachar guard, repo-root containment; 78 xUnit green') -Description 'Commit Group 1'

# --- Group 2: Build intermediates ---
Invoke-Git -Args @('add', '.gitignore') -Description 'Stage .gitignore'
Invoke-Git -Args @('rm', '-r', '-q', '--cached', '--ignore-unmatch',
    'app/DevOptimizer.App/bin', 'app/DevOptimizer.App/obj',
    'app/DevOptimizer.App.Tests/bin', 'app/DevOptimizer.App.Tests/obj',
    'app/launcher/bin', 'app/launcher/obj') -Description 'Untrack 6 build dirs (516 files)'
Invoke-Git -Args @('commit', '-m', 'chore: untrack 516 app build intermediates; ignore bin/obj (repo stays source-only)') -Description 'Commit Group 2'

# --- Group 3: Description sweep ---
Invoke-Git -Args @('add', '-u', '.', ':(exclude)py', ':(exclude)app') -Description 'Stage Group 3 (sweep, excl py/app)'
Invoke-Git -Args @('commit', '-m', 'docs: description sweep across 317 hub scripts; Discover-Scripts synopsis regex stops at #> (EOF-overrun fix); registries regenerated (354 cmds, 0 missing descriptions)') -Description 'Commit Group 3'

# --- Group 4: New features ---
Invoke-Git -Args @('add', '-A') -Description 'Stage Group 4 (all remaining)'
Invoke-Git -Args @('commit', '-m', 'feat: WSL status/memory checks, VHDX compaction suite, Devin maintenance scripts; py CLI safe-write guard; journal-stress tests; hammer plan docs') -Description 'Commit Group 4'

# --- Push ---
if (-not $SkipPush) {
    Invoke-Git -Args @('push', 'origin', 'main') -Description 'Push to origin/main'
} else {
    Write-Host "`n[SKIP] Push skipped (-SkipPush). Run: git push origin main" -ForegroundColor Yellow
}

Write-Host "`nDONE: Commit plan complete." -ForegroundColor Green
if (-not $DryRun -and -not $SkipPush) {
    Write-Host "Next (optional):" -ForegroundColor Cyan
    Write-Host "  git add Execute-Command.ps1"
    Write-Host "  git commit -m 'fix(execute-command): elevated branch - hidden console, output forwarding, dedicated log subdir'"
    Write-Host "  git push origin main"
}