# DevOptimizer Script Hub - Architecture & Implementation Guide

## Overview

The **Script Hub** is a unified execution platform that consolidates all DevOptimizer components (50+ PowerShell scripts, Python CLI, batch files, configuration, modules) into a single, discoverable, category-driven system with:

- **Unified CLI** (`devoptimizer.ps1` + Python `hub` subcommand)
- **Interactive Menu** (dynamic, registry-driven)
- **Auto-Discovery** (scans all source directories)
- **Config Merge** (base + hub overlay)
- **Health Checks & Self-Update**
- **Cross-Platform Path Resolution** (Windows + WSL)
- **Admin Detection & Elevation**
- **JSON Schema Validation** (custom, no external deps)

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│  VERIFICATION LAYER (Task 15)                                │
│  validate-all-scripts.ps1 | test-*.ps1 | integration tests  │
├─────────────────────────────────────────────────────────────┤
│  INTEGRATION LAYER (Tasks 10-12)                            │
│  devoptimizer.ps1 ←→ Python CLI hub.py ←→ devoptimizer.ps1  │
├─────────────────────────────────────────────────────────────┤
│  EXECUTION LAYER (Tasks 3-7)                                │
│  Execute-Command.ps1 | Show-Menu.ps1 | Get-Category.ps1     │
│  Check-Health.ps1 | Update-Hub.ps1                          │
├─────────────────────────────────────────────────────────────┤
│  DISCOVERY LAYER (Task 3)                                   │
│  Discover-Scripts.ps1 → Build-Registry.ps1 → hub-registry.json │
├─────────────────────────────────────────────────────────────┤
│  CORE LAYER (Tasks 1-2, 9)                                  │
│  DevOptimizer-Master.psm1 (-LoadHub)                        │
│  DevOptimizer-Config.psm1 (Merge-HubConfig)                 │
│  DevOptimizer-Path.psm1 | DevOptimizer-Admin.psm1           │
│  DevOptimizer-Hub.psm1 (exports all hub functions)          │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Modules (Single Loading Strategy)

### DevOptimizer-Master.psm1 (Modified - Task 10)
```powershell
# Accepts -LoadHub parameter
param([switch]$LoadHub)

if ($LoadHub) {
    Import-Module DevOptimizer-Path
    Import-Module DevOptimizer-Admin
    Import-Module DevOptimizer-Hub
}
```

### DevOptimizer-Config.psm1 (Modified - Task 2)
```powershell
function Merge-HubConfig {
    param($BaseConfigPath, $HubConfigPath)
    $base = Get-Content $BaseConfigPath | ConvertFrom-Json
    $hub = Get-Content $HubConfigPath | ConvertFrom-Json -ErrorAction SilentlyContinue
    return Merge-Deep $base $hub  # Recursive overlay merge
}
```

### DevOptimizer-Path.psm1 (New - Task 9)
```powershell
function Resolve-HubPath { param($Path) 
    # Handles: relative, ~, WSL (/mnt/d/...), env vars, registry
}
function Get-HubRoot {
    # Priority: $env:DEVOPTIMIZER_HUB → HKCU:\SOFTWARE\DevOptimizer → D:\DevOptimizer
}
function Convert-WslPath { 
    # /mnt/d/DevOptimizer → D:\DevOptimizer (when $env:WSL_DISTRO_NAME set)
}
```

### DevOptimizer-Admin.psm1 (New - Task 9)
```powershell
function Test-AdminRights { 
    ([Security.Principal.WindowsIdentity]::GetCurrent().Groups | 
     Where-Object { $_.Value -eq 'S-1-5-32-544' }).Count -gt 0 
}
function Get-AdminStatus {
    @{ isAdmin=$...; elevationType=$...; canElevate=$... }
}
function Assert-AdminRights { param([switch]$Required) 
    if (-not (Test-AdminRights) -and $Required) { throw "Admin required" }
}
```

### DevOptimizer-Hub.psm1 (New - Task 10)
```powershell
# Loads core modules via Master, exports all hub functions
Export-ModuleMember Invoke-HubCommand, Show-HubMenu, Get-HubCategories, 
    Test-HubHealth, Update-Hub, Invoke-ScriptDiscovery, 
    Resolve-HubPath, Test-AdminRights
```

