# Python Conversion Ledger

Status of the PowerShell→Python triage conversion (plan approved 2026-10-31).
One row per original: **converted** (Python port is live, PS deleted), **kept-PS**
(intentionally PowerShell), **retired** (wrapper/orphan removed, no replacement
needed), **deferred** (planned for a later tranche).

## Phase 1 — converted (2026-10-31)

| PS original | Python port | Notes |
|---|---|---|
| scripts/windows-update-cleanup.ps1 (521 L) | scripts/py/wu-cleanup.py | status/reset/clear-cache/fix; sc.exe/net/regsvr32/netsh/wevtutil/DISM via executor+winops |
| scripts/dev-cache-cleaner.ps1 (550 L) | scripts/py/dev-cache.py | nodejs/python/ide families, __pycache__ walker, Docker prune (DMR-filtered), git gc |

Deleted with them: portable/dev-cache-cleaner.bat, portable/windows-update-cleanup.bat.

## Phase 2 — wrapper retirement (2026-10-31)

Classification of 261 tracked `.bat/.cmd` + ≤20-line `.ps1` against scheduled
tasks, Start Menu, desktop shortcuts, hub registry, and tracked-content
references (tools/classify-wrappers.py + tools/content-refs.py):

| Bucket | Count | Action |
|---|---|---|
| Registry commands (live hub surface) | 258 bat + 36 trivial ps1 | KEEP (product) |
| Task/shortcut/content-referenced | 91 | KEEP |
| **True orphans (temp/scratch/debug one-offs)** | **29** | **DELETED 2026-10-31** |

Deleted orphans: CheckForUpdates.ps1, CheckUpdateMethods.ps1, Cleanup-CDrive_Test.ps1,
Create-Scheduled-Cleanup-Task.bat, Testing/{DEMO-REALTIME-FIXER, ENCODING-FIXED-PROGRESS,
START-ENHANCED-TESTING, START-PRODUCTION-FIXER, WORKING-PROGRESS-FIXER}.bat,
UpdateWindows.ps1, categories/uncategorized/{COMPREHENSIVE-BAT-SYSTEM-FIXER,
COMPREHENSIVE-BAT-SYSTEM-FIXER_NOPAUSE, CREATE-DESKTOP-SHORTCUTS-ENHANCED,
EXAMPLE-CONFIG-USAGE, FINAL-BATCH-SYSTEM-FIXER, IMPLEMENTATION-ROADMAP,
UI-ACCESS-GUIDE-EXTENDED}.bat, check-temp.ps1, check_camera.ps1, create_task.bat,
inspect2.ps1, run_cleanup.bat, temp_check_raised_task.ps1, temp_check_tasks.ps1,
temp_check_tasks_detailed.ps1, test-hub4.ps1, test-hub5.ps1, test-merge2.ps1,
test_debug.bat.

Registry after Phase 2: **452 commands / 14 categories** (classify-wrappers.py +
content-refs.py joined as hub tool commands). Pins synced: ci.yml ×2,
RegistryServiceTests (total + 14-category dict; search lock 29).

## Phase 3 tranche A — converted (2026-10-31)

| PS original | Python port | Notes |
|---|---|---|
| scripts/prerequisites-checker.ps1 (764 L) | scripts/py/prerequisites-checker.py | 10 check groups (PowerShell/.NET/Windows/Node/Python/Git/Docker/pkg-managers/dev-tools/disk+RAM); winget-free installers (msi/inno) gated behind --install-all; .cmd tools wrapped in cmd /c for CreateProcess |
| scripts/nuxt3-optimization.ps1 (693 L) | scripts/py/nuxt3-optimization.py | CLI dispatcher added (PS was a function library with no main): env/windows/wsl/prereqs/performance; Nuxt config + package-scripts templates; PS-profile aliases; WSL setup script execution; **.wslconfig overwrite now backs up the existing file first** (PS blindly clobbered it); category corrected gaming→development (one-time pin shift, now deterministic) |
| scripts/cursor-ai-optimization.ps1 (587 L) | scripts/py/cursor-ai-optimization.py | 6-action CLI (read-only `info` default; mutations explicit), 5 settings profiles ported, safe merge with existing settings.json, keybindings, extension sets, cache clear with dry-run; **discovery regex fixed to capture hyphenated categories** (`[\w-]+` — `ai-ml` no longer collapses to `ai`); parity via shared `_check_fn_map` |
| scripts/gpu-nvidia-broadcast-optimization.ps1 (667 L) | scripts/py/gpu-nvidia-broadcast-optimization.py | 7-action CLI (read-only `gpu-info` default), CIM reads via PS-shim JSON (tranche-B pattern), registry/powercfg tuning via winops+run_elevated, winget installs gated, per-platform acceleration configs; **fixes latent PS bug: Optimize-SingleGPU was called but never defined**; logs to stderr for clean --json piping |
| scripts/screen-settings-management.ps1 (801 L) | scripts/py/screen-settings-management.py | 8-action CLI; **ctypes user32 interop (DEVMODE/DISPLAY_DEVICE) replaces PS Add-Type**; live-verified (RTX 3070 Laptop, 42 available modes); WMI brightness via PS shim; DisplaySwitch multimonitor; JSON display profiles; read-only `info` default |
| scripts/dev-optimizer-fixed.ps1 (1,395 L) | scripts/py/dev-optimizer-fixed.py | 9-action CLI (read-only `info` default): optimize (4 registry levels), devtools, docker (prunes + Desktop/WSL settings with backup), 10-step comprehensive cleanup, network test/optimize, security hardening; **implements the 3 phantom functions the PS called but never defined** (Test-SystemVulnerabilities/Test-SystemSecurity/Set-SecurityHardening — Optimize-SecurityComplete was dead on arrival); Pester admin-specimen repointed to ai-development-tools |

**Phase 3-A COMPLETE: 6 of 6 ports.** Registry stable at 454 — pins auto-synced via tools/sync-registry-pins.py.

## Regression baseline (2026-10-31)

All 23 port surfaces regression-tested live: 23/23 effective pass
(one fix shipped: devopt network-test double JSON serialization;
devopt security exit-1 on genuine findings is by-design).
Maintenance pipeline: Build-Registry → sync-registry-pins → run-battery → gitops.

## Phase 4 — closeout (2026-10-31)

README updated (454/14, Python surface section, pipeline docs, battery command).
Plan complete: Phases 0-4 done.

Registry stable at 452 — name preserved, category development, entryPoint python.
Parity: prerequisites 10/10 Test-* mapping; nuxt3 5/5 function→action mapping (tools/parity-check.py).

## Phase 3 — remaining tranches

- **A. Pure orchestration** (deferred): dev-optimizer-fixed.ps1 (1,395 L),
  nuxt3-optimization.ps1 (693), cursor-ai-optimization.ps1 (587),
  gpu-nvidia-broadcast-optimization.ps1 (667), screen-settings-management.ps1 (801)
- **B. CIM/WMI reads** (deferred): port logic to Python, keep one-line PS shims
  for CIM queries via run_ps_command
- **C. Stays PowerShell permanently**: Optimize-VHD/Mount-VHD scripts,
  Add-Type/WinForms UI, PS modules (DevOptimizer-AppCore.psm1), platform tooling
  (Discover-Scripts.ps1, Build-Registry.ps1, Hub-Registry.ps1,
  validate-all-scripts.ps1, Check-Health.ps1, Build-App.ps1, Test-App.ps1),
  and the battle-tested scheduled-task production set (Invoke-VhdxCompaction.ps1,
  win11-admin-cleanup-elevated.ps1)

## Battery status at each tranche

pytest 82 · xUnit 78/78 · Pester 37/37 · validate-all-scripts 0 errors ·
Check-Health 270/275 · parity-check OK

## Phase 5 — full migration, tranche 1 (2026-11-16)

New program: port every non-Python hub command, tranches of 12 ordered by
category size (inventory: `tools/migration-inventory.json`, plan:
`docs/python-migration-plan.md`). **Originals are kept alongside** for review —
user-requested deviation from the delete-after-port rule.

| PS original | Python port | Notes |
|---|---|---|
| scripts/check-trigger.ps1 | scripts/py/check-trigger.py | trigger object via PS shim, --json |
| scripts/check-trigger2.ps1 | scripts/py/check-trigger2.py | Repetition block, --json |
| scripts/check-trigger3.ps1 | scripts/py/check-trigger3.py | CLR type names |
| scripts/check-devin-processes.ps1 | scripts/py/check-devin-processes.py | Get-Process *Devin* via shim, --json |
| scripts/check-vhdx.ps1 | scripts/py/check-vhdx.py | pure-Python file stat, --json |
| scripts/check-mem.ps1 | scripts/py/check-mem.py | Win32_OperatingSystem via CIM shim, --json |
| scripts/find-vhdx-task.ps1 | scripts/py/find-vhdx-task.py | Get-ScheduledTask via shim, --json |
| scripts/enable-ip-forwarding.ps1 | scripts/py/enable-ip-forwarding.py | mutating; --dry-run, --interface, elevated shim, stamp file |
| scripts/find-vhdx.ps1 | scripts/py/find-vhdx.py | pure-Python rglob, --json |
| scripts/restart-docker.ps1 | scripts/py/restart-docker.py | mutating; --dry-run, --wait |
| scripts/check-devin.ps1 | scripts/py/check-devin.py | pure-Python log scan, --count, --json |
| scripts/list-acp-dbs.ps1 | scripts/py/list-acp-dbs.py | pure-Python dir listing, --json |

## Phase 5 — full migration, tranche 2 (2026-11-16)

