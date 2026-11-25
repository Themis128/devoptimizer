# Nightly maintenance window

Sequenced nightly lane — replaces several blind tasks that fire independently
and sometimes collide. Run once per night when the user is idle.
Runtime target: under 30 min. Everything here is ordering + verification;
the work itself is done by existing scripts.

Multi-line PowerShell goes in a temp .ps1 file — never inline through bash
(quoting breaks).

## Gate — only run when safe

1. **No live agent session** — devin-server runs INSIDE Ubuntu-24.04, invisible
   to Windows `Get-Process`. Probe with retries:

   ```powershell
   $alive = $false
   foreach ($i in 1..3) {
     $out = & wsl.exe -d Ubuntu-24.04 -e bash -lc "pgrep -f 'devin acp|server-mai[n]' | head -3" 2>$null
     if ($out) { $alive = $true; break }
     Start-Sleep 2
   }
   ```

   If alive: STOP. Tonight is not the night.
2. **No deploy lock** — the cu130-slim deploy lock is `.deploy.lock` at the
   project root of the running checkout (`C:\Users\tbaltzakis\cu130-slim\.deploy.lock`),
   freshness window 1 hour (not 15 min). If the file exists and is younger
   than 60 minutes, a deploy is mid-flight — STOP.
3. **Docker engine answers**: `docker info` must succeed. If it doesn't,
   tonight's lane is the startup sentinel instead — run
   `zcode/docker-startup-sentinel.md`.

## Sequence (order matters — do not reorder)

After EACH step that can restart Docker or flap the engine, re-verify
`docker info` before the next docker-touching step. The memory-pressure
watchdog can restart Docker at 95% swap usage — never assume the engine
survived a step.

**1. Memory pressure relief first:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-wsl-memory-pressure.ps1
```

**2. DMR eviction check** (host RAM free < 2GB means the model runner holds
too much):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dmr-ram-guard.ps1
```

**3. Swap-orphan reaper:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cleanup-wsl-swap-orphans.ps1
```

**4. C: free-space check** — the 2026-11-11 crisis class (C: hit 0.7GB free,
crashed Docker, fed the flap loop). If under 15GB free, escalate the report
to warning and note it prominently; under 8GB skip the rest of the lane —
disk relief is the only job tonight.

**5. Docker hygiene — light tier, with the sleeping-container carve-out:**

```bash
docker builder prune -af
docker image prune -f
```

Do NOT run `daily-full-cleanup.ps1` here — its container prune deletes
intentionally sleeping sidecars (idle-sleep is a feature of the stack, not
litter; deleted containers must be recreated, not just started).
`docker container prune` is equally forbidden for the same reason.
NEVER volume prune, never `image prune -a` at night (the morning re-pull
storm hits production startup).

**6. Redis drift spot-check** (the 2026-11-25 incident — workers dead because
redis lost requirepass):

```bash
docker inspect social-redis --format '{{json .Config.Cmd}}' 2>/dev/null || docker inspect redis --format '{{json .Config.Cmd}}' 2>/dev/null
```

Check ONLY whether `--requirepass` is present in the output. Do NOT copy the
value into any report or log — the output contains the password itself; when
quoting the command, quote only presence/absence. If missing: do NOT recreate
at night — the heal_supervisor `redis_drift` watch owns that. A missing flag
in the morning means the watch is dead — that IS reportable.

## Verification + report

```bash
docker ps -q | wc -l
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9099/status
```

Write `logs/zcode-nightly-YYYYMMDD.md`: steps run, anything skipped + why,
GB reclaimed where measurable, final container count + watchers status.
Anomaly rule: if container count dropped by more than 3 during the window,
something you ran caused it — say so explicitly in the report.
