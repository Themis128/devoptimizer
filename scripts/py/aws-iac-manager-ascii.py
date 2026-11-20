"""AWS IaC manager, ASCII menu (port of
tools/Variants/AWS-IAC-MANAGER-ASCII-*.bat).

Interactive 0-14 menu mapping each item to an `aws` CLI call
(table output). --admin selects the admin variant (checks net
session in the original; here it only labels the mode).
"""

import argparse
import subprocess
from pathlib import Path

# CATEGORY: utilities
# TAGS: aws, iac, cloudformation, menu

MENU = [
    ("Infrastructure Discovery", [
        lambda: subprocess.run(
            ["aws", "ec2", "describe-regions", "--output", "table"]),
        lambda: subprocess.run(
            ["aws", "ec2", "describe-availability-zones",
             "--output", "table"])]),
    ("CloudFormation Stack Information", [
        lambda: subprocess.run(
            ["aws", "cloudformation", "list-stacks",
             "--stack-status-filter", "CREATE_COMPLETE",
             "UPDATE_COMPLETE", "--output", "table"])]),
    ("Terraform State Analysis", []),  # prints terraform.tfstate
    ("EC2 Instance Management", [
        lambda: subprocess.run(
            ["aws", "ec2", "describe-instances", "--output", "table"])]),
    ("RDS Database Information", [
        lambda: subprocess.run(
            ["aws", "rds", "describe-db-instances",
             "--output", "table"])]),
    ("Load Balancer Information", [
        lambda: subprocess.run(
            ["aws", "elbv2", "describe-load-balancers",
             "--output", "table"])]),
    ("Security Group Analysis", [
        lambda: subprocess.run(
            ["aws", "ec2", "describe-security-groups",
             "--output", "table"])]),
    ("S3 Bucket Analysis", [
        lambda: subprocess.run(["aws", "s3", "ls"])]),
    ("Lambda Function Information", [
        lambda: subprocess.run(
            ["aws", "lambda", "list-functions",
             "--output", "table"])]),
    ("Cost Analysis", [
        lambda: subprocess.run(
            ["aws", "ce", "get-cost-and-usage", "--time-period",
             "Start=2024-01-01,End=2024-12-31", "--granularity",
             "MONTHLY", "--metrics", "BlendedCost",
             "--output", "table"])]),
    ("Resource Optimization", [
        lambda: subprocess.run(
            ["aws", "ec2", "describe-instances", "--filters",
             "Name=instance-state-name,Values=stopped",
             "--output", "table"])]),
    ("Complete Infrastructure Report", [
        lambda: subprocess.run(
            ["aws", "ec2", "describe-instances", "--output", "table"]),
        lambda: subprocess.run(
            ["aws", "rds", "describe-db-instances",
             "--output", "table"]),
        lambda: subprocess.run(["aws", "s3", "ls"]),
        lambda: subprocess.run(
            ["aws", "elbv2", "describe-load-balancers",
             "--output", "table"])]),
    ("AWS CLI Setup", [
        lambda: subprocess.run(["aws", "configure"])]),
    ("Sync All Resources", []),
]


def terraform_state() -> None:
    tf = Path("terraform.tfstate")
    print(tf.read_text() if tf.is_file()
          else "No terraform.tfstate found")


def menu() -> None:
    while True:
        print("\nAWS IaC Manager\n" + "=" * 40)
        for i, (name, _) in enumerate(MENU, 1):
            print(f"{i}. {name}")
        print("0. Exit")
        try:
            choice = int(input("\nEnter your choice (0-14): ").strip())
        except (ValueError, EOFError):
            continue
        if choice == 0:
            return
        if not 1 <= choice <= len(MENU):
            print("Invalid choice.")
            continue
        name, cmds = MENU[choice - 1]
        print(f"\n>> {name}")
        if "Terraform" in name:
            terraform_state()
        for fn in cmds:
            fn()


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.parse_args()
    menu()


if __name__ == "__main__":
    main()
