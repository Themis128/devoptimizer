# DevOptimizer — agent notes

## Shell path safety (root cause of past junk files)

Git Bash/MSYS eats backslashes in unquoted Windows paths: `cp D:\DevOptimizer\x .`
creates a literal file named `D:DevOptimizerx`. Always quote paths or use
forward slashes (`D:/DevOptimizer/...`) when invoking bash from PowerShell or
passing Windows paths through bash. The weekly housekeeping task quarantines
any recurrence (names containing `:` are invisible to Win32).

## Housekeeping

- `scripts/devoptimizer-housekeeping.ps1 [-DryRun] [-OlderThanDays N] [-PruneDocker]`
  Archives stale reports / NT-native junk names / tiny stubs into
  `archive/housekeeping-<ts>/`, runs `check-broken-refs.py`, logs to
  `logs/housekeeping.log`. `-PruneDocker` is opt-in and destructive
  (`docker image prune -a` + `builder prune -af`); the scheduled task never
  passes it.
- Scheduled task `DevOptimizer-Housekeeping` (root `\`, Sat 05:30) via
  `scripts/register-housekeeping-task.ps1 [-Unregister]`.
- Scheduled task `DevOptimizer-WSL-Repair` (every 30 min) runs
  `scripts/repair-wsl-docker-integration.ps1` — watchdog for the
  "WSL integration unexpectedly stopped" popup: checks distro reachability,
  `~` ownership + `~/.docker/run` creatability (auto `chown -R` via
  `wsl -u root` when broken), and `/var/run/docker.sock` + engine
  reachability (restarts Docker Desktop only if it's running and the
  engine is unreachable). Log: `logs/wsl-repair.log`.
  Register via `scripts/register-wsl-repair-task.ps1 [-Unregister]`.
- Scheduled task `DevOptimizer-Docker-Prune` (monthly 1st 04:30, via
  `schtasks.exe` — `New-ScheduledTaskTrigger` has no `-Monthly` and the CIM
  trigger fails `Register-ScheduledTask` type checks) runs housekeeping with
  `-PruneDocker`. Remove with `scripts/register-docker-prune-task.ps1
  -Unregister`.

## VHDX compaction

- `WSL-Vhdx-Compact` task (`\DevOptimizer\`, daily 03:45) runs
  `scripts/Invoke-VhdxCompaction.ps1` — Devin-gated, defers with exit 2 when
  Devin.exe/devin-server is active. Register via
  `scripts/Register-VhdxCompaction.ps1` (self-elevating, `-Remove` unregisters).

## Registry pins

`config/hub-registry.json` is generated — never hand-edit. After adding/removing
scripts run `Discover-Scripts.ps1` then `Build-Registry.ps1 -Validate -Force`,
then sync the count pins in `.github/workflows/ci.yml` and
`app/DevOptimizer.App.Tests/RegistryServiceTests.cs` (Live_Registry test pins
total + per-category + `Search("cleanup")` count).

## Pre-PR check

`scripts/git-pr-check.ps1 [-Json]` — origin/main HEAD, divergence, open PRs,
24h merges. Run before any push to avoid duplicating another agent's PR.

## WSL2 swap-orphan reaper + C: guard

- `scripts/cleanup-wsl-swap-orphans.ps1 [-MinAgeHours N] [-DryRun]` deletes
  orphaned `swap.vhdx` files in `%TEMP%\<GUID>\` left by crashed/terminated
  WSL VMs (each boot makes a fresh one sized by `.wslconfig swap=`). Safe:
  only files older than 2h, live VM's swap is locked so delete fails and it
  is skipped. Runs every 30 min piggybacked on `WSL-Memory-Watchdog`
  (check-wsl-memory-pressure.ps1), which also logs C: free GB each pass and
  writes event 1004 (Warning <15GB, Error <5GB) — C: hosts swap.vhdx +
  docker_data.vhdx (229GB), and a full C: crashes Docker Desktop and feeds
  the vsock flap loop (2026-11-11: 5 orphans = ~63GB, C: hit 0.7GB free).
- `C:\Users\tbaltzakis\wsl-restart-recover.bat` (task `WslRestartRecover`,
  nightly 23:59 `wsl --shutdown` bounce) — `timeout.exe` fails under
  `conhost --headless`, so it sleeps via `ping -n` and retries the distro
  restart 3x.
- **VHDX compaction** lives in `scripts/admin-cleanup-elevated.ps1` [6]:
  compacts `docker_data.vhdx` (~230GB allocated vs ~90GB used) by
  terminating only the docker-desktop distro + `Optimize-VHD -Mode Full`;
  `-ShutdownWsl` additionally compacts Ubuntu `ext4.vhdx` after a full
  `wsl --shutdown`. All three disks get `wsl --manage --set-sparse true`.
  `check-drive-space.py` fires `AdminCleanupTask` automatically at ≥95%
  drive usage, so the whole chain is unattended.

## Broken refs

`scripts/check-broken-refs.py` validates BAT→PS1 and registry paths; also runs
as housekeeping step [4]. Dead launchers get archived to
`archive/dead-launchers-*/`, not deleted.
