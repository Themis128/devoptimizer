"""Phase 2 wrapper classifier: cross-references bat/cmd + trivial ps1 files
against scheduled tasks, Start Menu shortcuts, and hub registry commands.
Read-only; prints the classification. Exit 0 always.
"""

import csv
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def load_task_refs() -> set:
    refs = set()
    csv_path = REPO / "logs" / "task-references-20261031.csv"
    with open(csv_path, encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            blob = (row.get("Exec", "") + " " + row.get("Args", "")).lower()
            for m in re.finditer(r"[a-z0-9_\-.]+\.(?:ps1|bat|cmd|py|exe)", blob):
                refs.add(m.group(0))
            for m in re.finditer(r"devoptimizer[\\/][^,\"]*", blob):
                refs.add(m.group(0).replace("/", "\\"))
    return refs


def load_registry() -> tuple[set, set]:
    reg = json.load(open(REPO / "config" / "hub-registry.json", encoding="utf-8-sig"))
    paths = {c["path"].replace("/", "\\").lower() for c in reg["commands"]}
    names = {c["name"].lower() for c in reg["commands"]}
    return paths, names


def main() -> int:
    refs = load_task_refs()
    reg_paths, reg_names = load_registry()

    files = subprocess.run(
        ["git", "ls-files"], capture_output=True, text=True, cwd=REPO
    ).stdout.splitlines()

    bats = [f for f in files if f.lower().endswith((".bat", ".cmd"))]
    trivial_ps1 = []
    for f in (x for x in files if x.lower().endswith(".ps1")):
        p = REPO / f
        try:
            n = sum(1 for _ in open(p, encoding="utf-8", errors="replace"))
        except OSError:
            continue
        if n <= 20:
            trivial_ps1.append((f, n))

    def classify(relpath: str) -> str:
        low = relpath.lower()
        name = Path(low).name
        stem = Path(low).stem.lower()
        if low.replace("/", "\\") in reg_paths:
            return "registry"
        if name in refs or low.replace("/", "\\") in refs:
            return "task"
        if any(r.endswith(name) for r in refs):
            return "task-name"
        if stem.replace("_", "-") in reg_names:
            return "registry-name"
        return "unreferenced"

    bats_class = [(f, classify(f)) for f in bats]
    ps1_class = [(f, n, classify(f)) for f, n in trivial_ps1]

    from collections import Counter

    print("=== bat/cmd classification ===")
    for k, v in Counter(c for _f, c in bats_class).most_common():
        print(f"  {k}: {v}")
    print("=== trivial ps1 (<=20 lines) classification ===")
    for k, v in Counter(c for _f, _n, c in ps1_class).most_common():
        print(f"  {k}: {v}")

    print("=== UNREFERENCED bat/cmd ===")
    for f, c in bats_class:
        if c == "unreferenced":
            print("  " + f)
    print("=== UNREFERENCED trivial ps1 ===")
    for f, n, c in ps1_class:
        if c == "unreferenced":
            print(f"  {f} ({n}L)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
