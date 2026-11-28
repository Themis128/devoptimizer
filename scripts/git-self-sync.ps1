# git-self-sync.ps1 — keep this clone fast-forwarded to origin/main.
# Scheduled as DevOptimizer-GitSync (hourly, conhost --headless — no console).
# The scheduled tasks run THIS checkout, not the WSL ~/devoptimizer repo;
# letting it lag means stale watchdogs (hit 2026-11-28: diskguard missed the
# ntfy fan-out patch for hours after it landed on main).
$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot '..\logs\git-sync.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
try {
    & git -C $PSScriptRoot\.. fetch -q origin 2>$null
    $behind = [int](& git -C $PSScriptRoot\.. rev-list --count HEAD..origin/main 2>$null)
    if ($behind -gt 0) {
        $out = & git -C $PSScriptRoot\.. pull --ff-only 2>&1
        Add-Content $log "$stamp pulled $behind commit(s): $($out -join ' ')"
    }
} catch {
    Add-Content $log "$stamp sync failed: $_"
}
