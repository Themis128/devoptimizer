"""Port of scripts/update-compose-override.ps1.

Converts selected containers in the cu130-slim
docker-compose.override.yml to restart=no, reading and writing
the file inside the Ubuntu-24.04 distro via `wsl`.
"""

import re
import subprocess
import sys

OVERRIDE = "/home/tbaltzakis/cu130-slim/docker-compose.override.yml"
DISTRO = "Ubuntu-24.04"

CONTAINERS = {
    "browser-novnc",
    "languagetool",
    "metabase",
    "instagram-private-api",
    "tiktok-browser-sidecar",
    "warp-proxy",
}


def wsl(args):
    return subprocess.run(["wsl", "-d", DISTRO, "--"] + args,
                          capture_output=True, text=True)


def main():
    r = wsl(["bash", "-c", f"cat '{OVERRIDE}'"])
    if r.returncode != 0:
        print(f"read failed: {r.stderr.strip()}")
        return 1
    lines = re.split(r"\r?\n", r.stdout)
    in_service = False
    current = ""
    out = []
    for line in lines:
        m = re.match(r"^\s{2}(\w[\w\-]*):\s*$", line)
        if m:
            current = m.group(1)
            in_service = True
        if in_service and current in CONTAINERS and re.match(
                r"^\s{4}restart:\s+(always|unless-stopped)\s*$",
                line):
            line = re.sub(r"restart:\s+(always|unless-stopped)",
                          "restart: no", line)
            print(f"  Converted {current}: restart -> no")
        if in_service and re.match(r"^\s{2}\w", line) and not m:
            in_service = False
        out.append(line)
    new_content = "\n".join(out)
    w = subprocess.run(
        ["wsl", "-d", DISTRO, "--", "bash", "-c",
         f"cat > '{OVERRIDE}'"],
        input=new_content, text=True, capture_output=True)
    if w.returncode != 0:
        print(f"write failed: {w.stderr.strip()}")
        return 1
    print("docker-compose.override.yml updated successfully")
    return 0


if __name__ == "__main__":
    sys.exit(main())
