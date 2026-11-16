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
