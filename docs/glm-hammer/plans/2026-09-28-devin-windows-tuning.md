# Blueprint: Windows 11 tuning layer for Devin daily maintenance

**Date:** 2026-09-28
**Requested by:** user ("use and fine tune all windows 11 capabilities for the above to succeed") — harden the Devin-Daily-Maintenance automation (plan 2026-09-28-devin-daily-maintenance.md) with the Windows facilities it currently lacks.

## Spec

- Gaps identified in the current setup: (1) Task Scheduler history channel is disabled by default, so unattended runs leave no OS-level audit; (2) after a WakeToRun start, the default 2-minute **system unattended sleep timeout** can put the machine back to sleep mid-run — fatal if a ~700 MB bundle re-download is in progress; (3) the task does not restart on transient failure; (4) a failed/repaired run is invisible unless the user opens the report file — no toast, no Event Log entry.
- New one-time admin script `scripts/devin/Tune-Windows-For-Devin.ps1` (self-elevates via UAC RunAs, house pattern from `scripts/register-devoptimizer-tasks.ps1`): enables the `Microsoft-Windows-TaskScheduler/Operational` event channel, raises the unattended sleep timeout (AC 1800 s / DC 600 s, only if the current value is lower, then re-applies the active scheme), and creates the `DevOptimizer` event source on the Application log. Idempotent; reports current vs new values.
- Orchestrator gains an **Event Log heartbeat** (Information event on every completed run with per-step summary; Warning on repair/deferral; Error on WSL-down) and a **Windows toast** on every non-zero exit. Both best-effort with try/catch — notification failures never change the run's exit code.
- Register script gains `-RestartCount 3 -RestartInterval 1min` (RestartOnFailure) and `-WorkingDirectory D:\DevOptimizer` on the action; re-registered in place with `-Force`.

### Task 1: Create the one-time Windows tuning script
**Dependencies:** None
**Files:**
- Create: `scripts/devin/Tune-Windows-For-Devin.ps1`
**Acceptance Criteria:**
- [x] **Step 1:** Script parses clean under PowerShell 5.1, self-elevates via `Start-Process -Verb RunAs` when not admin (UAC-gated), and is safe to re-run (every step checks current state before changing it).
- [x] **Step 2:** Enables the Task Scheduler operational channel via `wevtutil sl Microsoft-Windows-TaskScheduler/Operational /e:true` and verifies with `wevtutil gl` that `enabled: true`.
- [x] **Step 3:** Reads the current unattended sleep timeout (`powercfg /q SCHEME_CURRENT SUB_SLEEP UNATTENDSLEEP`), sets AC index to 1800 and DC index to 600 only where the current value is lower, re-applies `scheme_current`, and prints before/after values.
- [x] **Step 4:** Creates event source `DevOptimizer` on the Application log if it does not already exist (guarded by `[System.Diagnostics.EventLog]::SourceExists` in the elevated context) and confirms writability with one Information test event.

### Task 2: Add Event Log heartbeat and toast to the orchestrator
**Dependencies:** None
**Files:**
- Modify: `scripts/devin/Invoke-DevinDailyMaintenance.ps1`
**Acceptance Criteria:**
- [x] **Step 1:** Every completed run writes one `DevOptimizer` Application-log event: Information (id 1000) on exit 0 with per-step name/status summary; Warning (id 1001) on exit 2 (repair performed); Error (id 1002) on exit 1 (WSL unreachable). Write-EventLog is wrapped so a missing source or ACL failure only logs a transcript note.
- [x] **Step 2:** Non-zero exits additionally raise a Windows toast (WinRT ToastText02, PowerShell AppId) titled with the run outcome; toast code is try/catch-silent. (Amended post-run: no failure occurred on the live machine, so the toast path is code-verified only, like the 1001/1002 event paths.)
- [x] **Step 3:** Behavior for exit 0 is otherwise unchanged (no toast on success); parse and real-run still exit 0 with Devin running.

### Task 3: Harden the task registration
**Dependencies:** None
**Files:**
- Modify: `scripts/devin/Register-Devin-Maintenance.ps1`
**Acceptance Criteria:**
- [x] **Step 1:** Settings add `-RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)`; action gains `-WorkingDirectory 'D:\DevOptimizer'`; everything else (name, path, 04:30 trigger, 30-min limit, battery flags, IgnoreNew, `-Remove`) unchanged.
- [x] **Step 2:** After re-registering with `-Force`, `Get-ScheduledTask` shows State Ready and the settings object reports RestartCount 3 and the working directory; next run time unchanged (tomorrow 04:30).

### Task 4: Apply tuning and verify end-to-end
**Dependencies:** Task 1, Task 2, Task 3
**Files:**
**Acceptance Criteria:**
- [x] **Step 1:** `Tune-Windows-For-Devin.ps1` completes (UAC approved on this machine) and its output shows channel enabled, unattended timeout values, and event-source confirmation; `wevtutil gl Microsoft-Windows-TaskScheduler/Operational` reports `enabled: true`.
- [x] **Step 2:** A real orchestrator run with Devin running exits 0 and leaves an Information event from provider `DevOptimizer` in the Application log queryable via `Get-WinEvent -FilterHashtable @{LogName='Application';ProviderName='DevOptimizer'}`.
- [x] **Step 3:** `powercfg /q SCHEME_CURRENT SUB_SLEEP UNATTENDSLEEP` shows AC >= 1800 and DC >= 600 seconds.
- [x] **Step 4:** `latest.json` still parses with the expected step list; no regression in exit code or step set.
