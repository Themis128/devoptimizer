"""Windows features manager (port of scripts/windows-features.ps1).

status / enable / disable / profile subcommands over
Get/Enable/Disable-WindowsOptionalFeature. Profiles: Developer, Gaming,
Server, Minimal, Custom. Optional-feature cmdlets need elevation;
--dry-run prints the PS instead.
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# REQUIRES: admin
# CATEGORY: utilities
# TAGS: windows-features, optional-features, wsl, hyper-v, iis

DEV_FEATURES = [
    "Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform",
    "Microsoft-Hyper-V-All", "IIS-WebServerRole", "IIS-WebServer",
    "NetFx4Extended-ASPNET45", "WCF-Services45", "TFTP",
    "TelnetClient", "SimpleTCP"]

ENABLE_MAP = {
    "wsl": [("Microsoft-Windows-Subsystem-Linux",
             "Windows Subsystem for Linux"),
            ("VirtualMachinePlatform", "Virtual Machine Platform")],
    "hyperv": [("Microsoft-Hyper-V-All", "Hyper-V Platform")],
    "iis": [("IIS-WebServerRole", "Internet Information Services"),
            ("IIS-WebServer", "World Wide Web Services"),
            ("IIS-CommonHttpFeatures", "Common HTTP Features"),
            ("IIS-HttpErrors", "HTTP Errors"),
            ("IIS-HttpRedirect", "HTTP Redirection"),
            ("IIS-ApplicationDevelopment",
             "Application Development Features"),
            ("IIS-NetFxExtensibility45", ".NET Extensibility 4.5"),
            ("IIS-ASPNET45", "ASP.NET 4.5")],
    "dotnet": [("NetFx4Extended-ASPNET45",
                ".NET Framework 4.5 Extended"),
               ("WCF-Services45", "WCF Services")],
    "containers": [("Containers", "Containers")],
}

DISABLE_MAP = {
    "legacy": [("LegacyComponents", "Legacy Components"),
               ("DirectPlay", "DirectPlay"),
               ("SimpleTCP", "Simple TCPIP Services")],
    "internet": [("Internet-Explorer-Optional-amd64",
                  "Internet Explorer 11"),
                 ("TFTP", "TFTP Client"),
                 ("TelnetClient", "Telnet Client")],
    "media": [("MediaPlayback", "Media Features"),
              ("WindowsMediaPlayer", "Windows Media Player")],
    "print": [("Printing-Foundation-Features",
               "Print and Document Services"),
              ("Printing-XPSServices-Features", "XPS Services")],
}

PROFILES = {
    "Development": (["wsl", "dotnet", "iis"], ["legacy", "media"]),
    "Gaming": (["dotnet"], ["legacy", "print", "internet"]),
    "Server": (["iis", "dotnet", "hyperv"],
               ["legacy", "media", "internet"]),
    "Minimal": ([], ["legacy", "internet", "media", "print"]),
    "Custom": ([], []),
}


def ps(script, dry):
    if dry:
        print("[dry-run] " + script)
        return 0, ""
    r = asyncio.run(run_ps_command(script, timeout=3600))
    out = (r.stdout + r.stderr).strip()
    if out:
        print(out)
    return r.returncode, r.stdout


def enable(names, dry):
    for name, disp in names:
        ps(f"Enable-WindowsOptionalFeature -Online -FeatureName "
           f"'{name}' -All -NoRestart | Out-Null; "
           f"Write-Host 'enabled {disp}'", dry)


def disable(names, dry):
    for name, disp in names:
        ps(f"$f = Get-WindowsOptionalFeature -Online -FeatureName "
           f"'{name}' -ErrorAction SilentlyContinue; "
           f"if ($f -and $f.State -eq 'Enabled') {{ "
           f"Disable-WindowsOptionalFeature -Online -FeatureName "
           f"'{name}' -NoRestart | Out-Null; "
           f"Write-Host 'disabled {disp}' }} "
           f"else {{ Write-Host 'skip {disp} (not enabled)' }}", dry)


def status(dry):
    feats = ", ".join(f"'{f}'" for f in DEV_FEATURES)
    rc, out = ps(
        "$f = Get-WindowsOptionalFeature -Online | "
        "Sort-Object FeatureName; "
        f"Write-Host ('Total: ' + $f.Count + ' | Enabled: ' + "
        "($f | ? {$_.State -eq 'Enabled'}).Count + ' | Disabled: ' + "
        "($f | ? {$_.State -eq 'Disabled'}).Count); "
        f"foreach ($n in @({feats})) {{ $x = $f | ? "
        "{$_.FeatureName -eq $n}; if ($x) { Write-Host "
        "('{0,-50} {1}' -f $x.DisplayName, $x.State) } }}", dry)
    return rc


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    e = sub.add_parser("enable")
    e.add_argument("features", nargs="+",
                   choices=list(ENABLE_MAP) + ["all"])
    d = sub.add_parser("disable")
    d.add_argument("features", nargs="+",
                   choices=list(DISABLE_MAP) + ["all"])
    pr = sub.add_parser("profile")
    pr.add_argument("profile", choices=list(PROFILES))
    dm = sub.add_parser("developer-mode")
    dm.add_argument("--off", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run

    if args.cmd == "status":
        sys.exit(status(dry))
    if args.cmd == "enable":
        keys = list(ENABLE_MAP) if "all" in args.features \
            else args.features
        enable([x for k in keys for x in ENABLE_MAP[k]], dry)
    elif args.cmd == "disable":
        keys = list(DISABLE_MAP) if "all" in args.features \
            else args.features
        disable([x for k in keys for x in DISABLE_MAP[k]], dry)
    elif args.cmd == "profile":
        en, dis = PROFILES[args.profile]
        print(f"Applying {args.profile} profile...")
        if args.profile == "Custom":
            status(dry)
        else:
            enable([x for k in en for x in ENABLE_MAP[k]], dry)
            if args.profile == "Development":
                ps("Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\"
                   "Microsoft\\Windows\\CurrentVersion\\"
                   "AppModelUnlock' -Name "
                   "'AllowDevelopmentWithoutDevLicense' -Value 1; "
                   "Write-Host 'DeveloperMode=1'", dry)
            disable([x for k in dis for x in DISABLE_MAP[k]], dry)
        print("NOTE: some changes may require a restart.")
    elif args.cmd == "developer-mode":
        val = "0" if args.off else "1"
        ps("Set-ItemProperty -Path "
           "'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion"
           "\\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense'"
           f" -Value {val}; Write-Host 'DeveloperMode={val}'", dry)


if __name__ == "__main__":
    main()
