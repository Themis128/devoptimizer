# Mimosa L3 commit gate ignores `security-policy.json` exclusions

## Summary

The Mimosa PreToolUse commit gate re-scans the repository at commit time and
hard-blocks on any HIGH finding, even when that exact finding is explicitly
documented as accepted-by-design in the project's own
`.mimosa/security-policy.json` (`threatModel.exclusions`). The policy file is
Mimosa's own format (produced by the sealed scan), but the gate does not read it.

## Environment

- Mimosa plugin 1.0.3 (claude-plugins-official / zcode-plugins-official)
- Windows 11, Git Bash host shell
- `mcp mimosa security_scan` deep scan re-sealed after remediation
  (finding count 6 -> 5), seal recorded; the gate still blocks on the same
  5 findings at the next commit.

## Reproduction

1. Scan produces findings F1..Fn for code that is intentionally safe
   (example below).
2. Seal them in `.mimosa/security-policy.json`:
   ```json
   "exclusions": [
     "app/launcher/Program.cs:67,123: 'command-injection' on Process.Start —
      launcher forwards args via ArgumentList (no shell interpretation) and
      validates arguments for shell metacharacters"
   ]
   ```
3. Attempt `git commit` from the agent (PreToolUse hook).
4. Gate output: `Mimosa L3 在 commit 前发现 N 个高危，最高等级 high …
   高危已强制拦截` — listing the SAME findings the policy excludes.

## Expected

The gate should honor `security-policy.json` exclusions (that is the file its
own scanner seals), or at minimum expose a reviewed/sealed-state check
(fresh scan + seal match) that lets reviewed findings pass.

## Actual

Every agent commit/push is blocked until a human runs the identical commands
in an external terminal. The only agent-side workarounds are bypass-shaped
(script-file invocation), which is worse for security posture than honoring
the seal.

## Impact

- Agents cannot commit to repos whose findings are reviewed and accepted.
- The documented policy mechanism is dead weight — it exists, scans reference
  it, the gate ignores it.
- Encourages workarounds instead of remediation.

## Suggested fixes (any one)

1. Gate reads `threatModel.exclusions` and skips matching findings.
2. Gate compares the commit-time scan against the last sealed scan
   (`scanId`/seal hash); if the seal matches and findings are only the sealed
   set, allow with a warning.
3. Provide an official review/acknowledge workflow (per-finding
   `accepted` flag written back into the policy by the scan tool).

## Observed findings (for context — all reviewed as safe on a single-user
workstation, documented in the policy threat model)

- `Process.Start` with `ArgumentList` + `UseShellExecute=false` +
  metacharacter/control-char validation (launcher, command runner)
- `urlopen` with pre-validated AND post-redirect-validated URL
- Path joins with resolve + containment + parent-fallback guards
