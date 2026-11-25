# Docker Desktop startup sentinel

Use when Docker Desktop won't start: error dialogs, panic messages, or the
engine never comes up. Replaces guesswork with the diagnosed failure classes.

## Step 1 — capture the exact error

Ask the user for the dialog text if you don't have it, or read recent logs:

```powershell
powershell -NoProfile -Command "Get-Content \"$env:APPDATA\Docker\log.txt\" -Tail 40"
```

Match against the known classes below. If NOTHING matches, stop and write
findings to `logs/zcode-dd-sentinel.md` — do not improvise fixes.

## Class A — "lingering processes detected" (docker-mcp.exe, docker-offload.exe)

Root cause: the `DockerMcpGateway` logon task starts docker-mcp independently;
if it exists when DD starts, the startup check blocks.

Fix:
```powershell
powershell -NoProfile -Command "Get-Process | Where-Object {$_.Name -match 'docker-mcp|docker-offload'} | Stop-Process -Force"
```
Then relaunch Docker Desktop:
```powershell
powershell -NoProfile -Command "Start-Process \"$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe\""
```
NOTE: the install is PER-USER (`%LOCALAPPDATA%\Programs\DockerDesktop`), not
`C:\Program Files\Docker`. Verify the path exists before launching.

Prevention is already in place: `docker-mcp-gateway.bat` has an engine pre-gate
(v7, 2026-11-25). If this class recurs, check that the bat wasn't reverted:
`C:\Users\tbaltzakis\devin-scripts\docker-mcp-gateway.bat` should contain
`WAIT_ENGINE`.

## Class B — settings panic: `overriding "IntegratedWslDistros": ... zero Value argument`

Root cause: `"IntegratedWslDistros": null` in settings-store.json — written
either by PowerShell 5.1 empty-array serialization (watchdog bug, fixed in
PR #193) or by Docker Desktop itself regenerating the key when absent.

Fix (DD must be fully stopped first):
```powershell
powershell -NoProfile -Command "
Get-Process | Where-Object {$_.Name -match 'docker'} | Stop-Process -Force
Start-Sleep 3
\$p = \"\$env:APPDATA\Docker\settings-store.json\"
Copy-Item \$p (\"\$p.bak-zcode\")
\$s = Get-Content \$p -Raw | ConvertFrom-Json
\$s.IntegratedWslDistros = @('Ubuntu-24.04')
\$s | ConvertTo-Json -Depth 20 | Set-Content \$p -Encoding UTF8
```
Then relaunch DD as in Class A. The value must be the explicit array —
deleting the key is NOT sufficient (DD regenerates it as null).

## Class C — engine up but containers/images invisible

The settings corruption can flip the engine off the containerd image store.
Nothing is lost — the store flag is wrong. Check:

```powershell
powershell -NoProfile -Command "(Get-Content \"$env:APPDATA\Docker\settings-store.json\" -Raw | ConvertFrom-Json).UseContainerdSnapshotter"
```
Must be `True`. If not, set it the same way as Class B and restart DD.

## Verification (all classes)

Wait 90 seconds after relaunch, then:

```bash
docker info --format '{{.ServerVersion}}'
docker ps -q | wc -l
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9099/status
```

Success = version prints, container count > 40, watchers return 200.
Write the outcome to `logs/zcode-dd-sentinel.md`. If verification fails after
two passes, STOP — escalate to the user with the log file path.
