# Deep cleanup (Windows 11 workstation)

Full deep-cleanup pass. Run monthly or when C: drops below 25GB free.
Estimated runtime: 30-90 min including the compaction wait.
Multi-line PowerShell goes in temp .ps1 files — never inline through bash.

## Phase 0 — baseline

```powershell
Get-PSDrive C,D,E | Select-Object Name,@{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}} | Format-Table
```

Write the numbers into `logs/zcode-deep-cleanup.md` with a timestamp.

## Phase 1 — dry-run audit first

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/devoptimizer-housekeeping.ps1 -DryRun
```

Read the output. If it plans to archive anything outside `archive/housekeeping-*`
paths or anything you don't recognize, STOP and report instead of proceeding.

**Disclosure — what the dry-run does NOT preview.** Before continuing, the
operator must know this lane irreversibly: empties the Recycle Bin
(`daily-full-cleanup.ps1`), and deletes the oldest shadow copy +
Windows.old / WU cache (`admin-cleanup-elevated.ps1`). All three are standard
maintenance on this host and run monthly via scheduled tasks regardless —
but they are deletions, not moves. If the user only wanted a tidy-up, run
Phases 1-2 only and stop.

## Phase 2 — user-space cleanup (no admin needed)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/devoptimizer-housekeeping.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cleanup-wsl-swap-orphans.ps1
```

Then `daily-full-cleanup.ps1` with one exception: if its docker container
prune is active, skip or accept that sleeping sidecars will be deleted —
check the script first; the idle-sleep containers are a feature, and deleted
containers must be recreated, not just started. If the script has no
exclusion mechanism, run its non-container steps only (report what you
skipped).

## Phase 3 — elevated cleanup via the existing task

Do NOT reimplement admin cleanup. Fire the registered task:

```
schtasks /run /tn "\DevOptimizer\DeepClean-Elevated"
```

Wait 5 minutes, then read the tail of `logs\admin-cleanup-elevated.log` and
confirm it completed. If the task is missing or errors, report — do not
improvise admin cleanup.

## Phase 4 — docker prune decision (judgment required)

```bash
docker ps -q | wc -l
docker system df
```

Rules:
- C: free now above 30GB: `docker builder prune -af` + `docker image prune -f` only.
- C: free still below 20GB: may add `docker image prune -a -f` (re-pull cost,
  no data loss).
- NEVER `docker volume prune` or `docker container prune` — volumes carry
  production data; stopped containers are intentionally sleeping sidecars.

## Phase 5 — VHDX compaction gate + WAIT

First the session gate — devin-server runs INSIDE Ubuntu, invisible to
Windows `Get-Process`:

```powershell
$alive = $false
foreach ($i in 1..3) {
  $out = & wsl.exe -d Ubuntu-24.04 -e bash -lc "pgrep -f 'devin acp|server-mai[n]' | head -3" 2>$null
  if ($out) { $alive = $true; break }
  Start-Sleep 2
}
```

- If alive: SKIP this phase entirely, note it in the report.
- If clear: `schtasks /run /tn "\DevOptimizer\Nightly-Vhdx-Compact"`.

**The task is asynchronous and the compaction takes 20-60 min while Docker
is down.** Do NOT measure final disk state yet. Either wait (poll
`docker info` until the engine returns + 5 min settle) or write the report
in two parts: preliminary now, final numbers after compaction. A report that
claims GB reclaimed before compaction finished is fiction.

## Phase 6 — report

Re-run the Phase 0 measurement (AFTER the compaction engine is back, if
Phase 5 ran). Write `logs/zcode-deep-cleanup.md`: before/after free GB per
drive, what each phase did or why skipped, anything unusual found. End with
one line: total GB reclaimed.
