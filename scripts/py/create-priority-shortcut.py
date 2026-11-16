"""Create a Startup-folder shortcut for lower-devin-priority (Python port of create-priority-shortcut.ps1).

Creates Devin-Lower-Priority.lnk in the user Startup folder running
lower-devin-priority.ps1 -Loop -Interval 30 at logon. Uses WScript.Shell
COM via the PS shim. --force recreates an existing shortcut.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: shortcut, startup, devin

SCRIPT_PATH = r"D:\DevOptimizer\scripts\lower-devin-priority.ps1"
SHORTCUT_NAME = "Devin-Lower-Priority.lnk"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true",
                        help="Recreate the shortcut if it already exists")
    parser.add_argument("--dry-run", action="store_true",
                        help="Describe the shortcut without creating it")
    args = parser.parse_args()

    ps = (
        f"$scriptPath = '{SCRIPT_PATH}'; "
        f"$startupPath = [Environment]::GetFolderPath('Startup'); "
        f"$shortcutPath = Join-Path $startupPath '{SHORTCUT_NAME}'; "
        "if (-not (Test-Path $scriptPath)) { Write-Error 'script missing'; exit 1 }; "
        "if ((Test-Path $shortcutPath) -and -not "
        f"${'true' if args.force else 'false'}) "
        "{ Write-Output \"EXISTS:$shortcutPath\"; exit 3 }; "
        "$shell = New-Object -ComObject WScript.Shell; "
        "$shortcut = $shell.CreateShortcut($shortcutPath); "
        "$shortcut.TargetPath = 'powershell.exe'; "
        "$shortcut.Arguments = \"-NoProfile -ExecutionPolicy Bypass -File `\"$scriptPath`\" -Loop -Interval 30\"; "
        "$shortcut.WorkingDirectory = 'D:\\DevOptimizer\\scripts'; "
        "$shortcut.Description = 'Lower Devin Desktop process priority to BelowNormal'; "
        "$shortcut.IconLocation = 'powershell.exe,0'; "
        "$shortcut.Save(); "
        "Write-Output \"CREATED:$shortcutPath\""
    )

    if args.dry_run:
        print(f"[dry-run] would create {SHORTCUT_NAME} in the Startup folder:")
        print(ps)
        return

    result = asyncio.run(run_ps_command(ps))
    out = result.stdout.strip()
    if result.returncode == 3 or out.startswith("EXISTS:"):
        print(f"Shortcut already exists at: {out.removeprefix('EXISTS:')}")
        print("Use --force to recreate")
        return
    if result.returncode != 0:
        print(result.stderr.strip() or out or "shortcut creation failed",
              file=sys.stderr)
        sys.exit(result.returncode)
    print(f"Created startup shortcut: {out.removeprefix('CREATED:')}")
    print("Will run at user logon, checking Devin priority every 30 seconds")


if __name__ == "__main__":
    main()