| PS original | Python port | Notes |
|---|---|---|
| scripts/check-elevated-task.ps1 | scripts/py/check-elevated-task.py | \DevOptimizer\ task-name match via shim, --json |
| scripts/check-acp-size.ps1 | scripts/py/check-acp-size.py | pure-Python dir size, --json |
| scripts/check-devin-logs.ps1 | scripts/py/check-devin-logs.py | pure-Python log tail, --count/--tail |
| scripts/check-devin-all-logs.ps1 | scripts/py/check-devin-all-logs.py | *.log only, --count/--tail |
| scripts/check-tasks.ps1 | scripts/py/check-tasks.py | Get-ScheduledTaskInfo via shim, --json |
| scripts/check-task-triggers.ps1 | scripts/py/check-task-triggers.py | trigger StartBoundary via shim, --json |
| scripts/shutdown-and-compact.ps1 | scripts/py/shutdown-and-compact.py | mutating; --dry-run, --vhdx, elevated Optimize-VHD |
| scripts/create-compaction-task.ps1 | scripts/py/create-compaction-task.py | mutating; --dry-run, --minutes |
| scripts/create-priority-task.ps1 | scripts/py/create-priority-task.py | mutating; --dry-run |
| scripts/check-outlook.ps1 | scripts/py/check-outlook.py | processes + AppModel events via shim, crash dumps pure-Python, --json |
| scripts/register-admin-task-elevated.ps1 | scripts/py/register-admin-task-elevated.py | mutating; --dry-run |
| scripts/check-store-apps.ps1 | scripts/py/check-store-apps.py | Get-AppxPackage via shim, --json |

## Phase 5 — full migration, tranche 3 (2026-11-16)

| PS original | Python port | Notes |
|---|---|---|
| scripts/docker-dashboard-guard.ps1 | scripts/py/docker-dashboard-guard.py | close dashboard windows via shim; --dry-run, --json, appends guard log |
| scripts/prune-acp.ps1 | scripts/py/prune-acp.py | pure-Python; --days (14), --dry-run |
| scripts/scan-d-usage.ps1 | scripts/py/scan-d-usage.py | pure-Python D:\ scan; --root, --top, --json |
| scripts/remove-large-acp.ps1 | scripts/py/remove-large-acp.py | pure-Python; --threshold-mb (50), --dry-run |
| scripts/docker-window-guard.ps1 | scripts/py/docker-window-guard.py | 3s closer loop; --interval, --max-iterations |
| scripts/devin/google-calendar-mcp-wrapper.ps1 | scripts/py/google-calendar-mcp-wrapper.py | npx launcher, stderr->log; --dry-run, --npx |
| scripts/check-all-syntax.ps1 | scripts/py/check-all-syntax.py | PS parser via shim per file; --root, --json |
| scripts/scan-nuxt-projects.ps1 | scripts/py/scan-nuxt-projects.py | pure-Python; --root, --json |
| scripts/register-dd-watchdog.ps1 | scripts/py/register-dd-watchdog.py | mutating; --dry-run |
| scripts/sshd-system-diag.ps1 | scripts/py/sshd-system-diag.py | subprocess sshd -t/-ddd capture; --dry-run |
| scripts/register-admin-system-elevated.ps1 | scripts/py/register-admin-system-elevated.py | mutating; --dry-run, --json verify row |
| scripts/check-social-apps.ps1 | scripts/py/check-social-apps.py | pure-Python dir match, --json |

## Phase 5 — full migration, tranche 4 (2026-11-16)

| PS original | Python port | Notes |
|---|---|---|
| scripts/devin/hook-session-start.ps1 | scripts/py/hook-session-start.py | WSL ping + CIM mem + Devin version; hook JSON |
| scripts/devin/hooks/session-end.ps1 | scripts/py/session-end-hook.py | stdin event -> sessions.log, webhook, msg.exe, queue check |
| scripts/devin/queue/session-end.ps1 | scripts/py/session-end-queue.py | duplicate original; -queue suffix port |
| scripts/create-priority-shortcut.ps1 | scripts/py/create-priority-shortcut.py | WScript.Shell COM via shim; --force, --dry-run |
| scripts/devin/hook-pre-devin.ps1 | scripts/py/hook-pre-devin.py | block/approve decision JSON |
| scripts/register-bat-sync-task.ps1 | scripts/py/register-bat-sync-task.py | mutating; --dry-run |
| scripts/devin/hooks/session-start.ps1 | scripts/py/session-start-hook.py | git/gh context + queue send-next; hook JSON |
| scripts/devin/queue/session-start.ps1 | scripts/py/session-start-queue.py | duplicate original; -queue suffix port |
| scripts/create-cline-mcp.ps1 | scripts/py/create-cline-mcp.py | wsl -d write of cline_mcp_settings.json; --dry-run |
| scripts/Start-OtterDesktop.ps1 | scripts/py/Start-OtterDesktop.py | CDP :9333 launch; --register/--unregister via shim |
| scripts/sync-bat-ps1.ps1 | scripts/py/sync-bat-ps1.py | pure-Python .bat launcher generator; --dry-run |
| scripts/devin/Add-DevinQueue.ps1 | scripts/py/Add-DevinQueue.py | queue-manager enqueue via pwsh subprocess |
## Phase 5 — full migration, tranche 5 (2026-11-16)

| PS original | Python port | Notes |
|---|---|---|
| scripts/register-devin-weekly-restart.ps1 | scripts/py/register-devin-weekly-restart.py | mutating; --force, --dry-run; headless conhost action |
| scripts/create-priority-task-com.ps1 | scripts/py/create-priority-task-com.py | COM Schedule.Service; --force, --dry-run; headless |
| scripts/register-devin-priority-simple.ps1 | scripts/py/register-devin-priority-simple.py | mutating; --force, --dry-run; headless |
| tools/wu-install.ps1 | scripts/py/wu-install.py | WU COM via generated PS block; log+exit-code contract kept |
| scripts/register-devin-session-manager.ps1 | scripts/py/register-devin-session-manager.py | mutating; --force, --dry-run; headless; -WhatIf preserved |
| scripts/watch-pending-actions.ps1 | scripts/py/watch-pending-actions.py | read-only status board; --json |
| scripts/apply-cline-settings.ps1 | scripts/py/apply-cline-settings.py | pure-Python JSON merge + backup; --dry-run, --json |
| scripts/register-devin-priority-task.ps1 | scripts/py/register-devin-priority-task.py | COM; --force, --dry-run; headless |
| scripts/create-priority-task-user.ps1 | scripts/py/create-priority-task-user.py | COM; --force, --dry-run; headless |
| scripts/register-devin-weekly-restart-elevated.ps1 | scripts/py/register-devin-weekly-restart-elevated.py | COM; --force, --dry-run; headless |
| scripts/restart-devin-weekly.ps1 | scripts/py/restart-devin-weekly.py | taskkill/tasklist + relaunch; --force, --dry-run |
| scripts/dmr-ram-guard.ps1 | scripts/py/dmr-ram-guard.py | GlobalMemoryStatusEx + docker model unload; --dry-run, --json |

Inventory: 15 items marked excluded — 14 already have .py siblings on
main (user ports at scripts/ root), plus scripts/chrome-ext-remove.ps1
(UI automation, Add-Type UIA + SendKeys) under the phase-3 rule.

## Phase 5 — full migration, tranche 6 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 61 | `scripts/Register-VhdxCompaction.ps1` | `scripts/py/Register-VhdxCompaction.py` | Self-elevating cmdlet registration, tbaltzakis/Interactive/Highest principal (SYSTEM ghosts on this Insider build); conhost headless action; `--remove`/`--trigger-now`/`--dry-run`; result sentinel preserved. |
| 62 | `scripts/manage-startup-apps.ps1` | `scripts/py/manage-startup-apps.py` | Run-key (HKCU+HKLM), Startup-folder and StartupTasks (State 2→1) sweep via PS block; mandatory/disable lists ported verbatim; `--dry-run`/`--json`. |
| 63 | `tools/run-ollama-all.ps1` | `scripts/py/run-ollama-all.py` | Native REST port (`/api/tags`, `/api/generate` stream:false) + ThreadPoolExecutor instead of the ollama-rest/config-loader modules; same exit-code contract (0/1/2/3) and aggregate.md output. |
| 64 | `tools/create-desktop-shortcut.ps1` | `scripts/py/create-desktop-shortcut.py` | WScript.Shell .lnk pair + red wrapper .bat; `--target`/`--shortcut-name`/`--dry-run`. |
| 65 | `scripts/cline-verify.ps1` | `scripts/py/cline-verify.py` | Read-only Cline storage/settings/.clineignore/.clinerules audit + NIM checklist; secrets masked; `--json`. |
| 66 | `tools/simple-dual-version-creator.ps1` | `scripts/py/simple-dual-version-creator.py` | Pure-Python Admin/NoAdmin variant generator; banner-aware admin-check injection; `--force`/`--dry-run`. |
| 67 | `scripts/devin/Verify-DevinSetup.ps1` | `scripts/py/Verify-DevinSetup.py` | All 9 checks ported (Devin.exe, devin-desktop CLI, WSL distro, devin-server commit, host RAM, credentials.toml, required ps1 files, mcp/hooks/skill config, daily-maintenance task); exit 0/1/2; `--json`. |
| 68 | `tools/add-script-descriptions.ps1` | `scripts/py/add-script-descriptions.py` | Reads hub-registry for empty descriptions; byte-level BOM/CRLF-preserving insertion; curated table + verbMap heuristic; backups under logs\description-backups\; `--dry-run`/`--json`. |
| 69 | `tools/normalize-bat-files.ps1` | `scripts/py/normalize-bat-files.py` | CRLF/space/Unicode->ASCII normalization, @echo off + setlocal + cd /d headers, :checkAdmin helpers for *-Admin.bat; backup dir preserved; `--dry-run`. |
| 70 | `tools/normalize-bat-files-fixed.ps1` | `scripts/py/normalize-bat-files-fixed.py` | Same normalizer as #69 via importlib (original ships both variants); separate hub command. |
| 71 | `scripts/check-nextcloud-sync.ps1` | `scripts/py/check-nextcloud-sync.py` | Client/journal/logs(gz)/conflict/Defender/cldflt checks + GitHub latest release; `--backup-config` with newest-5 retention; `--json`. |
| 72 | `scripts/manage-devin-sessions.ps1` | `scripts/py/manage-devin-sessions.py` | CLI sessions SQLite + main-window Desktop processes; embedded-python heredoc replaced with native sqlite3; `--max-concurrent`/`--idle-timeout-hours`/`--dry-run`. |

