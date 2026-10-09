#!/usr/bin/env python3
"""DevOptimizer Cleanup - Main entry point for all cleanup scripts."""
import sys
import subprocess
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent

SCRIPTS = {
    "check": ("check_cleanup_status.py", "Read-only cleanup status assessment"),
    "safe": ("win11_safe_cleanup.py", "Safe user-level cleanup (temp, caches, Docker build cache)"),
    "extended": ("extended_cleanup.py", "Extended weekly cleanup (GPU, browsers, VS Code, logs)"),
    "dev": ("dev_cleanup.py", "Developer cleanup (temp, caches, WSL, ports)"),
    "vhdx": ("invoke_vhdx_compaction.py", "VHDX compaction for WSL/Docker"),
    "elevated": ("elevated_complete_cleanup.py", "Elevated admin cleanup (DISM, WU, shadow copies, VHDX)"),
    "wsl": ("wsl_deep_clean.py", "WSL deep clean (journals, apt, docker, dev caches)"),
    "devcache": ("dev_cache_cleaner.py", "Dev cache cleaner (admin: DISM, WU, DO, WER)"),
}


def run_script(script_name: str, args: list = None):
    """Run a Python script with given arguments."""
    script_path = SCRIPTS_DIR / script_name
    if not script_path.exists():
        print(f"Error: Script not found: {script_path}")
        return 1
    
    cmd = [sys.executable, str(script_path)]
    if args:
        cmd.extend(args)
    
    return subprocess.run(cmd).returncode


def main():
    if len(sys.argv) < 2:
        print("DevOptimizer Cleanup - Python Port")
        print("==================================")
        print()
        print("Usage: python -m py.cleanup <command> [args...]")
        print()
        print("Commands:")
        for key, (script, desc) in SCRIPTS.items():
            print(f"  {key:<10} {desc}")
        print()
        print("Examples:")
        print("  python -m py.cleanup check              # Check cleanup status")
        print("  python -m py.cleanup safe               # Run safe cleanup")
        print("  python -m py.cleanup extended           # Run extended cleanup")
        print("  python -m py.cleanup dev                # Run dev cleanup")
        print("  python -m py.cleanup vhdx               # Compact VHDX disks")
        print("  python -m py.cleanup elevated           # Full admin cleanup (requires admin)")
        print("  python -m py.cleanup wsl                # Deep clean WSL")
        print("  python -m py.cleanup devcache           # Admin dev cache cleaner (requires admin)")
        print()
        print("Extended cleanup options:")
        print("  python -m py.cleanup extended --dry-run")
        print("  python -m py.cleanup extended --browser-days 14")
        return 0
    
    command = sys.argv[1]
    args = sys.argv[2:]
    
    if command not in SCRIPTS:
        print(f"Unknown command: {command}")
        print(f"Available: {', '.join(SCRIPTS.keys())}")
        return 1
    
    script_name, _ = SCRIPTS[command]
    return run_script(script_name, args)


if __name__ == "__main__":
    sys.exit(main())