"""Port of scripts/debug-config.ps1.

Loads DevOptimizer config via the config-loader module's JSON
output and prints the ollama section plus the full structure.
The module is still required (it isn't ported), so the port
invokes it through pwsh and renders the result in Python.
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE = REPO_ROOT / "modules" / "config-loader.ps1"

PROBE = (
    f'. "{MODULE}"; '
    'try { $c = Load-Configuration; '
    '  $o = @{ ok = $true; ollama = $c.ollama; '
    '          serverUrl = (Get-ConfigValue -Path '
    '"ollama.serverUrl"); '
    '          maxLoaded = (Get-ConfigValue -Path '
    '"ollama.maxLoaded"); '
    '          keepAlive = (Get-ConfigValue -Path '
    '"ollama.keepAliveSec"); '
    '          config = $c }; '
    '  $o | ConvertTo-Json -Depth 5 -Compress '
    '} catch { @{ ok = $false; error = '
    '$_.Exception.Message } | ConvertTo-Json -Compress }'
)


def main():
    pwsh = shutil.which("pwsh") or shutil.which("powershell")
    if not pwsh or not MODULE.exists():
        print(f"config-loader module not found: {MODULE}")
        return 1
    print("Loading configuration...")
    r = subprocess.run(
        [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-Command", PROBE],
        capture_output=True, text=True, cwd=str(REPO_ROOT))
    try:
        data = json.loads(r.stdout.strip() or "{}")
    except json.JSONDecodeError:
        print("Error: could not parse module output")
        print(r.stdout)
        print(r.stderr, file=sys.stderr)
        return 1
    if not data.get("ok"):
        print(f"Error: {data.get('error')}")
        return 1
    print("Configuration loaded successfully")
    print("\nChecking ollama section:")
    if data.get("ollama"):
        print("ollama section exists")
        for key in ("serverUrl", "maxLoaded", "keepAliveSec"):
            print(f"{key}: {(data.get('ollama') or {}).get(key)}")
        print("\nTesting Get-ConfigValue:")
        print(f"ollama.serverUrl: {data.get('serverUrl')}")
        print(f"ollama.maxLoaded: {data.get('maxLoaded')}")
        print(f"ollama.keepAliveSec: {data.get('keepAlive')}")
    else:
        print("ollama section does not exist")
    print("\nFull config structure:")
    print(json.dumps(data.get("config"), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
