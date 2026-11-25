# Nightly maintenance window

Sequenced nightly lane — replaces several blind tasks that fire independently
and sometimes collide. Run once per night when the user is idle.
Runtime target: under 30 min. Everything here is ordering + verification;
the work itself is done by existing scripts.

## Gate — only run when safe

1. No devin-server process:
   `powershell -NoProfile -Command "Get-Process devin-server -ErrorAction SilentlyContinue"`
   — if present, STOP. Tonight is not the night.
2. No deploy lock: check for the deploy-lock file used by cu130-slim's healers
   (`deploy/.deploy-lock` in the stack project). If fresh (under 15 min old),
   a deploy is mid-flight — STOP.
3. Docker engine answers: `docker info` must succeed. If it doesn't, tonight's
   lane is the startup sentinel instead — run `zcode/docker-startup-sentinel.md`.

## Sequence (order matters — do not reorder)

**1. Memory pressure relief first** (everything downstream goes faster):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-wsl-memory-pressure.ps1
```

**2. DMR eviction check** — if host RAM free < 2GB, the model runner is
holding too much:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dmr-ram-guard.ps1
```

**3. Swap-orphan reaper + temp cleanup:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cleanup-wsl-swap-orphans.ps1
```

**4. Daily cleanup suite:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/daily-full-cleanup.ps1
```

**5. Docker hygiene — light tier only at night:**

```bash
docker builder prune -af
docker image prune -f
```

NEVER volume prune, never `image prune -a` at night (the morning re-pull
storm would hit production startup).

**6. Redis drift spot-check** (the 2026-11-25 incident class):

```bash
docker inspect social-redis --format '{{.Config.Cmd}}' 2>/dev/null || docker inspect redis --format '{{.Config.Cmd}}' 2>/dev/null
```

Must contain `--requirepass`. If missing: do NOT recreate it yourself at
night — the heal_supervisor `redis_drift` watch owns that. Note it in the
report as a finding; if it's still missing in the morning it means the
watch is dead, which IS reportable.

## Verification + report

```bash
docker ps -q | wc -l
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9099/status
```

Write `logs/zcode-nightly.md` (overwrite nightly, keep 7 rotations by dating
the filename `zcode-nightly-YYYYMMDD.md`): steps run, anything skipped + why,
GB reclaimed where measurable, final container count + watchers status.
Anomaly rule: if container count dropped by more than 3 during the window,
something you ran caused it — say so explicitly in the report instead of
burying it.
