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
