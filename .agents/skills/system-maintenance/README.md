# System Maintenance Skill

This skill provides automated workflows for performing safe system maintenance on DevOptimizer environments while protecting ongoing work (especially Devin operations).

## Usage

### Via ZCode Interaction
Simply mention maintenance-related tasks and the skill will trigger automatically:
- "Run a safe maintenance workflow"
- "Clean up temp files and WSL without affecting Devin"
- "Optimize system performance safely"
- "Perform log cleanup"

### Direct Skill Invocation
You can also explicitly invoke the skill:
```
/skill system-maintenance <your request>
```

## What It Does

The skill orchestrates a safe maintenance sequence:

1. **Safe Cleanup** (`win11-safe-cleanup.ps1`)
   - Clears user temp files
   - Cleans package manager caches (npm, pip, pnpm)
   - Removes Docker dangling images (safe subset)
   - Clears PowerShell/IE transient files

2. **WSL Management**
   - Removes stopped containers
   - Cleans temporary files in `/tmp` and `/var/tmp`
   - Monitors memory usage improvements

3. **Log Cleanup**
   - Removes specific user log files (AWS, Firebase, CloudBase MCP)
   - Preserves system and Devin-related logs

4. **Reporting**
   - Generates timestamped log folder with execution details
   - Provides metrics on disk space freed, memory improved, etc.

## Safety Features

### Devin Work Protection
- Automatically excludes `/.devin`, `/.devin-server`, `.devin-shared` directories
- Filters Docker operations to preserve Devin-associated containers
- Limits log cleanup to user-specific, non-Devin paths
- Provides dry-run capabilities for previewing actions

### Non-Administrative
- All tasks performable without elevated privileges
- Avoids actions requiring admin rights (DISM, sfc, service changes)
- Safe for execution during active work sessions

## Logging & Audit Trail

All maintenance actions are logged to:
```
logs/maintenance-<timestamp>/
├── win11-safe-cleanup.log
├── wsl-cleanup.log  
├── log-cleanup.log
├── maintenance-summary-<timestamp>.md
└── metrics.json
```

## Example Workflow

When you say: "Run maintenance to clean temp files and WSL containers"

The skill will:
1. Execute `win11-safe-cleanup.ps1` via the DevOptimizer launcher
2. Run WSL container prune and temp file cleanup
3. Clean specified Windows user log files
4. Generate a maintenance report in `logs/maintenance-<timestamp>/`
5. Provide feedback on disk space and memory improvements

## Customization

The skill can be customized by modifying:
- WSL distribution name (default: Ubuntu-24.04)
- Log file patterns to clean
- Temporary file age thresholds
- Exclusion lists for Devin protection

See the SKILL.md file for full details and advanced usage.
