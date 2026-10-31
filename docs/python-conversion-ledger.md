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

Registry stable at 454 — pins auto-synced via tools/sync-registry-pins.py.

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
