# Plan: DevOptimizer Unified Script Hub

**Date:** 2026-08-29  
**Goal:** Create a unified Script Hub that consolidates all DevOptimizer components (PowerShell modules, 50+ scripts, Python CLI, portable batch files, configuration) into a single, discoverable, category-driven execution platform with unified CLI, interactive menu, auto-discovery, logging, and self-healing.

**Architecture:** The hub follows a layered architecture: (1) **Core Layer** - Configuration, Logging, Error Handling modules (existing DevOptimizer-*.psm1); (2) **Discovery Layer** - Auto-scans scripts/, modules/, tools/, portable/, categories/ to build a dynamic registry; (3) **Execution Layer** - Unified entry point (`devoptimizer.ps1` + Python `hub` subcommand) supporting interactive menu, direct CLI, and programmatic API; (4) **Integration Layer** - Bridges PowerShell, Batch, and Python via shared JSON config, single registry schema, and module-based utilities; (5) **Verification Layer** - Built-in validation, health checks, and update mechanism.

**Tech Stack:** PowerShell 5.1+/7+ (primary), Python 3.10+ (CLI via Typer/Rich, jsonschema for validation), Batch (legacy compatibility), JSON (config), Windows Registry (optional persistence), Ollama local API (AI features), MSI Afterburner/Intel XTU (overclocking).

**Work Scope:**
- **IN:** Unified CLI entry point, auto-discovery registry, category taxonomy, configuration-driven execution, unified logging/telemetry, health checks, self-update, interactive + non-interactive modes, cross-platform path resolution, admin privilege detection, JSON Schema validation, config merge
- **OUT:** Rewriting existing scripts (they remain as-is), new overclocking/AI features, GUI/TUI beyond menu, cloud sync, plugin marketplace

**Verification Strategy:** Level: integration | Commands: (1) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\validate-all-scripts.ps1"` (2) `.\devoptimizer.ps1 -Health` (3) `.\devoptimizer.ps1 -Quick` (4) `python -m devoptimizer_cli hub health` (5) `.\devoptimizer.ps1 -Category "system-optimization"` (6) `.\devoptimizer.ps1 -Search "cleanup"` (7) `Test-Path logs\hub-*.log` and validate `config\hub-registry.json` against schema (8) `Add-HubFavorite` then new session `Get-HubFavorites` (9) `.\devoptimizer.ps1 -Command "Test-AdminRights" -AsAdmin` (10) `Resolve-HubPath "/mnt/d/DevOptimizer"` with `$env:WSL_DISTRO_NAME="Ubuntu"` (11) `.\UNIFIED-LAUNCHER.ps1 -Help` and `.\DevOptimizer-Menu.bat` (12) `python -m devoptimizer_cli hub --help` (13) `.\devoptimizer.ps1 -List` (14) `.\devoptimizer.ps1 -Update -WhatIf` (15) `python -m devoptimizer_cli hub run Get-HubCategories` (16) `.\devoptimizer.ps1 -Command "Test-OllamaConnection"` (17) `.\devoptimizer.ps1 -Command "Test-OverclockingTools"` (18) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-discovery.ps1"` (19) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-execution.ps1"` (20) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-menu.ps1"` (21) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-config.ps1"` (22) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-config-merge.ps1"` (23) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-path.ps1"` (24) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-admin.ps1"` (25) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-health.ps1"` (26) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-update.ps1"` (27) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-python-cli.ps1"` (28) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-category.ps1"` (29) `powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\test-hub-module.ps1"` | What passing proves: All scripts validate, both entry points load, category discovery returns 11+ categories, health check returns structured status, update what-if shows plan, Python bridge executes commands, config merge works, logging writes to correct paths, favorites persist, admin elevation works, WSL paths resolve, backward compatibility maintained, Ollama/overclocking health checks pass, all 12 hub tests pass

---

## Declared Paths

### Create
- `D:\DevOptimizer\devoptimizer.ps1` — Unified PowerShell entry point
- `D:\DevOptimizer\scripts\hub\Discover-Scripts.ps1` — Auto-discovery engine
- `D:\DevOptimizer\scripts\hub\Build-Registry.ps1` — Registry builder (JSON + optional Windows Registry)
- `D:\DevOptimizer\scripts\hub\Execute-Command.ps1` — Unified execution wrapper (callable as script with param block)
- `D:\DevOptimizer\scripts\hub\Show-Menu.ps1` — Interactive menu system
- `D:\DevOptimizer\scripts\hub\Get-Category.ps1` — Category taxonomy & filtering
- `D:\DevOptimizer\scripts\hub\Check-Health.ps1` — Health/self-diagnostics
- `D:\DevOptimizer\scripts\hub\Update-Hub.ps1` — Self-update mechanism
- `D:\DevOptimizer\scripts\hub\DevOptimizer-Hub.psm1` — Hub module (loads core modules + exports hub functions)
- `D:\DevOptimizer\scripts\hub\DevOptimizer-Path.psm1` — Path resolution module (Resolve-HubPath, Get-HubRoot)
- `D:\DevOptimizer\scripts\hub\DevOptimizer-Admin.psm1` — Admin detection module (Test-AdminRights, Get-AdminStatus)
- `D:\DevOptimizer\scripts\hub\Validate-JsonSchema.ps1` — JSON Schema validator (custom, no external deps)
- `D:\DevOptimizer\config\hub-config.json` — Hub-specific configuration (extends devoptimizer-config.json)
- `D:\DevOptimizer\config\categories.json` — Category taxonomy definition
- `D:\DevOptimizer\config\hub-registry.schema.json` — JSON Schema (draft-07) for hub-registry.json
- `D:\DevOptimizer\py\devoptimizer_cli\commands\hub.py` — Python CLI hub command
- `D:\DevOptimizer\docs\SCRIPT-HUB.md` — Documentation

