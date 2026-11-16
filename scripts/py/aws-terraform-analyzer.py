"""AWS Terraform analyzer (port of
tools/Variants/AWS-TERRAFORM-ANALYZER-*.bat).

11-item menu of terraform commands writing reports to
%USERPROFILE%\\Desktop\\DevOptimizer\\Terraform-Reports\\. Resolves
terraform from PATH then the chocolatey shim. --choice N;
--admin variant.
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: aws, terraform, iac, menu

REPORTS = (Path.home() / "Desktop" / "DevOptimizer"
           / "Terraform-Reports")
TF_SHIM = (r"C:\ProgramData\chocolatey\lib\terraform\tools"
           r"\terraform.exe")


def tf() -> str:
    if Path(TF_SHIM).is_file():
        return TF_SHIM
    return shutil.which("terraform") or "terraform"


def run(args_: str, out_name: str, reports: Path, dry: bool):
    out = reports / out_name
    if dry:
        print(f"[dry-run] {tf()} {args_} > {out}")
        return
    reports.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as fh:
        subprocess.run(f'{tf()} {args_}', shell=True,
                       cwd=reports.parent, stdout=fh,
                       stderr=subprocess.STDOUT)


ACTIONS = [
    ("State Analysis", [
        ("init", None),
        ("show -json", "terraform-state.json"),
        ("state list", "terraform-resources.txt"),
        ("state show", "state-summary.txt"),
        ("version", "terraform-version.txt"),
        ("providers", "terraform-providers.txt")]),
    ("Resource Inventory", [
        ("state list", "resource-list.txt")]),
    ("Dependency Graph", [
        ("graph", "dependency-graph.dot"),
        ("graph -type=plan", "plan-graph.dot"),
        ("graph -type=apply", "apply-graph.dot"),
        ("graph -json", "dependency-graph.json")]),
    ("Drift Detection", [
        ("plan -detailed-exitcode", "drift-plan.txt")]),
    ("Cost Estimation", []),
    ("Security Analysis", []),
    ("Performance Analysis", []),
    ("Compliance Check", []),
    ("State Backup", [
        ("show -json", "state-backup.json")]),
    ("Workspace Management", [
        ("workspace list", "workspaces.txt")]),
    ("Complete Report", [
        ("show -json", "complete-report.json")]),
]


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def apply(choice: int, reports: Path, dry: bool):
    _name, cmds = ACTIONS[choice - 1]
    for args_, out in cmds:
        if out is None:
            print(f"[dry-run] {tf()} {args_}" if dry else
                  subprocess.run(f"{tf()} {args_}", shell=True)
                  or f"{tf()} {args_}")
        else:
            run(args_, out, reports, dry)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--choice", default="")
    p.add_argument("--reports", default=str(REPORTS))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)

    reports = Path(args.reports)
    if args.choice:
        if args.choice.isdigit() and 1 <= int(args.choice) <= 11:
            apply(int(args.choice), reports, args.dry_run)
        return
    if not sys.stdin.isatty():
        for i, (name, _) in enumerate(ACTIONS, 1):
            print(f"{i}. {name}")
        print("(non-interactive: pass --choice N)", file=sys.stderr)
        return
    for i, (name, _) in enumerate(ACTIONS, 1):
        print(f"{i}. {name}")
    c = input("Enter your choice (0-11): ").strip()
    if c.isdigit() and 1 <= int(c) <= 11:
        apply(int(c), reports, args.dry_run)


if __name__ == "__main__":
    main()