Excluded this tranche (phase-3 rules): `scripts/power-management.ps1` (function library, no entrypoint), `tools/create-dual-versions.ps1` (dot-sources admin-privilege-manager.ps1 module).

## Phase 5 — full migration, tranche 7 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 73 | `scripts/fine-tune-nextcloud.ps1` | `scripts/py/fine-tune-nextcloud.py` | Read-only integration health + `--apply-safe-tuning` self-elevates (Defender exclusions, cldflt auto-start); secrets filtered; `--json`. |
| 74 | `scripts/devin/queue/queue-manager.ps1` | `scripts/py/queue-manager.py` | Native file-queue + atomic O_EXCL lock; enqueue/dequeue/peek/list/clear/send-next via `devin -p` (cmd wrapper variant). |
| 75 | `scripts/devin/hooks/queue-manager.ps1` | `scripts/py/queue-manager-hooks.py` | Same queue; send-next uses direct argv invocation like the hooks original. |
| 76 | `scripts/automation-module.ps1` | `scripts/py/automation-module.py` | setup/create/list/remove/run/update modes; predefined task table; conhost headless + pwsh fallback registration. |
| 77 | `scripts/enhanced-event-log-checker.ps1` | `scripts/py/enhanced-event-log-checker.py` | System/App/Security window analysis via Get-WinEvent; `--detailed` samples, `--export-report` HTML, `--json`. |
| 78 | `scripts/overclocking-manager.ps1` | `scripts/py/overclocking-manager.py` | `--status` CPU/GPU/software/power-plan/registry; `--recommend` laptop-aware guidance; `--remove` OC registry keys; `--dry-run`. |
| 79 | `scripts/run-dism-admin.bat` | `scripts/py/run-dism-admin.py` | DISM StartComponentCleanup /NoRestart; `--dry-run`. |
| 80 | `scripts/run-compaction-elevated.bat` | `scripts/py/run-compaction-elevated.py` | RunAs-elevated compact-wsl-vhdx.ps1 -ForceAll -Force via Start-Process; `--dry-run`. |
| 81 | `scripts/create-admin-system-task.bat` | `scripts/py/create-admin-system-task.py` | schtasks weekly SUN 03:00 SYSTEM/HIGHEST registration; `--dry-run`. |
| 82 | `scripts/run-register-admin.bat` | `scripts/py/run-register-admin.py` | Runs register-admin-system-elevated.ps1; `--dry-run`. |
| 83 | `scripts/create-admin-task.bat` | `scripts/py/create-admin-task.py` | Same registration as create-admin-system-task (original ships both); delegates via importlib. |
| 84 | `scripts/create-devin-session-task.bat` | `scripts/py/create-devin-session-task.py` | schtasks every-4h HIGHEST task running manage-devin-sessions.ps1 -WhatIf; `--dry-run`. |

Excluded this tranche (phase-3 rules): `tools/admin-privilege-manager.ps1`, `tools/ollama-utils.ps1`, `tools/ollama-server-manager.ps1` (module-style libraries / module deps), `tools/ollama-analytics-dashboard.ps1` (interactive console UI + module dep), `scripts/startup-management.ps1` (function library, no entrypoint).

## Phase 5 — full migration, tranche 8 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 85 | `scripts/startup/ntfy-bridge.bat` | `scripts/py/ntfy-bridge.py` | pythonw hidden launch of ntfy-windows-bridge.py; --dry-run. |
| 86 | `scripts/create-admin-task-final.bat` | `scripts/py/create-admin-task-final.py` | Same registration as create-admin-system-task (original ships 3 variants); delegates via importlib. |
| 87 | `scripts/register-priority-task.bat` | `scripts/py/register-priority-task.py` | schtasks Devin-Lower-Priority ONSTART SYSTEM/HIGHEST; exit-code semantics preserved; --dry-run. |
| 88 | `scripts/create-priority-task-admin.bat` | `scripts/py/create-priority-task-admin.py` | Runs create-priority-task.ps1 (admin); --dry-run. |
| 89 | `scripts/apply-trigger-fixes-20261027.bat` | `scripts/py/apply-trigger-fixes-20261027.py` | RunAs-elevated trigger-fixes-20261027.ps1; --dry-run. |
| 90 | `portable/check-braces.bat` | `scripts/py/check-braces.py` | DEVOPT_HOME-aware pwsh/powershell shim; arg passthrough; --dry-run. |
| 91 | `portable/check-syntax.bat` | `scripts/py/check-syntax.py` | Same shim pattern to %DEVOPT_HOME%\check-syntax.ps1. |
| 92 | `portable/Run-Analysis.bat` | `scripts/py/Run-Analysis.py` | Same shim pattern to %DEVOPT_HOME%\ps\Run-Analysis.ps1. |
| 93 | `portable/Start-Dashboard.bat` | `scripts/py/Start-Dashboard.py` | Same shim pattern to %DEVOPT_HOME%\Start-Dashboard.ps1. |
| 94 | `portable/Monitor-Dashboard.bat` | `scripts/py/Monitor-Dashboard.py` | Same shim pattern to %DEVOPT_HOME%\Monitor-Dashboard.ps1. |
| 95 | `portable/run-ollama-all.bat` | `scripts/py/run-ollama-all-shim.py` | Shim renamed to avoid collision with the t6 run-ollama-all port. |
| 96 | `portable/vs.bat` | `scripts/py/vs.py` | Same shim pattern to %DEVOPT_HOME%\vs.ps1. |

## Phase 5 — full migration, tranche 9 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 97 | `portable/check-locked-files.bat` | `scripts/py/check-locked-files.py` | DEVOPT_HOME shim -> check-locked-files.ps1. |
| 98 | `portable/Rollback-Changes.bat` | `scripts/py/Rollback-Changes.py` | Shim -> ps\Rollback-Changes.ps1. |
| 99 | `portable/Start-Dashboard-PRO.bat` | `scripts/py/Start-Dashboard-PRO.py` | Shim -> Start-Dashboard-PRO.ps1. |
| 100 | `portable/kill.bat` | `scripts/py/kill.py` | Shim -> kill.ps1. |
| 101 | `portable/Verify-CygwinConfig.bat` | `scripts/py/Verify-CygwinConfig.py` | Shim -> Verify-CygwinConfig.ps1. |
| 102 | `portable/Check-Monitor-Status.bat` | `scripts/py/Check-Monitor-Status.py` | Shim -> Check-Monitor-Status.ps1. |
| 103 | `portable/apply-msi-xtu-config.bat` | `scripts/py/apply-msi-xtu-config.py` | Shim -> apply-msi-xtu-config.ps1. |
| 104 | `portable/Monitor-Dashboard-PRO.bat` | `scripts/py/Monitor-Dashboard-PRO.py` | Shim -> Monitor-Dashboard-PRO.ps1. |
| 105 | `portable/Verify-Installation.bat` | `scripts/py/Verify-Installation.py` | Shim -> ps\Verify-Installation.ps1. |
| 106 | `portable/nvidia.bat` | `scripts/py/nvidia.py` | Shim -> nvidia.ps1. |
| 107 | `portable/configure-xtu.bat` | `scripts/py/configure-xtu.py` | Shim -> config\overclocking\configure-xtu.ps1. |
| 108 | `portable/create-dual-versions.bat` | `scripts/py/create-dual-versions-shim.py` | Renamed: tools\create-dual-versions.ps1 is module-style (excluded); shim kept. |

## Phase 5 — full migration, tranche 10 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 109 | `portable/apply-xtu-cli.bat` | `scripts/py/apply-xtu-cli-shim.py` | Shim -> config\overclocking\apply-xtu-cli.ps1 (-shim: ps1 port exists). |
| 110 | `portable/configure-msi-xtu-simple.bat` | `scripts/py/configure-msi-xtu-simple-shim.py` | Shim -> configure-msi-xtu-simple.ps1. |
| 111 | `portable/Start-VSCodeMonitor-PROD.bat` | `scripts/py/Start-VSCodeMonitor-PROD-shim.py` | Shim -> Start-VSCodeMonitor-PROD.ps1. |
| 112 | `portable/Register-ScheduledTasks.bat` | `scripts/py/Register-ScheduledTasks-shim.py` | Shim -> ps\Register-ScheduledTasks.ps1. |
| 113 | `portable/apply-overclocking-config.bat` | `scripts/py/apply-overclocking-config-shim.py` | Shim -> apply-overclocking-config.ps1. |
| 114 | `portable/apply-overclocking-direct.bat` | `scripts/py/apply-overclocking-direct-shim.py` | Shim -> apply-overclocking-direct.ps1. |
| 115 | `portable/Bootstrap-DevEnvironment.bat` | `scripts/py/Bootstrap-DevEnvironment-shim.py` | Shim -> ps\Bootstrap-DevEnvironment.ps1. |
| 116 | `portable/verify-settings.bat` | `scripts/py/verify-settings-shim.py` | Shim -> config\overclocking\verify-settings.ps1. |
| 117 | `portable/create-desktop-shortcut.bat` | `scripts/py/create-desktop-shortcut-shim.py` | Shim -> tools\create-desktop-shortcut.ps1. |
| 118 | `portable/register-bat-sync-task.bat` | `scripts/py/register-bat-sync-task-shim.py` | Shim -> scripts\register-bat-sync-task.ps1. |
| 119 | `portable/REMOVE-DUPLICATE-BAT-FILES.bat` | `scripts/py/REMOVE-DUPLICATE-BAT-FILES.py` | Shim -> REMOVE-DUPLICATE-BAT-FILES.ps1. |
| 120 | `portable/apply-xtu-simple.bat` | `scripts/py/apply-xtu-simple.py` | Shim -> config\overclocking\apply-xtu-simple.ps1. |