### Modify
- `D:\DevOptimizer\modules\DevOptimizer-Master.psm1` — Add hub module loading (-LoadHub parameter) and config merge support
- `D:\DevOptimizer\modules\DevOptimizer-Config.psm1` — Add config merge logic (base + overlay)
- `D:\DevOptimizer\validate-all-scripts.ps1` — Ensure hub scripts included in recursive scan (no array edit needed)
- `D:\DevOptimizer\py\devoptimizer_cli\cli.py` — Register hub command
- `D:\DevOptimizer\py\devoptimizer_cli\__init__.py` — Export hub command
- `D:\DevOptimizer\py\requirements.txt` — Add jsonschema dependency

### Test
- `D:\DevOptimizer\tests\test-hub-discovery.ps1` — Discovery integration test
- `D:\DevOptimizer\tests\test-hub-execution.ps1` — Execution wrapper test
- `D:\DevOptimizer\tests\test-hub-menu.ps1` — Menu system test (automated via -Quick mode)
- `D:\DevOptimizer\tests\test-hub-config.ps1` — Configuration test (including merge validation)
- `D:\DevOptimizer\tests\test-config-merge.ps1` — Config merge test (Task 2)
- `D:\DevOptimizer\tests\test-hub-path.ps1` — Path resolution module test
- `D:\DevOptimizer\tests\test-hub-admin.ps1` — Admin detection module test
- `D:\DevOptimizer\tests\test-hub-health.ps1` — Health check test (including -AutoFix)
- `D:\DevOptimizer\tests\test-hub-update.ps1` — Update mechanism test (including rollback)
- `D:\DevOptimizer\tests\test-hub-python-cli.ps1` — Python CLI hub subcommands test
- `D:\DevOptimizer\tests\test-hub-category.ps1` — Category & favorites test
- `D:\DevOptimizer\tests\test-hub-module.ps1` — Hub module initialization test

---

## Tasks

### Task 1: Create Hub Configuration Schema
**Goal:** Define hub-config.json (extends devoptimizer-config.json with merge semantics), categories.json, hub-registry.schema.json, and Validate-JsonSchema.ps1 with all required settings.
**Dependencies:** None
**Files:**
- Create: `D:\DevOptimizer\config\hub-config.json`
- Create: `D:\DevOptimizer\config\categories.json`
- Create: `D:\DevOptimizer\config\hub-registry.schema.json`
- Create: `D:\DevOptimizer\scripts\hub\Validate-JsonSchema.ps1`
**Acceptance Criteria:**
- [ ] hub-config.json contains hub-specific sections only: discovery (scripts, modules, tools, portable, categories), execution (defaultTimeout, parallelLimit, adminRequired), update (enabled, intervalHours, sourceUrl, verifySignature), mergeStrategy ("overlay")
- [ ] categories.json defines 11+ categories matching existing categories/ directory structure with metadata (displayName, description, icon, priority, scriptPatterns[])
- [ ] hub-registry.schema.json is valid JSON Schema draft-07 defining registry structure: version, commands[] (name, description, category, language, path, parameters, requiresAdmin, tags), categories[], metadata (generatedAt, sourceDirs[])
- [ ] All three files are valid JSON and load without errors in PowerShell and Python
- [ ] Config merge logic documented: hub-config.json values overlay devoptimizer-config.json; missing keys fall back to base config
**Step 1:** Write hub-config.json with hub-specific sections only and "mergeStrategy": "overlay" (no "extends" key - merge implemented in code).
**Step 2:** Write categories.json mapping each category to its directory in categories/, with displayName, description, icon (Unicode), priority (integer), scriptPatterns[] (glob patterns).
**Step 3:** Write hub-registry.schema.json defining registry JSON structure with required fields and types.
**Step 4:** Write Validate-JsonSchema.ps1 implementing JSON Schema draft-07 validation (no external dependencies) with function `Test-JsonSchema` accepting `-JsonPath`, `-SchemaPath`, returning validation result object.
**Step 5:** Test loading configs in PowerShell (`Get-Content | ConvertFrom-Json`) and Python (`json.load`); validate hub-registry.json against schema using `Test-JsonSchema`.

