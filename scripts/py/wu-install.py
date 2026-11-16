"""Windows Update install (Python port of tools/wu-install.ps1).

Searches pending updates, downloads, installs, reports — via the WU COM
API driven through a generated PowerShell block (the API has no managed
Python binding). Log contract + exit codes preserved:
  0 = installed/nothing-to-do, 1 = install failed, 2 = aborted stage.
Mutating.
"""

import argparse
import asyncio
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command_elevated  # noqa: E402

# CATEGORY: utilities
# TAGS: windows-update, com, elevated


def build_ps(log_path: str) -> str:
    # Same stages as the original: session -> search -> download -> install.
    return (
        "$ErrorActionPreference = 'Stop'; "
        f"$Log = '{log_path}'; "
        "\"=== WU install started $(Get-Date -Format s) ===\" "
        "| Out-File $Log -Encoding utf8; "
        "function Fail($stage, $detail) { "
        "  \"FATAL: $stage failed: $detail\" | Add-Content $Log; "
        "  \"=== WU install ABORTED $(Get-Date -Format s) ===\" | Add-Content $Log; "
        "  exit 2 }; "
        "try { $session = New-Object -ComObject Microsoft.Update.Session } "
        "catch { Fail 'WU COM session' $_.Exception.Message }; "
        "try { "
        "  'Searching...' | Add-Content $Log; "
        "  $result = $session.CreateUpdateSearcher().Search("
        "    'IsInstalled=0 and IsHidden=0') "
        "} catch { Fail 'search (is wuauserv running? network up?)' "
        "  $_.Exception.Message }; "
        "\"Found: $($result.Updates.Count) update(s)\" | Add-Content $Log; "
        "foreach ($u in $result.Updates) { \"  - $($u.Title)\" | Add-Content $Log }; "
        "if ($result.Updates.Count -eq 0) { "
        "  'NOTHING TO DO' | Add-Content $Log; exit 0 }; "
        "$coll = New-Object -ComObject Microsoft.Update.UpdateColl; "
        "foreach ($u in $result.Updates) { "
        "  try { if (-not $u.EulaAccepted) { $u.AcceptEula() } } "
        "  catch { \"  EULA note for $($u.Title): $($_.Exception.Message)\" "
        "    | Add-Content $Log }; "
        "  [void]$coll.Add($u) }; "
        "try { "
        "  $dl = $session.CreateUpdateDownloader(); "
        "  $dl.Updates = $coll; 'Downloading...' | Add-Content $Log; "
        "  $d = $dl.Download() "
        "} catch { Fail 'download' $_.Exception.Message }; "
        "\"Download result: $($d.ResultCode)\" | Add-Content $Log; "
        "if ($d.ResultCode -notin 2, 3) { Fail 'download' "
        "  \"ResultCode $($d.ResultCode)\" }; "
        "try { "
        "  $i = $session.CreateUpdateInstaller(); "
        "  $i.Updates = $coll; 'Installing...' | Add-Content $Log; "
        "  $inst = $i.Install() "
        "} catch { Fail 'install' $_.Exception.Message }; "
        "\"Install result: $($inst.ResultCode)\" | Add-Content $Log; "
        "for ($x = 0; $x -lt $coll.Count; $x++) { "
        "  $r = $inst.GetUpdateResult($x); "
        "  \"  [$($r.ResultCode)] $($coll.Item($x).Title)\" | Add-Content $Log }; "
        "if ($inst.RebootRequired) { 'REBOOT_REQUIRED' | Add-Content $Log }; "
        "\"=== WU install done $(Get-Date -Format s) ===\" | Add-Content $Log; "
        "exit ($(if ($inst.ResultCode -in 2, 3) { 0 } else { 1 }))"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--log", default=r"D:\DevOptimizer\logs\wu-install.log")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show the generated WU script without running it")
    args = parser.parse_args()

    ps = build_ps(args.log)
    if args.dry_run:
        print(f"[dry-run] would run WU install, log {args.log}:")
        print(ps)
        return

    result = asyncio.run(run_ps_command_elevated(ps, timeout=3600))
    print(result.stdout.strip(), file=sys.stderr)
    if result.returncode != 0:
        print(result.stderr.strip(), file=sys.stderr)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
