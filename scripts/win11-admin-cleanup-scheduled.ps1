<#
.SYNOPSIS
    Scheduled wrapper for the elevated admin cleanup: transcripts the run to a dated log.
.DESCRIPTION
    Registered as \DevOptimizer\Admin-Cleanup-Weekly (Sundays 03:00, RunLevel Highest).
    Wraps win11-admin-cleanup-elevated-fixed.ps1 with a Start-Transcript so every
    scheduled run leaves a per-run log in logs\win11-admin-cleanup-<date>.log.
#>
#requires -Version 5.1
# CATEGORY: cleanup

$log = 'D:\DevOptimizer\logs\win11-admin-cleanup-{0:yyyyMMdd}.log' -f (Get-Date)
Start-Transcript -Path $log -Force | Out-Null
try {
    & 'D:\DevOptimizer\scripts\win11-admin-cleanup-elevated-fixed.ps1'

    # Weekly vhdx compaction rides on this elevated task (2026-10-05): the nightly
    # WSL-Vhdx-Compact SYSTEM task registration GHOSTS on this Insider build (task
    # invisible to the standard scheduler view, never runs). Invoke-VhdxCompaction
    # is Devin-gated and 10-GB-growth-gated, so weekly invocation with the same
    # gates is equivalent. Skips silently when the growth threshold is unmet.
    Write-Host "`n=== Part 2: vhdx compaction (gated) ===" -ForegroundColor Cyan
    & 'D:\DevOptimizer\scripts\Invoke-VhdxCompaction.ps1' -AsLibrary
} finally {
    Stop-Transcript | Out-Null
}
