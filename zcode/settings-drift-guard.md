# Settings drift guard

The central lesson of November 2026: half the Docker Desktop incidents traced
to silent drift in three small config files — `settings-store.json` (null
arrays, containerd flip), `.wslconfig` (virtiofs lost twice to syntax
nuances), and the watchdog scripts that write them. This lane verifies
current state against known-good, EXPLAINS any diff, and repairs only what
it can explain. Weekly, or after any Docker/WSL update. Read-only-report by
default; repairs listed need no user approval because they restore the
documented state.

Multi-line PowerShell goes in temp .ps1 files — never inline through bash.

## Check 1 — settings-store.json invariants

`%APPDATA%\Docker\settings-store.json`:

- `IntegratedWslDistros`: drift means the value is **null**, the wrong
  type, or an array that omits `Ubuntu-24.04` — null crashes startup with
  `reflect: Call using zero Value argument`, DD regenerates the key as null
  when it's absent across a restart, and an array without the distro means
  Ubuntu is not actually integrated (check: does `wsl.exe -d Ubuntu-24.04
  --exec docker info` answer?). A missing key with Docker running HEALTHY
  and the integration working is not corruption (the repair watchdog's
  reset lane intentionally clears and re-adds it) — do not restart a
  healthy Docker just to normalize the key.
- `UseContainerdSnapshotter` MUST be `true` — when flipped off, all
  containers/images vanish from view (they are hidden, not deleted).

Repair when warranted: stop docker processes first ONLY if a restart is
needed (null-value repair or containerd flip), backup (`*.bak-zcode`), write
with proper PS array serialization, **then always relaunch Docker Desktop**
(`Start-Process "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"`)
and verify the engine returns — a repair that leaves Docker stopped converts
a hidden-state problem into a full outage. Never write an empty array —
PowerShell 5.1 serializes `@()` as null, which is the bug class itself.
Restarting a healthy engine for cosmetics is worse than the drift.

## Check 2 — .wslconfig invariants

`C:\Users\tbaltzakis\.wslconfig`:

- `[wsl2]` section must contain `virtiofs=true` **on its own line** — no
  trailing comment (strict bool parse silently no-ops), and NOT under
  `[experimental]` (wrong section, silently ignored). Both mistakes were
  made and debugged on 2026-11-25.
- Existing memory/swap/processors values should match the backup
  `.wslconfig.bak-20261125-virtiofs` if present.

Verify the effective state, not just the file:

```bash
wsl.exe -d Ubuntu-24.04 --exec mount | grep 'on /mnt/c'
```

Must show `type virtiofs`. File correct + mount wrong = WSL needs a shutdown
cycle to pick it up — report, don't shutdown (the fsbridge responder owns
shutdowns).

## Check 3 — watchdog script integrity

The repair watchdogs write JSON settings. Verify none has reverted to the
empty-array bug: `scripts/repair-wsl-docker-integration.ps1` must NOT contain
an assignment of `@()` to `IntegratedWslDistros` — the fixed version writes
`@($Distro)` or removes nulls. grep for the pattern:

```bash
grep -n "IntegratedWslDistros" D:/DevOptimizer/scripts/repair-wsl-docker-integration.ps1
```

## Check 4 — docker-mcp gateway pre-gate

`C:\Users\tbaltzakis\devin-scripts\docker-mcp-gateway.bat` must contain
`WAIT_ENGINE` (the v7 pre-gate that keeps docker-mcp from existing before
the engine — the "lingering processes" startup block). If missing, restore
from `docker-mcp-gateway.bat.bak-20261125` comparison or re-apply per the
incident notes.

## Report

Write `logs/zcode-settings-drift.md`: per check PASS/DRIFTED/REPAIRED with the
exact before→after value. Any drift you cannot explain with this document is
reported, NOT repaired — unexplained config changes are a signal, not noise.
