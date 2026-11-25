# Fsbridge / mass-exit-127 responder

Use when many containers exit at once (waves of Exited 127/255), or
`docker start` fails with "not a directory" on docker-desktop-bind-mounts.
This is the WSL fsbridge poison class — the definitive diagnosis lives in
`cu130-slim/.devin/skills/wsl-fsbridge-ops/` — this playbook is the
Windows-side response sequence.

## Step 1 — confirm the class

```bash
docker ps -a --filter status=exited --format '{{.Names}} {{.Status}}' | head -20
```

If 5+ containers exited with code 127 within the same hour, it's the bridge.
Also probe:

```bash
wsl.exe -d Ubuntu-24.04 --exec python3 /home/tbaltzakis/cu130-slim/.devin/skills/wsl-fsbridge-ops/scripts/fsbridge_doctor.py status
```

If the probe doesn't exist or errors, rely on the exit-wave signal alone.

## Step 2 — check the heal gates (mandatory)

The durable heal is `wsl --shutdown` + Docker Desktop relaunch, which kills
everything in WSL. Before pulling that trigger:

```powershell
powershell -NoProfile -Command "Get-Process | Where-Object {$_.Name -match 'devin'} | Select-Object Name"
powershell -NoProfile -Command "(Get-Culture).DateTimeFormat; [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); $last=New-Object DevOptimizer.NoInput -ErrorAction SilentlyContinue"
```

Simple version of the gate:
- If any `devin-server` process is running: the `Vhdx-Compact-DevinExit` task
  owns this heal and will fire it when the session ends. Do NOT shutdown now.
  Write `logs/zcode-fsbridge.md` noting the deferred heal and STOP.
- If no Devin session is active AND the user is away (no console input in
  30+ min — when in doubt, ask the user or skip): proceed.

## Step 3 — the heal

```powershell
powershell -NoProfile -Command "
Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue | Stop-Process -Force
wsl.exe --shutdown
Start-Sleep 10
Start-Process \"\$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe\"
"
```

Wait 3-5 minutes. The engine boot plus container restart policy takes time.

## Step 4 — recreate casualties

Compose services with poisoned bind mounts don't self-heal — they need
force-recreate. Run inside WSL (Windows-side compose fails on these mounts
with "invalid cross distro token"):

```bash
wsl.exe -d Ubuntu-24.04 --exec bash -lc "
cd /home/tbaltzakis/cu130-slim/deploy/socialauto-standalone
docker compose ps -a --filter status=exited --format '{{.Names}}' | head
docker compose up -d
"
```

If specific containers still fail with "is a directory" or empty-file errors,
the mount source files themselves may have been replaced by empty directories
(the docker auto-create artifact class). That repair is documented in
`wsl-fsbridge-ops` SKILL.md — follow it exactly or stop and report.

## Step 5 — verify

```bash
docker ps -q | wc -l                                          # expect 45+
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8083/health   # 200
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9099/status   # 200
```

Also confirm virtiofs is still active (the 2026-11-25 root fix):

```bash
wsl.exe -d Ubuntu-24.04 --exec mount | grep 'on /mnt/c'
# must show: type virtiofs
```

If `/mnt/c` is NOT virtiofs, check `C:\Users\tbaltzakis\.wslconfig` —
`virtiofs=true` must be on its own line inside the `[wsl2]` section (strict
bool parse — no trailing comment, NOT `[experimental]`).

Write outcomes to `logs/zcode-fsbridge.md`. If containers still mass-exit
after one full heal pass, STOP and escalate — do not loop the heal.
