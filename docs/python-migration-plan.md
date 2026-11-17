# PowerShell/Batch → Python migration plan

**Status: COMPLETE (2026-11-17).** All 41 tranches merged (PRs #51–#91),
314 migrated originals retired via PR #132, registry rebuilt at 920
commands. This document remains as the migration's design record.

Goal: port every non-Python hub command to Python, in tranches, keeping the
original `.ps1`/`.bat` in place for review (deviation from the earlier ledger
rule that deleted originals — user-requested on 2026-11-16).

## Work list

`tools/migration-inventory.json` — generated from `config/hub-registry.json`:
every `entryPoint != "python"` command with its backing file, category, size,
and tranche number (12 files per tranche).

Tranche order = registry category size, largest first:
utilities (261) → cleanup (79) → ai-ml (41) → maintenance (40) → gaming (26) →
development → monitoring → backup-restore → network → security → docker →
the rest. Within a category, smallest files first (proves conventions cheaply
before the large orchestration scripts).

## Port conventions (same as the conversion ledger phases)

- Port lands at `scripts/py/<basename>.py` (lowercase, hyphens kept).
- `argparse` CLI. The default action is read-only; every mutating action
  supports `--dry-run`; data surfaces support `--json` (logs go to stderr).
- `# CATEGORY: <registry category>` docstring header + `# TAGS:` line so hub
  discovery picks the port up.
- Shared helpers: `py/devoptimizer_cli/core/winops.py`
  (`run_ps_command`/`run_ps_command_elevated` shims for CIM/WMI/registry,
  `run_task`, `reg_*`) and `executor.py` (`run_command`, `run_elevated`,
  `run_json_command`). Prefer these over ad-hoc subprocess calls.
- Windows-only operations that have no Python equivalent stay as one-line
  PowerShell shims via `run_ps_command` (tranche-B pattern).
- Original files stay; nothing re-points scheduled tasks, launchers, or
  wrappers — that is a separate decision after review.

## Per-tranche checklist

1. Port the tranche's files; keep behavior and exit codes.
2. `python -m py_compile` every new file.
3. Commit on a `devin/*` branch, open a PR per tranche (CI rebuilds the
   registry and runs the battery on Windows).
4. Append the tranche to `docs/python-conversion-ledger.md` (status
   **ported-alongside**, since originals are kept this round).

Port conventions (from review findings):

- `New-ScheduledTaskAction` must emit a headless action:
  `conhost.exe --headless "<shell>" <args>` (python → `pythonw.exe` instead,
  pwsh → the portable `D:\DevOptimizer\pwsh\pwsh.exe` — the Store stub is
  broken and `_rewrap-headless-all.ps1` skips already-wrapped actions).
- Quote action `-Argument` values as a single-quoted PS string containing
  literal double quotes (`-Argument '--headless pwsh.exe -File "x.ps1"'`);
  escaped `\"` inside double-quoted strings gets lost through the elevated
  runner.
- `--tail 0`-style slice args need an `n <= 0` guard (`[-0:]` is `[0:]`).

## Out of scope / stays PowerShell

Ledger phase-3 tranche-C: `Optimize-VHD`/`Mount-VHD` scripts, `Add-Type`/
WinForms UI, `DevOptimizer-AppCore.psm1` and other PS modules, platform
tooling that only exists as PowerShell cmdlets.

Inventory exclusion rule (`"excluded": true`, `"tranche": null`): the hub's
own tooling (`Build-App`, `Test-App`, `Hub-Registry`, `Discover-Scripts`,
`Build-Registry`, validate/test-syntax scripts), one-off test/debug
launchers, `scripts/lib/` and `modules/` support modules, and `app/` code.
24 commands excluded in tranche 1's inventory; the rule applies to later
tranches too.
