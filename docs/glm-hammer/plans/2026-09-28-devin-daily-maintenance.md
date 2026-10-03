# Blueprint: Devin daily unattended maintenance (Task Scheduler)

**Date:** 2026-09-28
**Requested by:** user ("i need a day to day automation to keep Devin at perfect shape, use windows 11 services to attend it and schedule daily maintenance").

## Spec

- Goal: a Windows Task Scheduler job (`\DevOptimizer\Devin-Daily-Maintenance`, daily 04:30, user-level) that keeps Devin Desktop self-healing: sweeps the regenerating Electron HTTP cache, prunes host + server-side Devin logs past retention, removes superseded/corrupt server-bundle commit dirs (the recurring Sep-21/25/26 failure) when the app is closed, and writes a machine-readable daily report.
- New orchestrator `scripts/devin/Invoke-DevinDailyMaintenance.ps1` reuses house conventions (`Invoke-Wsl`, `[ OK ]/[WARN]/[FAIL]` console style, `# CATEGORY: maintenance` header) and the existing scripts' boundaries: never touches `~/.devin-server/extensions`, `data/`, `.installation_lock`, or the live commit dir.
- Key constraint discovered in recon: `Check-DevinHealth.ps1` derives the commit from the RUNNING server process, so it cannot see a corrupt bundle while the app is closed. The orchestrator therefore implements the same integrity test (`node_modules/minimist` + `@vscode` present) natively across ALL commit dirs, independent of process state. `Check-DevinHealth.ps1` is still invoked for its standard verdict output, which is captured into the report/log.
- Safety model: app-running detection (`Get-Process Devin`) gates exactly one operation — bundle-orphan deletion — which is DEFERRED with `[WARN]` while Devin runs. Everything else is always-safe: the host-side per-file cache sweep with skip-on-locked (verified live-safe 2026-09-27), host session-log and age-gated server-log pruning (logs only touch `data/logs` entries older than the retention window). Live commit is parsed from `bin\devin-desktop.cmd --version` (line 2); if parsing fails, orphan cleanup is skipped (fail-safe).
- Exit codes follow the Check-DevinHealth convention: 0 = clean/completed (warnings and deferrals included), 1 = FAIL (WSL unreachable), 2 = performed a repair (corrupt bundle removed; fresh ~700 MB download on next app launch).
- New register script `scripts/devin/Register-Devin-Maintenance.ps1` mirrors `Register-WSL-PreWarm.ps1` (same task path, settings, `-Remove` switch, re-run safe via `-Force`), trigger daily 04:30 — after the 02:15/02:30/03:00 cleanup block, before work hours, when the app is normally closed.
- After the scripts land, the Hub registry is refreshed through the existing pipeline (`Build-Registry.ps1` runs `Discover-Scripts.ps1` inline) so the two new commands appear; `validate-all-scripts.ps1` must stay green.

