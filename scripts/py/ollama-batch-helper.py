"""Ollama batch helper (port of tools/ollama-batch-helper.bat).

Wraps tools/run-ollama-all.ps1: stamps a unique logs/ollama-<ts>/ output
dir, runs the multi-model pass, then copies aggregate.md (or the first
output) to -output (append with -append).
"""

import argparse
import glob
import shutil
import subprocess
import sys
import time
from pathlib import Path

# CATEGORY: utilities
# TAGS: ollama, batch, multi-model

REPO = Path(__file__).resolve().parents[2]


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--prompt", "-prompt", required=True)
    p.add_argument("--output", "-output", default="")
    p.add_argument("--append", "-append", action="store_true")
    p.add_argument("--concurrency", "-concurrency", type=int, default=1)
    p.add_argument("--timeout", "-timeout", type=int, default=300,
                   help="timeout seconds")
    p.add_argument("--output-dir", default="logs")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    ps = "pwsh" if shutil.which("pwsh") else "powershell"
    stamp = time.strftime("%Y%m%d-%H%M%S")
    out_dir = REPO / args.output_dir / f"ollama-{stamp}"
    cmd = [ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
           str(REPO / "tools" / "run-ollama-all.ps1"),
           "-Prompt", args.prompt, "-OutputDir", str(out_dir),
           "-Concurrency", str(args.concurrency),
           "-TimeoutSeconds", str(args.timeout)]
    if args.dry_run:
        print("[dry-run] " + " ".join(cmd))
        return

    r = subprocess.run(cmd)
    if r.returncode != 0:
        sys.exit(r.returncode)

    if args.output:
        dest = Path(args.output)
        mode = "a" if args.append else "w"
        srcs = sorted(out_dir.glob("**/aggregate.md"))
        content = ""
        if srcs:
            content = srcs[0].read_text(encoding="utf-8-sig")
        else:
            files = sorted(f for f in out_dir.glob("**/*") if f.is_file())
            if files:
                content = files[0].read_text(encoding="utf-8-sig")
        with open(dest, mode, encoding="utf-8") as fh:
            fh.write(content)


if __name__ == "__main__":
    main()
