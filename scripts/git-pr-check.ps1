<#
.SYNOPSIS
    Pre-PR / pre-push situational check for the DevOptimizer repo.
.DESCRIPTION
    Prints everything needed before opening a PR or pushing, so work is never
    duplicated against another agent's in-flight PR:
      - origin/main HEAD (fetch first unless -NoFetch)
      - current branch + how far it diverges from origin/main
      - open PRs (gh pr list) with author/head/age
      - PRs merged in the last 24h
      - staged/unstaged worktree summary
    Exit code 0 always (report-only). Use -Json for machine-readable output.
.EXAMPLE
    .\scripts\git-pr-check.ps1
    .\scripts\git-pr-check.ps1 -Json
#>
#requires -Version 5.1
# CATEGORY: verification

[CmdletBinding()]
param(
    [switch]$NoFetch,
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

function Invoke-Gh {
    param([string[]]$GhArgs)
    $out = & gh @GhArgs 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($out | Out-String).Trim()
}

# --- git state ---
if (-not $NoFetch) { git fetch origin --quiet 2>$null }
$mainHead = (git rev-parse --short origin/main 2>$null)
$branch   = (git rev-parse --abbrev-ref HEAD 2>$null)
$ahead    = (git rev-list --count "origin/main..HEAD" 2>$null)
$behind   = (git rev-list --count "HEAD..origin/main" 2>$null)
$dirty    = @(git status --porcelain 2>$null).Count

# --- GitHub state ---
$openPrs  = Invoke-Gh @('pr','list','--state','open','--json','number,title,author,headRefName,createdAt','--limit','30')
$merged   = Invoke-Gh @('pr','list','--state','merged','--json','number,title,author,mergedAt','--limit','50','--search','merged:>=2026-11-08')

$openPrsObj  = if ($openPrs)  { $openPrs  | ConvertFrom-Json } else { @() }
$mergedObj   = if ($merged)   { $merged   | ConvertFrom-Json } else { @() }
$merged24h   = @($mergedObj | Where-Object { ([datetime]$_.mergedAt) -gt (Get-Date).AddHours(-24) })

if ($Json) {
    @{
        originMainHead = $mainHead
        branch         = $branch
        ahead          = [int]$ahead
        behind         = [int]$behind
        dirtyEntries   = $dirty
        openPrs        = $openPrsObj
        mergedLast24h  = $merged24h
    } | ConvertTo-Json -Depth 5
    return
}

Write-Host "=== Pre-PR check: $repoRoot ===" -ForegroundColor Cyan
Write-Host ("origin/main HEAD : {0}" -f $mainHead)
Write-Host ("current branch   : {0}  (ahead {1}, behind {2}, dirty entries {3})" -f $branch, $ahead, $behind, $dirty)
if ($branch -eq 'main') { Write-Host 'NOTE: on main - create a feature branch before PR work' -ForegroundColor Yellow }
if ([int]$behind -gt 0) { Write-Host "NOTE: branch is $behind commit(s) behind origin/main - rebase before PR" -ForegroundColor Yellow }

Write-Host "`n--- Open PRs ($($openPrsObj.Count)) ---" -ForegroundColor Cyan
if ($openPrsObj.Count -eq 0) { Write-Host '  (none)' }
foreach ($p in $openPrsObj) {
    Write-Host ("  #{0,-4} {1,-28} {2}  ({3})" -f $p.number, $p.headRefName, $p.author.login, ([datetime]$p.createdAt).ToString('MM-dd'))
    Write-Host ("        {0}" -f $p.title)
}

Write-Host "`n--- Merged in last 24h ($($merged24h.Count)) ---" -ForegroundColor Cyan
if ($merged24h.Count -eq 0) { Write-Host '  (none)' }
foreach ($p in $merged24h) {
    Write-Host ("  #{0,-4} {1}  by {2} at {3}" -f $p.number, $p.title, $p.author.login, ([datetime]$p.mergedAt).ToString('MM-dd HH:mm'))
}

Write-Host "`nReminder: never duplicate another agent's open PR; branch from latest origin/main." -ForegroundColor DarkGray
