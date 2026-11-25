# Fsbridge / mass-exit-127 responder

Use when many containers exit at once (waves of Exited 127/255), or
`docker start` fails with "not a directory" on docker-desktop-bind-mounts.
This is the WSL fsbridge poison class — hit 2026-11-13, 11-22 (twice) and
11-25. The definitive diagnosis lives in cu130-slim's `wsl-fsbridge-ops`
skill; this playbook is the Windows-side response sequence.

Follow the same invocation rule as docker-startup-sentinel: multi-line
PowerShell goes in a temp .ps1 file, never inline through bash.

## Step 1 — confirm the class

```bash
docker ps -a --filter status=exited --format '{{.Names}} {{.Status}}' | head -20
```

If 5+ containers exited with code 127 within the same hour, it's the bridge.
Also probe (best-effort — wsl calls flake when the vsock plane is degraded):

```bash
wsl.exe -d Ubuntu-24.04 --exec python3 /home/tbaltzakis/cu130-slim/.devin/skills/wsl-fsbridge-ops/scripts/fsbridge_doctor.py status
```

## Step 2 — heal gates (mandatory, in order)

The durable heal is `wsl --shutdown` + Docker Desktop relaunch. It kills
EVERYTHING in WSL — including any live agent session. The gate is NOT
Windows-side processes: devin-server runs INSIDE Ubuntu-24.04 and is
invisible to `Get-Process`. Probe it the way
`scripts/vhdx-compact-on-devin-exit.ps1` does — retry 3x because wsl exec
flakes when the vsock plane is wedged:

```powershell
$alive = $false
foreach ($i in 1..3) {
  $out = & wsl.exe -d Ubuntu-24.04 -e bash -lc "pgrep -f 'devin acp|server-mai[n]' | head -3" 2>$null
  if ($out) { $alive = $true; break }
  Start-Sleep 2
}
Write-Output "devin-server-alive: $alive"
```

- If alive: DO NOT shut down. The `Vhdx-Compact-DevinExit` task owns the heal
  and fires it when the session ends or the user goes idle 30+ min. Note the
  deferred heal in `logs/zcode-fsbridge.md` and STOP.
- If not alive, check user idle time before proceeding (copy the DevOptIdle
  Add-Type block verbatim from `scripts/vhdx-compact-on-devin-exit.ps1` —
  it defines the LASTINPUTINFO probe correctly; do not invent your own type
  name). Under 30 min idle and interactive: ask the user or defer.

## Step 3 — the heal

```powershell
Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue | Stop-Process -Force
wsl.exe --shutdown
Start-Sleep 10
Start-Process "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
```

Wait 3-5 minutes for engine boot.

## Step 4 — cli-tools mount verification BEFORE any recreate

The 2026-11-13 fallout class: after a docker-desktop distro restart,
`/mnt/wsl/docker-desktop/cli-tools/*` materializes as EMPTY inside Ubuntu
until the per-distro iso9660 mount repopulates. Recreating too early caches
the empty dir as the mount source — "is a directory: permission denied" spam.

```bash
wsl.exe -d Ubuntu-24.04 --exec mount | grep cli-tools
```

Must show the iso mount. Retry for up to 5 minutes. Only then recreate.

## Step 5 — force-recreate ONLY the casualties

Plain `docker compose up -d` REUSES existing containers when config is
unchanged — the poisoned bind mount survives. But a blanket
`--force-recreate` also bounces healthy services for nothing. Scope to the
dead ones:

```powershell
cd C:\Users\tbaltzakis\cu130-slim\deploy\socialauto-standalone
docker compose ps -a --filter status=exited --format '{{.Service}}'
docker compose up -d --no-deps --force-recreate <svc1> <svc2>   # only the casualties
```

Three scoping rules:
- **`--no-deps` always** — otherwise a casualty with compose dependencies can
  drag a healthy dependency into the recreate with it.
- **Exited ≠ casualty**: idle-asleep sidecars also show as exited (the
  stack's idle-sleep is intentional, exits 137/143 or clean stops via
  stack-ops). Cross-check before recreating: `scripts/stackctl.py status`
  marks sleeping services; skip those — they wake on demand. Only recreate
  services whose exit is the failure wave (127/1, recent, clustered).
- **Running ≠ healthy**: a container can stay Up with a poisoned mount —
  `stack-watchers` is the known case (its supervisor loses the docker CLI).
  Check the watchers board (`curl http://127.0.0.1:9099/status`) and the
  supervisor log for `is a directory`/`permission denied` exec errors;
  include any such running-but-broken service in the recreate list.

**Which side runs compose depends on the mount source, not habit:**
- Services whose binds are C:-hosted project files (the socialauto fleet):
  compose from the WINDOWS side — WSL-side compose resolves `/mnt/c` paths
  as distro-internal and hits the poisoned bridge even for C: files.
- Services bind-mounting `/mnt/wsl/docker-desktop/cli-tools/*` (notably
  `stack-watchers`): Windows-side compose fails with `invalid cross distro
  token` — recreate these INSIDE Ubuntu-24.04, only AFTER the Step-4 iso
  verification passes (the repair watchdog does exactly this).
Never run a root-dir `compose up` in the repo root — it creates
hash-prefixed duplicate orphans that name-conflict the real fleet
(2026-11-22 incident, twice).

If specific containers still fail with empty-file errors, the mount SOURCE
files became empty-directory artifacts (docker auto-creates missing bind
sources as dirs). Delete the artifact, copy the real file back, then
recreate — documented in the wsl-fsbridge-ops SKILL.md.

## Step 6 — verify

```bash
docker ps -q | wc -l                                                            # expect 45+
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8083/health             # 200
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9099/status             # 200
wsl.exe -d Ubuntu-24.04 --exec mount | grep 'on /mnt/c'                         # must show virtiofs
```

If `/mnt/c` is NOT virtiofs, check `C:\Users\tbaltzakis\.wslconfig` —
`virtiofs=true` on its own line inside `[wsl2]` (strict bool parse — no
trailing comment, NOT `[experimental]`).

Write outcomes to `logs/zcode-fsbridge.md`. If containers still mass-exit
after ONE full heal pass, STOP and escalate — do not loop the heal.
