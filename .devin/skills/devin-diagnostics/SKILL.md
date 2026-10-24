---
name: devin-diagnostics
description: Deep Devin Desktop diagnostics - app version, commit dirs, logs, error signatures
allowed-tools: [bash, exec, read]
triggers: [user]
subagent: false
---

# Devin Diagnostics Skill

Comprehensive read-only diagnostic report for Devin Desktop.

## Usage
```
/devin-diagnostics [--outfile report.json]
```

## What It Collects
1. **App Version** - Devin.exe version
2. **WSL State** - Reachable, uptime, guest memory
3. **devin-server** - Process, commit, bundle integrity
4. **Commit Dirs** - All commit dirs in ~/.devin-server/bin/
5. **Superseded Dirs** - Old commits safe to clean
6. **Extensions** - Count in ~/.devin-server/extensions
7. **Server Logs** - Size of ~/.devin-server/data/logs
8. **Renderer Log Scan** - ERR_MODULE_NOT_FOUND, exthost crashes
9. **Server Log Scan** - ERR_MODULE_NOT_FOUND, exited processes

## Implementation
Delegates to `Get-DevinDiagnostics.ps1`.

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\devin\Get-DevinDiagnostics.ps1" --outfile report.json
```

## Output
- Console: Color-coded findings (PASS/WARN/FAIL)
- JSON (with --outfile): Full structured report for automation

## Common Findings
| Finding | Action |
|---------|--------|
| devin-server not running | Click "Reload Window" in Devin |
| Bundle corrupt | Run `/devin-repair --fix-bundle` |
| Superseded commits | Run `/devin-repair --clean-leftovers` |
| Host memory low | Run cleanup scripts |
| WSL boot race | Wait for WSL uptime > 3 min |