### Task 2: Modify DevOptimizer-Config.psm1 for Config Merge
**Goal:** Add Merge-HubConfig function that loads devoptimizer-config.json, then hub-config.json, and performs deep overlay merge (hub values override base).
**Dependencies:** Task 1
**Files:**
- Modify: `D:\DevOptimizer\modules\DevOptimizer-Config.psm1`
- Create: `D:\DevOptimizer\tests\test-config-merge.ps1`
**Acceptance Criteria:**
- [ ] Merge-HubConfig function exists, accepts optional -BaseConfigPath and -HubConfigPath parameters
- [ ] Function performs deep merge: base config loaded first, hub config overlay applied recursively (arrays replaced, objects merged)
- [ ] Function returns merged config object with all settings (base + overlay)
- [ ] Function handles missing hub-config.json gracefully (returns base config only)
- [ ] Function is exported in module manifest and callable from hub scripts
- [ ] Unit test validates merge with nested objects, arrays, and missing hub config
**Step 1:** Add Merge-HubConfig function to DevOptimizer-Config.psm1 with deep merge logic.
**Step 2:** Export Merge-HubConfig in DevOptimizer-Config.psd1 (FunctionsToExport).
**Step 3:** Write unit test in tests/test-config-merge.ps1 validating merge behavior.

### Task 3: Build Auto-Discovery Engine (Discover-Scripts.ps1)
**Goal:** Implement script discovery that scans all source directories and builds a unified registry of executable commands with metadata, validated against JSON Schema.
**Dependencies:** Task 1
**Files:**
- Create: `D:\DevOptimizer\scripts\hub\Discover-Scripts.ps1`
- Create: `D:\DevOptimizer\scripts\hub\Build-Registry.ps1`
**Acceptance Criteria:**
- [ ] Scans scripts/, modules/, tools/, portable/, categories/ recursively
- [ ] Identifies .ps1, .bat, .py files with executable entry points
- [ ] Extracts metadata: name, description (from comment header), category, parameters, requiresAdmin, language, tags
- [ ] Outputs unified registry as JSON to `config\hub-registry.json` valid against hub-registry.schema.json
- [ ] Optionally writes to Windows Registry (HKCU:\SOFTWARE\DevOptimizer\Hub) when admin available
- [ ] Handles missing directories gracefully, logs warnings via DevOptimizer-Logger
- [ ] Discovery completes and outputs registry (deterministic completion check)
**Step 1:** Implement `Discover-Scripts.ps1` with `Invoke-ScriptDiscovery` function taking `-ConfigPath` parameter, returning hashtable of discovered commands.
**Step 2:** Implement metadata extraction: parse first 30 lines of each script for `# .SYNOPSIS`, `# .DESCRIPTION`, `param()`, `requires -RunAsAdministrator`, `# .TAGS`.
**Step 3:** Implement `Build-Registry.ps1` that merges discovery results with categories.json, validates against hub-registry.schema.json using `Validate-JsonSchema.ps1`, writes hub-registry.json, and optionally updates Windows Registry.
**Step 4:** Add caching: store discovery timestamp in registry metadata, only re-scan if source directories modified (using Get-Item LastWriteTime).
**Step 5:** Integrate with DevOptimizer-Logger for structured logging of discovery progress and warnings.

### Task 4: Create Unified Execution Wrapper (Execute-Command.ps1)
**Goal:** Single execution entry point that handles PowerShell, Batch, and Python scripts with unified logging, error handling, timeout, and admin elevation. Callable as both dot-sourced function and standalone script for Python bridge.
**Dependencies:** Task 1, Task 2, Task 9 (DevOptimizer-Admin.psm1)
**Files:**
- Create: `D:\DevOptimizer\scripts\hub\Execute-Command.ps1`
**Acceptance Criteria:**
- [ ] Accepts `-CommandName` (from registry), `-Parameters` (hashtable), `-NoWait`, `-AsAdmin`, `-LogLevel`
- [ ] Resolves command to actual file path via registry
- [ ] Executes .ps1 via `& $scriptPath @Parameters`, .bat via `cmd /c`, .py via `python -m`
- [ ] Applies timeout from config (default 300s), kills process on timeout
- [ ] Captures stdout/stderr, writes to hub log with correlation ID
- [ ] Returns structured result: exitCode, stdout, stderr, duration, logPath
- [ ] Auto-elevates via `Start-Process powershell -Verb RunAs` when `-AsAdmin` and not elevated (uses Test-AdminRights from DevOptimizer-Admin.psm1)
- [ ] Integrates with DevOptimizer-Logger.psm1 (Write-Log) and DevOptimizer-ErrorHandler.psm1 (New-DevOptimizerError, Invoke-AutoFix)
- [ ] **Callable as standalone script**: param block at top, invokes `Invoke-HubCommand @PSBoundParameters` when run directly
- [ ] **Callable as function**: exports `Invoke-HubCommand` for dot-sourcing/Import-Module
**Step 1:** Write `Execute-Command.ps1` with `[CmdletBinding()]` param block, `Invoke-HubCommand` function, and tail invocation `Invoke-HubCommand @PSBoundParameters` for script mode.
**Step 2:** Implement language-specific executors: `Invoke-PowerShellScript`, `Invoke-BatchScript`, `Invoke-PythonScript`.
**Step 3:** Add admin elevation logic using `Test-AdminRights` from DevOptimizer-Admin.psm1 and `Start-Process -Verb RunAs`.
**Step 4:** Integrate logging: create correlation ID (GUID), log start/end/errors via `Write-Log` from DevOptimizer-Logger with component="hub".
**Step 5:** Integrate error handling: wrap execution in try/catch, create `New-DevOptimizerError` on failure, attempt `Invoke-AutoFix` for known error categories.

