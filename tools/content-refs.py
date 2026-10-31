"""Content-reference check for Phase 2 deletion candidates: finds any tracked
file whose content mentions a candidate stem — those flip to referenced.
Writes logs/wrapper-classification-final.txt.
"""

import importlib.util
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def _load(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, REPO / "tools" / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    cw = _load("classify_wrappers", "classify-wrappers.py")

    files = subprocess.run(
        ["git", "ls-files"], capture_output=True, text=True, cwd=REPO
    ).stdout.splitlines()

    bats = [f for f in files if f.lower().endswith((".bat", ".cmd"))]
    trivial_ps1 = []
    for f in (x for x in files if x.lower().endswith(".ps1")):
        try:
            n = sum(1 for _ in open(REPO / f, encoding="utf-8", errors="replace"))
        except OSError:
            continue
        if n <= 20:
            trivial_ps1.append((f, n))

    reg_paths, reg_names = cw.load_registry()
    refs = cw.load_task_refs()

    def base_class(relpath: str) -> str:
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

    candidates = [f for f in bats if base_class(f) == "unreferenced"]
    candidates += [f for f, _n in trivial_ps1 if base_class(f) == "unreferenced"]
    patterns = sorted({Path(f).stem for f in candidates})

    patfile = REPO / "logs" / "content-ref-patterns.txt"
    patfile.write_text("\n".join(patterns), encoding="utf-8")

    hits = subprocess.run(
        ["git", "grep", "-l", "-i", "-F", "-f", str(patfile), "--", "."],
        capture_output=True,
        text=True,
        cwd=REPO,
    )
    hit_files = {
        line.split(":", 1)[0]
        for line in hits.stdout.splitlines()
        if line.strip()
    }

    content_referenced = set()
    for cand in candidates:
        stem = Path(cand).stem.lower()
        for hf in hit_files:
            if hf.lower() == cand.lower():
                continue
            try:
                if stem in (REPO / hf).read_text(encoding="utf-8", errors="replace").lower():
                    content_referenced.add(cand)
                    break
            except OSError:
                continue

    orphans = sorted(set(candidates) - content_referenced)
    flipped = sorted(content_referenced)

    out = REPO / "logs" / "wrapper-classification-final.txt"
    with out.open("w", encoding="utf-8") as fh:
        fh.write(f"candidates: {len(candidates)}\n")
        fh.write(f"content-referenced (KEEP): {len(flipped)}\n")
        for f in flipped:
            fh.write(f"  KEEP {f}\n")
        fh.write(f"true orphans (DELETE): {len(orphans)}\n")
        for f in orphans:
            fh.write(f"  DEL  {f}\n")

    print(f"candidates: {len(candidates)} | content-referenced: {len(flipped)} | orphans: {len(orphans)}")
    for f in flipped:
        print("  KEEP " + f)
    return 0


if __name__ == "__main__":
    sys.exit(main())
