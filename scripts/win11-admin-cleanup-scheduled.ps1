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
} finally {
    Stop-Transcript | Out-Null
}
