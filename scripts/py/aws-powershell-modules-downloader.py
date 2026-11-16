"""AWS PowerShell modules downloader (port of
tools/Variants/AWS-POWERSHELL-MODULES-DOWNLOADER-*.bat).

Sequential PowerShell installs: RemoteSigned exec policy, NuGet
provider, PowerShellGet, AWS.Tools.* modules + Install-AWSToolsModule
cleanup. --admin selects the admin variant (identical commands).
Mutating; --dry-run.
"""

import argparse
import subprocess
import sys

# CATEGORY: utilities
# TAGS: aws, powershell, modules, install

STEPS = [
    "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force",
    "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force",
    "Install-Module -Name PowerShellGet -Force -AllowClobber",
    "Install-Module -Name AWS.Tools.Common -Force -AllowClobber",
    "Install-Module -Name AWS.Tools.Installer -Force -AllowClobber",
    "Install-AWSToolsModule -CleanUp -Force",
    "Install-Module -Name AWS.Tools.Lambda -Force -AllowClobber",
    "Install-Module -Name AWS.Tools.CloudFormation -Force -AllowClobber",
    "Install-Module -Name AWS.Tools.S3 -Force -AllowClobber",
    "Install-Module -Name AWS.Tools.EC2 -Force -AllowClobber",
]


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    failed = 0
    for i, step in enumerate(STEPS, 1):
        cmd = ["powershell", "-Command", step]
        print(f"[{i}/{len(STEPS)}] {step}")
        if args.dry_run:
            print("    [dry-run] " + " ".join(cmd))
            continue
        r = subprocess.run(cmd)
        if r.returncode != 0:
            failed += 1
            print(f"    FAILED ({r.returncode})", file=sys.stderr)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