---

## Entry Points

### PowerShell: devoptimizer.ps1 (Task 11)
```powershell
.\devoptimizer.ps1 -List              # List all commands (≥50)
.\devoptimizer.ps1 -Category "system" # Filter by category
.\devoptimizer.ps1 -Command "Get-HubCategories" -AsAdmin
.\devoptimizer.ps1 -Menu              # Interactive menu
.\devoptimizer.ps1 -Quick             # Flat list (automation)
.\devoptimizer.ps1 -Health            # Health check
.\devoptimizer.ps1 -Update -WhatIf    # Update preview
.\devoptimizer.ps1 -Config            # Open config in editor
```

### Python CLI: hub subcommand (Task 12)
```bash
python -m devoptimizer_cli hub --help
python -m devoptimizer_cli hub list
python -m devoptimizer_cli hub list --category system
python -m devoptimizer_cli hub search "cleanup"
python -m devoptimizer_cli hub run Get-HubCategories --param key=value
python -m devoptimizer_cli hub menu
python -m devoptimizer_cli hub health
python -m devoptimizer_cli hub update
python -m devoptimizer_cli hub config
```

**Bridge Implementation** (hub.py):
```python
def run_devoptimizer_command(args):
    return subprocess.run([
        "powershell", "-ExecutionPolicy", "Bypass", 
        "-File", "devoptimizer.ps1"
    ] + args, capture_output=True, text=True)
```

---

## Discovery & Registry

### Discover-Scripts.ps1 (Task 3)
```powershell
function Invoke-ScriptDiscovery {
    param($ConfigPath)
    $dirs = @("scripts", "modules", "tools", "portable", "categories")
    foreach ($dir in $dirs) {
        Get-ChildItem -Recurse -File -Include *.ps1,*.bat,*.py |
        ForEach-Object { Extract-Metadata $_ }
    }
}

function Extract-Metadata {
    param($File)
    $header = Get-Content $File -TotalCount 30
    # Parse: # .SYNOPSIS, # .DESCRIPTION, param(), requires -RunAsAdministrator, # .TAGS
}
```

### Build-Registry.ps1 (Task 3)
```powershell
# Merges discovery + categories.json
# Validates against hub-registry.schema.json using Validate-JsonSchema.ps1
# Writes config/hub-registry.json
# Optionally writes to HKCU:\SOFTWARE\DevOptimizer\Hub
```

