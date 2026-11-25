# Artifact + compose-health sweep

Two silent-corruption classes from the November incidents that no watchdog
covers today. Weekly, or after any Docker restart wave. Read-only detection +
report; repairs are spelled out but small.

## Lane 1 — empty-directory artifact detection

Docker auto-creates missing bind-mount sources as empty DIRECTORIES. When a
config file's path becomes such an artifact, every recreate re-poisons: the
mount materializes empty inside the container and the service crash-loops.
Hit 2026-11-25 on the Windows checkout (`docker-compose.yml` itself became an
empty dir).

Detection — in `C:\Users\tbaltzakis\cu130-slim` (the runtime checkout), look
for directories where files should be:

```powershell
$composeDir = 'C:\Users\tbaltzakis\cu130-slim\deploy\socialauto-standalone'
Get-ChildItem $composeDir -Recurse -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.PSIsContainer -and $_.Name -match '\.(yml|yaml|json|env|conf|sh|py)$' } |
  Select-Object FullName
```

Any hit is a file-that-became-a-directory artifact. Also scan bind-mount
sources listed in the compose file that are directories with 0 entries where
the git checkout has content.

Repair per artifact (exact sequence — skipping steps re-creates the artifact):
1. Note the container using it is stopped/dead.
2. Delete the artifact directory (PowerShell `Remove-Item -Recurse -Force`).
3. Restore the real file: the canonical source is the git checkout itself —
   `git -C C:\Users\tbaltzakis\cu130-slim checkout -- <path>` when tracked,
   or copy from the WSL mirror via `wsl.exe cat <src>` piped into the Windows
   path (direct cp through `/mnt/c` can hit permission issues on artifact
   dirs — the pipe avoids it).
4. Only then recreate the container.

## Lane 2 — compose project health

The 2026-11-22 class (hit twice): a root-dir `compose up` or a race creates
hash-prefixed duplicate containers (`3fa735747ada_social-api`) that
name-conflict the real fleet and abort converges.

Detection:

```bash
docker ps -a --format '{{.Names}}' | grep -E '^[0-9a-f]{12}_' 
docker ps -a --format '{{.Names}} {{.Status}}' | grep -iE 'created$'
```

- Hash-prefixed names = orphan duplicates. Verify the non-prefixed twin
  exists, then `docker rm` the orphan.
- Containers in `Created` state (never started) after a converge = aborted
  converge leftovers; `docker rm` them, then re-converge from the correct
  project directory.

Verification — the fleet should converge cleanly:

```powershell
cd C:\Users\tbaltzakis\cu130-slim\deploy\socialauto-standalone
docker compose ps --format '{{.Name}} {{.State}}' | Measure-Object -Line
```

Compose operations run from the WINDOWS side on this host — WSL-side compose
resolves `/mnt/c` bind paths as distro-internal and hits the fsbridge even
when targeting C: files.

## Report

Write `logs/zcode-artifact-compose-sweep.md`: artifacts found + repaired,
orphans removed, final converge state. If artifacts reappear in the SAME
paths week over week, escalate — that means an active process is recreating
them and the source must be found, not just the artifact swept.
