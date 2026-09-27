# DevOptimizer Script Hub

A unified execution platform for Windows maintenance and developer tooling — consolidating hundreds of PowerShell scripts, batch tools, a Python CLI, and a native WPF app behind one menu, registry, and health system.

> **Personal, machine-specific project.** Paths (e.g. `D:\DevOptimizer`), scheduled tasks, and hardware tuning assume this workstation. Private repo.

## What's inside

| Layer | Components |
|---|---|
| **Core** | `DevOptimizer-Master.psm1` module loader (Path → Admin → Hub), config merge, favorites |
| **Discovery** | `Discover-Scripts.ps1` → `Build-Registry.ps1` → `config/hub-registry.json` (schema-validated, **346 commands**, 12 categories) |
| **Execution** | `Execute-Command.ps1`, `Show-Menu.ps1`, `Check-Health.ps1`, `Update-Hub.ps1` |
| **Integration** | `devoptimizer.ps1` (12 parameter sets) ↔ Python CLI (`py/devoptimizer_cli`, Typer/Rich) |
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
# App + registry test suites (requires pwsh — Pester 6; sets DEVOPT_ROOT itself)
pwsh -File scripts\Test-App.ps1          # 37/37 passing

# Full script syntax sweep
powershell -File validate-all-scripts.ps1   # 612/612 valid

# Registry health: every command path resolves
pwsh -File Discover-Scripts.ps1 -PassThru
```

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
