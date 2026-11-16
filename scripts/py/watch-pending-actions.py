"""Watch pending actions (Python port of watch-pending-actions.ps1).

Read-only status board: elevated-task fix state, vmmemWSL zombie,
docker_data.vhdx size, git cleanliness, next task runs. --json emits the
collected state.
"""

import argparse
import asyncio
import json
import subprocess
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: monitoring, scheduled-task, vhdx, git

TASKS = ["Devin-Daily-Maintenance", "Devin-Weekly-Restart", "WSL-Memory-Watchdog"]
VHDX = r"C:\Users\tbaltzakis\AppData\Local\Docker\wsl\disk\docker_data.vhdx"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    names = ",".join(f"'{t}'" for t in TASKS)
    ps = (
        "$out = [ordered]@{}; "
        "$out.tasks = @(); "
        f"foreach ($name in @({names})) {{ "
        "  $t = Get-ScheduledTask -TaskPath '\\DevOptimizer\\' -TaskName $name "
        "    -ErrorAction SilentlyContinue; "
        "  if ($t) { "
        "    $a = $t.Actions[0].Arguments; "
        "    $out.tasks += [pscustomobject]@{ Name=$name; "
        "      Hidden=($a -match 'WindowStyle Hidden'); "
        "      Headless=($a -match '--headless|conhost') } "
        "  } "
        "}; "
        "$v = Get-Process vmmemWSL -ErrorAction SilentlyContinue; "
        "$out.vmmemWSL = if ($v) { "
        "  @{ pid=$v.Id; wsGB=[math]::Round($v.WorkingSet/1GB,1) } } "
        "else { $null }; "
        f"$vhdx = Get-Item '{VHDX}' -ErrorAction SilentlyContinue; "
        "$out.dockerVhdxGB = if ($vhdx) { "
        "  [math]::Round($vhdx.Length/1GB,1) } else { $null }; "
        "$out.nextRuns = @(Get-ScheduledTask -TaskPath '\\DevOptimizer\\' | "
        "  ForEach-Object { $i = $_ | Get-ScheduledTaskInfo; "
        "    @{ task=$_.TaskName; next=($i.NextRunTime.ToString('s')) } } | "
        "  Sort-Object next); "
        "$out | ConvertTo-Json -Compress -Depth 4"
    )

    result = asyncio.run(run_ps_command(ps))
    if result.returncode != 0:
        print(result.stderr.strip() or "status collection failed", file=sys.stderr)
        sys.exit(result.returncode)

    state = json.loads(result.stdout.strip())

    git = subprocess.run(
        ["git", "status", "--porcelain"], capture_output=True, text=True,
        cwd=_REPO_ROOT).stdout.strip()
    state["gitClean"] = not git

    if args.json:
        print(json.dumps(state, indent=2))
        return

    all_fixed = True
    print("=== PENDING ACTIONS WATCH ===")
    print("\n1. TASKS NEEDING ELEVATED FIX:")
    for t in state["tasks"]:
        ok = t["Hidden"] and t["Headless"]
        all_fixed &= ok
        print(f"   {'FIXED' if ok else 'PENDING'}  {t['Name']}")
    print("\n2. REBOOT STATUS:")
    if state["vmmemWSL"]:
        v = state["vmmemWSL"]
        print(f"   REBOOT NEEDED - vmmemWSL running (PID {v['pid']}, "
              f"WS {v['wsGB']} GB)")
    else:
        print("   REBOOT DONE - no vmmemWSL process")
    print("\n3. DOCKER VHDX SIZE:")
    if state["dockerVhdxGB"] is not None:
        print(f"   docker_data.vhdx: {state['dockerVhdxGB']} GB")
    print("\n4. GIT STATUS:")
    print("   CLEAN" if state["gitClean"] else f"   UNCOMMITTED CHANGES:\n{git}")
    print("\n5. NEXT TASK RUNS:")
    for r in state["nextRuns"]:
        print(f"   {r['task']}: {r['next']}")
    print()
    print("ALL PENDING ACTIONS COMPLETE" if (all_fixed and not state["vmmemWSL"])
          else "PENDING ACTIONS REMAIN")


if __name__ == "__main__":
    main()
