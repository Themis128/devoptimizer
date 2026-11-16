"""Port of scripts/get-all-task-details.ps1 — dump triggers, actions
and key settings for every task under \\DevOptimizer\\ via
schtasks /query /v /fo LIST.
"""
import subprocess
import sys


def main():
    r = subprocess.run(["schtasks", "/query", "/fo", "LIST", "/v"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("schtasks failed", file=sys.stderr)
        return 1
    # LIST output: blocks separated by blank lines, first field TaskName
    block, found = [], False
    for line in r.stdout.splitlines() + [""]:
        if line.strip():
            block.append(line)
        else:
            if block and any("TaskName:" in l
                             and "\\DevOptimizer\\" in l
                             for l in block):
                found = True
                print("\n".join(block))
                print()
            block = []
    if not found:
        print("No tasks under \\DevOptimizer\\")
    return 0


if __name__ == "__main__":
    sys.exit(main())