### Task 5: Implement Interactive Menu System (Show-Menu.ps1)
**Goal:** Rich interactive menu matching UNIFIED-LAUNCHER.ps1 quality but driven by dynamic registry from Task 3.
**Dependencies:** Task 3, Task 4
**Files:**
- Create: `D:\DevOptimizer\scripts\hub\Show-Menu.ps1`
**Acceptance Criteria:**
- [ ] Displays hierarchical menu: Categories → Commands → Execute/Details
- [ ] Shows command metadata: description, parameters, admin required, estimated duration
- [ ] Supports keyboard navigation (arrows, enter, escape, search filter)
- [ ] Color-coded output using DevOptimizer-Logger color scheme
- [ ] "Quick mode" (`-Quick`) shows flat list for automation
- [ ] "Status mode" (`-Status`) shows system health, recent executions, config summary
- [ ] Persists last selection per session
- [ ] Integrates with Execute-Command.ps1 for actual execution
**Step 1:** Implement `Show-HubMenu` function with `[CmdletBinding()]`, parameters `-Quick`, `-Status`, `-Category`.
**Step 2:** Build menu renderer using ANSI escape codes for colors, box-drawing chars for borders.
**Step 3:** Implement navigation loop: render → read key → update state → repeat.
**Step 4:** Add search filter mode (type to filter commands by name/description).
**Step 5:** Connect "Execute" action to `Invoke-HubCommand` from Task 3.

### Task 6: Create Category Taxonomy & Filtering (Get-Category.ps1)
**Goal:** Category management system that maps discovered commands to taxonomy, supports filtering, and provides category-specific views with favorites persistence.
**Dependencies:** Task 1, Task 2, Task 3
**Files:**
- Create: `D:\DevOptimizer\scripts\hub\Get-Category.ps1`
**Acceptance Criteria:**
- [ ] Loads categories.json, merges with discovered registry (hub-registry.json)
- [ ] Provides `Get-HubCategories` (list all), `Get-HubCategoryCommands` (filter by category), `Search-HubCommands` (text search)
- [ ] Supports tags: system, ai, monitoring, overclocking, maintenance, network, security, development, utilities, launchers, diagnostics
- [ ] Each category has: displayName, description, icon, priority, scriptPatterns[]
- [ ] Category "All" shows every command; "Favorites" shows user-pinned commands
- [ ] Outputs objects compatible with Format-Table, Out-GridView, ConvertTo-Json
- [ ] `Add-HubFavorite` / `Remove-HubFavorite` persist to config\hub-favorites.json (array of command names)
- [ ] Favorites survive process restart (file-based persistence)
**Step 1:** Write `Get-HubCategories` returning array of category objects with computed command counts.
**Step 2:** Write `Get-HubCategoryCommands` taking `-CategoryName` and `-IncludeSubcategories`.
**Step 3:** Write `Search-HubCommands` taking `-Query` (searches name, description, tags).
**Step 4:** Add `Add-HubFavorite` / `Remove-HubFavorite` persisting to config\hub-favorites.json.
**Step 5:** Implement `Get-HubFavorites` reading favorites file, filtering registry to return favorite command objects.

