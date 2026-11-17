"""Port of scripts/devin/Install-DevinCLI.ps1.

Installs Devin CLI via the official PowerShell
installer (`irm https://static.devin.ai/cli/setup.ps1
| iex`), or prints the Devin Desktop Command Palette
instructions with -Method desktop.
"""

import argparse
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

LOG = Path("D:/DevOptimizer/logs/devin-cli-install.log")


def log(msg):
    print(msg)
    try:
        LOG.parent.mkdir(exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} "
                    f"{msg}\n")
    except OSError:
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Method", default="official",
                    choices=["official", "desktop"])
    ap.add_argument("-Force", action="store_true")
    a = ap.parse_args()

    log(f"=== Devin CLI Installation ({a.Method}) ===")
    if a.Method == "official":
        log("Installing via official PowerShell "
            "installer...")
        devin = shutil.which("devin")
        if devin and not a.Force:
            log(f"Devin CLI already installed at: {devin}")
            log("Use -Force to reinstall")
            return 0
        cmd = ("Invoke-Expression "
               "'irm https://static.devin.ai/cli/"
               "setup.ps1 | iex'")
        log("Running: irm https://static.devin.ai/cli/"
            "setup.ps1 | iex")
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "irm https://static.devin.ai/cli/setup.ps1 "
             "| iex"], capture_output=True, text=True)
        if r.returncode != 0:
            log(f"ERROR: Installation failed: "
                f"{r.stderr[:300]}")
            return 1
        log("Installer completed")
        devin = shutil.which("devin")
        if devin:
            v = subprocess.run(
                ["devin", "--version"],
                capture_output=True, text=True)
            log(f"SUCCESS: Devin CLI installed at: "
                f"{devin}")
            log(f"Version: {v.stdout.strip()}")
        else:
            log("WARNING: devin command not found in "
                "PATH. Restart terminal or add to PATH "
                "manually.")
            log("Expected location: "
                "%USERPROFILE%\\.local\\bin\\devin.exe "
                "or %LOCALAPPDATA%\\Programs\\Devin"
                "\\bin\\devin-desktop.cmd")
    else:
        for line in (
                "Devin Desktop Command Palette "
                "installation:",
                "1. Open Devin Desktop",
                "2. Press Ctrl+Shift+P (Command Palette)",
                "3. Search 'Install Devin CLI' and select"
                " it",
                "4. Requires: Admin rights + 'Install "
                "Devin CLI in Devin Desktop' enabled in "
                "team settings",
                "5. Restart terminal after installation"):
            log(line)
    log("=== Installation Complete ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
