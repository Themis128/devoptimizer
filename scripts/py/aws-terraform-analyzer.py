"""AWS Terraform analyzer (port of
tools/Variants/AWS-TERRAFORM-ANALYZER-*.bat).

11-item menu of terraform commands run in the project dir
(--project, default cwd), writing reports to
%USERPROFILE%\\Desktop\\DevOptimizer\\Terraform-Reports\\. Resolves
terraform from PATH then the chocolatey shim. --choice N;
--admin variant.
"""

import argparse
import datetime
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: aws, terraform, iac, menu

REPORTS = (Path.home() / "Desktop" / "DevOptimizer"
           / "Terraform-Reports")
BACKUPS = (Path.home() / "Desktop" / "DevOptimizer"
           / "Terraform-Backups")
TF_SHIM = (r"C:\ProgramData\chocolatey\lib\terraform\tools"
           r"\terraform.exe")


def tf() -> str:
    if Path(TF_SHIM).is_file():
        return TF_SHIM
    return shutil.which("terraform") or "terraform"


def run(args_: str, out_name, reports: Path, project: Path,
        dry: bool, tool=None):
    exe = tool or tf()
    if out_name:
        out = reports / out_name
        if dry:
            print(f"[dry-run] {exe} {args_} > {out} (cwd={project})")
            return
        reports.mkdir(parents=True, exist_ok=True)
        with open(out, "w") as fh:
            subprocess.run(f'{exe} {args_}', shell=True,
                           cwd=project, stdout=fh,
                           stderr=subprocess.STDOUT)
    else:
        if dry:
            print(f"[dry-run] {exe} {args_} (cwd={project})")
            return
        subprocess.run(f'{exe} {args_}', shell=True, cwd=project)


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
        ("plan -detailed-exitcode", "drift-plan.txt"),
        ("plan -out=drift-plan.out", None),
        ("show -json drift-plan.out", "drift-plan.json")]),
    ("Cost Estimation", []),   # special-cased below
    ("Security Analysis", []),
    ("Performance Analysis", []),
    ("Compliance Check", []),
    ("State Backup", []),
    ("Workspace Management", [
        ("workspace list", "workspace-list.txt"),
        ("workspace show", "current-workspace.txt")]),
    ("Complete Report", [
        ("show -json", "complete-report.json")]),
]


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def cost_estimation(reports, project, dry):
    if shutil.which("infracost"):
        run("breakdown --path . --format json",
            "infracost-breakdown.json", reports, project, dry,
            tool="infracost")
        run("breakdown --path . --format table",
            "infracost-breakdown.txt", reports, project, dry,
            tool="infracost")
        run("summary --path .",
            "infracost-summary.txt", reports, project, dry,
            tool="infracost")
    else:  # terraform_cost_estimation fallback
        run("plan -out=cost-plan.out", None, reports, project, dry)
        run("show -json cost-plan.out", "cost-plan.json",
            reports, project, dry)


def security_analysis(reports, project, dry):
    if shutil.which("tfsec"):
        run(". --format json", "tfsec-results.json",
            reports, project, dry, tool="tfsec")
        run(". --format table", "tfsec-results.txt",
            reports, project, dry, tool="tfsec")
        run(". --format summary", "tfsec-summary.txt",
            reports, project, dry, tool="tfsec")
    else:  # basic_security_analysis: keyword scan of *.tf
        pats = {"security-keywords.txt":
                ("password", "secret", "key", "token"),
                "open-security-groups.txt": ("0.0.0.0/0",)}
        if dry:
            print(f"[dry-run] findstr on {project}\\*.tf")
            return
        reports.mkdir(parents=True, exist_ok=True)
        for name, needles in pats.items():
            hits = []
            for f in project.glob("*.tf"):
                for line in f.read_text(errors="ignore").splitlines():
                    if any(n in line.lower() for n in needles):
                        hits.append(f"{f.name}: {line.strip()}")
            (reports / name).write_text("\n".join(hits))


def performance_analysis(reports, project, dry):
    run("state list", "total-resources.txt", reports, project, dry)
    run('state list | findstr /i "aws_"', "aws-resources.txt",
        reports, project, dry)
    run("plan -out=perf-plan.out", "plan-performance.txt",
        reports, project, dry)


def compliance_check(reports, project, dry):
    if shutil.which("terraform-compliance"):
        run("-f . -t .", "compliance-results.txt",
            reports, project, dry, tool="terraform-compliance")
    else:  # basic_compliance_check
        pats = {"encryption-check.txt": ("encryption",),
                "logging-check.txt": ("logging",),
                "backup-check.txt": ("backup",)}
        if dry:
            print(f"[dry-run] findstr on {project}\\*.tf")
            return
        reports.mkdir(parents=True, exist_ok=True)
        for name, needles in pats.items():
            hits = []
            for f in project.glob("*.tf"):
                for line in f.read_text(errors="ignore").splitlines():
                    if any(n in line.lower() for n in needles):
                        hits.append(f"{f.name}: {line.strip()}")
            (reports / name).write_text("\n".join(hits))


def state_backup(project, dry):
    src = project / "terraform.tfstate"
    if not src.is_file():
        print("terraform.tfstate not found in project dir",
              file=sys.stderr)
        return
    stamp = datetime.datetime.now().strftime("%Y%m%d.%H%M%S")
    dest = BACKUPS / f"terraform.tfstate.backup.{stamp}"
    if dry:
        print(f"[dry-run] copy {src} -> {dest}")
        return
    BACKUPS.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    print(f"backed up -> {dest}")


def apply(choice: int, reports: Path, project: Path, dry: bool):
    if choice == 5:
        cost_estimation(reports, project, dry)
        return
    if choice == 6:
        security_analysis(reports, project, dry)
        return
    if choice == 7:
        performance_analysis(reports, project, dry)
        return
    if choice == 8:
        compliance_check(reports, project, dry)
        return
    if choice == 9:
        state_backup(project, dry)
        return
    _name, cmds = ACTIONS[choice - 1]
    for args_, out in cmds:
        run(args_, out, reports, project, dry)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--choice", default="")
    p.add_argument("--project", default=".")
    p.add_argument("--reports", default=str(REPORTS))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)

    reports = Path(args.reports)
    project = Path(args.project)
    if args.choice:
        if args.choice.isdigit() and 1 <= int(args.choice) <= 11:
            apply(int(args.choice), reports, project, args.dry_run)
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
        apply(int(c), reports, project, args.dry_run)


if __name__ == "__main__":
    main()