### Task 7: Build Health Check & Self-Diagnostics (Check-Health.ps1)
**Goal:** Comprehensive health checking for hub itself, dependencies, configuration, and external tools with automated verification.
**Dependencies:** Task 1, Task 9 (DevOptimizer-Admin.psm1)
**Files:**
- Create: `D:\DevOptimizer\scripts\hub\Check-Health.ps1`
**Acceptance Criteria:**
- [ ] Checks: PowerShell version (≥5.1), required modules loaded, config files valid (JSON syntax + schema), registry accessible
- [ ] Checks external: Ollama server reachable (HTTP GET /api/tags), MSI Afterburner installed (registry detection), Intel XTU installed (registry detection), admin privileges (Test-AdminRights)
- [ ] Checks hub: registry file exists & valid (against schema), log directory writable, discovery cache fresh (<24h)
- [ ] Returns structured health object: overallStatus (Healthy/Degraded/Critical), checks[] with name, status (Pass/Warning/Fail), message, remediation
- [ ] `-Verbose` shows detailed diagnostics; `-AutoFix` attempts to repair common issues (recreate dirs, regenerate registry, fix config)
- [ ] Integrates with DevOptimizer-ErrorHandler for AI-powered remediation suggestions
- [ ] **Automated verification**: Each check returns Pass/Warning/Fail enum; overallStatus computed deterministically
**Step 1:** Implement `Test-HubHealth` function with `[OutputType([PSCustomObject])]`.
**Step 2:** Create individual check functions: `Test-PowerShellVersion`, `Test-ModulesLoaded`, `Test-ConfigFiles`, `Test-OllamaConnection` (Invoke-WebRequest http://localhost:11434/api/tags), `Test-OverclockingTools` (registry scan for MSI/XTU), `Test-AdminRights` (from DevOptimizer-Admin), `Test-RegistryAccess`, `Test-LogDirectory`.
**Step 3:** Aggregate results, compute overall status: Healthy (all Pass), Degraded (any Warning, no Fail), Critical (any Fail).
**Step 4:** Implement `-AutoFix` for: missing log dirs (New-Item), missing config files (regenerate defaults from template), stale registry (Invoke-ScriptDiscovery).
**Step 5:** Return structured object with deterministic status enum for automated test verification.

### Task 8: Implement Self-Update Mechanism (Update-Hub.ps1)
**Goal:** Self-update capability that checks for hub updates, validates, and applies them atomically with rollback and testable rollback verification.
**Dependencies:** Task 1, Task 7
**Files:**
- Create: `D:\DevOptimizer\scripts\hub\Update-Hub.ps1`
**Acceptance Criteria:**
- [ ] Reads update config from hub-config.json (enabled, intervalHours, sourceUrl, verifySignature)
- [ ] `Check-HubUpdates` compares local version vs remote manifest (JSON with version, files[], checksums, sourceUrl from config)
- [ ] `Update-Hub` downloads package, validates checksum (Get-FileHash), backs up current hub scripts (Compress-Archive to backups\hub\), applies update (Copy-Item -Force)
- [ ] Rollback on failure: restores backup, logs failure
- [ ] `-Force` skips version check; `-WhatIf` shows planned changes without applying
- [ ] Logs all update activities to hub log with correlation ID
- [ ] Supports updating hub scripts only (not user scripts in scripts/)
- [ ] **Rollback testable**: `Restore-HubBackup` function restores most recent backup; test can simulate failure and verify rollback
**Step 1:** Implement `Check-HubUpdates` reading manifest from configured sourceUrl (JSON with version, files[], checksums).
**Step 2:** Implement `Update-Hub` with backup (Compress-Archive to backups\hub\hub-backup-<timestamp>.zip), download (Invoke-WebRequest), verify (Get-FileHash -Algorithm SHA256), apply (Copy-Item -Force).
**Step 3:** Add rollback function `Restore-HubBackup` using most recent backup in backups\hub\.
**Step 4:** Add scheduled check via `Register-ScheduledTask` if enabled in config (daily/weekly).
**Step 5:** Ensure all operations use correlation IDs and structured logging via DevOptimizer-Logger.

### Task 9: Cross-Platform Path Resolution & Admin Detection Modules
**Goal:** Shared utilities for path resolution (Windows/WSL) and admin privilege detection as PowerShell modules (.psm1) for clean Import-Module usage.
**Dependencies:** Task 1
**Files:**
- Create: `D:\DevOptimizer\scripts\hub\DevOptimizer-Path.psm1` — Path resolution module
- Create: `D:\DevOptimizer\scripts\hub\DevOptimizer-Admin.psm1` — Admin detection module
**Acceptance Criteria:**
- [ ] `DevOptimizer-Path.psm1` exports: `Resolve-HubPath`, `Get-HubRoot`, `Convert-WslPath`, `Expand-HubVariables`
- [ ] `Resolve-HubPath` handles: relative paths, ~ expansion, WSL paths (/mnt/d/...), env vars, registry overrides
- [ ] `Get-HubRoot` returns absolute hub root using priority: $env:DEVOPTIMIZER_HUB → registry (HKCU:\SOFTWARE\DevOptimizer) → default (D:\DevOptimizer)
- [ ] `DevOptimizer-Admin.psm1` exports: `Test-AdminRights`, `Get-AdminStatus`, `Assert-AdminRights`
- [ ] `Test-AdminRights` returns boolean using `[Security.Principal.WindowsIdentity]::GetCurrent()`
- [ ] `Get-AdminStatus` returns object: isAdmin (bool), elevationType (None/Token/UIAccess), canElevate (bool)
- [ ] `Assert-AdminRights` throws terminating error with remediation if not admin and `-Required` specified
- [ ] Both modules work in PowerShell 5.1, 7+, and when imported via DevOptimizer-Master.psm1
- [ ] Modules follow DevOptimizer module pattern: class-based or advanced functions, proper Export-ModuleMember
**Step 1:** Write `DevOptimizer-Path.psm1` with `Resolve-HubPath`, `Get-HubRoot`, `Convert-WslPath` (detects $env:WSL_DISTRO_NAME, converts /mnt/d/... → D:\...), `Expand-HubVariables` (expands ${env:VAR} and ~).
**Step 2:** Write `DevOptimizer-Admin.psm1` with `Test-AdminRights`, `Get-AdminStatus` (using .NET Principal API), `Assert-AdminRights` (throws DevOptimizerError via ErrorHandler if available).
**Step 3:** Add module manifests (.psd1) or inline Export-ModuleMember for clean imports.
**Step 4:** Cache `Get-HubRoot` result in `$Global:DevOptimizerHubRoot` for performance.

### Task 10: Create Hub Module (DevOptimizer-Hub.psm1)
**Goal:** PowerShell module that loads core modules via DevOptimizer-Master (with -LoadHub) and exports all hub functions. Single loading strategy through Master.
**Dependencies:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9
**Files:**
- Create: `D:\DevOptimizer\scripts\hub\DevOptimizer-Hub.psm1`
- Modify: `D:\DevOptimizer\modules\DevOptimizer-Master.psm1` — add hub module loading (-LoadHub parameter)
**Acceptance Criteria:**
- [ ] DevOptimizer-Master.psm1 accepts `-LoadHub` switch; when set, imports DevOptimizer-Path.psm1, DevOptimizer-Admin.psm1, then DevOptimizer-Hub.psm1
- [ ] DevOptimizer-Hub.psm1 loads core modules via Master: DevOptimizer-Config, DevOptimizer-Logger, DevOptimizer-Validator, DevOptimizer-Ollama, DevOptimizer-ErrorHandler (in order)
- [ ] Exports: `Invoke-HubCommand`, `Show-HubMenu`, `Get-HubCategories`, `Test-HubHealth`, `Update-Hub`, `Invoke-ScriptDiscovery`, `Resolve-HubPath`, `Test-AdminRights`
- [ ] Initializes hub config (merges hub-config.json with devoptimizer-config.json), creates default dirs, validates registry on import
- [ ] Sets `$Global:DevOptimizerHub` with module instances and status
- [ ] No double-initialization: Master controls load order, Hub module only adds its exports
**Step 1:** Write `DevOptimizer-Hub.psm1` with proper module structure, `Export-ModuleMember` for all public functions.
**Step 2:** Implement `Import-HubModules` function that calls `Import-Module DevOptimizer-Master -ArgumentList @{LoadHub=$true}` or uses Master's public API.
**Step 3:** Add hub initialization: load merged config (base + hub overlay), ensure log dir, run discovery if registry stale or missing.
**Step 4:** Modify `DevOptimizer-Master.psm1` to accept `-LoadHub` parameter; when true, import DevOptimizer-Path, DevOptimizer-Admin, then DevOptimizer-Hub in that order.
**Step 5:** Ensure global variables ($Global:DevOptimizerModules, $Global:DevOptimizerHub) are set once by Master, not duplicated.

### Task 11: Create Unified PowerShell Entry Point (devoptimizer.ps1)
**Goal:** Single `devoptimizer.ps1` at repo root that serves as the primary CLI entry point for all hub operations, loading via DevOptimizer-Master with -LoadHub.
**Dependencies:** Task 10
**Files:**
- Create: `D:\DevOptimizer\devoptimizer.ps1`
**Acceptance Criteria:**
- [ ] Parameters: `-Command`, `-Category`, `-List`, `-Search`, `-Menu`, `-Quick`, `-Status`, `-Health`, `-Update`, `-Config`, `-Version`, `-Help`
- [ ] `-Command <name> [params...]` executes command via `Invoke-HubCommand`
- [ ] `-Category <name>` lists commands in category
- [ ] `-List` / `-Search` use `Get-HubCategories` / `Search-HubCommands`
- [ ] `-Menu` / `-Quick` / `-Status` invoke `Show-HubMenu` with appropriate mode
- [ ] `-Health` runs `Test-HubHealth` with `-Verbose`
- [ ] `-Update` runs `Update-Hub` with `-Force` if `-Force` passed
- [ ] `-Config` opens hub-config.json in editor (notepad/code)
- [ ] Returns appropriate exit codes (0=success, 1=error, 2=invalid command, 3=admin required)
- [ ] Help text generated from command metadata
- [ ] **Loads via Master**: `Import-Module DevOptimizer-Master -ArgumentList @{LoadHub=$true}` at script start
**Step 1:** Write `devoptimizer.ps1` with comprehensive `[CmdletBinding()]` and parameter sets.
**Step 2:** Implement parameter set logic: CommandMode, ListMode, MenuMode, HealthMode, UpdateMode, ConfigMode.
**Step 3:** Import DevOptimizer-Master with -LoadHub at script start (single loading strategy).
**Step 4:** Implement help system: auto-generate from registry metadata for `-Help` and `-Command <name> -Help`.

### Task 12: Create Python CLI Hub Command
**Goal:** Add `hub` command to Python CLI (devoptimizer_cli) providing parity with PowerShell entry point via devoptimizer.ps1 bridge.
**Dependencies:** Task 1, Task 2, Task 3, Task 11
**Files:**
- Create: `D:\DevOptimizer\py\devoptimizer_cli\commands\hub.py`
- Modify: `D:\DevOptimizer\py\devoptimizer_cli\cli.py` — register hub command
- Modify: `D:\DevOptimizer\py\devoptimizer_cli\__init__.py` — export hub command
- Modify: `D:\DevOptimizer\py\requirements.txt` — add jsonschema dependency
**Acceptance Criteria:**
- [ ] `devoptimizer hub --help` shows all subcommands
- [ ] `devoptimizer hub list` / `devoptimizer hub list --category <name>` — lists commands
- [ ] `devoptimizer hub search <query>` — searches commands
- [ ] `devoptimizer hub run <command> [--param key=value]` — executes via PowerShell bridge (calls devoptimizer.ps1 -Command)
- [ ] `devoptimizer hub menu` — launches PowerShell interactive menu (subprocess calls devoptimizer.ps1 -Menu)
- [ ] `devoptimizer hub health` — runs health check, outputs Rich table
- [ ] `devoptimizer hub update` — checks/applies updates
- [ ] `devoptimizer hub config` — shows/edits configuration
- [ ] Uses Typer for CLI, Rich for tables/colors, reads hub-registry.json and hub-config.json directly
- [ ] **PowerShell bridge**: `subprocess.run(["powershell", "-ExecutionPolicy", "Bypass", "-File", "devoptimizer.ps1", ...])` for all operations
**Step 1:** Write `hub.py` with Typer app, subcommands for list, search, run, menu, health, update, config.
**Step 2:** Implement registry loading: read hub-registry.json, parse into Pydantic models.
**Step 3:** Implement PowerShell bridge: `run_devoptimizer_command(args_list)` helper calling devoptimizer.ps1 with appropriate parameters.
**Step 4:** Register in `cli.py`: `app.add_typer(hub_app, name="hub")`.

### Task 13: Integrate Hub with Validation Suite
**Goal:** Ensure hub scripts are validated by existing validate-all-scripts.ps1 and add comprehensive hub-specific tests for all modules.
**Dependencies:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9, Task 10, Task 11, Task 12
**Files:**
- Modify: `D:\DevOptimizer\validate-all-scripts.ps1` — add hub scripts to scan
- Create: `D:\DevOptimizer\tests\test-hub-discovery.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-execution.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-menu.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-config.ps1`
- Create: `D:\DevOptimizer\tests\test-config-merge.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-path.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-admin.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-health.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-update.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-python-cli.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-category.ps1`
- Create: `D:\DevOptimizer\tests\test-hub-module.ps1`
**Acceptance Criteria:**
- [ ] validate-all-scripts.ps1 includes scripts\hub\ in scan paths
- [ ] test-hub-discovery.ps1: runs discovery, asserts registry contains ≥50 commands across ≥10 categories
- [ ] test-hub-execution.ps1: runs `Invoke-HubCommand` on known command, asserts exitCode=0, result structure valid
- [ ] test-hub-menu.ps1: launches menu in `-Quick` mode, captures output, asserts categories displayed (automated)
- [ ] test-hub-config.ps1: loads hub-config.json and categories.json, validates against schema, asserts required keys present
- [ ] test-config-merge.ps1: validates config merge behavior (base + overlay)
- [ ] test-hub-path.ps1: tests `Resolve-HubPath`, `Get-HubRoot`, `Convert-WslPath` with Windows and WSL paths
- [ ] test-hub-admin.ps1: tests `Test-AdminRights`, `Get-AdminStatus`, `Assert-AdminRights` (mocked elevation)
- [ ] test-hub-health.ps1: tests `Test-HubHealth` with `-Verbose` and `-AutoFix`, asserts deterministic status enum
- [ ] test-hub-update.ps1: tests `Check-HubUpdates`, `Update-Hub -WhatIf`, `Restore-HubBackup` (simulated rollback)
- [ ] test-hub-python-cli.ps1: tests Python CLI hub subcommands via subprocess (list, search, run, health)
- [ ] test-hub-category.ps1: tests category filtering and favorites
- [ ] test-hub-module.ps1: tests hub module initialization
- [ ] All tests pass when run via `powershell -ExecutionPolicy Bypass -File test-*.ps1`
**Step 1:** Verify validate-all-scripts.ps1 recursive scan includes `scripts\hub\` (uses `-Path` parameter with `Get-ChildItem -Recurse`, already covers hub scripts); no edit needed.
**Step 2:** Write test-hub-discovery.ps1 using simple assertions (if/throw) for registry content validation.
**Step 3:** Write test-hub-execution.ps1 testing `Invoke-HubCommand` with a safe command (e.g., `Get-HubCategories`).
**Step 4:** Write test-hub-menu.ps1 testing `Show-HubMenu -Quick` output contains expected category names from categories.json.
**Step 5:** Write test-hub-config.ps1 validating JSON structure against hub-registry.schema.json and required fields.
**Step 6:** Write test-config-merge.ps1 testing config merge behavior.
**Step 7:** Write test-hub-path.ps1 testing path resolution with various input formats.
**Step 8:** Write test-hub-admin.ps1 testing admin detection functions.
**Step 9:** Write test-hub-health.ps1 testing health check with -AutoFix simulation.
**Step 10:** Write test-hub-update.ps1 testing update check, what-if, and rollback functions.
**Step 11:** Write test-hub-python-cli.ps1 testing Python CLI subcommands via subprocess.
**Step 12:** Write test-hub-category.ps1 testing category filtering and favorites.
**Step 13:** Write test-hub-module.ps1 testing hub module initialization.

### Task 14: Create Documentation (SCRIPT-HUB.md)
**Goal:** Complete documentation for the Script Hub covering architecture, usage, configuration, extension, and troubleshooting.
**Dependencies:** All previous tasks
**Files:**
- Create: `D:\DevOptimizer\docs\SCRIPT-HUB.md`
**Acceptance Criteria:**
- [ ] Architecture overview with diagram (Mermaid)
- [ ] Quick start: `.\devoptimizer.ps1 -Menu`, `python -m devoptimizer_cli hub menu`
- [ ] CLI reference: all parameters and subcommands for both entry points
- [ ] Category reference: all 11+ categories with example commands
- [ ] Configuration guide: hub-config.json and categories.json schema
- [ ] Extending the hub: adding custom scripts, creating new categories
- [ ] Troubleshooting: common issues, health check, logs, reset
- [ ] Migration guide: from UNIFIED-LAUNCHER.ps1 / DevOptimizer-Menu.bat
**Step 1:** Write architecture section with Mermaid diagram showing layers.
**Step 2:** Write CLI reference with tables for PowerShell and Python entry points.
**Step 3:** Document category taxonomy from categories.json.
**Step 4:** Write configuration schema with examples.
**Step 5:** Write extending guide with script metadata conventions.
**Step 6:** Write troubleshooting FAQ based on health check codes.

### Task 15: Final Verification & Integration Test
**Goal:** End-to-end verification that the complete Script Hub works as specified. All criteria binary-decidable via automated commands.
**Dependencies:** All previous tasks
**Files:** None (verification only)
**Acceptance Criteria:**
- [ ] `.\devoptimizer.ps1 -List` outputs all discovered commands (≥50) as table (exit code 0)
- [ ] `.\devoptimizer.ps1 -Category "system-optimization"` lists category commands (exit code 0)
- [ ] `.\devoptimizer.ps1 -Command "Get-HubCategories"` executes successfully (exit code 0, JSON output valid)
- [ ] `python -m devoptimizer_cli hub --help` shows help (exit code 0)
- [ ] `python -m devoptimizer_cli hub run Get-HubCategories` works via bridge (exit code 0)
- [ ] `.\devoptimizer.ps1 -Health` returns Healthy or Degraded status object (exit code 0, structured output)
- [ ] `.\devoptimizer.ps1 -Update -WhatIf` shows update plan without applying (exit code 0)
- [ ] `validate-all-scripts.ps1` passes with exit code 0 including hub scripts
- [ ] All 12 test scripts (Task 13) pass with exit code 0
- [ ] Logs written to `logs\hub-YYYYMMDD.log` with proper format (file exists, non-empty, valid lines)
- [ ] Registry `config\hub-registry.json` exists and validates against hub-registry.schema.json
- [ ] Favorites persist: `Add-HubFavorite` then new session `Get-HubFavorites` returns saved command
- [ ] Admin elevation test: `.\devoptimizer.ps1 -Command "Test-AdminRights" -AsAdmin` returns correct elevation status
- [ ] WSL path test: `Resolve-HubPath "/mnt/d/DevOptimizer/scripts"` returns "D:\DevOptimizer\scripts" (when WSL env var set)
- [ ] Ollama integration test: `Test-OllamaConnection` in health check returns Pass/Warning with message
- [ ] Overclocking tool detection test: `Test-OverclockingTools` returns MSI/XTU status in health check
- [ ] Backward compatibility: `.\UNIFIED-LAUNCHER.ps1 -Help` and `.\DevOptimizer-Menu.bat` still execute without error
**Step 1:** Run full validation suite: `powershell -ExecutionPolicy Bypass -File validate-all-scripts.ps1` → assert exit code 0
**Step 2:** Run all 12 hub tests: `powershell -ExecutionPolicy Bypass -File tests\test-hub-discovery.ps1`, `tests\test-hub-execution.ps1`, `tests\test-hub-menu.ps1`, `tests\test-hub-config.ps1`, `tests\test-config-merge.ps1`, `tests\test-hub-path.ps1`, `tests\test-hub-admin.ps1`, `tests\test-hub-health.ps1`, `tests\test-hub-update.ps1`, `tests\test-hub-python-cli.ps1`, `tests\test-hub-category.ps1`, `tests\test-hub-module.ps1` → assert each exit code 0
**Step 3:** Run hub health check: `.\devoptimizer.ps1 -Health` → assert structured output with overallStatus ∈ {Healthy,Degraded,Critical}
**Step 4:** Run automated menu test: `.\devoptimizer.ps1 -Quick` → assert output contains ≥10 category names from categories.json
**Step 5:** Test Python CLI help: `python -m devoptimizer_cli hub --help` → assert exit code 0
**Step 6:** Test Python CLI health: `python -m devoptimizer_cli hub health` → assert Rich table output, exit code 0
**Step 7:** Test category filtering: `.\devoptimizer.ps1 -Category "system-optimization"` → assert commands listed, exit code 0
**Step 8:** Test search: `.\devoptimizer.ps1 -Search "cleanup"` → assert results contain cleanup-related commands, exit code 0
**Step 9:** Test Python bridge: `python -m devoptimizer_cli hub run Get-HubCategories` → assert exit code 0
**Step 10:** Verify logs and registry files: `Test-Path logs\hub-*.log` and validate `config\hub-registry.json` against schema
**Step 11:** Test favorites persistence: run `Add-HubFavorite -Name "Get-HubCategories"`, restart PowerShell, run `Get-HubFavorites` → assert command present
**Step 12:** Test admin elevation: `.\devoptimizer.ps1 -Command "Test-AdminRights" -AsAdmin` → assert returns elevation status object
**Step 13:** Test WSL path: set `$env:WSL_DISTRO_NAME="Ubuntu"`, run `Resolve-HubPath "/mnt/d/DevOptimizer"` → assert returns "D:\DevOptimizer"
**Step 14:** Confirm backward compatibility: `.\scripts\UNIFIED-LAUNCHER.ps1 -Help` exit code 0, `.\DevOptimizer-Menu.bat` launches without error
**Step 15:** Test update what-if: `.\devoptimizer.ps1 -Update -WhatIf` → assert shows update plan without applying, exit code 0

---

## Critic Responses Section

*(To be populated after critic panel review)*