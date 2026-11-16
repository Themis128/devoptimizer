"""Manage startup apps (Python port of manage-startup-apps.ps1).

Disables optional startup entries in HKCU/HKLM Run keys, Startup folders,
and packaged-app StartupTasks (State=1). Keeps the mandatory list.
Mutating; --dry-run reports without removing.
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
# TAGS: startup, registry, cleanup

MANDATORY = ["Docker Desktop", "SecurityHealth", "Tailscale", "Nextcloud",
             "Telegram", "ntfy", "cdp-launch", "dmr-tunnel",
             "galaxy_s22_dashboard", "win_agent"]
DISABLE = ["OneDrive", "Microsoft.Lists", "Teams", "Adobe Acrobat Synchronizer",
           "Adobe Acrobat", "EPSDNMON", "EPLTarget", "WhatsApp",
           "MicrosoftEdgeAutoLaunch", "RtkAudUService", "EPPCCMON",
           "DataCollectionAgentController", "Logitech Download Assistant",
           "Logi Download Assistant", "LogiFetch", "Devin-Lower-Priority"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    mand = ",".join(f"'{m}'" for m in MANDATORY)
    dis = ",".join(f"'{d}'" for d in DISABLE)

    dry = "1" if args.dry_run else "0"
    ps = (
        f"$dry = {dry}; "
        f"$mand = @({mand}); $dis = @({dis}); "
        "function IsM($s) { foreach ($m in $mand) { if ($s -like \"*$m*\") { return $true } }; $false } "
        "function IsD($s) { foreach ($d in $dis) { if ($s -like \"*$d*\") { return $true } }; $false } "
        "$acts = @(); "
        "foreach ($root in @('HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',"
        "                   'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run')) { "
        "  $item = Get-ItemProperty $root -ErrorAction SilentlyContinue; "
        "  if (-not $item) { continue }; "
        "  foreach ($p in $item.PSObject.Properties) { "
        "    if ($p.Name -match '^PS') { continue }; "
        "    $n=$p.Name; $c=[string]$p.Value; "
        "    if (IsM $n -or IsM $c) { $acts += @{k='KEEP';n=$n;v=$c;src=$root} } "
        "    elseif ((IsD $n) -or (IsD $c)) { "
        "      $acts += @{k='DISABLE';n=$n;v=$c;src=$root}; "
        "      if (-not $dry) { Remove-ItemProperty $root -Name $n -ErrorAction SilentlyContinue } "
        "    } else { $acts += @{k='UNKNOWN-KEEP';n=$n;v=$c;src=$root} } "
        "  } "
        "}; "
        "foreach ($dir in @('C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\\StartUp',"
        "   (Join-Path $env:APPDATA 'Microsoft\\Windows\\Start Menu\\Programs\\Startup'))) { "
        "  Get-ChildItem $dir -ErrorAction SilentlyContinue | ForEach-Object { "
        "    if (IsM $_.Name) { $acts += @{k='KEEP';n=$_.Name;v='';src=$dir} } "
        "    else { $acts += @{k='DISABLE';n=$_.Name;v='';src=$dir}; "
        "      if (-not $dry) { $_ | Remove-Item -Force -ErrorAction SilentlyContinue } } "
        "  } "
        "}; "
        "$sad = 'HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\CurrentVersion\\AppModel\\SystemAppData'; "
        "Get-ChildItem $sad -ErrorAction SilentlyContinue | ForEach-Object { "
        "  $pkg = $_.PSChildName; if (-not (IsD $pkg)) { return }; "
        "  Get-ChildItem $_.PSPath | ForEach-Object { "
        "    $pr = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue; "
        "    if ($null -ne $pr.State -and $pr.State -eq 2) { "
        "      $acts += @{k='DISABLE';n=($pkg + ' ' + $_.PSChildName);v='StartupTask';src=$sad}; "
        "      if (-not $dry) { Set-ItemProperty $_.PSPath -Name State -Value 1 -Type DWord } "
        "    } } }; "
        "$acts | ConvertTo-Json -Compress -Depth 3"
    )

    result = asyncio.run(run_ps_command(ps, timeout=120))
    if result.returncode != 0:
        print(result.stderr.strip() or "startup sweep failed", file=sys.stderr)
        sys.exit(result.returncode)

    raw = result.stdout.strip()
    acts = json.loads(raw) if raw else []
    if isinstance(acts, dict):
        acts = [acts]

    if args.json:
        print(json.dumps({"dryRun": args.dry_run, "actions": acts}, indent=2))
        return

    print("=== Startup App Management ===")
    for a in acts:
        print(f"  {a['k']:14} [{a['n']}] {a['v']}  ({a['src']})")
    print(f"\n{len(acts)} entries evaluated"
          + (" (dry-run, nothing changed)" if args.dry_run else ""))


if __name__ == "__main__":
    main()
