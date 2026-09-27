# Blueprint: Get-DevinDiagnostics — skip empty stray session dirs

**Date:** 2026-09-27
**Requested by:** user ("do it") after diagnostics warned `renderer.log not found in newest session 20260927T104010` — that dir is a zero-file window-relaunch artifact; real logs live in `20260927T103919`.

## Spec

- Symptom: the renderer-log scan picks the newest `%APPDATA%\Devin\logs\<YYYYMMDDThhmmss>` dir unconditionally and warns when `window1\renderer.log` is absent. Stray dirs (created by a window relaunch, containing no log files) trigger a false warning.
- Fix: newest-first session selection skips session dirs that contain zero `*.log` files (recursive) and scans the first dir that has logs. A genuine (non-stray) session lacking `window1\renderer.log` still warns. All-empty and zero-dir cases each get a distinct warning. Report JSON gains an additive `logs.renderer.session` field (scanned dir name); strays skipped are surfaced as one `[ OK ]` line.
- Script stays strictly read-only; console + `-OutFile` JSON behavior otherwise unchanged.

### Task 1: Skip stray session dirs in renderer-log scan
**Dependencies:** None
**Files:**
- Modify: `scripts/devin/Get-DevinDiagnostics.ps1`
**Acceptance Criteria:**
- [x] **Step 1:** Session selection iterates newest-first, skips dirs containing zero `*.log` files recursively, and scans the first dir with logs; each skipped dir increments a stray counter reported as one `[ OK ] skipped N empty stray session dir(s)` line.
- [x] **Step 2:** Synthetic sandbox (APPDATA override): newest dir empty + prior dir holding a clean `window1\renderer.log` → no `renderer.log not found` warning, output shows the stray-skip line, `renderer.log clean`, and JSON `logs.renderer.session` equals the prior dir's name.
- [x] **Step 3:** Synthetic sandbox: newest dir contains a log file but no `window1\renderer.log` → `[WARN] renderer.log not found in newest session <name>` still fires.
- [x] **Step 4:** Synthetic sandbox: session dirs exist but all are empty → distinct `[WARN] all N ... empty (stray)`; zero session dirs → existing `[WARN] no Devin session log dirs` preserved.
- [x] **Step 5:** Against the real machine state (stray `20260927T104010` present), the script exits 0, emits no renderer.log warning, and `-OutFile` JSON parses with `logs.renderer.file` pointing inside `20260927T103919`.

### Task 2: Final verification
**Dependencies:** Task 1
**Files:**
**Acceptance Criteria:**
- [x] **Step 1:** Real run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\devin\Get-DevinDiagnostics.ps1` exits 0 with `=== DIAGNOSTICS COMPLETE - NO FINDINGS ===` and no renderer.log WARN.
- [x] **Step 2:** Real run with `-OutFile`: JSON parses (`ConvertFrom-Json`) and `logs.renderer.session` = `20260927T103919`.
- [x] **Step 3:** No other script sections changed (app/WSL/memory/bundle/commit/server-log scans byte-identical); no new parameters, so script-registry count is unaffected.