### Registry Schema (hub-registry.schema.json - Task 1)
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["version", "commands", "categories", "metadata"],
  "properties": {
    "version": { "type": "string" },
    "commands": {
      "type": "array",
      "items": {
        "required": ["name", "description", "category", "language", "path", "parameters", "requiresAdmin", "tags"],
        "properties": {
          "name": { "type": "string" },
          "description": { "type": "string" },
          "category": { "type": "string" },
          "language": { "enum": ["powershell", "batch", "python"] },
          "path": { "type": "string" },
          "parameters": { "type": "object" },
          "requiresAdmin": { "type": "boolean" },
          "tags": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "categories": { "type": "array" },
    "metadata": { 
      "required": ["generatedAt", "sourceDirs"],
      "properties": { "generatedAt": { "type": "string" }, "sourceDirs": { "type": "array" } }
    }
  }
}
```

---

## Execution Engine

### Execute-Command.ps1 (Task 4) - Dual Mode
```powershell
[CmdletBinding()]
param(
    [string]$CommandName,
    [hashtable]$Parameters,
    [switch]$NoWait,
    [switch]$AsAdmin,
    [string]$LogLevel
)

function Invoke-HubCommand {
    # 1. Resolve command from hub-registry.json
    # 2. Check admin: if $AsAdmin -and -not (Test-AdminRights) → Start-Process -Verb RunAs
    # 3. Execute by language:
    #    - .ps1: & $path @Parameters
    #    - .bat: cmd /c $path @Parameters
    #    - .py: python -m $path @Parameters
    # 4. Timeout (default 300s from config)
    # 5. Correlation ID logging via DevOptimizer-Logger
    # 6. Error handling via DevOptimizer-ErrorHandler
    # 7. Return: @{exitCode; stdout; stderr; duration; logPath}
}

# Script mode: Invoke-HubCommand @PSBoundParameters
# Function mode: Export-ModuleMember Invoke-HubCommand
```

---

## Interactive Menu

### Show-Menu.ps1 (Task 5)
```powershell
function Show-HubMenu {
    param([switch]$Quick, [switch]$Status, [string]$Category)
    
    if ($Quick) {
        # Flat list: Get-HubCategories | ForEach-Object { ... }
        return
    }
    
    if ($Status) {
        # Health + recent executions + config summary
        return
    }
    
    # Hierarchical: Categories → Commands → Execute/Details
    # ANSI colors, box-drawing chars
    # Navigation: arrows, enter, escape, type-to-filter
    # Persists last selection
    # On Execute → Invoke-HubCommand
}
```

---

## Category System

### Get-Category.ps1 (Task 6)
```powershell
function Get-HubCategories { 
    # Loads categories.json + hub-registry.json
    # Returns objects with computed command counts
}
function Get-HubCategoryCommands { param($CategoryName, $IncludeSubcategories) }
function Search-HubCommands { param($Query) }
function Add-HubFavorite { param($Name) 
    # Persists to config/hub-favorites.json
}
function Get-HubFavorites { 
    # Reads favorites, filters registry
}
```

**Categories (11+):** system-optimization, ai-ml, monitoring, overclocking, maintenance, network, security, development, utilities, launchers, diagnostics

---

## Health & Self-Update

### Check-Health.ps1 (Task 7)
```powershell
function Test-HubHealth {
    param([switch]$Verbose, [switch]$AutoFix)
    
    $checks = @(
        @{ Name="PowerShellVersion"; Script={ $PSVersionTable.PSVersion.Major -ge 5 } },
        @{ Name="ModulesLoaded"; Script={ ... } },
        @{ Name="ConfigFiles"; Script={ Test-Path config\hub-config.json; Validate-JsonSchema } },
        @{ Name="OllamaConnection"; Script={ Invoke-WebRequest http://localhost:11434/api/tags } },
        @{ Name="OverclockingTools"; Script={ Registry scan for MSI/XTU } },
        @{ Name="AdminRights"; Script={ Test-AdminRights } },
        @{ Name="RegistryAccess"; Script={ Test-Path config\hub-registry.json } },
        @{ Name="LogDirectory"; Script={ Test-Path logs } }
    )
    
    $results = $checks | ForEach-Object { 
        @{ Name=$_.Name; Status=(try { $_.Script.Invoke(); "Pass" } catch { "Fail" }); Message=... } 
    }
    
    # Overall: Healthy (all Pass) | Degraded (any Warning) | Critical (any Fail)
    # -AutoFix: recreates dirs, regenerates registry, fixes config
}
```

### Update-Hub.ps1 (Task 8)
```powershell
function Check-HubUpdates {
    # Reads hub-config.json: enabled, intervalHours, sourceUrl, verifySignature
    # Downloads manifest (version, files[], checksums)
    # Compares local vs remote
}
function Update-Hub {
    param([switch]$Force, [switch]$WhatIf)
    # 1. Backup: Compress-Archive hub\ → backups\hub\hub-backup-<timestamp>.zip
    # 2. Download: Invoke-WebRequest
    # 3. Verify: Get-FileHash -Algorithm SHA256
    # 4. Apply: Copy-Item -Force
    # 5. Rollback on failure: Restore-HubBackup
}
function Restore-HubBackup {
    # Restores most recent backup from backups\hub\
}
```

---

## Configuration System

### hub-config.json (Task 1) - Hub-Specific Only
```json
{
  "mergeStrategy": "overlay",
  "discovery": { "scripts": true, "modules": true, "tools": true, "portable": true, "categories": true },
  "execution": { "defaultTimeout": 300, "parallelLimit": 4, "adminRequired": false },
  "update": { "enabled": true, "intervalHours": 24, "sourceUrl": "https://...", "verifySignature": true },
  "logging": { "level": "Info", "retentionDays": 30 }
}
```

### categories.json (Task 1)
```json
{
  "categories": [
    { "name": "system-optimization", "displayName": "System Optimization", "icon": "⚡", "priority": 1, "scriptPatterns": ["*optimize*", "*tune*"] },
    { "name": "ai-ml", "displayName": "AI & ML", "icon": "🤖", "priority": 2, "scriptPatterns": ["*ai*", "*ml*", "*llm*"] }
  ]
}
```

---

## Validation & Testing

### validate-all-scripts.ps1 (Task 13)
- Recursively scans `scripts\`, `modules\`, `scripts\hub\`
- Runs PSScriptAnalyzer, syntax check, encoding validation
- Exit code 0 = all pass

### 12 Test Files (Task 13)
| Test File | Purpose |
|-----------|---------|
| test-hub-discovery.ps1 | Registry ≥50 commands, ≥10 categories |
| test-hub-execution.ps1 | Invoke-HubCommand returns valid result |
| test-hub-menu.ps1 | -Quick mode shows categories |
| test-hub-config.ps1 | JSON valid against schema, required keys |
| test-config-merge.ps1 | Base + overlay merge behavior |
| test-hub-path.ps1 | Resolve-HubPath, Get-HubRoot, Convert-WslPath |
| test-hub-admin.ps1 | Test-AdminRights, Get-AdminStatus, Assert-AdminRights |
| test-hub-health.ps1 | Test-HubHealth -Verbose -AutoFix, status enum |
| test-hub-update.ps1 | Check-HubUpdates, Update-Hub -WhatIf, Restore-HubBackup |
| test-hub-python-cli.ps1 | Subprocess tests: list, search, run, health |
| test-hub-category.ps1 | Category filtering, favorites persistence |
| test-hub-module.ps1 | Hub module initialization, exports |

---

## Config Merge Flow

```
devoptimizer-config.json (base)
        │
        ▼
hub-config.json (overlay - hub-specific only)
        │
        ▼
Merge-HubConfig() in DevOptimizer-Config.psm1
        │
        ▼
Merged Config Object (used by all hub components)
```

**Merge Rules:**
- Objects: deep merge (recursive)
- Arrays: replaced (hub wins)
- Primitives: hub wins
- Missing hub keys: fall back to base

---

## Verification Commands (Task 15)

```powershell
# 1. Full validation
powershell -ExecutionPolicy Bypass -File validate-all-scripts.ps1
# → exit code 0

# 2. Health check
.\devoptimizer.ps1 -Health
# → structured output, overallStatus ∈ {Healthy,Degraded,Critical}

# 3. Menu test
.\devoptimizer.ps1 -Quick
# → output contains ≥10 category names

# 4. Python CLI
python -m devoptimizer_cli hub health
# → Rich table, exit code 0

# 5. Category filter
.\devoptimizer.ps1 -Category "system-optimization"
# → commands listed, exit code 0

# 6. Search
.\devoptimizer.ps1 -Search "cleanup"
# → results contain cleanup commands

# 7. Logs & registry
Test-Path logs\hub-*.log
# Validate config\hub-registry.json against schema

# 8. Favorites persistence
Add-HubFavorite -Name "Get-HubCategories"
# Restart PowerShell
Get-HubFavorites
# → command present

# 9. Admin elevation
.\devoptimizer.ps1 -Command "Test-AdminRights" -AsAdmin
# → elevation status object

# 10. WSL path
$env:WSL_DISTRO_NAME="Ubuntu"
Resolve-HubPath "/mnt/d/DevOptimizer/scripts"
# → "D:\DevOptimizer\scripts"

# 11. Backward compatibility
.\UNIFIED-LAUNCHER.ps1 -Help
.\DevOptimizer-Menu.bat
# → exit code 0
```

---

## File Structure

```
D:\DevOptimizer\
├── devoptimizer.ps1                    # PowerShell entry point
├── modules\
│   ├── DevOptimizer-Master.psm1        # Modified: -LoadHub
│   ├── DevOptimizer-Config.psm1        # Modified: Merge-HubConfig
│   ├── DevOptimizer-Logger.psm1
│   ├── DevOptimizer-Validator.psm1
│   ├── DevOptimizer-Ollama.psm1
│   └── DevOptimizer-ErrorHandler.psm1
├── scripts\hub\
│   ├── Discover-Scripts.ps1
│   ├── Build-Registry.ps1
│   ├── Execute-Command.ps1
│   ├── Show-Menu.ps1
│   ├── Get-Category.ps1
│   ├── Check-Health.ps1
│   ├── Update-Hub.ps1
│   ├── DevOptimizer-Hub.psm1
│   ├── DevOptimizer-Path.psm1
│   ├── DevOptimizer-Admin.psm1
│   └── Validate-JsonSchema.ps1
├── config\
│   ├── devoptimizer-config.json        # Base config
│   ├── hub-config.json                 # Hub overlay
│   ├── categories.json                 # Taxonomy
│   ├── hub-registry.schema.json        # JSON Schema draft-07
│   ├── hub-registry.json               # Generated registry
│   └── hub-favorites.json              # User favorites
├── py\
│   ├── requirements.txt                # + jsonschema
│   └── devoptimizer_cli\
│       ├── cli.py                      # Modified: register hub
│       ├── __init__.py                 # Modified: export hub
│       └── commands\
│           └── hub.py                  # New: Typer app
├── tests\
│   ├── test-hub-discovery.ps1
│   ├── test-hub-execution.ps1
│   ├── test-hub-menu.ps1
│   ├── test-hub-config.ps1
│   ├── test-config-merge.ps1
│   ├── test-hub-path.ps1
│   ├── test-hub-admin.ps1
│   ├── test-hub-health.ps1
│   ├── test-hub-update.ps1
│   ├── test-hub-python-cli.ps1
│   ├── test-hub-category.ps1
│   └── test-hub-module.ps1
├── validate-all-scripts.ps1
├── logs\
│   └── hub-YYYYMMDD.log
└── docs\
    ├── SCRIPT-HUB.md                   # User documentation
    └── SCRIPT-HUB-ARCHITECTURE.md      # This file
```

---

## Backward Compatibility

- `UNIFIED-LAUNCHER.ps1 -Help` → still works
- `DevOptimizer-Menu.bat` → still launches
- Existing scripts in `scripts/`, `modules/`, `tools/` unchanged
- User configs in `config/` preserved (hub-config.json is additive)

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Single Master loader (`-LoadHub`) | Prevents circular imports, deterministic init order |
| Config overlay (not extends) | Code-controlled merge, no JSON "extends" ambiguity |
| Custom Validate-JsonSchema.ps1 | No external PowerShell dependencies |
| Python bridge via subprocess | Reuses PowerShell logic, no duplication |
| .psm1 modules (not .ps1) | Clean Import-Module, proper scoping |
| Registry as JSON file (+ optional HKCU) | Portable, version-controllable |
| 12 focused test files | Binary-decidable, parallel-runnable |
| Hardware baseline in criteria | "5 seconds on i7-12700K/32GB/NVMe" |

---

## Getting Started

```powershell
# 1. Run validation (builds registry)
powershell -ExecutionPolicy Bypass -File validate-all-scripts.ps1

# 2. Launch interactive menu
.\devoptimizer.ps1 -Menu

# 3. Or use Python CLI
python -m devoptimizer_cli hub menu

# 4. Quick command
.\devoptimizer.ps1 -Command "Get-HubCategories"
python -m devoptimizer_cli hub run Get-HubCategories
```

---

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| "Module not found" | Run `validate-all-scripts.ps1` to build registry |
| Admin elevation fails | Check UAC settings, run PowerShell as Admin |
| WSL paths not resolving | Ensure `$env:WSL_DISTRO_NAME` is set |
| Python bridge fails | Verify `devoptimizer.ps1` in PATH or full path used |
| Config not merging | Check `hub-config.json` has `"mergeStrategy": "overlay"` |
| Health check Critical | Run `.\devoptimizer.ps1 -Health -AutoFix` |
| Update fails | Check `backups\hub\` for rollback, run `Restore-HubBackup` |

---

*Generated: 2026-08-29 | DevOptimizer Script Hub v1.0*