"""Check installed store apps (Python port of check-store-apps.ps1).

Queries Get-AppxPackage for a fixed list of package names and prints
version, publisher, install location and status for each installed one.
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: appx, store, packages

APPS = [
    "5319275A.WhatsAppDesktop",
    "7EE7776C.LinkedInforWindows",
    "BytedancePte.Ltd.TikTok",
    "com.tinyspeck.slackdesktop",
    "FACEBOOK.FACEBOOK",
    "Facebook.InstagramBeta",
    "Instagram.ThreadsanInstagramapp",
    "MSTeams",
    "SpotifyAB.SpotifyMusic",
    "TelegramMessengerLLP.TelegramDesktop",
    "www.messenger.com-43D6998D",
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit results as JSON")
    args = parser.parse_args()

    names = ", ".join(f"'{a}'" for a in APPS)
    script = (
        f"@({names}) | ForEach-Object {{ "
        "  Get-AppxPackage -Name $_ -ErrorAction SilentlyContinue } | "
        "Select-Object Name, Version, PublisherDisplayName, InstallLocation, "
        "IsFramework, IsResourcePackage, Status | ConvertTo-Json -Compress"
    )
    result = asyncio.run(run_ps_command(script, timeout=180))
    if result.returncode != 0:
        print(result.stderr.strip() or "AppX query failed", file=sys.stderr)
        sys.exit(result.returncode)

    apps = json.loads(result.stdout or "[]")
    if isinstance(apps, dict):
        apps = [apps]

    if args.json:
        print(json.dumps(apps, indent=2))
        return
    for a in apps:
        print(f"=== {a.get('Name', '')} ===")
        print(f"  Version: {a.get('Version', '')}")
        print(f"  Publisher: {a.get('PublisherDisplayName', '')}")
        print(f"  InstallLocation: {a.get('InstallLocation', '')}")
        print(f"  IsFramework: {a.get('IsFramework', '')}")
        print(f"  IsResourcePackage: {a.get('IsResourcePackage', '')}")
        print(f"  Status: {a.get('Status', '')}")
        print()


if __name__ == "__main__":
    main()
