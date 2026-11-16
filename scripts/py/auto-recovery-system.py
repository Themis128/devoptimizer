"""Auto-recovery system (port of
tools/Variants/AUTO-RECOVERY-SYSTEM-*.bat).

Self-healing pass: fix .bat files missing @echo off / with bare
`pause`, repair permissions + exec policy, network reset, temp/cache
cleanup, then validation. Logs to logs/auto-recovery.log.
Mutating; --dry-run. --admin = admin variant (elevation check).
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

# CATEGORY: utilities
# TAGS: recovery, repair, self-healing

SCRIPT_DIR = Path(r"D:\DevOptimizer")


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def log(logf, msg, recovery=False):
    line = f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line)
    logf.parent.mkdir(parents=True, exist_ok=True)
    with open(logf, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def fix_batch_issues(script_dir, logf, dry):
    log(logf, "Scanning for batch file issues...")
    for f in script_dir.glob("*.bat"):
        try:
            text = f.read_text(errors="replace")
        except OSError:
            continue
        new = text
        if not re.search(r"(?im)^@echo\s+off", new):
            new = "@echo off\r\n" + new.lstrip("\r\n")
            log(logf, f"Fixed missing @echo off in {f.name}", True)
        if re.search(r"(?im)^pause\s*$", new):
            new = re.sub(r"(?im)^pause\s*$", "pause >nul", new)
            log(logf, f"Fixed bare pause in {f.name}", True)
        if new != text:
            if dry:
                print(f"[dry-run] rewrite {f.name}")
            else:
                f.write_text(new)


def repair_network(logf, dry):
    log(logf, "Repairing network issues...")
    for cmd in (["ipconfig", "/release"], ["ipconfig", "/renew"],
                ["ipconfig", "/flushdns"]):
        if dry:
            print("[dry-run] " + " ".join(cmd))
        else:
            subprocess.run(cmd, capture_output=True)
    log(logf, "Network issues repaired", True)


def repair_disk(logf, dry):
    log(logf, "Repairing disk issues...")
    for pattern in (Path(tempfile.gettempdir()).glob("*"),
                    Path(os.environ.get("WINDIR", r"C:\Windows"))
                    .joinpath("Temp").glob("*"),
                    Path(os.environ.get("LOCALAPPDATA", ""))
                    .joinpath(r"Google\Chrome\User Data\Default\Cache")
                    .glob("*")):
        for p in pattern:
            if dry:
                print(f"[dry-run] delete {p}")
                break
            try:
                if p.is_dir():
                    shutil.rmtree(p, ignore_errors=True)
                else:
                    p.unlink(missing_ok=True)
            except OSError:
                pass
    log(logf, "Disk issues repaired", True)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--script-dir", default=str(SCRIPT_DIR))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)

    script_dir = Path(args.script_dir)
    logf = script_dir / "logs" / "auto-recovery.log"
    log(logf, "Auto-recovery system started")

    fix_batch_issues(script_dir, logf, args.dry_run)
    log(logf, "Repairing file permissions...")
    if args.dry_run:
        print(f"[dry-run] icacls <top-level *.bat> /reset + grant in "
              f"{script_dir}")
    else:
        for bat in script_dir.glob("*.bat"):
            subprocess.run(["icacls", str(bat), "/reset"],
                           capture_output=True)
            subprocess.run(["icacls", str(bat), "/grant:r",
                            f"{os.environ.get('USERNAME','')}:(F)"],
                           capture_output=True)
    log(logf, "Repairing PowerShell execution...")
    if args.dry_run:
        print("[dry-run] Set-ExecutionPolicy Bypass -Scope CurrentUser")
    else:
        subprocess.run(
            ["powershell", "-Command",
             "Set-ExecutionPolicy -ExecutionPolicy Bypass "
             "-Scope CurrentUser -Force"], capture_output=True)
    repair_network(logf, args.dry_run)
    repair_disk(logf, args.dry_run)

    log(logf, "Validating repairs...")
    if args.dry_run:
        print("[dry-run] powershell -Command \"Write-Host 'Test'\"")
    else:
        r = subprocess.run(["powershell", "-Command", "Write-Host 'Test'"],
                           capture_output=True)
        log(logf, "SUCCESS: validation passed" if r.returncode == 0
            else "WARNING: PowerShell execution test failed")
    log(logf, "Auto-recovery complete")


if __name__ == "__main__":
    main()
