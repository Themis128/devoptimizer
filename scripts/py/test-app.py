"""Port of scripts/Test-App.ps1.

Runs the app's Pester 5 suite at tests\\app via Windows
PowerShell 5.1 (the app's real host). Ensures Pester
>=5 exists in CurrentUser scope first. -CI selects
normal output; -Tag forwards a tag filter. Exits 1 on
any failed test.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEST_DIR = ROOT / "tests" / "app"


def ps(cmd, timeout=600):
    host = Path(os.environ.get("SystemRoot", r"C:\Windows")) / \
        "System32" / "WindowsPowerShell" / "v1.0" / \
        "powershell.exe"
    exe = str(host) if host.exists() else "powershell"
    return subprocess.run([exe, "-NoProfile",
                           "-ExecutionPolicy", "Bypass",
                           "-Command", cmd],
                          capture_output=True,
                          text=True, timeout=timeout)


def ensure_pester():
    r = ps("$m = Get-Module -ListAvailable Pester | "
           "Where-Object { $_.Version.Major -ge 5 } | "
           "Sort-Object Version -Descending | "
           "Select-Object -First 1; "
           "if ($m) { $m.Version }")
    v = (r.stdout or "").strip()
    if v:
        return v
    print("Pester 5+ not found - installing to "
          "CurrentUser (no elevation)...")
    ps("[Net.ServicePointManager]::SecurityProtocol = "
       "[Net.SecurityProtocolType]::Tls12; "
       "try { $null = Get-PackageProvider -Name NuGet "
       "-ErrorAction Stop } catch { "
       "Install-PackageProvider -Name NuGet "
       "-MinimumVersion 2.8.5.201 -Force -Scope "
       "CurrentUser | Out-Null }; "
       "Install-Module Pester -MinimumVersion 5.5.0 "
       "-Scope CurrentUser -Force -SkipPublisherCheck "
       "-AllowClobber", timeout=1200)
    r = ps("(Get-Module -ListAvailable Pester | "
           "Where-Object { $_.Version.Major -ge 5 } | "
           "Sort-Object Version -Descending | "
           "Select-Object -First 1).Version")
    return (r.stdout or "").strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-CI", action="store_true")
    ap.add_argument("-Tag", default="")
    a = ap.parse_args()
    os.environ["DEVOPT_ROOT"] = str(ROOT)

    ver = ensure_pester()
    if not ver:
        print("Pester 5+ could not be installed or "
              "found.")
        return 1
    print(f"DevOptimizer app tests - Pester {ver}")
    tag = f" -Tag '{a.Tag}'" if a.Tag else ""
    output = "Normal" if a.CI else "Detailed"
    r = ps(
        "Import-Module Pester -MinimumVersion 5.0 "
        "-Force; "
        f"$res = Invoke-Pester -Path '{TEST_DIR}' "
        f"-Output {output} -PassThru{tag}; "
        "\"App tests: $($res.TotalCount) total, "
        "$($res.PassedCount) passed, "
        "$($res.FailedCount) failed\"; "
        "exit $res.FailedCount",
        timeout=3600)
    sys.stdout.write(r.stdout or "")
    sys.stderr.write(r.stderr or "")
    return 1 if r.returncode else 0


if __name__ == "__main__":
    sys.exit(main())
