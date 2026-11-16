#!/usr/bin/env python3
"""Python port of install-dmr-gpu.ps1 — install the Docker Model Runner
GPU runner (llama.cpp backend, CUDA). Extra args are passed through;
--dry-run prints without executing.
"""
import argparse
import shutil
import subprocess
import sys


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Install Docker Model Runner GPU runner "
                    "(llama.cpp + CUDA)")
    ap.add_argument("extra", nargs=argparse.REMAINDER,
                    help="extra args passed to docker model install-runner")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the command without executing")
    args = ap.parse_args()

    cmd = ["docker", "model", "install-runner",
           "--backend", "llama.cpp", "--gpu", "cuda"] + args.extra
    if args.dry_run:
        print("[dry-run]", " ".join(cmd))
        return 0
    if shutil.which("docker") is None:
        print("docker CLI not found on PATH", file=sys.stderr)
        return 1
    try:
        return subprocess.run(cmd).returncode
    except OSError as e:
        print(f"failed to run docker: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
