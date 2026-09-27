# Blueprint: DMR Review Leftovers — Fixes + Verification

**Date:** 2026-09-26
**Status:** approved by user request ("can you address any leftovers and test the above?")
**Source:** DMR implementation review findings F1–F5 + new live-verified facts

## New facts established by live probing (2026-09-26 evening)

- Runtime configs ARE canonical (`configure show`), but the runner's config store is
  **lost on every model-runner restart** and the watchdog needs up to ~60–90 s to
  re-apply → during that window loads run bare (4B at ctx 262144 → 138× "failed to
  fit params", 21× "context canceled" today, across 2–3 restart windows).
- Ollama-compatible API is live on the runner: `/api/ps` (loaded models),
  `/api/tags`, `/api/chat` honors `keep_alive: 0` (verified: smollm3 loaded →
  served → unloaded; ps empty after). `/inference/_configure|ps|unload|status` → 404.
- Explicit `docker-model configure` push (rc=0) restores flags on the next load
  (verified: args carried `--ctx-size 4096 --reasoning-budget 0`, ps showed UNTIL +4m).
- social-api container has python but **no nvidia-smi** and **no docker CLI** →
  VRAM guards + CLI fallbacks are dormant in containers (documented gap).

## Tasks

### Task 1: dmr.py — F1 key fix, F2 endpoint honesty, unload rewire, warmup cleanup

**Dependencies:** None

**Files:**
- Modify: `\\wsl$\Ubuntu-26.04\home\tbaltzakis\cu130-slim\social-automation\backend\app\services\dmr.py`

**Acceptance Criteria:**
- [ ] F1: warmup vision branch reads the real key (`vram.get("free", 0)`)
- [ ] F2a: `configure_keep_alive` logs a WARNING (once per model) when the endpoint
      returns 404, instead of silent debug; function still returns cleanly
- [ ] F2b: `_unload_idle_models` tries `/inference/unload` first, then falls back to
      `/api/ps` + per-model Ollama `/api/chat` with `keep_alive: 0`; both paths
      wrapped, no exception escapes
- [ ] warmup_models no longer calls `configure_keep_alive` (dead endpoint + would
      fight the watchdog's 30m 4B pin if the endpoint ever returns); comment points
      at watchdog ownership
- [ ] `python -m py_compile` passes; module imports cleanly inside social-api container

**Step 1:** Apply the four edits
**Step 2:** py_compile + container import + targeted function tests (Task 3)

### Task 2: dmr-watchdog — tighten the restart-window race (F4)

**Dependencies:** None

**Files:**
- Modify: `\\wsl$\Ubuntu-26.04\home\tbaltzakis\cu130-slim\docker-compose.yml` (dmr-watchdog command block: sleep 60 → 10)

**Acceptance Criteria:**
- [ ] Watchdog polls every 10 s (was 60 s) so post-restart bare-config windows shrink
      from ~60–90 s to ≤10–15 s
- [ ] `docker compose config` parses; `docker compose up -d dmr-watchdog` recreates it;
      logs show the 10 s cadence and an apply after runner StartedAt change

**Step 1:** Edit the compose sleep + comment
**Step 2:** Recreate watchdog, observe 2–3 poll cycles in logs

### Task 3: Verification

**Dependencies:** Task 1, Task 2

**Files:**
- Modify: `\\wsl$\Ubuntu-26.04\home\tbaltzakis\cu130-slim\docs\dmr-architecture.md` (doc drift: endpoints + dormancy + race notes)

**Acceptance Criteria:**
- [ ] Container-level function tests pass inside social-api: `_check_dmr_health()` True;
      `_get_vram_info()` returns None gracefully; `_has_vram_for_model()` True;
      `_unload_idle_models()` runs and actually empties `/api/ps` after a load;
      `configure_keep_alive()` returns without raising and logs the 404 warning
- [ ] Real end-to-end inference through the client: `call_dmr_chat("hi")` routes to the
      tiny model and returns non-empty text
- [ ] Watchdog recreated on 10 s cadence; canonical configs still in effect
      (`configure show`) after watchdog restart
- [ ] Doc updated: /inference/* 404 on current build, /api/ps + /api/tags live,
      VRAM-guard dormancy in containers, restart-race + watchdog tick change,
      free_mb fix
- [ ] Stack health: 36 containers running, 0 unhealthy; workers unaffected

**Step 1:** Run container-level function tests
**Step 2:** Run real inference via client
**Step 3:** Recreate watchdog; verify cadence + configs
**Step 4:** Update doc; final stack health check
