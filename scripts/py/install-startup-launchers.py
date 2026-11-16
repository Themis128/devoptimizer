"""Port of scripts/install-startup-launchers.ps1 — install hidden
wscript .vbs launchers for startup .bat files (no console flash).
"""
# REQUIRES: admin
import ctypes

def _ensure_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Administrator privileges required", file=sys.stderr)
        sys.exit(1)

import os
import shutil
import sys
from pathlib import Path

BATS = ["cdp-launch", "dmr-tunnel", "win_agent", "ntfy-bridge"]
SRC = Path("D:" + chr(92) + "DevOptimizer" + chr(92)
         + "scripts" + chr(92) + "startup")


def main():
    _ensure_admin()
    hidden = Path(os.environ["USERPROFILE"]) / "startup-hidden"
    startup = (Path(os.environ["APPDATA"]) / "Microsoft" / "Windows"
               / "Start Menu" / "Programs" / "Startup")
    hidden.mkdir(parents=True, exist_ok=True)
    for b in BATS:
        dst = hidden / (b + ".bat")
        shutil.copy2(SRC / (b + ".bat"), dst)
        stale = startup / (b + ".bat")
        if stale.exists():
            stale.unlink()
            print("removed stale", stale)
        vbs = startup / (b + "-hidden.vbs")
        vbs.write_text(
            'CreateObject("Wscript.Shell").Run "cmd /c ""'
            + str(dst) + '""", 0, False', encoding="ascii")
        print("installed", vbs, "->", dst, "(hidden)")
    print("Done. Launchers take effect at next logon "
          "(or run the .vbs manually).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
