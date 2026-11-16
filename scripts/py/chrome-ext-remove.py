"""Port of scripts/chrome-ext-remove.ps1.

Removes a Chrome extension via UI Automation: focuses
the visible Chrome window, navigates to
chrome://extensions/?id=<id> via the omnibox
(chrome:// is unreachable via CDP on the default
profile), invokes "Remove extension", confirms the
dialog.

UIA + SendKeys are Win32/Forms facilities, so the port
drives the same steps through the original PowerShell
script's logic hosted in powershell.exe — matching how
the bat launchers delegate.
"""

import argparse
import subprocess
import sys
from pathlib import Path

PS1 = Path(r"D:\DevOptimizer\scripts\chrome-ext-remove.ps1")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-ExtensionId", required=True)
    ap.add_argument("-ChromeMatch", default="Chrome")
    a = ap.parse_args()

    if not PS1.exists():
        print(f"original script not found: {PS1}")
        return 1
    import shutil
    try:
        needs7 = any(t in PS1.read_text(
            encoding="utf-8", errors="replace")
            for t in ("-AsHashtable", "??", ".Where("))
    except OSError:
        needs7 = False
    order = ("pwsh", "powershell") if needs7 \
        else ("powershell", "pwsh")
    ps = next((shutil.which(h) for h in order
               if shutil.which(h)), None)
    r = subprocess.run(
        [ps, "-NoProfile", "-ExecutionPolicy",
         "Bypass", "-File", str(PS1),
         "-ExtensionId", a.ExtensionId,
         "-ChromeMatch", a.ChromeMatch])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
