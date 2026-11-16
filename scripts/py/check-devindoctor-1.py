"""Port of scripts/devin/Check-DevinDoctor.ps1 — locate/install
devin-doctor via pipx, run `check` + snapshot JSON under
logs\\devin-doctor\\, event 1005 on FAIL findings.
"""
# REQUIRES: admin
import ctypes
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required",
              file=sys.stderr)
        sys.exit(1)


LOG = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs"
           + chr(92) + "devin-doctor-check.log")
SNAP_DIR = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs"
                + chr(92) + "devin-doctor")


def log(msg):
    line = time.strftime("%Y-%m-%d %H:%M:%S") + " " + msg
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def find_doctor():
    c = shutil.which("devin-doctor")
    if c:
        return c
    bin_dir = os.environ.get("PIPX_BIN_DIR") or os.path.join(
        os.environ.get("USERPROFILE", ""), ".local", "bin")
    exe = os.path.join(bin_dir, "devin-doctor.exe")
    if Path(exe).exists():
        return exe
    return None


def main():
    _ensure_admin()
    skip_install = "--skip-install" in sys.argv
    json_only = "--json-only" in sys.argv
    data_dir = config_dir = None
    for i, a in enumerate(sys.argv):
        if a == "--data-dir" and i + 1 < len(sys.argv):
            data_dir = sys.argv[i + 1]
        if a == "--config-dir" and i + 1 < len(sys.argv):
            config_dir = sys.argv[i + 1]
    log("--- devin-doctor run started ---")
    py = shutil.which("python") or shutil.which("py")
    if not py:
        log("FAIL: no python interpreter found")
        print("FAIL: python not found")
        return 2
    doctor = find_doctor()
    if not doctor:
        if skip_install:
            log("devin-doctor not found and --skip-install given")
            print("devin-doctor not installed (run without "
                  "--skip-install to install)")
            return 2
        log("devin-doctor not found - installing pipx + devin-doctor")
        r = subprocess.run([py, "-m", "pip", "install", "--user",
                            "pipx"], capture_output=True, text=True)
        for l in (r.stdout + r.stderr).splitlines()[-2:]:
            log("  pip: " + l)
        r = subprocess.run([py, "-m", "pipx", "ensurepath"],
                           capture_output=True, text=True)
        for l in (r.stdout + r.stderr).splitlines():
            log("  pipx: " + l)
        r = subprocess.run(
            [py, "-m", "pipx", "install",
             "git+https://github.com/Icaro0310/devin-doctor.git"],
            capture_output=True, text=True)
        for l in (r.stdout + r.stderr).splitlines()[-3:]:
            log("  pipx: " + l)
        doctor = find_doctor()
        if not doctor:
            log("FAIL: devin-doctor still not found after install")
            print("FAIL: devin-doctor install did not produce an "
                  "executable - check log")
            return 2
        log("installed: " + doctor)
    else:
        log("using: " + doctor)
    args = ["check"]
    if data_dir:
        args += ["--data-dir", data_dir]
    if config_dir:
        args += ["--config-dir", config_dir]
    check = subprocess.run([doctor] + args, capture_output=True,
                           text=True)
    for l in (check.stdout + check.stderr).splitlines():
        log("  check: " + l)
        if any(k in l for k in ("PASS", "WARN", "FAIL", "health",
                                "overall")) and not json_only:
            print(l)
    jout = subprocess.run([doctor] + args + ["--json"],
                          capture_output=True, text=True)
    jtext = jout.stdout.strip()
    overall = None
    if json_only and jtext:
        print(jtext)
    try:
        import json as _json
        SNAP_DIR.mkdir(parents=True, exist_ok=True)
        snap = SNAP_DIR / ("devin-doctor-"
                           + time.strftime("%Y%m%d-%H%M%S") + ".json")
        snap.write_text(jtext, encoding="utf-8")
        log(f"snapshot: {snap}")
        overall = _json.loads(jtext).get("overall")
        if overall:
            log(f"overall: {overall}")
    except (OSError, ValueError) as e:
        log(f"snapshot/parse issue: {e}")
    if check.returncode == 0:
        log("devin-doctor: no FAIL findings (exit 0)")
        print("devin-doctor check complete: no FAIL findings")
        return 0
    log(f"devin-doctor reported FAIL findings (exit "
        f"{check.returncode})")
    subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Write-EventLog -LogName 'DevOptimizer' -Source "
         "'DevOptimizer' -EventId 1005 -EntryType Error -Message "
         "\"devin-doctor reported FAIL findings (exit "
         + str(check.returncode)
         + "). Run scripts\\devin\\Check-DevinDoctor.ps1 for "
         "details.\" -ErrorAction SilentlyContinue"],
        capture_output=True)
    print("devin-doctor check complete: FAIL findings present "
          "(event 1005 written)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
