# Blueprint: DMR + Hub Leftovers — MCP endpoints, watchdog verify, discovery regex

**Date:** 2026-09-26 evening
**Status:** approved by user request ("address any leftovers")
**Context:** follow-up to the DMR review/fix session; leftovers identified during recon

## Leftovers being addressed

1. The `dmr` MCP server (used by Devin) has three tools wired to `/inference/*`
   endpoints that 404 on the current runner build: `dmr_ps`, `dmr_unload`, and the
   backends section of `dmr_status` (which also mislabels the *available* model list
   as "Loaded models"). CLI fallbacks make them functional on the host, but the API
   paths are dead and the status output is wrong.
2. `SKILL.md` documents the dead endpoints.
3. `dmr-watchdog` `apply_configs` swallows failures (`|| true`) and marks the runner
   applied even when a configure call failed — the config-loss race window has no
   retry if a push fails.
4. Hub `Discover-Scripts.ps1` skips every second `.PARAMETER` block (consuming `\.`
   in the regex), so registry entries miss parameters (e.g. `repair-devin` shows
   4 of 6 params).

## Tasks

### Task 1: dmr-mcp-server.py — rewire the three tools to live endpoints

**Dependencies:** None

**Files:**
- Modify: `\\wsl$\Ubuntu-26.04\home\tbaltzakis\cu130-slim\.devin\skills\docker-model-runner\scripts\dmr-mcp-server.py`

**Acceptance Criteria:**
- [ ] `dmr_ps` uses `/api/ps` (verified live) with the CLI fallback retained
- [ ] `dmr_unload` tries `/inference/unload`, then falls back to `/api/ps` +
      per-model `/api/chat` with `keep_alive: 0` (same mechanism verified in
      dmr.py), CLI fallback retained
- [ ] `dmr_status` reports "Available models" from `/engines/v1/models` and
      "Loaded models" from `/api/ps` (true semantics), no `/inference/status` call
- [ ] `python3 -m py_compile` passes; live tool invocation from the host returns
      real data for dmr_status, dmr_ps, dmr_unload

**Step 1:** Apply edits; **Step 2:** compile + live-invocation tests

### Task 2: SKILL.md endpoint table + watchdog verify-and-retry

**Dependencies:** None

**Files:**
- Modify: `\\wsl$\Ubuntu-26.04\home\tbaltzakis\cu130-slim\.devin\skills\docker-model-runner\SKILL.md`
- Modify: `\\wsl$\Ubuntu-26.04\home\tbaltzakis\cu130-slim\docker-compose.yml` (dmr-watchdog apply_configs)

**Acceptance Criteria:**
- [ ] SKILL.md endpoint table reflects live endpoints (adds /api/ps + keep_alive:0
      eviction; marks /inference/* absent on the current build)
- [ ] Watchdog apply_configs tracks per-call success; `last_started` is only set
      when ALL configure calls succeeded, so a failed push retries next tick
- [ ] Watchdog recreated; apply runs on startup; `configure show` still canonical

**Step 1:** Edits; **Step 2:** recreate watchdog, verify apply + configs

### Task 3: Discover-Scripts.ps1 .PARAMETER regex + registry rebuild

**Dependencies:** None

**Files:**
- Modify: `D:\DevOptimizer\Discover-Scripts.ps1`
- Modify: `D:\DevOptimizer\config\hub-registry.json` (via Build-Registry.ps1)

**Acceptance Criteria:**
- [ ] Regex uses a lookahead for the terminator (no consumption → no alternating skip)
- [ ] Rebuilt registry: still 350 commands; `repair-devin` parameters now include
      Commit and Confirm; `check-devinhealth` and `get-devindiagnostics` intact
- [ ] Spot-check another script's params (no regression, e.g. Repair-Devin.ps1's
      siblings or a known 2-param command)

**Step 1:** Edit regex; **Step 2:** rebuild; **Step 3:** verify via JSON parse

### Task 4: Final verification

**Dependencies:** Task 1, Task 2, Task 3

**Acceptance Criteria:**
- [ ] Live dmr_status/dmr_ps/dmr_unload invocations return correct, non-error output
- [ ] Stack: 36 containers running, 0 unhealthy; DMR inference 200
- [ ] No leftover temp files

**Step 1:** Run the verification batch
