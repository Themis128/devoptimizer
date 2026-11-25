# Docker Desktop startup sentinel

Use when Docker Desktop won't start: error dialogs, panic messages, or the
engine never comes up. Replaces guesswork with the diagnosed failure classes
from the November incident history.

## Invocation rule — never inline PowerShell

Nested quoting through bash → powershell.exe breaks every time. For ANY
PowerShell of more than one line: write it to a temp `.ps1` file first, then
execute it:

```bash
cat > /tmp/step.ps1 <<'PS1'
# powershell content here, exactly as written
PS1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\...\tmp\step.ps1'
```

(git-bash `/tmp` maps inside the git install — prefer a real Windows path
like `C:\Users\tbaltzakis\AppData\Local\Temp\zcode-step1.ps1` written via the
file tools, or pipe stdin: `powershell.exe -NoProfile -Command -` reading the
script from stdin. Pick whichever works; never fight nested quotes inline.)

## Step 1 — capture the exact error

Ask the user for the dialog text if you don't have it. Match against the
known classes below. If NOTHING matches, stop and write findings to
`logs/zcode-dd-sentinel.md` — do not improvise fixes.

## Class A — "lingering processes detected" (docker-mcp.exe, docker-offload.exe)

Root cause: the `DockerMcpGateway` logon task starts docker-mcp independently;
if it exists when DD starts, the startup check blocks.

Fix — kill the stragglers, then relaunch:

```powershell
Get-Process | Where-Object {$_.Name -match 'docker-mcp|docker-offload'} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
```

NOTE: the install is PER-USER (`%LOCALAPPDATA%\Programs\DockerDesktop`), not
`C:\Program Files\Docker`. Verify the exe exists before launching.

Prevention is already in place: `docker-mcp-gateway.bat` has an engine
pre-gate (v7, 2026-11-25). If this class recurs, verify the bat wasn't
reverted: `C:\Users\tbaltzakis\devin-scripts\docker-mcp-gateway.bat` should
contain `WAIT_ENGINE`.

## Class B — settings panic: `overriding "IntegratedWslDistros": ... zero Value argument`

Root cause: `"IntegratedWslDistros": null` in settings-store.json — written
either by PowerShell 5.1 empty-array serialization (fixed in devoptimizer
PR #193) or by Docker Desktop itself regenerating the key when absent.

Fix — DD must be fully stopped first:

```powershell
Get-Process | Where-Object {$_.Name -match 'docker'} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 3
$p = "$env:APPDATA\Docker\settings-store.json"
Copy-Item $p "$p.bak-zcode" -Force
$s = Get-Content $p -Raw | ConvertFrom-Json
$s.IntegratedWslDistros = @('Ubuntu-24.04')
$s | ConvertTo-Json -Depth 20 | Set-Content $p -Encoding UTF8
```

Then relaunch as in Class A. The value must be the explicit array — deleting
the key is NOT sufficient (DD regenerates it as null on shutdown).

## Class C — engine up but containers/images invisible

The settings corruption can flip the engine off the containerd image store.
Nothing is lost — the store flag is wrong. `UseContainerdSnapshotter` in
settings-store.json must be `true`; fix it the same way as Class B and
restart DD.

## Verification (all classes)

Wait 90 seconds after relaunch, then:

```bash
docker info --format '{{.ServerVersion}}'
docker ps -q | wc -l
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9099/status
```

Success = version prints, container count > 40, watchers 200. Write the
outcome to `logs/zcode-dd-sentinel.md`. If verification fails after two
passes, STOP — escalate to the user with the log file path.
