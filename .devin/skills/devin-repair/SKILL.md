---
name: devin-repair
description: Repair Devin Desktop issues - fix bundle, clean leftovers, prune logs
allowed-tools: [bash, exec]
triggers: [user]
subagent: false
---

# Devin Repair Skill

Guarded repair actions for Devin Desktop's WSL remote. **Dry-run by default** - use flags to execute.

## Usage
```
/devin-repair [--fix-bundle] [--clean-leftovers] [--prune-logs] [--days N] [--force]
```

## Repair Actions

| Flag | Action | Safety |
|------|--------|--------|
| `--fix-bundle` | Kill devin-server, delete corrupt commit dir (~700 MB re-download) | Only runs if bundle fails integrity test, or with `--force` |
| `--clean-leftovers` | Delete superseded commit dirs + sidecar files (.log, .pid, .token) | Never touches live commit, extensions/, data/, .installation_lock |
| `--prune-logs` | Delete server logs older than N days (default 14) | Age-gated only |
| `--force` | Skip confirmations and integrity checks | Use with caution |

## Implementation
Delegates to `Repair-Devin.ps1`.

```bash
# Dry-run (default)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\devin\Repair-Devin.ps1"

# Fix corrupt bundle
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\devin\Repair-Devin.ps1" --fix-bundle --force

# Clean leftovers + prune logs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\devin\Repair-Devin.ps1" --clean-leftovers --prune-logs --days 7 --force
```

## Prerequisites
- WSL Ubuntu-26.04 reachable
- Devin Desktop closed (for --fix-bundle)
- Run without flags first to see dry-run plan

## Exit Codes
- 0 = Done (dry-run or repairs completed)
- 1 = Refused (WSL down, bundle intact without --force)
- 2 = --fix-bundle executed (finish with "Reload Window" in Devin)

## Common Scenarios
1. **"Remote Extension host terminated unexpectedly"** → `--fix-bundle`
2. **Disk space low in ~/.devin-server/bin/** → `--clean-leftovers`
3. **Old logs accumulating** → `--prune-logs --days 7`