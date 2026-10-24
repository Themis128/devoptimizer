---
name: devin-health-check
description: Quick Devin Desktop health check - WSL, devin-server, memory, bundles
allowed-tools: [bash, exec]
triggers: [user]
subagent: false
---

# Devin Health Check Skill

Run a quick health check of Devin Desktop's WSL remote environment.

## Usage
```
/devin-health-check
```

## What It Checks
1. **WSL Ubuntu-26.04** - Reachable and responsive
2. **WSL Uptime** - Detects boot race conditions (< 3 min)
3. **devin-server** - Process running, current commit
4. **Bundle Integrity** - node_modules/minimist + @vscode present
5. **Host Memory** - Free RAM (warn < 2 GB, fail < 1 GB)
6. **Superseded Commits** - Old commit dirs wasting space

## Implementation
Delegates to `Check-DevinHealth.ps1` in DevOptimizer scripts.

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\devin\Check-DevinHealth.ps1"
```

## Exit Codes
- 0 = Healthy
- 1 = Problems found
- 2 = Repaired (rerun to confirm)

## Repair
If issues found, run:
```
/devin-repair --fix-bundle --clean-leftovers
```