## Phase 5 — full migration, tranche 11 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 121 | `portable/apply-msi-profile.bat` | `scripts/py/apply-msi-profile.py` | Shim -> config\overclocking\apply-msi-profile.ps1. |
| 122 | `portable/configure-overclocking-tools.bat` | `scripts/py/configure-overclocking-tools.py` | Shim -> configure-overclocking-tools.ps1. |
| 123 | `portable/create-msi-profile.bat` | `scripts/py/create-msi-profile.py` | Shim -> config\overclocking\create-msi-profile.ps1. |
| 124 | `portable/configure-overclocking-values.bat` | `scripts/py/configure-overclocking-values.py` | Shim -> configure-overclocking-values.ps1. |
| 125 | `portable/apply-msi-overclock.bat` | `scripts/py/apply-msi-overclock.py` | Shim -> config\overclocking\apply-msi-overclock.ps1. |
| 126 | `portable/apply-xtu-overclock.bat` | `scripts/py/apply-xtu-overclock.py` | Shim -> config\overclocking\apply-xtu-overclock.ps1. |
| 127 | `portable/switch-profile.bat` | `scripts/py/switch-profile.py` | Shim -> switch-profile.ps1. |
| 128 | `portable/CREATE-DESKTOP-SHORTCUT-OLLAMA.bat` | `scripts/py/CREATE-DESKTOP-SHORTCUT-OLLAMA.py` | Shim -> CREATE-DESKTOP-SHORTCUT-OLLAMA.ps1. |
| 129 | `portable/Start-VSCodeMonitor-AGGRESSIVE.bat` | `scripts/py/Start-VSCodeMonitor-AGGRESSIVE.py` | Shim -> Start-VSCodeMonitor-AGGRESSIVE.ps1. |
| 130 | `portable/copy-to-desktop.bat` | `scripts/py/copy-to-desktop.py` | Shim -> copy-to-desktop.ps1. |
| 131 | `portable/ollama-rest.bat` | `scripts/py/ollama-rest-shim.py` | Shim -> modules\ollama-rest.ps1 (module excluded from migration). |
| 132 | `portable/ollama-utils.bat` | `scripts/py/ollama-utils-shim.py` | Shim -> tools\ollama-utils.ps1 (module excluded). |

## Phase 5 — full migration, tranche 12 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 133 | `portable/save-msi-config.bat` | `scripts/py/save-msi-config.py` | Shim -> save-msi-config.ps1. |
| 134 | `portable/CREATE-CORRECT-DESKTOP-SHORTCUT.bat` | `scripts/py/CREATE-CORRECT-DESKTOP-SHORTCUT.py` | Shim -> CREATE-CORRECT-DESKTOP-SHORTCUT.ps1. |
| 135 | `portable/apply-and-document-overclocking.bat` | `scripts/py/apply-and-document-overclocking.py` | Shim -> apply-and-document-overclocking.ps1. |
| 136 | `portable/sync-bat-ps1.bat` | `scripts/py/sync-bat-ps1.py` | Shim -> scripts\sync-bat-ps1.ps1. |
| 137 | `portable/configure-overclocking.bat` | `scripts/py/configure-overclocking.py` | Shim -> config\overclocking\configure-overclocking.ps1. |
| 138 | `portable/configure-overclocking-automated.bat` | `scripts/py/configure-overclocking-automated.py` | Shim -> configure-overclocking-automated.ps1. |
| 139 | `portable/configure-xtu-advanced.bat` | `scripts/py/configure-xtu-advanced.py` | Shim -> config\overclocking\configure-xtu-advanced.ps1. |
| 140 | `portable/apply-all-overclock-cli.bat` | `scripts/py/apply-all-overclock-cli.py` | Shim -> config\overclocking\apply-all-overclock-cli.ps1. |
| 141 | `portable/playwright-helpers.bat` | `scripts/py/playwright-helpers.py` | Shim -> playwright-helpers.ps1. |
| 142 | `portable/VSCode-AutoMonitor.bat` | `scripts/py/VSCode-AutoMonitor.py` | Shim -> VSCode-AutoMonitor.ps1. |
| 143 | `portable/configure-xtu-v7.14.2.67.bat` | `scripts/py/configure-xtu-v7.14.2.67.py` | Shim -> config\overclocking\configure-xtu-v7.14.2.67.ps1. |
| 144 | `portable/create-and-apply-profile.bat` | `scripts/py/create-and-apply-profile.py` | Shim -> config\overclocking\create-and-apply-profile.ps1. |

## Phase 5 — full migration, tranche 13 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 145 | `portable/verify-and-apply-profile.bat` | `scripts/py/verify-and-apply-profile.py` | Shim -> config\overclocking\verify-and-apply-profile.ps1. |
| 146 | `portable/ollama-analytics.bat` | `scripts/py/ollama-analytics-shim.py` | Shim -> modules\ollama-analytics.ps1 (module excluded). |
| 147 | `portable/power-management.bat` | `scripts/py/power-management-shim.py` | Shim -> scripts\power-management.ps1 (function library excluded). |
| 148 | `portable/automation-module.bat` | `scripts/py/automation-module-shim.py` | Shim -> scripts\automation-module.ps1 (t7 port exists). |
| 149 | `portable/VSCode-ProcessMonitor.bat` | `scripts/py/VSCode-ProcessMonitor.py` | Shim -> VSCode-ProcessMonitor.ps1. |
| 150 | `portable/normalize-bat-files.bat` | `scripts/py/normalize-bat-files-shim.py` | Shim -> tools\normalize-bat-files.ps1 (t6 port exists). |
| 151 | `portable/startup-management.bat` | `scripts/py/startup-management-shim.py` | Shim -> scripts\startup-management.ps1 (module excluded). |
| 152 | `portable/configure-xtu-hardware-based.bat` | `scripts/py/configure-xtu-hardware-based.py` | Shim -> config\overclocking\configure-xtu-hardware-based.ps1. |
| 153 | `portable/apply-conservative-overclock.bat` | `scripts/py/apply-conservative-overclock.py` | Shim -> config\overclocking\apply-conservative-overclock.ps1. |
| 154 | `portable/apply-overclock-programmatic.bat` | `scripts/py/apply-overclock-programmatic.py` | Shim -> config\overclocking\apply-overclock-programmatic.ps1. |
| 155 | `portable/ollama-server-manager.bat` | `scripts/py/ollama-server-manager-shim.py` | Shim -> tools\ollama-server-manager.ps1 (module excluded). |
| 156 | `portable/overclocking-manager.bat` | `scripts/py/overclocking-manager-shim.py` | Shim -> scripts\overclocking-manager.ps1 (t7 port exists). |

## Phase 5 — full migration, tranche 14 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 157 | `portable/SIMPLE-PROGRESS-DEMO.bat` | `scripts/py/SIMPLE-PROGRESS-DEMO.py` | Shim -> Testing\SIMPLE-PROGRESS-DEMO.ps1. |
| 158 | `portable/admin-privilege-manager.bat` | `scripts/py/admin-privilege-manager-shim.py` | Shim -> tools\admin-privilege-manager.ps1 (module excluded). |
| 159 | `portable/WORKING-PROGRESS-FIXED.bat` | `scripts/py/WORKING-PROGRESS-FIXED.py` | Shim -> Testing\WORKING-PROGRESS-FIXED.ps1. |
| 160 | `portable/configure-intel-xtu-programmatic.bat` | `scripts/py/configure-intel-xtu-programmatic.py` | Shim -> config\overclocking\configure-intel-xtu-programmatic.ps1. |
| 161 | `portable/FIXED-ENCODING-PROGRESS.bat` | `scripts/py/FIXED-ENCODING-PROGRESS.py` | Shim -> Testing\FIXED-ENCODING-PROGRESS.ps1. |
| 162 | `portable/auto-configure-msi.bat` | `scripts/py/auto-configure-msi.py` | Shim -> config\overclocking\auto-configure-msi.ps1. |
| 163 | `portable/auto-configure-xtu.bat` | `scripts/py/auto-configure-xtu.py` | Shim -> config\overclocking\auto-configure-xtu.ps1. |
| 164 | `portable/normalize-bat-files-fixed.bat` | `scripts/py/normalize-bat-files-fixed-shim.py` | Shim -> tools\normalize-bat-files-fixed.ps1 (t6 port exists). |
| 165 | `portable/auto-create-profile.bat` | `scripts/py/auto-create-profile.py` | Shim -> config\overclocking\auto-create-profile.ps1. |
| 166 | `portable/next-steps-complete.bat` | `scripts/py/next-steps-complete.py` | Shim -> config\overclocking\next-steps-complete.ps1. |
| 167 | `portable/ollama-analytics-dashboard.bat` | `scripts/py/ollama-analytics-dashboard-shim.py` | Shim -> tools\ollama-analytics-dashboard.ps1 (module excluded). |
| 168 | `portable/PowerShell-Progress-Fixer.bat` | `scripts/py/PowerShell-Progress-Fixer.py` | Shim -> Testing\PowerShell-Progress-Fixer.ps1. |

