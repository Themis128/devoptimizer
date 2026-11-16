"""Port of scripts/check-tasks-detailed.ps1 — list every task under
\\DevOptimizer\\ with trigger type, start boundary and repetition as a
table. Data comes from schtasks /query /fo CSV /v.
"""
import csv
import io
import subprocess
import sys


def main():
    r = subprocess.run(["schtasks", "/query", "/fo", "CSV", "/v"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("schtasks failed", file=sys.stderr)
        return 1
    rows = list(csv.reader(io.StringIO(r.stdout)))
    if not rows:
        return 0
    hdr = [h.strip().strip('"') for h in rows[0]]
    try:
        i_name = hdr.index("TaskName")
    except ValueError:
        i_name = 0
    i_sched = hdr.index("Scheduled Task State") \
        if "Scheduled Task State" in hdr else None
    i_start = hdr.index("Start Time") if "Start Time" in hdr else None
    i_rep = hdr.index("Repeat: Every") \
        if "Repeat: Every" in hdr else None
    out = [("TaskName", "State", "Time", "Repetition")]
    for row in rows[1:]:
        if len(row) <= i_name:
            continue
        name = row[i_name].strip('"')
        if not name.startswith("\\DevOptimizer\\"):
            continue
        def cell(i):
            return (row[i].strip('"') if i is not None
                    and i < len(row) else "")
        out.append((name, cell(i_sched), cell(i_start), cell(i_rep)))
    w = [max(len(r2[i]) for r2 in out) for i in range(4)]
    for r2 in out:
        print("  ".join(r2[i].ljust(w[i]) for i in range(4)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
