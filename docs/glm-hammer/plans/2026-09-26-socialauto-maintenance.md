# Blueprint: Zero-Downtime SocialAuto Infrastructure Maintenance

**Date:** 2026-09-26 evening
**Status:** approved by user request ("automate some maintenance … but I don't want the platform to go down")

## Downtime constraint (binding)

Everything automated must be non-disruptive:
- No restarts of healthy containers, no `wsl --shutdown`, no vhdx compaction,
  no image updates/recreates (those are the only downtime-bearing ops and are
  explicitly excluded).
- Unhealthy-container restarts are opt-in (`-Remediate`) because an unhealthy
  container is already failing; default is report-only.
- Prunes are limited to: exited containers, dangling (untagged) images, and
  build cache older than 7 days (`--filter until=168h`). Never `-a` image prune
  (would delete the user's v2.417/418 rollback tags), never volume prune.

## Existing automation (do not duplicate)

- celery-beat: dmr_health every 5 min → Redis dmr:status; publishing queue 30 s.
- dmr-watchdog compose service: DMR API health + config re-apply (10 s tick).
- Docker healthchecks on 34/36 containers.

## Tasks

### Task 1: Maintain-SocialAuto.ps1

**Dependencies:** None

**Files:**
- Create: `D:\DevOptimizer\scripts\socialauto\Maintain-SocialAuto.ps1`

**Acceptance Criteria:**
- [ ] `<# .SYNOPSIS #>` help block + `# CATEGORY: maintenance` header
- [ ] Preflight: WSL reachable + docker engine responsive, else exit 1
- [ ] Safe housekeeping (default ON): prune exited containers, dangling images,
      build cache `--filter until=168h`; prints freed amounts (0 is fine)
- [ ] Unhealthy container report (name + status); `-Remediate` restarts them and
      re-checks; without the switch it is report-only
- [ ] DMR section: `/engines/v1/models` reachable, watchdog container status,
      loaded-models count via `/api/ps`
- [ ] Host memory: when free < `-MinHostFreeGB` (default 2), drops WSL page caches
      via `wsl -u root` (proven safe, zero downtime) and reports before/after
- [ ] Log-driver debt note: reports that all containers use unbounded json-file
      (fix = per-service logging opts at next recreate — downtime-bearing, manual)
- [ ] `-ReportOnly` skips all mutating actions; output logged to
      `D:\DevOptimizer\logs\socialauto-maintenance-<date>.log` when run by the
      scheduled task (script accepts `-LogDir`, default D:\DevOptimizer\logs)
- [ ] Exit 0 healthy / 1 engine unreachable / 2 unhealthy containers found
- [ ] `py`-equivalent: PowerShell parser reports 0 errors

**Step 1:** Write the script
**Step 2:** Parser check + live run + zero-downtime proof (36 running before/after)

### Task 2: Register-SocialAuto-Maintenance.ps1 + Hub registration

**Dependencies:** Task 1

**Files:**
- Create: `D:\DevOptimizer\scripts\socialauto\Register-SocialAuto-Maintenance.ps1`
- Modify: `D:\DevOptimizer\config\hub-registry.json` (via Build-Registry.ps1 -Force)

**Acceptance Criteria:**
- [ ] Scheduler script follows the Register-WSL-PreWarm.ps1 pattern
      (`\DevOptimizer\SocialAuto-Maintenance`, daily 04:00, user principal,
      30-min limit, IgnoreNew); `-Remove` unregisters
- [ ] Task registered and in Ready state; manual Start-ScheduledTask runs the
      maintenance script successfully
- [ ] Registry: 351 commands with `maintain-socialauto` present (category
      maintenance, description from SYNOPSIS)

**Step 1:** Write scheduler script; register task; verify Ready
**Step 2:** Trigger once via Start-ScheduledTask; verify log file written
**Step 3:** Build-Registry + JSON verification

### Task 3: Final verification

**Dependencies:** Task 1, Task 2

**Acceptance Criteria:**
- [ ] After a full maintenance run: 36 containers running, 0 unhealthy, 0 exited
      (zero-downtime proof), DMR inference 200
- [ ] Scheduled task last-run result 0
- [ ] Memory notes updated

**Step 1:** Run the batch and record results
