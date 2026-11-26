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
- Scheduled task `DeepClean-Elevated` (`\DevOptimizer\`, monthly 1st 04:00,
  Highest) runs `scripts/admin-cleanup-elevated.ps1 -SkipVhdx`: DISM
  component-store cleanup, WU download cache, Delivery Optimization cache,
  oldest shadow copy, Windows.old — WITHOUT touching Docker Desktop or WSL
  (section 6 skipped), so it is safe to fire any time via
  `schtasks /run /tn "\DevOptimizer\DeepClean-Elevated"`. Self-registers via
  the `WSL-Memory-Watchdog` piggyback (no UAC); the script transcripts to
  `logs\admin-cleanup-elevated.log`. The section-6 VHDX tier stays in the
  05:00 `Nightly-Vhdx-Compact` window.
- Scheduled task `Daily-Full-Cleanup` (`\DevOptimizer\`, daily 06:30 —
  after the 05:00 VHDX compaction window so Docker is back) runs
  `scripts/daily-full-cleanup.ps1`: swap-orphan reaper, safe cleanup,
  recycle bin, docker builder/container/image prune (volumes kept),
  E: shader cache. Register via `scripts/register-daily-cleanup-task.ps1
  [-Unregister]`. Log: `logs/daily-full-cleanup.log`.

## DMR RAM guard

- `scripts/dmr-ram-guard.ps1` + task `DevOptimizer-DMR-RAM-Guard` (every 5 min,
  conhost --headless). Evicts Docker Model Runner residents under host RAM
  pressure: <1.8GB free evicts non-pinned models, <1.0GB also evicts the
  pinned set (qwen3-4b-instruct, qwen3-embedding-0.6b — cold reload beats a
  stalled host). Thresholds sit ABOVE Host Guard 1007's ~1GB pri-5 line so
  eviction lands before the insistent ntfy alarm fires. Model loads come from
  real SocialAuto traffic so the load→crunch→evict loop is structural — this
  is the gentle tier below wsl-guardian's T2/T3 ladder (which only reacts to
  probe failures after the dive). Log: `logs/dmr-ram-guard.log`.

## VHDX compaction

- Canonical daily compactor: `\DevOptimizer\Nightly-Vhdx-Compact` (05:00,
  elevated) runs `logs\nightly-wsl-vhdx-compact.ps1` — forced window, NOT
  Devin-gated by design (devin-server respawns). Takes `Global\vhdx-compact`
  mutex shared with `devin-scripts\vhdx-compact.ps1` (the C-drive emergency
  compactor, task `\Vhdx-Compact` 04:00, space-gated MinFreeGB=20).
- `WSL-Vhdx-Compact` (Devin-gated daily 03:45 via
  `scripts/Invoke-VhdxCompaction.ps1`) is currently NOT registered — redundant
  with Nightly. Re-register only if needed via
  `scripts/Register-VhdxCompaction.ps1` (self-elevating, `-Remove` unregisters).
- `Get-VhdxTargets` covers `%LOCALAPPDATA%\wsl`, `C:\WSL` (Ubuntu-24.04's
  custom install location — ext4.vhdx lives there, ~103GB) and
  `docker_data.vhdx`. `logs\nightly-wsl-vhdx-compact.ps1` (the forced 05:00
  task script) was patched the same way 2026-11-13.
- `Vhdx-Compact-DevinExit` task (root `\`, every 5 min, limited rights) runs
  `scripts/vhdx-compact-on-devin-exit.ps1` — fires `\DevOptimizer\Nightly-Vhdx-Compact`
  once per day when Devin.exe AND devin-server are both gone (compaction
  needs `wsl --shutdown`, which kills this agent's session mid-work).
  Same gates guard the vsock-wedge heal, plus **idle escalation** (2026-11-14):
  if wedge evidence is pending, the user has been away ≥30 min
  (GetLastInputInfo), and devin-server is not alive, it heals (`wsl --shutdown`
  + DD relaunch) even while the Devin app stays open — the user never has to
  close Devin for the heal to land. When deferral happens it sends one ntfy
  notice/day (`logs\.vsock-heal-notified`) so the queued heal is visible.
  **Idle-recycle lane** (2026-11-15, PR #46): a third heal class for the
  fsbridge poison (hashed `\\wsl.localhost` mounts empty -> Exited(127)
  waves) which leaves the distro proxy ALIVE and produces no wedge-log
  evidence — the wedge heal never saw it. The script probes
  `cu130-slim/.devin/skills/wsl-fsbridge-ops/scripts/fsbridge_doctor.py
  status` each pass (skipped when a wedge heal is pending) and, when the
  bridge is poisoned + user idle ≥30min + no devin-server, runs
  `Invoke-IdleRecycle` (`wsl --shutdown` + DD relaunch, once/day stamp
  `logs\.idle-recycle-fired`). Post-heal, cu130-slim's
  `scripts/fsbridge-reconcile.sh` (called from social-stack-watchdog)
  auto-retires the volume-transplant overrides. Gate B alerts once/day if
  the bridge stays poisoned after the day's recycle.
  Register via `scripts/register-vhdx-devin-exit-task.ps1 [-Unregister]`.

- Quiesce safety (2026-11-19): the compactor disables every scheduled task
  whose action touches wsl.exe/docker/UNC-wsl for the shutdown window
  (they'd relaunch the utility VM and re-lock the VHDXs). The disabled
  list is persisted to `logs\.quiesced-probe-tasks` and re-enabled in
  `finally` AND at the start of the next run — a reboot mid-compaction
  used to orphan ~23 watchdogs Disabled forever (happened 00:29 reboot).
  Elevated tasks the agent can't re-enable are covered by the state file.

- Sparse-VHD unlock chain (2026-11-19/20, verified live): WSL/DD "sparse
  auto-reclaim" does NOT cash in on this host (fstrim inside docker-desktop
  unmaps ~888GB in-guest, `wsl --shutdown` returned ZERO host reclaim), and
  fsutil cannot clear the sparse flag (set-only). The compactor was patched:
  (0) pre-shutdown `fstrim -av` inside BOTH distros while they're up,
  (1) `Stop-Service com.docker.service` for the window — the DD Windows
  service was the hidden relauncher bringing the VM back mid-compaction
  (restarted in section 5), (2) unlock fallback in the compact loop: kill
  zombie vmmemWSL → `Restart-Service vmcompute` + `Restart-Service
  WslService` (orphaned VHDMP sections live in vmcompute after vmmemWSL
  dies; both vhdxs stayed locked after a bare vmmemWSL kill even idle),
  (3) `Optimize-VHD` attempted on sparse-flagged files — **it WORKS on this
  build** (old "must not be sparse" skip was stale): docker_data.vhdx
  186→133→120GB across two runs (80GB reclaimed). ext4.vhdx (Ubuntu) keeps
  skipping NOT for sparse reasons but because `\\wsl.localhost` UNC handles
  (Devin/VS Code) pin the file post-shutdown even through vmcompute/WslService
  restarts — it compacts in the first window where those apps are closed.
  Ubuntu's 122GB is real data (/home 86G→48G after the 2026-11-19/20 inner
  cleanup: ~20G caches+syslog+pnpm, ollama models 16.9G removed after
  verifying :11434 dead, staging 11.9G archived to
  `archive/wsl-staging-20261119/`; the "%TEMP% 19GB" that check-cleanup-status
  flags is the LIVE swap.vhdx, not junk). Deep-clean archive:
  `archive/housekeeping-20261119-deepclean/` (stray check-disks.ps1).
  Skill/tool for this: skill `devoptimizer-vhdx-compaction` (playbook +
  gotchas) and `scripts/diagnose-vhdx-locks.ps1` (read-only: sizes, sparse
  flags, lock holders via `tools/handle.exe`, last compaction log tail).

## Console-popup prevention (2026-11-13)

- All scheduled tasks must run headless: `conhost.exe --headless <cmd>` for
  ps1/bat/wsl, `pythonw.exe` for python scripts. `python.exe`/`py.exe`/`cmd.exe`
  actions flash a cmd window on every run.
- `scripts/_rewrap-headless-all.ps1` rewrites offending task actions
  automatically (piggybacked on `WSL-Memory-Watchdog` every 6h, throttled by
  `scripts/_rewrap-last-run.stamp`). Now also maps `python.exe`→`pythonw.exe`.
- Startup-folder launchers: `.bat` files flash a window at logon. Canonical
  copies in `scripts/startup/` are synced to `%USERPROFILE%\startup-hidden\`
  and exposed via hidden wscript `.vbs` launchers in the Startup folder by
  `scripts/install-startup-launchers.ps1` (idempotent).
  `start-chrome-debug.bat` is deliberately NOT installed — it binds :9222,
  which Lenovo Vantage WebView2 owns; debug lane is :9229 via cdp-launch.
- `scripts/ntfy-windows-bridge.py` (2026-11-15): read-only ntfy.cloudless.gr
  topic streams (cloudless-alerts/-ops, nextcloud-ops, devoptimizer-alerts)
  -> native Windows toasts via `windows_toasts`, pri>=4 as Alarm scenario.
  Runs under `pythonw.exe` via `scripts/startup/ntfy-bridge.bat` +
  `ntfy-bridge-hidden.vbs`; token at
  `%APPDATA%\devin\secrets\ntfy-phone-token`. Needs `pip install
  windows-toasts` (user site). Logs to `logs/ntfy-bridge.log`.
- Disabled autostart entries (2026-11-13): Teams (`Run` value removed +
  `TeamsTfwStartupTask` State=1), LinkedIn UWP (`LinkedInAppStartUpId`
  State=1), stale EPSDNMON/Chrome/Edge auto-launch values removed. UWP
  StartupTask state lives under
  `HKCU:\...\AppModel\SystemAppData\<PackageFamilyName>\<TaskId>` State
  (2=Enabled, 1=DisabledByUser). Teams + LinkedIn UWP packages were fully
  uninstalled 2026-11-13 evening (`Remove-AppxPackage` works even though
  `Get-AppxPackage` is ACL-blocked on this host; package full names can be
  read from `HKCU:\...\AppModel\Repository\Packages`).

## Docker Desktop bounce fallout (2026-11-13)

- Every docker-desktop distro restart empties
  `/mnt/wsl/docker-desktop/cli-tools/*` in the VM namespace while the same
  path inside Ubuntu-24.04 is a per-distro iso9660 mount that repopulates
  lazily. Compose services bind-mounting
  `/mnt/wsl/docker-desktop/cli-tools/usr/bin/docker` (e.g. `stack-watchers`)
  then materialize the source as an EMPTY DIRECTORY -> `exec: is a
  directory: permission denied` spam in `heal_supervisor` logs.
  Fix: `docker compose up -d --force-recreate <svc>` INSIDE Ubuntu-24.04,
  but only AFTER Ubuntu has re-mounted the cli-tools iso (check
  `mount | grep cli-tools` — recreating too early re-caches the empty dir).
  Windows-side `docker compose` fails on these mounts
  (`invalid cross distro token`) - must run inside WSL.
- `Exited` on sidecar containers is often idle-sleep via stack-ops, not a
  crash — verify with `scripts/stackctl.py status` before restarting.

## Upstream escalation notes (researched 2026-11-11)

- `DevOptimizer-WSL-Repair` also runs `wsl --update --web-download` weekly
  (stamp `logs/.wsl-update-stamp`) — most vsock `WSAETIMEDOUT` and
  `wsl-bootstrap` failures are fixed upstream (docker/for-win#14841,
  microsoft/WSL#42006).
- If the distro hangs with high `vmmemWSL` CPU and vsock timeouts persist
  after updates, try `virtioFS=false` under `[wsl2]` in `~/.wslconfig`
  (Windows drive shares fall back to 9p — slower `/mnt/c`, diagnostic only).
- If Docker engine stays unreachable after the repair task's DD restart,
  `repair-wsl-docker-integration.ps1` now runs the docker/for-win#13426
  reset itself (once/day, only when the wsl exec channel still answers —
  a dead channel means the wedge class, which the exit-gate heal owns):
  stop DD → clear `IntegratedWslDistros` + `EnableIntegrationWithDefaultWslDistro`
  in `settings-store.json` → start DD → verify engine → re-add the distro.
  The old "Apply & restart" GUI step is obsolete — settings edits while DD
  is stopped are honored on next start (verified live 2026-11-13/14).
- `netsh winsock reset` is near no-op on Win11 (LSPs deprecated since
  Win8) AND wants a reboot — superseded by `scripts/network-soft-reset.ps1`
  (flushdns + ARP clear + physical adapter restart, no reboot). Fires
  automatically via the on-demand `\DevOptimizer\Net-Soft-Reset` task when
  wedge evidence survives today's `wsl --shutdown` heal (heal-resistant
  tier, once/day). If the wedge still persists after that, the remaining
  fix is a real reboot — still manual.
- Zombie CDP tabs on :9229 (listed in `/json/list`, ws dead on recv) are
  handled by `idika-watch/engine.py` `_close_target` — same pattern applies
  to any CDP watcher.

## Registry pins

`config/hub-registry.json` is generated — never hand-edit. After adding/removing
scripts run `Discover-Scripts.ps1` then `Build-Registry.ps1 -Validate -Force`,
then sync the count pins in `.github/workflows/ci.yml` and
`app/DevOptimizer.App.Tests/RegistryServiceTests.cs` (Live_Registry test pins
total + per-category + `Search("cleanup")` count).

## Phone tailnet watch (2026-11-14)

- Two layers keep `galaxy-s22` (100.84.31.85) on the tailnet:
  - **Layer 1, omv**: `~/tailnet-watch/tailnet-phone-watch.py` via cron `*/2` —
    pings phone internet over adb, exit-node failover, relaunches
    `com.tailscale.ipn` when its process dies, mDNS/stale-endpoint recovery.
    Source repo: `D:\tailnet-watch` (github.com/Themis128/tailnet-watch).
  - **Layer 2, this host**: `\DevOptimizer\Phone-Tailnet-Watch` (10 min,
    LIMITED rights, `conhost --headless`) runs
    `scripts/phone-tailnet-watch.ps1` — covers endpoints omv can't see
    (USB serial `RFCTA0AEKZP`, current-DHCP LAN, tailnet :5555). Exits
    silently when the peer is online; relaunches the app + re-pins
    `always_on_vpn_app` when `pidof` is empty; 30-min cooldown stamp
    `logs/.phone-ts-lastfix`; ntfy alert on remediation or when no adb
    endpoint answers. Log: `logs/phone-tailnet-watch.log`.
- Gotchas: peer `HostName` is `Galaxy S22+` (match `-match 'galaxy|s22'`,
    not `-eq`); `tailscale status --json` returns `Peer:null` while
    tailscaled restarts — treat as transient, not offline; `adb devices`
    can hang on a dead adb server — `Get-AdbDevices` wraps it in a 20s
    job timeout; Powershell vars are case-insensitive (`$Peer`/`$peer`
    collide).
- Android side: `settings put global always_on_vpn_app com.tailscale.ipn`
  is set — the OS restarts the tunnel on process kill without any
  watcher.
  - **Layer 3, on-phone Termux watchdog (2026-11-20)**:
    `~/phone-watchdog.sh` in Termux on the phone, looped 60s by
    `~/.termux/boot/phone-watchdog-boot.sh` (Termux:Boot + wake-lock).
    Survives house outages, where Layers 1-2 die with the power. Checks
    internet (gstatic 204) + home nodes (TCP:22 to each tailnet IP via
    bash /dev/tcp; Termux has no ping) and drives the Tailscale app UI via
    self-adb (`localhost:5555` tcpip; `uiautomator dump` + `input tap`):
    net dead → exit node **None** (direct ISP/cellular — closes the
    documented house-outage blackhole gap; Tailscale has no native
    failover-on-node-death and the Android app has no Automatic option);
    net back + home back + last-set was None → restores **github-omv**.
    Only acts on failure/restore. Termux adb needs the libc++ upgrade
    first (`pkg install libc++ && pkg reinstall android-tools` — stock
    adb fails to link). Battery exemption (Unrestricted) still REQUIRED
    (user pending); wireless debugging must stay ON; verify loop restarts
    after phone reboots. Canonical: `D:\tailnet-watch\scripts\
    phone-watchdog-termux.sh`; log `~/phone-watchdog.log` on the phone.
    Skill/tool: skill `devoptimizer-phone-watchdog` (redeploy + MCP
    phone-driving + battle-test procedures) and
    `scripts/deploy-phone-watchdog.ps1` (push canonical → omv tailnet
    HTTP :8000 → prints the phone-side pull one-liner; `-StopServer`
    cleans up).

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
  validity, subscriber gauge). Probes publish at `Priority: 1` with human
  titles (`canary ok - <topic>`, `devopt token ok`) — stay in history but
  never beep (2026-11-17). Auto-remediation: rollout restart after 2
  consecutive external-health fails; all other failures → Telegram alert.
  Secrets in `~/ntfy-watchdog/secrets.env` (PHONE_TOKEN + DEVOPT_TOKEN).
  Log: `~/ntfy-watchdog/watchdog.log`.
- PWA/web-app persistence (2026-11-26): `enable_login: true` is set in the
  `ntfy-config` ConfigMap — subscriptions + settings live server-side in
  `accounts.db` on the PVC under the `pc` account (login once per client).
  Manifests mirrored in OMV repo `k3s/ntfy/`. Cleanup scripts are NOT a
  threat: `extended-cleanup.py` only prunes regenerable caches (CacheStorage,
  ScriptCache, Code/GPUCache) — IndexedDB, Local Storage, and Cookies are
  never touched. Do not add "protect IndexedDB" exclusions.
- Publisher convention (readable feed): Title = plain words for what
  happened + where (`Host Guard - RAM low`, `RAM guard - models evicted`);
  body = numbers; `Tags` = emoji shortcodes (`warning`→⚠️,
  `rotating_light`→🚨); Priority 1 = silent history, 3 = one beep,
  4/5 = act now (5 loops until dismissed when the app's "Keep alerting"
  toggle is on — that toggle is now OFF on the phone).
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
- **WSL-interop `powershell.exe` calls flash a console on the desktop too**
  (console subsystem allocates a visible conhost even for `-WindowStyle
  Hidden`/`Start-Process -WindowStyle Hidden` — the flash happens before the
  style applies). Every `powershell.exe -Command`/`-File` invoked from bash
  pops a window for the user. Route through the same helper instead:
  `wscript.exe //nologo "C:\Users\tbaltzakis\devin-scripts\run-hidden.vbs"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\path\script.ps1`
  — pass the command as separate args (the vbs re-quotes only args containing
  spaces; a single pre-quoted arg breaks exe parsing). Have the .ps1 write
  its own log file (sh.Run does no shell redirection); read results via
  `/mnt/c`. `conhost --headless` is NOT a substitute for output-capturing
  calls — it swallows child stdout.
- `devin-scripts\wsl-resume-watch.ps1` + task `WSL-Resume-Watch` (event:
  Power-Troubleshooter ID 1) probes WSL vsock after resume and only runs
  `wsl --shutdown` + distro recovery when actually wedged — never restarts a
  healthy stack. Log: `D:\DevOptimizer\logs\wsl-resume-watch.log`.
- `devin-scripts\windows-patch-check.ps1` + task `Windows-Patch-Check-Elevated`
  (monthly 1st 05:00): winget upgrade Docker.DockerDesktop + PSWindowsUpdate
  (no auto-reboot). The elevated variant is now registered automatically:
  the elevated `WSL-Memory-Watchdog` piggyback registers it in-process on
  first pass and removes the limited `Windows-Patch-Check` duplicate —
  no UAC prompt needed (done 2026-11-14).