## Phase 5 — full migration, tranche 15 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 169 | `portable/PRODUCTION-REALTIME-FIXER.bat` | `scripts/py/PRODUCTION-REALTIME-FIXER.py` | Shim -> Testing\PRODUCTION-REALTIME-FIXER.ps1. |
| 170 | `portable/enhanced-event-log-checker.bat` | `scripts/py/enhanced-event-log-checker-shim.py` | Shim -> scripts\enhanced-event-log-checker.ps1 (t7 port exists). |
| 171 | `portable/simple-dual-version-creator.bat` | `scripts/py/simple-dual-version-creator-shim.py` | Shim -> tools\simple-dual-version-creator.ps1 (t6 port exists). |
| 172 | `portable/automate-profile-creation.bat` | `scripts/py/automate-profile-creation.py` | Shim -> config\overclocking\automate-profile-creation.ps1. |
| 173 | `portable/save-msi-config-to-program-files.bat` | `scripts/py/save-msi-config-to-program-files.py` | Shim -> config\overclocking\save-msi-config-to-program-files.ps1. |
| 174 | `scripts/startup/dmr-tunnel.bat` | `scripts/py/dmr-tunnel.py` | ssh -R 12436 keep-alive loop + single-instance guard; --once for a single connect. |
| 175 | `tools/Variants/03-Install-Dev-Tools-NoAdmin.bat` | `scripts/py/install-dev-tools-noadmin.py` | Runs dev-optimizer-fixed.ps1 -Mode Basic -NoPause; --dry-run. |
| 176 | `scripts/startup/cdp-launch.bat` | `scripts/py/cdp-launch.py` | Launches headless Chrome :9330 + cdp_relay.py :9229 when not listening. |
| 177 | `scripts/register-admin-task-elevated.bat` | `scripts/py/register-admin-task-elevated.py` | SYSTEM weekly SUN 03:00 registration; action wrapped in conhost --headless (repo rule). |
| 178 | `tools/Variants/03-Install-Dev-Tools-Admin.bat` | `scripts/py/install-dev-tools-admin.py` | Same as NoAdmin variant (admin :checkAdmin tail is dead code); delegates via importlib. |
| 179 | `portable/create-desktop-shortcut-admin.bat` | `scripts/py/create-desktop-shortcut-admin-shim.py` | Shim -> create-desktop-shortcut-admin.ps1. |
| 180 | `portable/apply-overclock-admin.bat` | `scripts/py/apply-overclock-admin.py` | Shim -> config\overclocking\apply-overclock-admin.ps1. |

## Phase 5 — full migration, tranche 16 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 181 | `tools/Variants/OPEN-UI-NEW-WINDOW-Admin.bat` | `scripts/py/open-ui-new-window.py` | Menu -> start-in-new-window launchers; `--admin` = the admin variant's elevation check. |
| 182 | `tools/standard-admin-helpers.bat` | — | Excluded: function library (checkAdmin helpers), no entrypoint. |
| 183 | `tools/Variants/OPEN-UI-NEW-WINDOW-NoAdmin.bat` | `scripts/py/open-ui-new-window.py` | Same port; standard mode is the default. |
| 184 | `tools/Variants/QUICK-UI-ACCESS-NoAdmin.bat` | `scripts/py/quick-ui-access.py` | Shared launcher menu via importlib; `--admin` variant. |
| 185 | `tools/Variants/QUICK-UI-ACCESS-Admin.bat` | `scripts/py/quick-ui-access.py` | Same port with `--admin`. |
| 186 | `tools/Variants/00-SETUP-GLOBAL-ACCESS-NoAdmin.bat` | `scripts/py/setup-global-access.py` | HKLM system-PATH append; self-checks admin and exits like NoAdmin variant. |
| 187 | `tools/Variants/QUICK-GLOBAL-SETUP-NoAdmin.bat` | `scripts/py/quick-global-setup.py` | setx PATH + desktop shortcut + %USERPROFILE%\bin global launchers + bin on PATH; --dry-run. |
| 188 | `scripts/organize-files.bat` | `scripts/py/organize-files.py` | Moves backups/docs/logs/ps1/-Admin/-NoAdmin/launcher files into hub subfolders; keeps DEVOPTIMIZER-HUB + COMPREHENSIVE-LAUNCHER. |
| 189 | `tools/ollama-batch-helper.bat` | `scripts/py/ollama-batch-helper.py` | Unique logs/ollama-<ts> dir, runs run-ollama-all.ps1, copies aggregate.md to -output. |
| 190 | `tools/Variants/00-SETUP-GLOBAL-ACCESS-Admin.bat` | `scripts/py/setup-global-access.py` | Same port (admin check is the whole variant difference). |
| 191 | `tools/Variants/QUICK-GLOBAL-SETUP-Admin.bat` | `scripts/py/quick-global-setup.py` | Same port (`--admin` label only; actions identical). |
| 192 | `tools/Variants/CREATE-DESKTOP-SHORTCUTS-NoAdmin.bat` | `scripts/py/create-desktop-shortcuts.py` | 5 WScript.Shell .lnk files via COM. |


## Phase 5 — full migration, tranche 18 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 205 | `tools/Variants/AUTO-RECOVERY-SYSTEM-NoAdmin.bat` | `scripts/py/auto-recovery-system.py` | Self-healing pass: batch fixes, perms, exec policy, network, temp/cache, validation; logs/auto-recovery.log. |
| 206 | `tools/Variants/AUTO-RECOVERY-SYSTEM-Admin.bat` | `scripts/py/auto-recovery-system.py` | Same port with `--admin`. |
| 207 | `tools/Variants/ENHANCED-DEV-TOOLS-INSTALLER-Admin.bat` | `scripts/py/enhanced-dev-tools-installer.py` | choco + npm -g + config steps; --dry-run. |
| 208 | `tools/Variants/QUALITY-GATES-NoAdmin.bat` | `scripts/py/quality-gates.py` | 20 named gates -> shell checks; logs/quality-gates.log; --json; exit 1 on failure. |
| 209 | `tools/Variants/QUALITY-GATES-Admin.bat` | `scripts/py/quality-gates.py` | Same port with `--admin`. |
| 210 | `tools/Variants/MAKE-ALL-BAT-OPERATIONAL-NoAdmin.bat` | `scripts/py/make-all-bat-operational.py` | -NoAdmin copies of 5 admin bats, exec policy, @echo off check. |
| 211 | `tools/Variants/MAKE-ALL-BAT-OPERATIONAL-Admin.bat` | `scripts/py/make-all-bat-operational.py` | Same port with `--admin`. |
| 212 | `tools/Variants/ENHANCED-DEV-TOOLS-INSTALLER-NoAdmin.bat` | `scripts/py/enhanced-dev-tools-installer.py` | Same port. |
| 213 | `tools/Variants/ollama-intelligent-monitor-NoAdmin.bat` | `scripts/py/ollama-intelligent-monitor.py` | 9-item monitoring menu -> ollama-batch-helper; --choice. |
| 214 | `tools/Variants/ollama-intelligent-monitor-Admin.bat` | `scripts/py/ollama-intelligent-monitor.py` | Same port with `--admin`. |
| 215 | `tools/Variants/ollama-script-generator-NoAdmin.bat` | `scripts/py/ollama-script-generator.py` | 8-item generator menu -> helper; --choice/--sub/--desc. |
| 216 | `tools/Variants/ollama-script-generator-Admin.bat` | `scripts/py/ollama-script-generator.py` | Same port with `--admin`. |


## Phase 5 — full migration, tranche 17 (2026-11-16)

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 193 | `tools/Variants/CREATE-DESKTOP-SHORTCUTS-Admin.bat` | `scripts/py/create-desktop-shortcuts-admin.py` | Admin-gated delegate of create-desktop-shortcuts.py. |
| 194 | `tools/Variants/00-SETUP-GLOBAL-ACCESS-IMPROVED-NoAdmin.bat` | `scripts/py/setup-global-access-improved.py` | HKLM + user PATH append with confirm; `--admin` = admin variant. |
| 195 | `tools/Variants/REAL-TIME-MONITOR-NoAdmin.bat` | `scripts/py/real-time-monitor.py` | 5s health loop: critical files, exec policy, admin; logs/real-time-monitor.log. |
| 196 | `tools/Variants/00-SETUP-GLOBAL-ACCESS-IMPROVED-Admin.bat` | `scripts/py/setup-global-access-improved.py` | Same port with `--admin`. |
| 197 | `tools/Variants/REAL-TIME-MONITOR-Admin.bat` | `scripts/py/real-time-monitor.py` | Same port with `--admin`. |
| 198 | `tools/Variants/AWS-POWERSHELL-MODULES-DOWNLOADER-Admin.bat` | `scripts/py/aws-powershell-modules-downloader.py` | Sequential Install-Module steps; --dry-run; exit 1 on any failure. |
| 199 | `tools/Variants/SETUP-GLOBAL-ACCESS-NoAdmin.bat` | `scripts/py/setup-global-access-v2.py` | setx PATH /M (user fallback) + Master Suite desktop shortcut. |
| 200 | `tools/Variants/AWS-IAC-MANAGER-ASCII-Admin.bat` | `scripts/py/aws-iac-manager-ascii.py` | 14-item menu -> aws CLI table calls; terraform.tfstate print. |
| 201 | `tools/Variants/SETUP-GLOBAL-ACCESS-Admin.bat` | `scripts/py/setup-global-access-v2.py` | Same port with `--admin`. |
| 202 | `tools/Variants/AWS-IAC-MANAGER-ASCII-NoAdmin.bat` | `scripts/py/aws-iac-manager-ascii.py` | Same port. |
| 203 | `tools/Variants/AWS-POWERSHELL-MODULES-DOWNLOADER-NoAdmin.bat` | `scripts/py/aws-powershell-modules-downloader.py` | Same port. |
| 204 | `tools/normalize-bat-files.bat` | `scripts/py/normalize-bat-files.py` | Standard-header rewrite + non-ASCII strip; backup dir; -dry-run. |


