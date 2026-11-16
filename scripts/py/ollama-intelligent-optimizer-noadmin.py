"""Ollama intelligent system optimizer (port of
tools/Variants/ollama-intelligent-optimizer-NoAdmin.bat).

Interactive menu: generates optimization plans via
tools/Variants/tools/ollama-batch-helper.bat, writes them to
<Variants>/ai-analysis/*.txt, applies each plan, then logs via
tools/DEVOPTIMIZER-LAUNCHER.bat. Standard (non-admin) mode.
--dry-run prints actions only.
"""

import argparse
import ctypes
import os
import subprocess
import sys
from pathlib import Path

# CATEGORY: ai-ml
# TAGS: ollama, optimization, interactive

SCRIPT_DIR = Path(__file__).resolve().parent
VARIANTS_DIR = (SCRIPT_DIR.parents[1] / "tools" / "Variants"
                if (SCRIPT_DIR.parents[1] / "tools" / "Variants").is_dir()
                else SCRIPT_DIR)
BAT_HUB = VARIANTS_DIR
HELPER = VARIANTS_DIR / "tools" / "ollama-batch-helper.bat"
LAUNCHER = VARIANTS_DIR.parent / "DEVOPTIMIZER-LAUNCHER.bat"
OUT_DIR = BAT_HUB / "ai-analysis"

MODES = {
    "1": ("auto_optimize", "AUTO-OPTIMIZE MODE - AI-driven automatic "
          "optimization", "auto-optimize-plan.txt",
          "Analyze Windows 11 Build 26120 system and create automatic "
          "optimization plan. System: Intel i9-12900H (20 threads), "
          "32GB RAM. Generate step-by-step optimization commands for: "
          "1) CPU performance tuning 2) Memory optimization 3) Storage "
          "configuration 4) Background process management 5) Registry "
          "optimizations. Output as executable batch commands."),
    "2": ("performance_focus", "PERFORMANCE-FOCUS MODE - Maximize "
          "Intel i9-12900H performance", "performance-optimize.txt",
          "Create performance-focused optimization for Intel i9-12900H "
          "(20 threads) on Windows 11 Build 26120. Focus on: 1) CPU "
          "core utilization optimization 2) Thread scheduling "
          "improvements 3) Cache optimization 4) Memory bandwidth "
          "optimization 5) Process priority management. Generate "
          "specific registry tweaks and system configurations."),
    "3": ("security_focus", "SECURITY-FOCUS MODE - Enhanced security "
          "with performance balance", "security-optimize.txt",
          "Create security-focused optimization for Windows 11 Build "
          "26120 with performance balance. Focus on: 1) Windows "
          "Defender optimization 2) Firewall configuration 3) Process "
          "isolation 4) Memory protection 5) Network security. Ensure "
          "performance impact is minimal while maximizing security "
          "posture."),
    "4": ("storage_focus", "STORAGE-FOCUS MODE - Multi-drive "
          "optimization", "storage-optimize.txt",
          "Create storage optimization for Windows 11 Build 26120 "
          "with multiple drives (C: 672GB, D: 145GB, E: 135GB free). "
          "Focus on: 1) Drive performance optimization 2) File system "
          "tuning 3) Cache configuration 4) Disk I/O optimization "
          "5) Storage space management. Generate specific "
          "optimizations for each drive."),
    "5": ("network_focus", "NETWORK-FOCUS MODE - Latency and "
          "bandwidth optimization", "network-optimize.txt",
          "Create network optimization for Windows 11 Build 26120. "
          "Focus on: 1) TCP/IP stack optimization 2) DNS "
          "configuration 3) Network adapter tuning 4) Bandwidth "
          "optimization 5) Latency reduction. Generate specific "
          "network registry tweaks and configurations."),
    "6": ("custom_profile", "CUSTOM PROFILE MODE - Tailored "
          "optimizations", "custom-optimize.txt",
          "Create custom optimization profile for Windows 11 Build "
          "26120 with Intel i9-12900H (20 threads), 32GB RAM. "
          "Requirements: {custom_req}. Generate specific "
          "optimizations tailored to these requirements while "
          "maintaining system stability."),
    "7": ("benchmark_mode", "BENCHMARK MODE - System performance "
          "baseline", "benchmark-script.txt",
          "Create comprehensive benchmarking script for Windows 11 "
          "Build 26120 with Intel i9-12900H. Generate benchmarks "
          "for: 1) CPU performance 2) Memory bandwidth 3) Storage "
          "I/O 4) Network performance 5) System responsiveness. "
          "Include comparison with optimal configurations."),
}


def is_admin():
    if sys.platform != "win32":
        return False
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def _run(cmd, dry):
    if dry:
        print("[dry-run]", " ".join(map(str, cmd)))
        return 0
    try:
        return subprocess.run([str(c) for c in cmd],
                              cwd=str(VARIANTS_DIR)).returncode
    except OSError as e:
        print(f"failed to run {cmd[0]}: {e}", file=sys.stderr)
        return 1


def launcher_log(msg, dry):
    if LAUNCHER.exists():
        _run([LAUNCHER, ":log", msg], dry)


def run_mode(choice, dry):
    name, title, out_name, prompt = MODES[choice]
    print(f"\n {title}\n{'=' * 64}\n")
    if name == "custom_profile":
        req = input("Describe your optimization requirements: ").strip()
        prompt = prompt.format(custom_req=req or "general optimization")
    OUT_DIR.mkdir(exist_ok=True)
    out_file = OUT_DIR / out_name
    rc = _run([HELPER, "-prompt", prompt, "-output", out_file], dry)
    if rc != 0:
        print(f"{name}: helper failed (rc={rc})")
        return rc
    print(f"Applying AI-generated plan: {out_file}")
    if out_file.exists() or dry:
        _run(["cmd", "/c", str(out_file)], dry)
    print(f"{name} complete!")
    launcher_log(f"{name.replace('_', ' ').title()} completed", dry)
    return 0


def main():
    ap = argparse.ArgumentParser(
        description="Ollama intelligent system optimizer")
    ap.add_argument("--mode", choices=sorted(MODES),
                    help="run a mode non-interactively")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.mode:
        return run_mode(args.mode, args.dry_run)
    while True:
        print("\nOLLAMA INTELLIGENT SYSTEM OPTIMIZER")
        print("=" * 64)
        for k in sorted(MODES):
            print(f"[{k}] {MODES[k][1].split(' - ')[0].title()}")
        print("[0] Exit\n")
        choice = input("Enter your choice (0-7): ").strip()
        if choice == "0":
            return 0
        if choice not in MODES:
            print("Invalid choice. Please try again.")
            continue
        run_mode(choice, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
