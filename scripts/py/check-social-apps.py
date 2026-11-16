"""Find social-app install dirs (Python port of check-social-apps.ps1).

Lists entries matching known social/chat app names under
%LOCALAPPDATA%, %APPDATA%, %PROGRAMFILES% and %PROGRAMFILES(X86)%.
"""

import argparse
import json
import os
import re
from pathlib import Path

# CATEGORY: utilities
# TAGS: apps, inventory

NAME_RE = re.compile(
    r"discord|slack|zoom|teams|skype|telegram|whatsapp|signal|messenger|"
    r"facebook|instagram|twitter|linkedin|reddit|tiktok|spotify|youtube|"
    r"twitch|bluesky|mastodon|threads",
    re.IGNORECASE,
)

SECTIONS = [
    ("AppData\\Local", "LOCALAPPDATA"),
    ("AppData\\Roaming", "APPDATA"),
    ("Program Files", "PROGRAMFILES"),
    ("Program Files (x86)", "PROGRAMFILES(X86)"),
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="Emit result as JSON")
    args = parser.parse_args()

    found = {}
    for label, env_var in SECTIONS:
        base = os.environ.get(env_var)
        matches = []
        if base and Path(base).exists():
            for entry in Path(base).iterdir():
                if NAME_RE.search(entry.name):
                    matches.append({"Name": entry.name, "FullName": str(entry)})
        found[label] = matches

    if args.json:
        print(json.dumps(found, indent=2))
        return
    for label, matches in found.items():
        print(f"=== {label} ===")
        for m in matches:
            print(m["FullName"])


if __name__ == "__main__":
    main()
