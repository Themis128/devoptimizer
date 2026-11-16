"""Port of scripts/get-task-details.ps1 — dump triggers, actions and
settings of the \\DevOptimizer\\Safe-Cleanup-Daily scheduled task.
Uses schtasks /query /v as the native interface.
"""
import subprocess
import sys


def main():
    r = subprocess.run(
        ["schtasks", "/query", "/tn", r"\DevOptimizer\Safe-Cleanup-Daily",
         "/v", "/fo", "LIST"],
        capture_output=True, text=True)
    if r.returncode != 0:
        print("Task not found", file=sys.stderr)
        return 1
    print(r.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
