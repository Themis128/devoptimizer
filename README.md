# DevOptimizer Script Hub

A unified execution platform for Windows maintenance and developer tooling — consolidating hundreds of PowerShell scripts, batch tools, a Python CLI, and a native WPF app behind one menu, registry, and health system.

> **Personal, machine-specific project.** Paths (e.g. `D:\DevOptimizer`), scheduled tasks, and hardware tuning assume this workstation. Private repo.

## What's inside

| Layer | Components |
|---|---|
| **Core** | `DevOptimizer-Master.psm1` module loader (Path → Admin → Hub), config merge, favorites |
| **Discovery** | `Discover-Scripts.ps1` → `Build-Registry.ps1` → `config/hub-registry.json` (schema-validated, **454 commands**, 14 categories, deterministic) |
| **Execution** | `Execute-Command.ps1`, `Show-Menu.ps1`, `Check-Health.ps1`, `Update-Hub.ps1` |
| **Integration** | `devoptimizer.ps1` (12 parameter sets) ↔ Python CLI (`py/devoptimizer_cli`, Typer/Rich) |
| **Python ports** | `scripts/py/` — 8 converted workflows (see [conversion ledger](docs/python-conversion-ledger.md)) |
| **App** | WPF Windows 11 app (`app/`) with launcher exe, settings page, toasts, jump list, per-user installer |

## Quick start

```powershell
# Interactive menu (desktop launcher: DevOptimizer.bat)
powershell.exe -ExecutionPolicy Bypass -File "D:\DevOptimizer\devoptimizer.ps1" -Menu

# Search / run by category / health check
devoptimizer.ps1 -Search "cleanup"
devoptimizer.ps1 -Category maintenance
devoptimizer.ps1 -Health
```

Key areas: `scripts\` (general + issue-specific subfolders like `scripts\devin\`), `portable\`, `tools\`, `modules\`, `config\`, `app\`.

## Verification

```powershell
# One-command battery: pytest, xUnit, Pester, validate-all, syntax, parity, health
python tools/run-battery.py                # ALL GREEN expected; --skip-slow for fast surfaces

# App + registry test suites (requires pwsh — Pester 6; sets DEVOPT_ROOT itself)
pwsh -File scripts\Test-App.ps1            # 37/37 passing
dotnet test app/DevOptimizer.App.Tests -c Release   # 78/78 passing (incl. live registry pins)
cd py && python -m pytest tests/ -q        # 82 passing

# Full script syntax sweep
powershell -File validate-all-scripts.ps1  # 0 errors expected

# Registry health: every command path resolves
pwsh -File Discover-Scripts.ps1 -PassThru
```

## Python ports (`scripts/py/`)

Converted PowerShell workflows, registered as regular hub commands
(`python "<path>"` entry points). Conventions:

- **argparse CLI**, read-only action as the default; every mutating action
  supports `--dry-run`, data surfaces support `--json` (logs go to stderr)
- `# CATEGORY:` docstring header drives hub discovery (hyphenated categories OK)
- shared Windows helpers in `py/devoptimizer_cli/core/winops.py`
  (schtasks, eventlog, registry, elevated PowerShell shims)
- after adding/removing any discovered file, run the pipeline:
  `Build-Registry.ps1 -Force` → `python tools/sync-registry-pins.py` → battery

Maintenance tooling: `tools/sync-registry-pins.py` (pin auto-sync),
`tools/run-battery.py` (verification battery), `tools/parity-check.py`
(PS↔Python structural parity gate), `tools/classify-wrappers.py` +
`tools/content-refs.py` (wrapper audits). Conversion status:
[`docs/python-conversion-ledger.md`](docs/python-conversion-ledger.md).

## Documentation

- [`DEVOPTIMIZER-HUB-DOCS.md`](DEVOPTIMIZER-HUB-DOCS.md) — complete hub documentation
- [`docs/SCRIPT-HUB-ARCHITECTURE.md`](docs/SCRIPT-HUB-ARCHITECTURE.md) — architecture deep-dive
- [`INDEX.md`](INDEX.md) — VS Code optimization docs index
- [`PLAYWRIGHT-TESTING-README.md`](PLAYWRIGHT-TESTING-README.md) — Playwright testing helper scripts
- Plan log: [`docs/glm-hammer/plans/`](docs/glm-hammer/plans/)

## Notes

- Admin-required scripts carry `#Requires -RunAsAdministrator`; the app auto-elevates from registry metadata.
- Mimosa security policy (`.mimosa/security-policy.json`) documents the single-user trust model and accepted-by-design scanner findings.
- Logs, caches, archives, and tooling state are gitignored — see [.gitignore](.gitignore).
