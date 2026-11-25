# wsl-disk-ops — WSL2 disk pressure relief on the Win11 host

Procedures for the recurring C: disk-pressure class on this workstation.
Root structural cause fixed 2026-11-26: the live WSL swap file (sparse VHDX,
up to `swap=` size) is created in `%TEMP%\<GUID>\swap.vhdx` on **C:** at every
VM boot. On a near-full system drive that is a time bomb — the VM inflates a
multi-GB file onto the fullest disk exactly when memory pressure is highest.

## The relocation (the 20GB fix)

`.wslconfig` `[wsl2]` supports `swapfile=<windows-path>` — an explicit location
for the swap VHDX. Procedure (`scripts/swap-relocate.ps1` automates it):

1. Pick a drive with headroom (D: on this host). `New-Item D:\wsl-sys`.
2. Backup `.wslconfig` (`.bak-YYYYMMDD-swapmove`), insert on the line after
   `swap=`:  `swapfile=D:\\wsl-sys\\swap.vhdx`
3. Full stop + relaunch — corrections only apply at VM boot:
   stop `Docker Desktop`/`com.docker.backend` processes → `wsl.exe --shutdown`
   → relaunch Docker Desktop.
4. Verify: the `%TEMP%\<GUID>\swap.vhdx` no longer reappears after boot;
   `D:\wsl-sys\swap.vhdx` exists (sparse); `wsl -d Ubuntu-24.04 -- free -m`
   shows swap.

**Never** delete `%TEMP%\*\swap.vhdx` while the VM runs — it is locked and the
delete fails anyway, but attempting it on a live VM can wedge the disk plane.
After a shutdown the orphaned GUID dirs are fair game (the swap-orphan reaper
task already does this).

## C: pressure tiers (what to clean, in order)

1. `%TEMP%\wsl-crashes\*`, `%TEMP%\DiagOutputDir\*` (Docker diagnostics),
   `%TEMP%\DockerDesktop\*` — always safe, regenerate.
2. Recycle Bin — irreversible, confirm scope first.
3. Docker Desktop log `com.docker.backend` rotates poorly — truncate, not delete.
4. Note: the elevated task (`admin-cleanup-elevated.ps1`) also deletes the
   oldest C: shadow copy and removes `Windows.old` when present — both
   irreversible; that's rollback data, so it's opt-in via the task, not the
   user-space tiers.
5. `docker builder prune` / `docker image prune` (never `-a` unattended,
   never volume prune) — shrinks usage inside docker_data.vhdx but NOT the
   host file; the vhdx shrink needs compaction.
6. Elevated: DISM component cleanup + WU cache via the registered
   `\DevOptimizer\DeepClean-Elevated` task.

## VHDX compaction gate

docker_data.vhdx / distro vhdx compaction requires the VM stopped — which kills
devin-server inside Ubuntu-24.04. Probe first (3x retry, vsock flakes):

```powershell
wsl.exe -d Ubuntu-24.04 -e bash -lc "pgrep -f 'devin ac[p]|server-mai[n]' | head -3"
```

If alive: report, do not compact. Async lane: `vhdx-compact-on-devin-exit.ps1`.