## Phase 5 — full migration, tranche 21

| # | Original | Port | Notes |
|---|----------|------|-------|
| 241 | `scripts/wsl-vsock-watchdog.ps1` | `scripts/py/wsl-vsock-watchdog.py` | State json, 5-fail threshold, 25-min cooldown, probe+bounce. |
| 242 | `scripts/migrate-folders-to-wsl.ps1` | `scripts/py/migrate-folders-to-wsl.py` | rsync via wsl. |
| 243 | `scripts/win11-admin-cleanup.ps1` | `scripts/py/win11-admin-cleanup.py` | DISM + WU/DO cache + Windows.old rd. |
| 244 | `scripts/win11-os-deep-cleanup.ps1` | `scripts/py/win11-os-deep-cleanup.py` | Windows.old passes, upgrade dirs, hibernation, DISM, >30d logs, WU cache. |
| 245 | `scripts/win11-admin-cleanup-elevated.ps1` | `scripts/py/win11-admin-cleanup-elevated.py` | Delegates to -fixed port (originals identical). |
| 246 | `scripts/win11-admin-cleanup-elevated-fixed.ps1` | `scripts/py/win11-admin-cleanup-elevated-fixed.py` | DISM+RestoreHealth+SFC, WU/DO cache, oldest shadow, Windows.old. |
| 247 | `scripts/wsl-deep-clean.ps1` | `scripts/py/wsl-deep-clean.py` | 34 standard + 3 aggressive wsl commands; --no-aggressive. |
| 248 | `scripts/win11-safe-cleanup.ps1` | `scripts/py/win11-safe-cleanup.py` | Non-admin temp/caches/bin/docker-safe subset. |
| 249 | `scripts/Clean-DDrive.ps1` | `scripts/py/clean-ddrive.py` | Stale-target deletion + Nuxt Projects; --months-inactive/--force. |
| 250 | `scripts/admin-cleanup-elevated-robust.ps1` | `scripts/py/admin-cleanup-elevated-robust.py` | 9-section robust suite, continues on failure. |
| 251 | `scripts/admin-cleanup-system.ps1` | `scripts/py/admin-cleanup-system.py` | SYSTEM variant; Send-DevOptAlert on failures. |
| 252 | `scripts/mcp-devoptimizer-server.ps1` | `scripts/py/mcp-devoptimizer-server.py` | Stdio JSON-RPC MCP 2024-11-05; 7 devin_* tools. |
| 253 | `scripts/check-cleanup-status.ps1` | `scripts/py/check-cleanup-status.py` | Read-only cleanable-space assessment + verdict. |
| 254 | `scripts/elevated-complete-cleanup.ps1` | `scripts/py/elevated-complete-cleanup.py` | VHDX compaction + DISM/SFC/WU/DO/shadow/Windows.old orchestrator. |
| 255 | `scripts/devoptimizer-housekeeping.ps1` | `scripts/py/devoptimizer-housekeeping.py` | Repo housekeeping: archive stale reports, NT-name quarantine via Git Bash, check-broken-refs, optional --prune-docker. |
| 256 | `scripts/windows-features.ps1` | `scripts/py/windows-features.py` | status/enable/disable/profile subcommands over WindowsOptionalFeature. |
| 257 | `scripts/wsl-resource-balancer.ps1` | `scripts/py/wsl-resource-balancer.py` | Meminfo pressure -> tiered docker memory/restart limits + drop_caches. |
| 258 | `scripts/wsl-guardian.ps1` | `scripts/py/wsl-guardian.py` | T1/T2/T3 self-healing ladder, state.json cooldowns, deploy-lock, ntfy. |
| 259 | `scripts/extended-cleanup.ps1` | `scripts/py/extended-cleanup.py` | 7-section user-level cache/log cleanup with per-section day thresholds. |
| 260 | `scripts/FIXED-SYSTEM-DEEP-CLEAN.ps1` | `scripts/py/fixed-system-deep-clean.py` | 12-step system clean (temps, caches, WU, prefetch, event logs, cleanmgr). |
| 261 | `scripts/admin-cleanup-elevated.ps1` | `scripts/py/admin-cleanup-elevated.py` | Sections 0-7 incl. docker_data.vhdx compact, --shutdown-wsl/--skip-vhdx. |
| 262 | `scripts/check-wsl-memory-pressure.ps1` | `scripts/py/check-wsl-memory-pressure.py` | Swap watchdog (1003/1004 events, drop_caches, DD restart) + elevated piggyback lanes. |
| 263 | `scripts/dev-cleanup.ps1` | `scripts/py/dev-cleanup.py` | Interactive dev cleanup: processes, caches, ports, WSL, Cline; --yes/--aggressive. |

## Exclusions (tranche 22)

- `scripts/DevOptimizer-Core.ps1` — shared PowerShell module (logging/config helpers consumed by other scripts), not a runnable command; Python equivalent already exists as `py/devoptimizer_cli`.

## Phase 5 — full migration, tranche 23
| 264 | `portable/Cleanup-CDrive.bat` | `scripts/py/cleanup-cdrive.py` | DEVOPT_HOME/pwsh shim launcher. |
| 265 | `portable/Cleanup-VSCodeInsiders.bat` | `scripts/py/cleanup-vscodeinsiders.py` | DEVOPT_HOME/pwsh shim launcher. |
| 266 | `portable/Reorganize-DevOptimizer.bat` | `scripts/py/reorganize-devoptimizer.py` | DEVOPT_HOME/pwsh shim launcher. |
| 267 | `portable/Uninstall-DevOptimizer.bat` | `scripts/py/uninstall-devoptimizer.py` | DEVOPT_HOME/pwsh shim launcher. |
| 268 | `portable/wsl-ports.bat` | `scripts/py/wsl-ports.py` | DEVOPT_HOME/pwsh shim launcher. |
| 269 | `portable/optimizer.bat` | `scripts/py/optimizer.py` | DEVOPT_HOME/pwsh shim launcher. |
| 270 | `portable/quick-cleanup.bat` | `scripts/py/quick-cleanup.py` | DEVOPT_HOME/pwsh shim launcher. |
| 271 | `portable/Start-VSCodeInsidersOptimized.bat` | `scripts/py/start-vscodeinsidersoptimized.py` | DEVOPT_HOME/pwsh shim launcher. |
| 272 | `portable/monitor-temperatures.bat` | `scripts/py/monitor-temperatures.py` | DEVOPT_HOME/pwsh shim launcher (config/overclocking target). |
| 273 | `portable/optimize-wsl-memory.bat` | `scripts/py/optimize-wsl-memory.py` | DEVOPT_HOME/pwsh shim launcher. |
| 274 | `portable/wsl-reset-and-setup.bat` | `scripts/py/wsl-reset-and-setup.py` | DEVOPT_HOME/pwsh shim launcher. |
| 275 | `portable/playwright-optimizer.bat` | `scripts/py/playwright-optimizer.py` | DEVOPT_HOME/pwsh shim launcher. |

## Phase 5 — full migration, tranche 24
| 276 | `portable/windows-features.bat` | `scripts/py/windows-features-shim.py` | DEVOPT_HOME/pwsh shim (suffix — t22 native port owns the base name). |
| 277 | `portable/DevOptimizer-Core.bat` | `scripts/py/devoptimizer-core.py` | DEVOPT_HOME/pwsh shim launcher. |
| 278 | `portable/configure-hardware-optimized.bat` | `scripts/py/configure-hardware-optimized.py` | DEVOPT_HOME/pwsh shim (config/overclocking target). |
| 279 | `portable/monitor-temperatures-enhanced.bat` | `scripts/py/monitor-temperatures-enhanced.py` | DEVOPT_HOME/pwsh shim. |
| 280 | `portable/VS-Code-Cleanup-Launcher.bat` | `scripts/py/vs-code-cleanup-launcher.py` | DEVOPT_HOME/pwsh shim. |
| 281 | `portable/FIXED-SYSTEM-DEEP-CLEAN.bat` | `scripts/py/fixed-system-deep-clean-shim.py` | DEVOPT_HOME/pwsh shim (t22 native port owns base name). |
| 282 | `portable/VSCode-AutoMonitor-Optimized.bat` | `scripts/py/vscode-automonitor-optimized.py` | DEVOPT_HOME/pwsh shim. |
| 283 | `portable/devoptimizer-backend.bat` | `scripts/py/devoptimizer-backend.py` | DEVOPT_HOME/pwsh shim (system-scripts/backend target). |
| 284 | `scripts/admin-cleanup-run-as-admin.bat` | `scripts/py/admin-cleanup-run-as-admin.py` | Interactive 5-step admin clean (DISM, WU cache, DO, shadow, Windows.old); requires admin. |
| 285 | `tools/Variants/error-handling-template-NoAdmin.bat` | `scripts/py/error-handling-template-noadmin.py` | Error-logging scaffold, standard mode. |
| 286 | `tools/Variants/error-handling-template-Admin.bat` | `scripts/py/error-handling-template-admin.py` | Error-logging scaffold, admin gate. |
| 287 | `tools/Variants/OPTIMIZE-TIMEOUT-DELAYS-NoAdmin.bat` | `scripts/py/optimize-timeout-delays-noadmin.py` | Rewrites `timeout /t N` -> `ping -n 2` in sibling .bat files with .backup. |

## Phase 5 — full migration, tranche 25

