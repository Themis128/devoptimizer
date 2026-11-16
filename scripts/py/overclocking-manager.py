"""Overclocking manager (Python port of overclocking-manager.ps1).

--status: CPU clock vs max, GPU info, OC software detection, power plan,
registry OC settings. --recommend: tailored guidance (laptop GPUs ->
undervolt, desktop -> Afterburner). --remove: deletes OC registry values.
Read-only by default.
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
# TAGS: overclocking, hardware, diagnostics

OC_SOFTWARE = ["MSI Afterburner", "Ryzen Master", "Intel XTU",
               "EVGA Precision X1", "Corsair iCUE", "ASUS GPU Tweak"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--recommend", action="store_true")
    parser.add_argument("--remove", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if not (args.status or args.recommend or args.remove):
        args.status = True  # original shows menu; CLI port defaults to status

    progs = ",".join(f"'{p}'" for p in OC_SOFTWARE)
    ps = (
        "$out = [ordered]@{}; "
        "$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1; "
        "$out.cpu = @{ name = $cpu.Name; cores = $cpu.NumberOfCores; "
        "  threads = $cpu.NumberOfLogicalProcessors; "
        "  maxGHz = [math]::Round($cpu.MaxClockSpeed/1000,2); "
        "  curGHz = [math]::Round($cpu.CurrentClockSpeed/1000,2) }; "
        "$out.cpu.overclocked = $out.cpu.curGHz -gt $out.cpu.maxGHz; "
        "$out.gpus = @(Get-CimInstance Win32_VideoController | "
        "  Where-Object { $_.Name -notlike '*Remote*' -and $_.Name -notlike '*Virtual*' } | "
        "  ForEach-Object { @{ name = $_.Name; "
        "    vramGB = [math]::Round($_.AdapterRAM/1GB,2); "
        "    laptop = ($_.Name -match 'Laptop|Mobile|GeForce.*M'); "
        "    vendor = $(if ($_.Name -match 'NVIDIA') {'NVIDIA'} "
        "      elseif ($_.Name -match 'AMD|Radeon') {'AMD'} "
        "      else {'Other'}) } }); "
        "$out.software = @(); "
        f"foreach ($p in @({progs})) {{ "
        "  if (Get-Process | Where-Object { $_.ProcessName -like \"*$p*\" } "
        "      -ErrorAction SilentlyContinue) { $out.software += $p } }; "
        "$pp = Get-CimInstance -Namespace 'root\\cimv2\\power' "
        "  -ClassName Win32_PowerPlan | Where-Object IsActive; "
        "$out.powerPlan = $pp.ElementName; "
        "$out.regOC = @(); "
        "foreach ($k in @('HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power',"
        "  'HKCU:\\SOFTWARE\\NVIDIA Corporation\\Global\\NVTweak')) { "
        "  if (Test-Path $k) { $out.regOC += $k } }; "
        "$out | ConvertTo-Json -Depth 4"
    )

    if args.remove:
        remove_ps = (
            "$removed = @(); "
            "foreach ($k in @('HKCU:\\SOFTWARE\\NVIDIA Corporation\\Global\\NVTweak')) { "
            f"  if (Test-Path $k) {{ {'# dry: ' if args.dry_run else ''}"
            "    $removed += $k } }; "
            "if (-not $env:DRY) { $removed | ForEach-Object { "
            "  Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue } }; "
            "$removed | ConvertTo-Json -Compress")
        if args.dry_run:
            remove_ps = ("$removed = @(); "
                         "foreach ($k in @('HKCU:\\SOFTWARE\\NVIDIA Corporation\\Global\\NVTweak')) { "
                         "  if (Test-Path $k) { $removed += $k } }; "
                         "$removed | ConvertTo-Json -Compress")
        r = asyncio.run(run_ps_command(remove_ps))
        removed = json.loads(r.stdout.strip() or "[]")
        if isinstance(removed, str):
            removed = [removed]
        print(("Would remove" if args.dry_run else "Removed")
              + f": {removed if removed else '(no OC registry values found)'}")
        return

    result = asyncio.run(run_ps_command(ps, timeout=120))
    if result.returncode != 0:
        print(result.stderr.strip() or "status query failed", file=sys.stderr)
        sys.exit(result.returncode)

    raw = result.stdout.strip()
    rep = json.loads(raw[raw.index("{"):]) if "{" in raw else {}

    if args.json:
        print(json.dumps(rep, indent=2))
        return

    cpu = rep.get("cpu", {})
    print("CPU Information")
    print(f"  {cpu.get('name')} — {cpu.get('cores')}c/{cpu.get('threads')}t, "
          f"{cpu.get('curGHz')}/{cpu.get('maxGHz')} GHz "
          + ("[OVERCLOCKED]" if cpu.get("overclocked") else ""))
    print("\nGPU Information")
    for g in rep.get("gpus") or []:
        print(f"  {g['name']} ({g['vendor']}, {g['vramGB']} GB)"
              + (" [LAPTOP]" if g.get("laptop") else ""))
    print(f"\nOC software running: {rep.get('software') or 'none'}")
    print(f"Power plan: {rep.get('powerPlan')}")
    print(f"OC registry keys: {rep.get('regOC') or 'none'}")

    if args.recommend:
        print("\nRecommendations")
        laptop = any(g.get("laptop") for g in rep.get("gpus") or [])
        nvidia = any(g.get("vendor") == "NVIDIA" for g in rep.get("gpus") or [])
        if laptop:
            print("  - Laptop GPU: thermal/power limits — prefer undervolting")
            print("    over overclocking; monitor temps closely")
        elif nvidia:
            print("  - NVIDIA desktop: MSI Afterburner / NVIDIA Control Panel, "
                  "conservative offsets")
        if rep.get("powerPlan") != "High performance":
            print("  - Enable High performance power plan for OC stability")


if __name__ == "__main__":
    main()