### Task 1: Create the maintenance orchestrator
**Dependencies:** None
**Files:**
- Create: `scripts/devin/Invoke-DevinDailyMaintenance.ps1`
**Acceptance Criteria:**
- [x] **Step 1:** Script header carries `# CATEGORY: maintenance`; parameters are exactly `[int]$LogRetentionDays = 14`, `[int]$ReportRetentionDays = 30`, `[string]$ReportDir = 'D:\DevOptimizer\logs\devin-maintenance'`; runs under Windows PowerShell 5.1 with no elevation requirement.
- [x] **Step 2:** Emits a run report JSON to `<ReportDir>\latest.json` with top-level fields `date`, `appRunning`, `steps` (array of `name`/`status`/`detail`), `healthExitCode`, `exitCode`, and appends a dated transcript log `<ReportDir>\devin-maintenance-<yyyyMMdd>.log`; report files older than `$ReportRetentionDays` days in `<ReportDir>` are removed.
- [x] **Step 3:** WSL preflight `wsl -d Ubuntu-26.04 -- bash -c 'echo ok'`: on failure records a `wsl-preflight` step with status FAIL, writes the report, and exits 1 without attempting any WSL-side step.
- [x] **Step 4:** Cache sweep deletes every unlocked file under `%APPDATA%\Devin\Cache` (recursive, per-file try/catch), records freed MB and locked-file count as a step detail, and never throws on locked files.
- [x] **Step 5:** Host log retention removes `%APPDATA%\Devin\logs\*` session dirs whose LastWriteTime is older than `$LogRetentionDays` days and records the removed count; WSL server-log retention removes `~/.devin-server/data/logs` entries with `find -mindepth 1 -maxdepth 1 -mtime +$LogRetentionDays -exec rm -rf` and records the before/after entry counts.
- [x] **Step 6:** Bundle orphan cleanup: lists `~/.devin-server/bin/*/` dirs, parses the live commit from line 2 of `bin\devin-desktop.cmd --version`; deletes (only when Devin.exe is NOT running) any dir that fails the integrity test (`node_modules/minimist` and `node_modules/@vscode` both present) or whose commit differs from live, together with that commit's `~/.devin-server/.<commit>.log/.pid/.token` sidecars; when the app IS running or the live commit cannot be parsed, records DEFERRED/SKIP instead and changes nothing on the WSL side.
- [x] **Step 7:** Runs `scripts/devin/Check-DevinHealth.ps1` (no switches), captures its console output into the transcript and its exit code into the report as `healthExitCode`; a repair performed in Step 6 makes the final exit code 2.
- [x] **Step 8:** With Devin running, a full execution exits 0: cache sweep, host-log prune, and server-log prune run (server-log prune is age-gated and only touches `data/logs`, safe live), bundle-orphan cleanup performs no WSL-side deletion (amended post-run: the live machine had no stale/corrupt dir to defer, so it recorded OK "all commit dirs intact and current" rather than DEFER — the DEFER branch is code-verified, not machine-exercised), and `latest.json` parses with `ConvertFrom-Json`.

### Task 2: Create the register script
**Dependencies:** Task 1
**Files:**
- Create: `scripts/devin/Register-Devin-Maintenance.ps1`
**Acceptance Criteria:**
- [x] **Step 1:** Mirrors `Register-WSL-PreWarm.ps1`: task `\DevOptimizer\Devin-Daily-Maintenance`, action `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\devin\Invoke-DevinDailyMaintenance.ps1"`, trigger `-Daily -At 04:30`, settings `-WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 30min -MultipleInstances IgnoreNew`, re-register safe via `-Force`, `-Remove` unregisters and confirms.

### Task 3: Register the task and refresh the Hub registry
**Dependencies:** Task 2
**Files:**
- Modify: `config/hub-registry.json`
**Acceptance Criteria:**
- [x] **Step 1:** `Register-Devin-Maintenance.ps1` run output confirms registration and `Get-ScheduledTask -TaskPath '\DevOptimizer\' -TaskName 'Devin-Daily-Maintenance'` shows State Ready with next run time today/tomorrow 04:30.
- [x] **Step 2:** `Build-Registry.ps1` completes and `config/hub-registry.json` contains both new commands (`Invoke-DevinDailyMaintenance`, `Register-Devin-Maintenance`) with total command count increased by exactly 2 over 346. (Recon correction: the live registry is `config/hub-registry.json`; `registry/script-registry.json` is an empty placeholder and stays untouched.)
- [x] **Step 3:** `validate-all-scripts.ps1` reports the two new scripts valid (no new syntax failures).

### Task 4: Final verification
**Dependencies:** Task 3
**Files:**
**Acceptance Criteria:**
- [x] **Step 1:** Real run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\devin\Invoke-DevinDailyMaintenance.ps1` against live machine state (Devin running) exits 0, and `latest.json` shows `appRunning: true`, a non-empty `steps` array, and no FAIL statuses.
- [x] **Step 2:** Rerun is idempotent: second run exits 0 with identical step names, `latest.json` overwritten in place, no unbounded growth in `<ReportDir>` beyond dated logs + latest.json.
- [x] **Step 3:** No path outside `%APPDATA%\Devin\Cache`, `%APPDATA%\Devin\logs`, `<ReportDir>`, `~/.devin-server/data/logs`, and `~/.devin-server/bin` (+ its dot-file sidecars) is read, written, or deleted by the orchestrator (grep-audit of the script source for file-touching cmdlets confirms the allowlist).
