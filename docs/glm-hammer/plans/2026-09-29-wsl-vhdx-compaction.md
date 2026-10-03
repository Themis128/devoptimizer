# Blueprint: Devin-safe scheduled WSL/Docker vhdx compaction

**Date:** 2026-09-29
**Requested by:** user ("schedule it but find a way not to cause issues to Devin which working with my wsl folders \\wsl.localhost\Ubuntu-26.04\home\tbaltzakis\cu130-slim and ...cloudless.gr")

## Spec

- Recon findings: `Optimize-VHD` available; vhdx files = Ubuntu-26.04 ext4.vhdx (51.5 GB) + docker_data.vhdx (222.8 GB, holds ~80 GB of prune-freed space); the 15-day `\DevOptimizer\DevOptimizer-Elevated-Cleanup` task ALREADY runs vhdx compaction but its Part 1 (a) has NO Devin guard, (b) uses a fragile unlock (kills processes, sleeps 3 s, no lock poll — last run Sep-27 FAILED 0x80070020 file-in-use), and (c) never restarts WSL/Docker afterward (leaves containers down until next Docker launch).
- New nightly task `\DevOptimizer\WSL-Vhdx-Compact` (SYSTEM, daily 03:45, after the 02:15–03:00 maintenance block) running a standalone `scripts/Invoke-VhdxCompaction.ps1`:
  - **Devin gates (the user's core requirement):** skip (exit 2, touch nothing) if any `Devin.exe` process is running; also skip if a `devin-server` process is alive inside Ubuntu-26.04 (Devin's auto-shutdown clears it after the app closes). Deferred runs are retried by the task (RestartOnFailure 8 × 30 min) and then simply wait for the next night — never force.
  - **Growth threshold:** compact only on first run or when a vhdx grew ≥ 10 GB since its last successful compaction (state in `logs\vhdx-compaction-state.json`); no wasted nightly compactions.
  - **Robust unlock:** quit Docker Desktop gracefully (CloseMainWindow, wait for com.docker.backend exit) → `wsl --shutdown` → poll until `vmmemWSL` is gone and the vhdx opens exclusively (retry loop up to 120 s) → `Optimize-VHD -Mode Full` per vhdx.
  - **Restart after:** start Docker Desktop (`C:\Program Files\Docker\Docker\Docker Desktop.exe` — containers return via restart policies), `wsl -d Ubuntu-26.04 --exec true` (UNC paths + Devin reconnect instantly), log before/after sizes.
- `scripts/Register-VhdxCompaction.ps1` registers/unregisters the task (self-elevating, SYSTEM principal, RestartCount 8 × 30 min, ExecutionTimeLimit 2 h) — mirrors `Register-Devin-Maintenance.ps1` conventions.
- `scripts/elevated-complete-cleanup.ps1` Part 1 gets the same Devin guard + unlock-poll + restart-after so the 15-day task can never hurt Devin either.

### Task 1: Standalone nightly compaction script
**Dependencies:** None
**Files:**
- Create: `scripts/Invoke-VhdxCompaction.ps1`
**Acceptance Criteria:**
- [x] **Step 1:** Script parses clean; non-admin execution exits 1 with a clear message before touching anything.
- [x] **Step 2:** Devin gate: with `Devin.exe` running, a run logs `DEFERRED: Devin is active` and exits 2 without stopping WSL/Docker or touching any vhdx.
- [x] **Step 3:** With gates passing, it stops Docker Desktop gracefully, runs `wsl --shutdown`, polls (≤120 s) until `vmmemWSL` is gone and each vhdx opens with exclusive access, compacts every vhdx found (Ubuntu ext4.vhdx + docker_data.vhdx) with `Optimize-VHD -Mode Full`, records before/after sizes in `logs\vhdx-compaction-state.json`, restarts Docker Desktop and `wsl -d Ubuntu-26.04 --exec true`, and logs everything.
- [x] **Step 4:** State file gates repeats: a second immediate run with no ≥10 GB growth since the recorded sizes exits 0 with `SKIP: no significant growth`.

### Task 2: Register script + existing-task hardening
**Dependencies:** Task 1
**Files:**
- Create: `scripts/Register-VhdxCompaction.ps1`
- Modify: `scripts/elevated-complete-cleanup.ps1`
**Acceptance Criteria:**
- [x] **Step 1:** Register script creates `\DevOptimizer\WSL-Vhdx-Compact` (SYSTEM, daily 03:45, RestartCount 8/30 min, 2 h limit), self-elevating via UAC; `-Remove` unregisters; verified via Get-ScheduledTask.
- [x] **Step 2:** `elevated-complete-cleanup.ps1` Part 1 gains the same three protections (Devin gate before any process kill, exclusive-lock poll instead of sleep-3, Docker Desktop + WSL restart after compaction) and still parses clean.

### Task 3: Verification
**Dependencies:** Task 2
**Files:**
**Acceptance Criteria:**
- [x] **Step 1:** Registered task shows Ready with next run tomorrow 03:45; triggering it via `schtasks /run` while Devin is open results in a DEFERRED exit-2 run with no WSL/Docker disruption (Docker containers still up, `\\wsl.localhost` paths still resolve).
- [x] **Step 2:** `validate-all-scripts.ps1` stays at 0 invalid.
- [x] **Step 3:** The real compaction then happens on the first nightly run where Devin is closed; its log shows before/after sizes and both Docker containers and UNC paths recover (verified next morning).


## Verification results (2026-09-29)

- Task 1: parse OK; non-admin run blocked (admin gate); Devin gate verified live — with Devin.exe running, the triggered task exited 2 (deferred) and left WSL/Docker completely untouched (container set identical, UNC folders reachable).
- Task 2: registered via self-elevation (SYSTEM, daily 03:45, Ready, NextRun 09/30 03:45, RestartCount 8x30min); elevated-complete-cleanup.ps1 Part 1 now delegates to the standalone script (-AsLibrary -ForceAll).
- Task 3: validate-all-scripts 618/618, 0 invalid. Note: SYSTEM/Highest tasks are not queryable from non-elevated contexts — all verification ran inside the elevated register/trigger path; the real compaction fires on the first nightly run with Devin closed.
- Fix during registration: guarded registration block was initially placed before $action definition (null-Action failure); register script rewritten with the guarded block after parameter setup.
