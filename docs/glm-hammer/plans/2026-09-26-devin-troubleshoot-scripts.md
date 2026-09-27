# Blueprint: Devin Troubleshooting Scripts for DevOptimizer Hub

**Date:** 2026-09-26
**Status:** drafted (blueprint)
**Origin:** user request "create scripts to DevOptimizer app to troubleshoot Devin if has issues"

## Goal

Complement the existing `scripts\devin\Check-DevinHealth.ps1` (health check + corrupt-bundle repair) with two scripts covering the rest of the documented Devin failure modes (memory: devin-desktop-install), and register them in the Hub registry so they appear in the app.

## Recon findings (verified)

- Registry pipeline: `Discover-Scripts.ps1` auto-discovers scripts, reads `<# .SYNOPSIS #>` for description (regex at Discover-Scripts.ps1:127), `# CATEGORY: <name>` comment for category (line 149), `.PARAMETER` entries for parameters; `Build-Registry.ps1` regenerates `config\hub-registry.json` (currently 348 commands). Existing devin entries: `check-devinhealth` (maintenance), `register-wsl-prewarm` (cleanup).
- Existing pattern to follow: `scripts\devin\Check-DevinHealth.ps1` — `Invoke-Wsl` helper, OK/WARN/FAIL console output, exit codes 0 healthy / 1 problems / 2 repaired.
- Known failure modes to cover (from memory, all previously diagnosed): corrupt server bundle (ERR_MODULE_NOT_FOUND / exthost crash loop); superseded commit dirs left by repairs; stale `.pid`/`.log` files; growing `~/.devin-server/data/logs`; boot race; host memory starvation; WSL unreachable.
- WSL command quoting: `Invoke-Wsl` in Check-DevinHealth passes plain strings and works; avoid `$()` interpolation pitfalls by single-quoted bash with escaped `` `$HOME ``.

## Tasks

### Task 1: Create Get-DevinDiagnostics.ps1

Read-only deep-dive diagnostic report. No mutations, always exit 0 unless WSL unreachable (exit 1).

**Dependencies:** None

**Files:**
- Create: `D:\DevOptimizer\scripts\devin\Get-DevinDiagnostics.ps1`

**Acceptance Criteria:**
- [ ] Script has a `<# .SYNOPSIS #>` help block (app description) and `# CATEGORY: maintenance` header comment
- [ ] Report includes: Devin app version, WSL reachability + uptime, devin-server process + commit, bundle integrity (minimist + @vscode test), list of commit dirs in `~/.devin-server/bin/` (flags superseded), extensions count, `.devin-server/data/logs` size, host free memory, guest memory
- [ ] Log scan: tails today's newest `%APPDATA%\Devin\logs\<ts>\window1\renderer.log` and the WSL `~/.devin-server/.<commit>.log` for `ERR_MODULE_NOT_FOUND`, `terminated unexpectedly`, `exited with code`, counts occurrences and prints the last match of each
- [ ] `-OutFile <path>` writes the report as JSON (ConvertTo-Json, depth 4) in addition to console output
- [ ] Exit 0 when WSL reachable; exit 1 with guidance when WSL unreachable; never modifies any file or process
- [ ] Running it on the current healthy system completes without errors and flags zero corrupt-bundle findings

**Step 1:** Write the script following Check-DevinHealth.ps1 conventions (param block, Invoke-Wsl helper, OK/WARN/FAIL output, exit codes)
**Step 2:** Run it twice (console mode, then `-OutFile`) and confirm both acceptance outputs

### Task 2: Create Repair-Devin.ps1

Opt-in repair actions with dry-run default. Never touches extensions/, data/, settings, or `.installation_lock`.

**Dependencies:** None

**Files:**
- Create: `D:\DevOptimizer\scripts\devin\Repair-Devin.ps1`

**Acceptance Criteria:**
- [ ] Script has `<# .SYNOPSIS #>` help block and `# CATEGORY: maintenance` header comment
- [ ] With no switches: prints a dry-run summary of what each repair would do right now and exits 0 without changing anything
- [ ] `-FixBundle`: only when the current commit's bundle fails the minimist/@vscode test (or `-Commit <40hex>` given) — `pkill -f 'server-mai[n]'` + `rm -rf ~/.devin-server/bin/<commit>`, prints the "Reload Window" instruction, exit 2; refuses (exit 1) when bundle is intact unless `-Force`
- [ ] `-CleanLeftovers`: deletes commit dirs in `bin/` other than the current/live one plus their stale `.log`/`.pid`/`.token` files; keeps `.installation_lock`, `extensions/`, `data/`; prints each deletion
- [ ] `-PruneServerLogs -Days N` (default 14): deletes `~/.devin-server/data/logs` entries older than N days, prints freed size
- [ ] `-Confirm` prompt before every destructive step unless `-Force`; WSL unreachable exits 1 with the "check WSL first" rule from memory
- [ ] Dry-run on the current system reports exactly 1 superseded-item candidate class or "nothing to clean", and changes nothing (file counts unchanged before/after)

**Step 1:** Write the script with the four action paths and shared safety guard (refuse when WSL down; Confirm gate; never delete live commit)
**Step 2:** Dry-run it; verify zero mutations by comparing `bin/` listing + log file count before/after

### Task 3: Register scripts in the Hub registry

**Dependencies:** Task 1, Task 2

**Files:**
- Modify: `D:\DevOptimizer\config\hub-registry.json`

**Acceptance Criteria:**
- [ ] `Build-Registry.ps1` runs successfully and `config\hub-registry.json` contains `get-devindiagnostics` and `repair-devin` entries with non-empty descriptions sourced from the SYNOPSIS blocks and category `maintenance`
- [ ] Command count grows 348 → 350 (no existing entries lost — spot-check `check-devinhealth` still present)

**Step 1:** Run `Build-Registry.ps1` from `D:\DevOptimizer`
**Step 2:** Verify via JSON parse: new names present, descriptions non-empty, category maintenance, total count 350

### Task 4: Final verification

**Dependencies:** Task 1, Task 2, Task 3

**Acceptance Criteria:**
- [ ] Repo syntax validator passes both new scripts (same validator as the 613/613 sweep)
- [ ] `Check-DevinHealth.ps1` still exits 0 on the healthy system (no regression)
- [ ] `Get-DevinDiagnostics.ps1 -OutFile` produces parseable JSON
- [ ] `Repair-Devin.ps1` with no switches exits 0 and leaves `bin/` untouched

**Step 1:** Run the four checks in order and record results
