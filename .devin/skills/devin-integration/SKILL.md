---
name: devin-integration
description: DevOptimizer Devin Desktop integration - health checks, maintenance, diagnostics, and WSL management
allowed-tools: [read, write, edit, bash, glob, grep, exec]
triggers: [user, model]
subagent: false
model: ""
---

# DevOptimizer Devin Integration Skill

This skill provides comprehensive Devin Desktop management through DevOptimizer scripts. It wraps the official Devin CLI patterns and extends them with Windows/WSL-specific optimizations.

## Capabilities

### Health & Diagnostics
- **`/devin-health`** - Quick health check (WSL, devin-server, memory, bundles)
- **`/devin-diag`** - Deep diagnostics (app version, commit dirs, logs, error signatures)
- **`/devin-doctor`** - Community devin-doctor wrapper (stores, schema, config, disk)

### Maintenance & Repair
- **`/devin-maintain`** - Daily maintenance (cache sweep, log retention, bundle cleanup)
- **`/devin-repair`** - Repair actions (fix bundle, clean leftovers, prune logs)
- **`/devin-cleanup check`** - Run devin-doctor check (stores, schema, config, disk)
- **`/devin-cleanup report`** - Generate formatted report for issues
- **`/devin-cleanup plan`** - Emit remediation plan (read-only)
- **`/devin-cleanup prune-acp`** - Prune old ACP message databases (14-day default)
- **`/devin-cleanup cleanup-sessions`** - Remove superseded commit dirs + prune server logs
- **`/devin-cleanup daily-maintenance`** - Run full daily maintenance suite
- **`/devin-cleanup health`** - Quick health check (alias for /devin-health)
- **`/devin-cleanup diagnostics`** - Deep read-only diagnostics
- **`/devin-cleanup repair-bundle`** - Repair corrupt bundle (requires Reload Window)
- **`/devin-cleanup verify-setup`** - 9-check verification with auto-fix

### WSL & System
- **`/devin-wsl-status`** - WSL system status check
- **`/devin-wsl-pressure`** - WSL memory pressure monitor
- **`/devin-tune-windows`** - Windows tuning for Devin (priority, startup, etc.)

### Configuration
- **`/devin-config`** - Manage Devin CLI config (mcp_config.json, hooks.v1.json, skills)
- **`/devin-credentials`** - Setup credentials.toml for CLI auth

## Usage Examples

```
/devin-health
/devin-diag --outfile report.json
/devin-doctor --skip-install
/devin-maintain --log-retention 14
/devin-repair --fix-bundle --force
/devin-cleanup --days 14 --remove-large
/devin-tune-windows --priority high --startup
```

## Implementation Notes

All commands delegate to PowerShell scripts in `D:\DevOptimizer\scripts\devin\` which follow:
- Official Devin Desktop data paths (%APPDATA%\devin, ~/.devin-server in WSL)
- WSL Ubuntu-26.04 distro for devin-server
- Read-first, write-guarded patterns (dry-run by default)
- Event Log integration (DevOptimizer source, IDs 1000-1005)
- JSON reporting for automation

## Files

| Script | Purpose |
|--------|---------|
| Check-DevinHealth.ps1 | Quick health check |
| Get-DevinDiagnostics.ps1 | Deep diagnostics |
| Check-DevinDoctor.ps1 | Community devin-doctor wrapper |
| Invoke-DevinDailyMaintenance.ps1 | Daily maintenance |
| Repair-Devin.ps1 | Repair actions |
| Tune-Windows-For-Devin.ps1 | Windows optimization |

## Prerequisites

- Windows 10/11 with WSL2 (Ubuntu-26.04)
- Devin Desktop installed
- Python + pipx (for devin-doctor)
- PowerShell 5.1+