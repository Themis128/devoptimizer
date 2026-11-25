# ZCode maintenance playbooks

Agent-executable maintenance lanes for this Windows 11 workstation, designed to
run in ZCode with the workspace open at `D:\DevOptimizer`.

**Model pin**: `nvidia/nemotron-3-ultra-550b-a55b` — user directive, do not switch.

## Why these exist

The scheduled-task fleet (`AGENTS.md`) is fire-and-forget PowerShell: it follows
fixed rules and cannot diagnose. These playbooks are the judgment layer — an
agent reads logs, picks the right heal, verifies the outcome, and stops when
the situation is novel instead of guessing.

## Design rules for the pinned model

The pinned model is not a frontier agent model, so every playbook is:

1. **Single-purpose** — one failure class per file, never "maintain everything".
2. **Script-first** — the agent orchestrates existing scripts (`scripts/`,
   `scripts/py/`) instead of improvising shell. Improvised destructive commands
   are out of bounds.
3. **Verify-or-abort** — each lane ends with an explicit verification command
   and an abort condition. If verification fails or the state doesn't match any
   documented case, the agent stops and writes findings to `logs/zcode-<lane>.md`
   instead of escalating the fix ladder on its own.
4. **Dry-run first** — lanes that delete anything run their `-DryRun` pass first
   and only proceed when the output matches expectations.

## The lanes

| File | Lane | Trigger |
|---|---|---|
| `deep-cleanup.md` | Full-disk + docker + WSL deep cleanup | manual / monthly |
| `docker-startup-sentinel.md` | Docker Desktop startup failures (lingering processes, settings panics) | when DD won't start |
| `fsbridge-responder.md` | Container mass-exit-127 / fsbridge poison | when containers die in waves |
| `watchdog-audit.md` | Weekly audit of the scheduled-task fleet itself | weekly |
| `nightly-maintenance.md` | Sequenced nightly window (prune, reclaim, cleanup) | nightly, user idle |

## Wiring in ZCode

Paste or reference the playbook file as the task prompt, e.g.:

```
Execute zcode/deep-cleanup.md exactly as written.
```

Keep `Full access` on (the lanes shell out to PowerShell/wsl/docker) and
`Computer Use` off — everything here is terminal work.

## Hard boundaries (all lanes)

- Never touch `C:\Users\tbaltzakis\cu130-slim` or `/home/tbaltzakis/cu130-slim`
  git checkouts beyond `git status` reads.
- Never run `wsl --shutdown` while a Devin session is active on the box unless
  the playbook explicitly says to — check for `devin-server` processes first.
- Never edit `.env` files, never print secrets.
- Never disable or uninstall a scheduled task — report it instead.
- Deletion lanes stay inside the paths each playbook enumerates. Anything
  unexpected is reported, not removed.