| # | Original | Python port | Notes |
|---|----------|-------------|-------|
| 288 | `tools/Variants/OPTIMIZE-TIMEOUT-DELAYS-Admin.bat` | `scripts/py/optimize-timeout-delays-admin.py` | Timeout rewriter; admin gate. |
| 289 | `tools/Variants/performance-optimization-template-NoAdmin.bat` | `scripts/py/performance-optimization-template-noadmin.py` | Perf scaffold (log/progress/smart_wait/check_process), standard mode. |
| 290 | `tools/Variants/performance-optimization-template-Admin.bat` | `scripts/py/performance-optimization-template-admin.py` | Perf scaffold, admin gate. |
| 291 | `tools/Variants/advanced-error-handling-template-NoAdmin.bat` | `scripts/py/advanced-error-handling-template-noadmin.py` | Retry + system validation scaffold. |
| 292 | `tools/Variants/advanced-error-handling-template-Admin.bat` | `scripts/py/advanced-error-handling-template-admin.py` | Same, admin gate. |
| 293 | `tools/Variants/self-healing-system-template-NoAdmin.bat` | `scripts/py/self-healing-system-template-noadmin.py` | Health score + auto-recovery scaffold. |
| 294 | `tools/Variants/self-healing-system-template-Admin.bat` | `scripts/py/self-healing-system-template-admin.py` | Same, admin gate. |
| 295 | `tools/Variants/ollama-intelligent-optimizer-NoAdmin.bat` | `scripts/py/ollama-intelligent-optimizer-noadmin.py` | 7-mode menu driving ollama-batch-helper.bat. |
| 296 | `tools/Variants/ollama-intelligent-optimizer-Admin.bat` | `scripts/py/ollama-intelligent-optimizer-admin.py` | Same, admin gate. |
| 297 | `tools/Old-Launchers/DEVOPTIMIZER-WORKING-LAUNCHER.bat` | `scripts/py/devoptimizer-working-launcher.py` | Status check + 15-option menu to Old-Launchers .bat tools. |
| 298 | `tools/Old-Launchers/DEVOPTIMIZER-UNIFIED-LAUNCHER.bat` | `scripts/py/devoptimizer-unified-launcher.py` | Admin/standard dual-mode menu launcher. |
| 299 | `tools/ai-ml/install-dmr-gpu.ps1` | `scripts/py/install-dmr-gpu.py` | `docker model install-runner --backend llama.cpp --gpu cuda` + pass-through args. |

### Tranche 27 — ai-ml/config (PR #77)

| # | Original | Port | Notes |
|---|----------|------|-------|
| 312 | scripts/Cursor-AI-Module.ps1 | scripts/py/cursor-ai-module.py | 7 ops; 38-key config + profiles |
| 313 | scripts/ai-integration-module.ps1 | scripts/py/ai-integration-module.py | 6 modes; landed in t26 |
| 314 | portable/maintenance.bat | scripts/py/maintenance-shim.py | pwsh shim |
| 315 | portable/nvidia-pair.bat | scripts/py/nvidia-pair-shim.py | pwsh shim |
| 316 | portable/onedrive-repair.bat | scripts/py/onedrive-repair-shim.py | pwsh shim |
| 317 | portable/Cursor-AI-Module.bat | scripts/py/cursor-ai-module-shim.py | pwsh shim |
| 318 | portable/ml-frameworks-setup.bat | scripts/py/ml-frameworks-setup-shim.py | pwsh shim |
| 319 | portable/ai-development-tools.bat | scripts/py/ai-development-tools-shim.py | pwsh shim |
| 320 | scripts/onedrive-repair.ps1 | scripts/py/onedrive-repair.py | landed in t26 PR #76 |
| 321 | scripts/nvidia-pair-setup.ps1 | scripts/py/nvidia-pair-setup.py | landed in t26 PR #76 |
| 322 | scripts/ml-frameworks-setup.ps1 | scripts/py/ml-frameworks-setup.py | landed in t26 PR #76 |
| 323 | scripts/ai-development-tools.ps1 | scripts/py/ai-development-tools.py | landed in t26 PR #76 |

### Tranche 28 — Variants ai-ml launchers (PR #78)

| # | Original | Port | Notes |
|---|----------|------|-------|
| 324 | tools/Variants/RUN-OLLAMA-ALL-MODELS-Admin.bat | scripts/py/run-ollama-all-models-admin.py | shim, REQUIRES admin |
| 325 | tools/Variants/CURSOR-AI-GIT-CACHE-CLEAR-NoAdmin.bat | scripts/py/cursor-ai-git-cache-clear-noadmin.py | 8 git steps + user caches |
| 326 | tools/Variants/CURSOR-AI-GIT-CACHE-CLEAR-Admin.bat | scripts/py/cursor-ai-git-cache-clear-admin.py | + npm/yarn/TEMP/Chrome clears |
| 327 | tools/Variants/ollama-ai-analyzer-NoAdmin.bat | scripts/py/ollama-ai-analyzer-noadmin.py | 4 metrics + 4 prompts |
| 328 | tools/Variants/ollama-ai-analyzer-Admin.bat | scripts/py/ollama-ai-analyzer-admin.py | derived, admin gate |
| 329 | tools/Variants/OLLAMA-MULTI-MODEL-SYSTEM-STATUS-NoAdmin.bat | scripts/py/ollama-multi-model-system-status-noadmin.py | status report |
| 330 | tools/Variants/OLLAMA-MULTI-MODEL-SYSTEM-STATUS-Admin.bat | scripts/py/ollama-multi-model-system-status-admin.py | derived, admin gate |
| 331 | tools/Variants/CURSOR-AI-ESSENTIAL-TOOLS-NoAdmin.bat | scripts/py/cursor-ai-essential-tools-noadmin.py | choco installs + workspace |
| 332 | tools/Variants/CURSOR-AI-ESSENTIAL-TOOLS-Admin.bat | scripts/py/cursor-ai-essential-tools-admin.py | derived, admin gate |
| 333 | tools/Variants/ollama-predictive-maintenance-NoAdmin.bat | scripts/py/ollama-predictive-maintenance-noadmin.py | 7-mode menu |
| 334 | tools/Variants/ollama-predictive-maintenance-Admin.bat | scripts/py/ollama-predictive-maintenance-admin.py | derived, admin gate |
| 335 | portable/ai-integration-module.bat | scripts/py/ai-integration-module-shim.py | pwsh shim |

### Tranche 29 — Cursor optimizer menus + scheduled-task registrars (PR #79)

