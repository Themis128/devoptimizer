"""Ollama script generator (port of
tools/Variants/ollama-script-generator-*.bat).

8-item generator menu -> ollama-batch-helper port with the original
prompt templates; output to generated-scripts\\<kind>-<rand>.bat.
--choice/--sub/--desc drive it non-interactively; --admin variant.
"""

import argparse
import random
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: ollama, generator, menu

HELPER = Path(__file__).resolve().parent / "ollama-batch-helper.py"
OUT_DIR = Path(r"D:\DevOptimizer\generated-scripts")
W11 = "Windows 11 Build 26120 with Intel i9-12900H"

TASK_CATS = ["File Management", "System Configuration",
             "Network Operations", "Security Operations",
             "Performance Tuning", "Backup and Recovery",
             "Software Management", "Hardware Management"]
REPAIRS = ["Registry Repair", "File System Repair", "Network Repair",
           "Performance Repair", "Security Repair",
           "Complete System Repair"]
PERF = ["CPU Optimization", "Memory Optimization",
        "Storage Optimization", "Network Optimization",
        "Overall System Performance"]
SEC = ["Windows Defender Optimization", "Firewall Configuration",
       "User Account Security", "System Security Policies",
       "Network Security", "Complete Security Hardening"]
MON = ["System Performance Monitoring", "Hardware Health Monitoring",
       "Security Event Monitoring", "Network Activity Monitoring",
       "Application Performance Monitoring",
       "Comprehensive System Monitoring"]
TEST = ["System Functionality Testing", "Performance Benchmarking",
        "Security Testing", "Compatibility Testing", "Stress Testing",
        "Comprehensive Testing Suite"]


def call_helper(prompt: str, name: str, out_dir: Path, dry: bool):
    out = out_dir / f"{name}-{random.randint(0, 32767)}.bat"
    cmd = [sys.executable, str(HELPER), "--prompt", prompt,
           "--output", str(out)]
    if dry:
        cmd.append("--dry-run")
    subprocess.run(cmd)


def pick(options, label):
    for i, o in enumerate(options, 1):
        print(f"{i}. {o}")
    c = input(f"Select {label} (1-{len(options)}): ").strip()
    return options[int(c) - 1] if c.isdigit() and int(c) <= len(options) else options[0]


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--choice", default="", help="top-level menu 1-8")
    p.add_argument("--sub", default="",
                   help="sub-category index for the chosen menu")
    p.add_argument("--desc", default="",
                   help="free-text description/requirements input")
    p.add_argument("--out-dir", default=str(OUT_DIR))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)
    out_dir = Path(args.out_dir)
    sub = int(args.sub) if args.sub.isdigit() else 0
    desc = args.desc

    def run(choice: int):
        nonlocal desc
        if choice == 1:
            cat = TASK_CATS[sub - 1] if 1 <= sub <= 8 else pick(TASK_CATS, "task category")
            desc = desc or input("Enter task description: ")
            call_helper(
                f"Generate a Windows batch script for {cat} task: "
                f"{desc}. System: {W11}, 32GB RAM. Create a complete, "
                "executable batch script with proper error handling, "
                "logging, and safety checks. Include comments "
                "explaining each section.", cat.lower().replace(" ", "-"),
                out_dir, args.dry_run)
        elif choice == 2:
            desc = desc or input("Enter workflow description: ")
            call_helper(
                "Create a comprehensive workflow automation script for "
                f"Windows 11 Build 26120. Workflow: {desc}. Include: "
                "1) Step-by-step automation 2) Error handling and "
                "recovery 3) Progress tracking 4) Logging system "
                "5) User notifications 6) Rollback capabilities. "
                "Generate a complete, production-ready script.",
                "workflow", out_dir, args.dry_run)
        elif choice == 3:
            t = REPAIRS[sub - 1] if 1 <= sub <= 6 else pick(REPAIRS, "repair type")
            call_helper(
                f"Create a comprehensive {t} script for {W11}. "
                "Include: 1) Diagnostic checks 2) Repair procedures "
                "3) Backup creation 4) Rollback options 5) Progress "
                "monitoring 6) Success verification. Generate a safe, "
                "reversible repair script.",
                t.lower().replace(" ", "-"), out_dir, args.dry_run)
        elif choice == 4:
            t = PERF[sub - 1] if 1 <= sub <= 5 else pick(PERF, "performance focus")
            call_helper(
                f"Create a {t} script for {W11} (20 threads), 32GB "
                "RAM. Focus on maximizing performance while "
                "maintaining system stability. Include: 1) "
                "Performance baseline measurement 2) Optimization "
                "procedures 3) Performance monitoring 4) Rollback "
                "options 5) Performance validation.",
                t.lower().replace(" ", "-"), out_dir, args.dry_run)
        elif choice == 5:
            t = SEC[sub - 1] if 1 <= sub <= 6 else pick(SEC, "security focus")
            call_helper(
                f"Create a {t} script for Windows 11 Build 26120. "
                "Focus on enhancing security while maintaining "
                "usability. Include: 1) Security assessment 2) "
                "Hardening procedures 3) Security monitoring 4) "
                "Rollback options 5) Security validation. Ensure "
                "compliance with security best practices.",
                t.lower().replace(" ", "-"), out_dir, args.dry_run)
        elif choice == 6:
            t = MON[sub - 1] if 1 <= sub <= 6 else pick(MON, "monitoring type")
            call_helper(
                f"Create a {t} script for {W11}. Include: 1) Real-time "
                "monitoring 2) Alert system 3) Data logging 4) "
                "Threshold configuration 5) Notification system 6) "
                "Reporting. Generate a comprehensive monitoring "
                "solution.",
                t.lower().replace(" ", "-"), out_dir, args.dry_run)
        elif choice == 7:
            t = TEST[sub - 1] if 1 <= sub <= 6 else pick(TEST, "testing type")
            call_helper(
                f"Create a {t} script for {W11}. Include: 1) Test case "
                "execution 2) Results collection 3) Performance "
                "metrics 4) Error detection 5) Reporting system 6) "
                "Test validation. Generate a comprehensive testing "
                "solution.",
                t.lower().replace(" ", "-"), out_dir, args.dry_run)
        elif choice == 8:
            desc = desc or input("Enter detailed requirements: ")
            call_helper(
                "Create a custom Windows batch script for "
                f"{W11}, 32GB RAM. Requirements: {desc}. Generate a "
                "complete, executable script with proper error "
                "handling, logging, safety checks, and documentation. "
                "Ensure the script is optimized for this specific "
                "system configuration.",
                "custom", out_dir, args.dry_run)

    if args.choice:
        if args.choice.isdigit() and 1 <= int(args.choice) <= 8:
            run(int(args.choice))
        return
    if not sys.stdin.isatty():
        print("(non-interactive: pass --choice N [--sub N] [--desc t])",
              file=sys.stderr)
        return
    print("1. Task-Specific Script\n2. Workflow Automation\n"
          "3. System Repair\n4. Performance Boost\n"
          "5. Security Hardening\n6. Monitoring Scripts\n"
          "7. Testing Scripts\n8. Custom Scripts\n0. Exit")
    c = input("Enter your choice (0-8): ").strip()
    if c.isdigit() and 1 <= int(c) <= 8:
        run(int(c))


if __name__ == "__main__":
    main()
