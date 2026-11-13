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

## Upstream escalation notes (researched 2026-11-11)

- `DevOptimizer-WSL-Repair` also runs `wsl --update --web-download` weekly
  (stamp `logs/.wsl-update-stamp`) — most vsock `WSAETIMEDOUT` and
  `wsl-bootstrap` failures are fixed upstream (docker/for-win#14841,
  microsoft/WSL#42006).
- If the distro hangs with high `vmmemWSL` CPU and vsock timeouts persist
  after updates, try `virtioFS=false` under `[wsl2]` in `~/.wslconfig`
  (Windows drive shares fall back to 9p — slower `/mnt/c`, diagnostic only).
- If Docker engine stays unreachable after the repair task's DD restart,
  the docker/for-win#13426 workaround is: stop DD → set
  `"integratedWslDistros": []` + `"enableIntegrationWithDefaultWslDistro": false`
  in `%APPDATA%\Docker\settings.json` → start DD → re-enable integration in
  Settings → Resources → WSL integration ("Apply & restart", wait for it to
  go gray). Manual GUI step — do not script blind.
- `netsh winsock reset` fixes some vsock/port-forwarding failures but
  requires a reboot — escalate to the user, never automate.
- Zombie CDP tabs on :9229 (listed in `/json/list`, ws dead on recv) are
  handled by `idika-watch/engine.py` `_close_target` — same pattern applies
  to any CDP watcher.

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

## ntfy alerting (ntfy.cloudless.gr)

- Server: k3s pod `ntfy` (ns `ntfy`) on OMV, auth-file deny-all. Manage via
  `sudo kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml -n ntfy exec deploy/ntfy -- ntfy <cmd>`
  with `NTFY_CONFIG_FILE=/etc/ntfy/server.yml`.
- Topics/users: `devoptimizer` (write-only `devoptimizer-alerts`), `phone`
  (rw cloudless-*, read-only devoptimizer-alerts), `cloudless-app`, `kuma`,
  `grafana-cloud-pub`. Publisher token: `%APPDATA%/devin/secrets/ntfy-devoptimizer-token`
  (read by `scripts/lib/Notify.ps1` + `wsl-guardian.ps1`).
- Read-back check: `GET /<topic>/json?poll=1&since=72h` with a user token.
- Server upgraded to `binwiederhier/ntfy:v2.37.2` (2026-11-13) with
  `--enable-metrics` (`/metrics` public: `ntfy_subscribers_total` gauge etc.).
  Go 1.26 ServeMux returns 307 (was 301) for `//topic` path-clean redirects —
  this FIXED ntfy-android app-side publishing on subscriptions whose stored
  base URL ends with `/` (upstream bug binwiederhier/ntfy-android#106). Old
  image rollback: `kubectl set image deploy/ntfy ntfy=binwiederhier/ntfy:v2.13.0`.
- Watchdog: `omv:~/ntfy-watchdog/ntfy-watchdog.sh` via cron `*/5` — probes
  internal NodePort `:30080` + external `ntfy.cloudless.gr` (health, `//`
  redirect regression, per-topic publish+read-back canary, devoptimizer token
  validity, subscriber gauge). Auto-remediation: rollout restart after 2
  consecutive external-health fails; all other failures → Telegram alert.
  Secrets in `~/ntfy-watchdog/secrets.env` (PHONE_TOKEN + DEVOPT_TOKEN).
  Log: `~/ntfy-watchdog/watchdog.log`.
- Monitoring: ServiceMonitor `monitoring/ntfy` + PrometheusRule
  `ntfy-health` (NtfyTargetDown/NtfyNoSubscribers/NtfyPublishFailures);
  Alertmanager routes `namespace="ntfy"` alerts to Telegram (patched
  alertmanager.yaml secret — re-apply patch if Helm overwrites).
  PVC backup: CronJob `ntfy/pvc-backup-ntfy` → R2 `pvc-backups/ntfy/daily/`.

## R2 credentials (rotated 2026-11-13)

- All R2 S3 access died ~15:30 UTC (every stored keypair → 401; the old
  R2 API token was revoked/rolled on the CF side). Replaced with account
  token `r2-s3-backups-2026-11` (id `7f1a21492bbbc15f594acd983d399065`,
  Workers R2 Storage Read+Write, all buckets) created via
  `POST /accounts/{id}/tokens`; S3 pair = token id + sha256(token value).
- Propagated to: omv `/root/.config/rclone/rclone.conf` (`r2`) +
  `~/.config/rclone/rclone.conf` (`r2ev`, needs `region = auto`, no `acl`)
  + `~/r2-s3-creds`; k8s secrets `pvc-backup-r2` (appflowy, espocrm, n8n,
  ntfy, postiz, uptime-kuma), `appflowy/appflowy-walg-r2`,
  `cloudless/cloudless-secrets` (CF_R2_*); `.env` keys `R2_*`, `CF_R2_*`,
  `AWS_*` (Windows + WSL copies); Infisical prod (same 6 keys).
- Containers carrying R2 env (social-api, social-api-green, 4 workers,
  celery-beat) were recreated via `docker compose up -d` under deploy
  lock — `docker restart` does NOT reload env.
- Recreate-name race: orphaned `<hash>_` `Created` containers block
  `compose up` — `docker rm -f` them and retry (wsl-docker-doctor skill).
- CF API can manage R2 objects directly:
  `GET/DELETE /accounts/{id}/r2/buckets/{bucket}/objects[/{key}]` —
  useful when S3 creds are dead (e.g. stray object cleanup).

## Hidden console launches (2026-11-12)

- `conhost.exe --headless <cmd>` is the established pattern for scheduled
  tasks (no console flash, stays in user session).
- `C:\Users\tbaltzakis\devin-scripts\run-hidden.vbs` is the generic helper for
  commands that still pop a window: task action = `wscript.exe //nologo
  "...\run-hidden.vbs" "<cmd> [args]>"` — waits for exit, propagates the real
  exit code so Task Scheduler's Last Run Result stays truthful.
- `devin-scripts\wsl-resume-watch.ps1` + task `WSL-Resume-Watch` (event:
  Power-Troubleshooter ID 1) probes WSL vsock after resume and only runs
  `wsl --shutdown` + distro recovery when actually wedged — never restarts a
  healthy stack. Log: `D:\DevOptimizer\logs\wsl-resume-watch.log`.
- `devin-scripts\windows-patch-check.ps1` + task `Windows-Patch-Check`
  (monthly 1st 05:00): winget upgrade Docker.DockerDesktop + PSWindowsUpdate
  (no auto-reboot). Registered Limited token — machine-scope installs need
  the elevated variant: run `devin-scripts\register-windows-patch-task.ps1`
  once (one UAC prompt) to swap in `Windows-Patch-Check-Elevated`.
