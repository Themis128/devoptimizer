# Watchdog-of-watchdogs audit

Weekly audit of the scheduled-task fleet itself. Today a dead watchdog only
surfaces when something downstream breaks — this lane finds them first.
Read-only: it NEVER modifies tasks, only reports. Runtime ~5 min.

## Step 1 — inventory and last-run results

```powershell
powershell -NoProfile -Command "
Get-ScheduledTask | Where-Object {\$_.TaskPath -like '*DevOptimizer*' -or \$_.TaskName -match 'docker|wsl|vhdx|cleanup|devoptimizer|phone|ntfy|watchdog|guard'} | ForEach-Object {
  \$info = \$_ | Get-ScheduledTaskInfo
  [PSCustomObject]@{
    Task = \$_.TaskName
    State = \$_.State
    LastRun = \$info.LastRunTime
    Result = \$info.LastTaskResult
    Missed = \$info.NumberOfMissedRuns
  }
} | Sort-Object LastRun -Descending | Format-Table -AutoSize
"
```

## Step 2 — classify each task

For every task in the inventory:

- **Result 0 or 267009 (0x41301, still running)**: healthy, no action.
- **Result nonzero** (especially 1, 2, 0x80070002, 0x41303): failing — read
  its action, find the script, read the last 20 lines of its log under `logs/`.
- **LastRun older than 2x its schedule interval**: silently dead. Cross-check
  `State` — `Disabled` or `Ready`-but-never-runs both count as findings.
- **Missed > 0 repeatedly**: the machine is off/asleep at the trigger time —
  a scheduling-design finding, not an error.

## Step 3 — log freshness cross-check

The fleet transcripts to `logs/`. Any log file not written in 48h whose task
claims to run more often is a suspect:

```powershell
powershell -NoProfile -Command "
Get-ChildItem logs\*.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object Name, LastWriteTime, @{n='SizeKB';e={[math]::Round(\$_.Length/1KB)}} | Format-Table -AutoSize
"
```

## Step 4 — popup-free audit

The host has a zero-console-flash rule. Verify the headless wrappers are intact:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/popup_task_audit.ps1
```

`risky` must be 0. Any nonzero count is a finding with the task names.

## Step 5 — report only

Write `logs/zcode-watchdog-audit.md` with three sections:

1. **Failing tasks** — name, last result code, log tail excerpt, your read of
   the cause. Do NOT fix: fixing watchdogs is a design decision for the user
   or a full agent session.
2. **Silently dead** — name, expected cadence, last run.
3. **Healthy count** — one line, e.g. "14/16 healthy".

End with a one-line verdict. If everything is healthy, the whole report can be
three lines — do not pad it.
