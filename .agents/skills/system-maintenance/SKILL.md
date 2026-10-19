---
name: system-maintenance
description: |
  Performs safe Windows 11 system maintenance tasks including cleanup, WSL management, and log cleanup while preserving Devin work. Use when the user wants to run maintenance workflows, clean temporary files, manage WSL containers, or perform system optimization without administrative privileges.
---

# System Maintenance Skill

This skill automates safe system maintenance workflows for DevOptimizer environments, focusing on non-administrative tasks that improve system health without interfering with ongoing work (especially Devin operations).

## Workflows

### 1. Safe Maintenance Workflow

**Execute Standard Maintenance Sequence**
```powershell
# 1. Safe cleanup (user temp, package caches, Docker images)
./scripts/Execute-Command.ps1 -ScriptPath scripts/win11-safe-cleanup.ps1 -RunNow

# 2. WSL cleanup (stopped containers, temp files)
wsl.exe -d Ubuntu-26.04 docker container prune -f
wsl.exe -d Ubuntu-26.04 find /tmp /var/tmp -type f -mtime +1 -delete 2>/dev/null || true

# 3. Windows log cleanup (user-specific logs)
Remove-Item -Path "$HOME/.aws/amazonq/lspLog.log" -ErrorAction SilentlyContinue
Remove-Item -Path "$HOME/.cache/firebase/firebase-debug.log" -ErrorAction SilentlyContinue
Remove-Item -Path "$HOME/.cloudbase-mcp/logs\*" -Recurse -ErrorAction SilentlyContinue

# 4. Generate maintenance report
$logDir = "logs/maintenance-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Path $logDir | Out-Null
# Copy relevant logs to maintenance directory
```

**Key Validation Steps**
- Check WSL memory status before/after: `check-wsl-system-status.ps1`
- Verify disk space changes: Monitor C: drive free space
- Confirm Devin directories untouched: Validate `/.devin*` paths preserved
- Check Docker status: `docker system df`

### 2. Devin-Protected Cleanup

**Preserve Critical Paths**
The skill automatically excludes:
- `/.devin`, `/.devin-server`, `/.devin-shared` directories
- Devin-associated Docker containers/images
- Devin configuration and credential files
- Any paths containing "devin" in the name (configurable)

**Safe Cleanup Targets**
- User temp files (`$env:TEMP`, `$TMP`, `/tmp`, `/var/tmp`)
- Package manager caches (npm, pip, pnpm, yarn)
- Docker build cache and dangling images (safe subset)
- Windows user-specific log files
- Stopped WSL containers
- PowerShell/IE transient files

### 3. Reporting & Metrics

**Generate Maintenance Summary**
After execution, produces:
- Disk space freed (C: drive)
- WSL memory improvement (host RAM free, vmmemWSL working set)
- Container cleanup count (stopped containers removed)
- Log files deleted
- Docker space reclaimed
- Timestamped log folder with execution details

**Output Format**
Markdown report with sections:
- Executive Summary
- Disk Space Metrics
- WSL Memory Metrics  
- Container Management
- Log Cleanup Results
- Devin Protection Verification
- Recommendations

## Trigger Patterns

Auto-triggers on (in this repo):
- Keywords: `system maintenance`, `safe cleanup`, `WSL cleanup`, `log cleanup`, `maintenance workflow`, `optimize system`, `clean temp files`
- File paths: `scripts/win11-safe-cleanup.ps1`, `scripts/check-wsl-*`, maintenance-related operations
- Directory: Working in `/d/DevOptimizer` or `D:\DevOptimizer`
- Phrases: "run maintenance", "perform cleanup", "optimize WSL", "clean logs safely"

## Example Interactions

**User: "Run a safe maintenance workflow"**
→ Skill executes: win11-safe-cleanup → WSL container cleanup → temp file removal → log cleanup → generates report

**User: "Clean up temp files and WSL without affecting Devin"**  
→ Skill performs: user temp cleanup, npm/pip/pnpm cache clear, WSL stopped container removal, /tmp cleanup, skips all Devin paths

**User: "Show me what maintenance actions are safe to run now"**
→ Skill lists: available safe cleanup commands, explains Devin protection mechanisms, provides dry-run options

**User: "Did the last maintenance improve WSL memory?"**  
→ Skill compares: pre/post maintenance WSL metrics from logs, reports memory improvement metrics

## Safety Features

### Devin Work Protection
- Automatic exclusion of `/.devin*` paths
- Container filtering to preserve Devin-associated services
- Log cleanup limited to user-specific, non-Devin logs
- Dry-run capability to preview actions before execution
- Elevation-aware (avoids admin tasks unless explicitly requested)

### Idempotency
- Safe to run multiple times
- Tracks what was cleaned in session logs
- Reports "0 items cleaned" when already clean
- No destructive actions without explicit confirmation

## Logging & Audit Trail

All maintenance actions logged to:
- `logs/maintenance-<timestamp>/` directory
- Individual action logs: win11-safe-cleanup.log, wsl-cleanup.log, etc.
- Consolidated summary: maintenance-summary-<timestamp>.md
- JSON metrics file for programmatic access

## Dependencies

Requires:
- PowerShell 5.1+
- WSL2 with Ubuntu-26.04 (configurable)
- Docker Desktop or Docker Engine
- DevOptimizer script hub (Check-Health.ps1, win11-safe-cleanup.ps1, etc.)
- Standard Windows utilities (Remove-Item, wsl.exe, docker)