| # | Original | Port | Notes |
|---|----------|------|-------|
| 336 | tools/Variants/CURSOR-AI-OPTIMIZATION-SUITE-NoAdmin.bat | scripts/py/cursor-ai-optimization-suite-noadmin.py | 10-mode menu, tty-guarded |
| 337 | tools/Variants/CURSOR-AI-OPTIMIZATION-SUITE-Admin.bat | scripts/py/cursor-ai-optimization-suite-admin.py | derived, admin gate |
| 338 | tools/Variants/CURSOR-AI-COMPLETE-OPTIMIZER-NoAdmin.bat | scripts/py/cursor-ai-complete-optimizer-noadmin.py | deep-clean 1st item |
| 339 | tools/Variants/CURSOR-AI-COMPLETE-OPTIMIZER-Admin.bat | scripts/py/cursor-ai-complete-optimizer-admin.py | derived, admin gate |
| 340 | scripts/check-updates.ps1 | scripts/py/check-updates.py | COM update search via PS call, --json |
| 341 | scripts/register-health-dashboard.ps1 | scripts/py/register-health-dashboard.py | logon + 2-min task via COM |
| 342 | scripts/register-phone-watchdog-task.ps1 | scripts/py/register-phone-watchdog-task.py | schtasks /SC MINUTE /MO 15 |
| 343 | scripts/register-wsl-repair-task.ps1 | scripts/py/register-wsl-repair-task.py | schtasks /SC MINUTE /MO 30 |
| 344 | scripts/register-admin-cleanup-weekly.ps1 | scripts/py/register-admin-cleanup-weekly.py | Sunday 03:00 elevated + log |
| 345 | scripts/register-docker-prune-task.ps1 | scripts/py/register-docker-prune-task.py | schtasks monthly 1st 04:30 |
| 346 | scripts/register-vhdx-devin-exit-task.ps1 | scripts/py/register-vhdx-devin-exit-task.py | 5-min limited task via COM |
| 347 | scripts/install-startup-launchers.ps1 | scripts/py/install-startup-launchers.py | vbs hidden launchers |
| repair-phone-notifications.ps1 | scripts/py/repair-phone-notifications.py | t30 (via #79) | adb phone watchdog | notification-count restart loop |
| network-soft-reset.ps1 | scripts/py/network-soft-reset.py | t30 (via #79) | adapter reset | + --register-task lane |
| check-devinhealth.ps1 | scripts/py/check-devinhealth.py | t30 (via #79) | WSL devin-server health | commit-parse + bundle check |
| register-daily-cleanup-task.ps1 | scripts/py/register-daily-cleanup-task.py | t30 (via #79) | COM task registrar | \DevOptimizer\ daily 06:30 |
| register-diskspaceguard-task.ps1 | scripts/py/register-diskspaceguard-task.py | t30 (via #79) | COM task registrar | pythonw hourly |
| register-housekeeping-task.ps1 | scripts/py/register-housekeeping-task.py | t30 (via #79) | COM task registrar | Sat weekly |
| register-socialauto-maintenance.ps1 | scripts/py/register-socialauto-maintenance.py | t30 (via #79) | COM task registrar | Interactive IgnoreNew |
| update-all-ollama-scripts.ps1 | scripts/py/update-all-ollama-scripts.py | t30 | bat rewriter | backup+rollback per file |
| Tune-Windows-For-Devin.ps1 | scripts/py/tune-windows-for-devin.py | t30 | host tuning | wevtutil + powercfg + eventlog |
| Check-DevinDoctor.ps1 | scripts/py/check-devindoctor.py | t30 | pipx health check | --skip-install/--json-only |
| phone-tailnet-watch.ps1 | scripts/py/phone-tailnet-watch.py | t30 | tailnet watchdog | adb endpoint fallback chain |
| vhdx-compact-on-devin-exit.ps1 | scripts/py/vhdx-compact-on-devin-exit.py | t30 | exit-gate launcher | vsock heal + idle recycle lanes |
| portable/advanced-script-updater.bat | scripts/py/advanced-script-updater.py | t32 | pwsh shim | DEVOPT_HOME target |
| portable/enhanced-system-health.bat | scripts/py/enhanced-system-health-1.py | t32 | pwsh shim | scripts/ target |
| tools/update-ollama-scripts.bat | scripts/py/update-ollama-scripts.py | t32 | ollama-*.bat rewriter | .backup + helper routing |
| tools/Variants/launcher-NoAdmin.bat | scripts/py/launcher-noadmin.py | t32 | 00-LAUNCHER delegate | full-path call |
| tools/Variants/launcher-Admin.bat | scripts/py/launcher-admin.py | t32 | 00-LAUNCHER delegate | full-path call |
| tools/Variants/HEALTH-MONITOR-NoAdmin.bat | scripts/py/health-monitor-noadmin.py | t32 | 6-check score monitor | 30s loop, auto-repair <70 |
| tools/Variants/HEALTH-MONITOR-Admin.bat | scripts/py/health-monitor-admin.py | t32 | health monitor | admin gate + delegate |
| tools/Variants/06-System-Health-Check-NoAdmin.bat | scripts/py/06-system-health-check-noadmin.py | t32 | inline-PS CIM report | 3x retry, exit=errors |
| tools/Variants/06-System-Health-Check-Admin.bat | scripts/py/06-system-health-check-admin.py | t32 | health check | admin gate + delegate |
| scripts/vscode-optimization.ps1 | scripts/py/vscode-optimization.py | t32 | settings+extensions | Stable/Insiders |
| scripts/CENTERAL-LAUNCHER.ps1 | scripts/py/centeral-launcher.py | t32 | 30-entry menu | --quick/--status/--help |
| scripts/UNIFIED-LAUNCHER.ps1 | scripts/py/unified-launcher.py | t32 | logged 30-entry menu | config/help sub-menus |
| portable/Workspace-Launcher.bat | scripts/py/workspace-launcher.py | t33 | pwsh shim | DEVOPT_HOME target |
| portable/UNIFIED-LAUNCHER.bat | scripts/py/unified-launcher-2.py | t33 | pwsh shim | scripts/ target |
| portable/CENTERAL-LAUNCHER.bat | scripts/py/centeral-launcher-2.py | t33 | pwsh shim | scripts/ target |
| portable/vscode-optimization.bat | scripts/py/vscode-optimization-1.py | t33 | pwsh shim | scripts/ target |
| tools/Old-Launchers/UNIVERSAL-DESKTOP-LAUNCHER.bat | scripts/py/universal-desktop-launcher.py | t33 | working-launcher delegate | full-path call |
| tools/Old-Launchers/CREATE-DESKTOP-LAUNCHER.bat | scripts/py/create-desktop-launcher.py | t33 | shortcut creator | repo tools/ fallback |
| tools/Old-Launchers/UNIVERSAL-LAUNCHER.bat | scripts/py/universal-launcher.py | t33 | 4-option menu | elevated RUN-AS-ADMIN lane |
| tools/Variants/UNIVERSAL-LAUNCHER-NoAdmin.bat | scripts/py/universal-launcher-noadmin.py | t33 | 4-option menu | standard-mode banner |
| tools/Variants/UNIVERSAL-LAUNCHER-Admin.bat | scripts/py/universal-launcher-admin.py | t33 | 4-option menu | admin gate + delegate |
| tools/Variants/02-Ultra-Performance-NoAdmin.bat | scripts/py/02-ultra-performance-noadmin.py | t33 | dev-optimizer -Mode Basic | exit 1 on fail |
| tools/Variants/02-Ultra-Performance-Admin.bat | scripts/py/02-ultra-performance-admin.py | t33 | dev-optimizer -Mode Basic | checkAdmin never invoked in original |
| tools/Variants/01-Quick-Optimization-NoAdmin.bat | scripts/py/01-quick-optimization-noadmin.py | t33 | dev-optimizer -Mode Basic | exit = error count |
| 396 | `tools/Variants/01-Quick-Optimization-Admin.bat` | `scripts/py/01-quick-optimization-admin.py` | t34 | `python3 scripts/py/01-quick-optimization-admin.py` | Admin gate + delegate to noadmin sibling |
| 397 | `tools/Old-Launchers/UNIFIED-LAUNCHER.bat` | `scripts/py/unified-launcher-1.py` | t34 | `python3 scripts/py/unified-launcher-1.py` | 30-entry menu + config/help submenus |
| 398 | `tools/Variants/ollama-performance-scorer-NoAdmin.bat` | `scripts/py/ollama-performance-scorer-noadmin.py` | t34 | `python3 scripts/py/ollama-performance-scorer-noadmin.py` | 10 scoring modes; mode 1 collects counter JSON to ai-analysis/ |
| 399 | `tools/Variants/ollama-performance-scorer-Admin.bat` | `scripts/py/ollama-performance-scorer-admin.py` | t34 | `python3 scripts/py/ollama-performance-scorer-admin.py` | Admin gate + delegate |
| 400 | `tools/Old-Launchers/UNIFIED-LAUNCHER-NoAdmin.bat` | `scripts/py/unified-launcher-noadmin.py` | t34 | `python3 scripts/py/unified-launcher-noadmin.py` | 30-entry menu, U-variant entries 21/22 |
| 401 | `tools/Old-Launchers/UNIFIED-LAUNCHER-Admin.bat` | `scripts/py/unified-launcher-admin.py` | t34 | `python3 scripts/py/unified-launcher-admin.py` | Admin gate; REQUIRES: admin marker |
| 402 | `tools/Old-Launchers/CENTERAL-LAUNCHER-1.bat` | `scripts/py/centeral-launcher-1.py` | t34 | `python3 scripts/py/centeral-launcher-1.py` | Same 30-entry menu, C-variant entries |
| 403 | `tools/Old-Launchers/CENTERAL-LAUNCHER-NoAdmin.bat` | `scripts/py/centeral-launcher-noadmin.py` | t34 | `python3 scripts/py/centeral-launcher-noadmin.py` | Canonical template for launcher family |
| 404 | `tools/Old-Launchers/CENTERAL-LAUNCHER-Admin.bat` | `scripts/py/centeral-launcher-admin.py` | t34 | `python3 scripts/py/centeral-launcher-admin.py` | Admin gate; REQUIRES: admin marker |
| 405 | `scripts/debug-config.ps1` | `scripts/py/debug-config.py` | t34 | `python3 scripts/py/debug-config.py` | Invokes config-loader module via pwsh, prints ollama section |
| 406 | `scripts/update-compose-override.ps1` | `scripts/py/update-compose-override.py` | t34 | `python3 scripts/py/update-compose-override.py` | restart=no for 6 cu130-slim containers via wsl |
| 407 | `scripts/Insider-Automation.ps1` | `scripts/py/insider-automation.py` | t34 | `python3 scripts/py/insider-automation.py -Operation dailyhealth` | Module ops delegate to DevOptimizer-Core via ps1; tasks via schtasks |
| 408 | `portable/Monitor-VSCodeInsiders.bat` | `scripts/py/monitor-vscodeinsiders.py` | t35 | `python3 scripts/py/monitor-vscodeinsiders.py` | DEVOPT_HOME ps1 shim |
| 409 | `portable/debug-line899.bat` | `scripts/py/debug-line899.py` | t35 | `python3 scripts/py/debug-line899.py` | DEVOPT_HOME ps1 shim |
| 410 | `portable/debug-config.bat` | `scripts/py/debug-config-1.py` | t35 | `python3 scripts/py/debug-config-1.py` | DEVOPT_HOME scripts/ ps1 shim |
| 411 | `portable/Insider-Automation.bat` | `scripts/py/insider-automation-1.py` | t35 | `python3 scripts/py/insider-automation-1.py` | DEVOPT_HOME scripts/ ps1 shim |
| 412 | `portable/insiders-extension-config.bat` | `scripts/py/insiders-extension-config.py` | t35 | `python3 scripts/py/insiders-extension-config.py` | DEVOPT_HOME ps1 shim |
| 413 | `portable/vscode-insiders-extension-config.bat` | `scripts/py/vscode-insiders-extension-config.py` | t35 | `python3 scripts/py/vscode-insiders-extension-config.py` | DEVOPT_HOME ps1 shim |
| 414 | `portable/Collect-Metrics.bat` | `scripts/py/collect-metrics.py` | t35 | `python3 scripts/py/collect-metrics.py` | DEVOPT_HOME ps/ ps1 shim |
| 415 | `scripts/pre-bounce-check.ps1` | `scripts/py/pre-bounce-check.py` | t35 | `python3 scripts/py/pre-bounce-check.py -Force` | 8-check safety list; exit 0/1/2 |
| 416 | `scripts/host-guard.ps1` | `scripts/py/host-guard.py` | t35 | `python3 scripts/py/host-guard.py -OnceVerbose` | T2 drop_caches / T3 runner restart / T4 auto-bounce (Devin-closed only) |
| 417 | `scripts/dd-settings-watchdog.ps1` | `scripts/py/dd-settings-watchdog.py` | t35 | `python3 scripts/py/dd-settings-watchdog.py` | drift detect + restore + 6h restart cooldown; store-v2 tolerated |
| 418 | `scripts/real-time-monitoring.ps1` | `scripts/py/real-time-monitoring.py` | t35 | `python3 scripts/py/real-time-monitoring.py -Mode metrics` | typeperf counters; dashboard/report/metrics/alerts modes |
| 419 | `scripts/health-dashboard.ps1` | `scripts/py/health-dashboard.py` | t35 | `python3 scripts/py/health-dashboard.py` | state JSONs + log tails -> html+json dashboard |
