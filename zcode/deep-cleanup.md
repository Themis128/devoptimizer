# Deep cleanup (Windows 11 workstation)

Full deep-cleanup pass. Run monthly or when C: drops below 25GB free.
Estimated runtime: 20-60 min. Safe to run while the user works, EXCEPT the
final compaction step — see the gate there.

## Phase 0 — baseline

Record starting state; you'll compare at the end.

```powershell
powershell -NoProfile -Command "Get-PSDrive C,D,E | Select-Object Name,@{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}} | Format-Table"
```

Write the numbers into `logs/zcode-deep-cleanup.md` with a timestamp.

## Phase 1 — dry-run audit first

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/devoptimizer-housekeeping.ps1 -DryRun
```

Read the output. If it plans to archive anything outside `archive/housekeeping-*`
paths or anything you don't recognize, STOP and report instead of proceeding.

## Phase 2 — user-space cleanup (no admin needed)

Run each, in order. If one errors, log it and continue to the next.

```powershell
# housekeeping archival (real run)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/devoptimizer-housekeeping.ps1

# WSL swap orphans (safe: live VM swap is locked, can't be deleted)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cleanup-wsl-swap-orphans.ps1

# daily cleanup suite: recycle bin, docker builder/container/image prune, shader cache
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/daily-full-cleanup.ps1
```

## Phase 3 — elevated cleanup via the existing task

Do NOT reimplement admin cleanup. Fire the registered task — it transcripts
to `logs\admin-cleanup-elevated.log`:

```powershell
schtasks /run /tn "\DevOptimizer\DeepClean-Elevated"
```

Wait 5 minutes, then read the tail of `logs\admin-cleanup-elevated.log` and
confirm it reached the end of its sections. If the task is missing or errors,
report that — do not improvise admin cleanup yourself.

## Phase 4 — docker prune decision (judgment required)

Check docker state first:

```bash
docker ps -q | wc -l
docker images -q | wc -l
docker system df
```

Rules:
- If containers are running fine and C: free is now above 30GB: run only
  `docker builder prune -af` and `docker image prune -f` (dangling only).
- If C: free is still below 20GB: you may run `docker image prune -a -f`
  (removes unused images — they re-pull on demand, costs time not data).
- NEVER `docker volume prune` — volumes carry production data (postgres,
  redis, nextcloud assets). This is a hard stop.

## Phase 5 — VHDX compaction gate

Compaction requires `wsl --shutdown`, which kills every WSL process including
any active Devin/agent session. Before this phase:

```powershell
powershell -NoProfile -Command "Get-Process | Where-Object {$_.Name -match 'devin'} | Select-Object Name,Id"
```

- If ANY devin/devin-server process exists: SKIP this phase entirely and note
  it in the report. The `Vhdx-Compact-DevinExit` task will pick it up.
- If the coast is clear, fire the existing task:
  `schtasks /run /tn "\DevOptimizer\Nightly-Vhdx-Compact"` — do not run
  compaction inline; the task sequencing handles the restart ordering.

## Phase 6 — report

Re-run the Phase 0 disk measurement. Write `logs/zcode-deep-cleanup.md`:

- before/after free GB per drive
- what each phase did or why it was skipped
- anything unusual found (large unexpected directories, unknown junk)

End with one line: total GB reclaimed.
