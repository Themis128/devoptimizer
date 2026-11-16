"""Write the Cline MCP settings inside WSL (Python port of create-cline-mcp.ps1).

Creates cline_mcp_settings.json under the VS Code server globalStorage in
Ubuntu-24.04 via `wsl -d`. Mutating inside WSL.
"""

import argparse
import subprocess
import sys

# CATEGORY: utilities
# TAGS: cline, mcp, wsl, config

DISTRO = "Ubuntu-24.04"
SETTINGS_PATH = ("~/.vscode-server/data/User/globalStorage/"
                 "saoudrizwan.claude-dev/cline_mcp_settings.json")

SETTINGS_JSON = """{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/tbaltzakis"],
      "disabled": false,
      "autoApprove": []
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": ""
      },
      "disabled": true,
      "autoApprove": []
    },
    "sqlite": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sqlite", "/home/tbaltzakis/test.db"],
      "disabled": true,
      "autoApprove": []
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": ""
      },
      "disabled": true,
      "autoApprove": []
    },
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"],
      "disabled": false,
      "autoApprove": []
    },
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": ""
      },
      "disabled": true,
      "autoApprove": []
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"],
      "disabled": false,
      "autoApprove": []
    }
  }
}
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--distro", default=DISTRO)
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the JSON without writing it")
    args = parser.parse_args()

    if args.dry_run:
        print(f"[dry-run] would write {SETTINGS_PATH} in distro {args.distro}:")
        print(SETTINGS_JSON)
        return

    bash = (
        f"cat > {SETTINGS_PATH} << 'EOF'\n{SETTINGS_JSON}EOF\n"
        "echo Created\n"
        f"cat {SETTINGS_PATH}\n"
    )
    proc = subprocess.run(
        ["wsl", "-d", args.distro, "-e", "bash", "-c", bash],
        capture_output=True, text=True)
    if proc.returncode != 0:
        print(proc.stderr.strip() or "wsl write failed", file=sys.stderr)
        sys.exit(proc.returncode)
    print(proc.stdout)


if __name__ == "__main__":
    main()
