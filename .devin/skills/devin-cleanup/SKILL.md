---
name: devin-cleanup
description: Devin Desktop data cleanup and maintenance via devin-doctor and DevOptimizer scripts
version: 1.0.0
---

# Devin Cleanup Skill

This skill provides commands to clean up and maintain Devin Desktop's data stores using the official devin-doctor tool and DevOptimizer's maintenance scripts.

## Commands

### `/devin-cleanup check`
Run devin-doctor check to diagnose data stores, schema versions, and disk usage.

### `/devin-cleanup report`
Generate a formatted report suitable for GitHub issues.

### `/devin-cleanup plan`
Emit a remediation plan for WARN/FAIL findings (read-only, no execution).

### `/devin-cleanup prune-acp`
Prune old ACP message databases (14-day retention) using DevOptimizer's prune-acp.ps1.

### `/devin-cleanup cleanup-sessions`
Remove superseded Devin commit directories and prune server logs using Repair-Devin.ps1.

### `/devin-cleanup daily-maintenance`
Run the full daily maintenance suite (Invoke-DevinDailyMaintenance.ps1).

### `/devin-cleanup health`
Run Check-DevinHealth.ps1 for a quick health verdict.

### `/devin-cleanup diagnostics`
Run Get-DevinDiagnostics.ps1 for deep read-only diagnostics.

### `/devin-cleanup repair-bundle`
Repair a corrupt bundle (kills devin-server, deletes commit dir - requires Reload Window).

### `/devin-cleanup verify-setup`
Run Verify-DevinSetup.ps1 for a comprehensive 9-check verification.

## Usage Examples

```
/devin-cleanup check
/devin-cleanup plan
/devin-cleanup prune-acp
/devin-cleanup cleanup-sessions --days 7
/devin-cleanup daily-maintenance
/devin-cleanup health
/devin-cleanup diagnostics --outfile ~/devin-diag.json
/devin-cleanup repair-bundle --force
/devin-cleanup verify-setup
```

## Notes

- All commands are read-only except `prune-acp`, `cleanup-sessions`, `daily-maintenance`, and `repair-bundle`
- The `repair-bundle` command requires clicking "Reload Window" in Devin Desktop afterward
- Commands run via WSL (Ubuntu-26.04) for devin-doctor, and PowerShell for DevOptimizer scripts