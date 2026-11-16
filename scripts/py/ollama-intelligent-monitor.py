"""Ollama intelligent monitor (port of
tools/Variants/ollama-intelligent-monitor-*.bat).

Menu of 9 monitoring-script generations; each calls the
ollama-batch-helper port with the original prompt and writes to
generated-scripts\\<name>-<rand>.bat. --choice N non-interactive;
--admin variant.
"""

import argparse
import random
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: ollama, monitor, generator, menu

HELPER = (Path(__file__).resolve().parent / "ollama-batch-helper.py")
OUT_DIR = Path(r"D:\DevOptimizer\generated-scripts")

SYS = ("Windows 11 Build 26120 with Intel i9-12900H")
PROMPTS = [
    ("Real-Time Monitoring", "real-time-monitor",
     f"Create a real-time monitoring script for {SYS}. Include: "
     "1) CPU usage monitoring 2) Memory usage tracking 3) Disk I/O "
     "monitoring 4) Network activity tracking 5) Process monitoring "
     "6) Temperature monitoring 7) Performance alerts 8) Data logging "
     "9) Web dashboard 10) Mobile notifications. Generate a "
     "comprehensive monitoring solution."),
    ("Alert System", "intelligent-alerts",
     f"Create intelligent alert system for {SYS}. Include: 1) CPU "
     "threshold alerts 2) Memory usage alerts 3) Disk space alerts "
     "4) Network anomaly alerts 5) Security event alerts 6) "
     "Performance degradation alerts 7) Hardware failure alerts "
     "8) Application crash alerts 9) System error alerts 10) Custom "
     "threshold alerts. Generate alert configuration and "
     "notification system."),
    ("Performance Tracking", "performance-tracking",
     f"Create performance tracking system for {SYS}. Include: "
     "1) Performance baseline establishment 2) Trend analysis "
     "3) Performance regression detection 4) Optimization "
     "opportunity identification 5) Performance prediction "
     "6) Comparative analysis 7) Performance reporting 8) Data "
     "visualization 9) Performance recommendations 10) Automated "
     "optimization triggers. Generate comprehensive tracking "
     "solution."),
    ("Security Monitoring", "security-monitoring",
     "Create security monitoring system for Windows 11 Build 26120. "
     "Include: 1) Windows Defender monitoring 2) Firewall activity "
     "tracking 3) User access monitoring 4) File system security "
     "monitoring 5) Network security monitoring 6) Application "
     "security monitoring 7) Registry security monitoring 8) "
     "Process security monitoring 9) Security event correlation "
     "10) Threat detection and response. Generate comprehensive "
     "security monitoring solution."),
    ("Resource Monitoring", "resource-monitoring",
     f"Create resource monitoring system for {SYS} (20 threads), "
     "32GB RAM. Include: 1) CPU core utilization monitoring "
     "2) Memory usage tracking 3) Storage I/O monitoring 4) Network "
     "bandwidth monitoring 5) Process resource usage 6) Service "
     "resource consumption 7) Application resource usage 8) System "
     "resource optimization 9) Resource leak detection 10) Resource "
     "allocation analysis. Generate comprehensive resource "
     "monitoring solution."),
    ("Network Monitoring", "network-monitoring",
     "Create network monitoring system for Windows 11 Build 26120. "
     "Include: 1) Network traffic monitoring 2) Bandwidth usage "
     "tracking 3) Connection monitoring 4) Latency monitoring "
     "5) Packet loss detection 6) Network security monitoring "
     "7) Application network usage 8) Network performance analysis "
     "9) Network optimization recommendations 10) Network "
     "troubleshooting tools. Generate comprehensive network "
     "monitoring solution."),
    ("System Health Monitoring", "health-monitoring",
     f"Create system health monitoring for {SYS}. Include: "
     "1) Hardware health monitoring 2) System stability monitoring "
     "3) Performance health tracking 4) Security health monitoring "
     "5) Network health monitoring 6) Storage health monitoring "
     "7) Application health monitoring 8) Service health monitoring "
     "9) System integrity monitoring 10) Health trend analysis. "
     "Generate comprehensive health monitoring solution."),
    ("Performance Dashboard", "performance-dashboard",
     f"Create performance dashboard for {SYS}. Include: "
     "1) Real-time performance metrics 2) Historical performance "
     "data 3) Performance comparisons 4) System health indicators "
     "5) Resource utilization charts 6) Performance alerts "
     "7) Optimization recommendations 8) System status overview "
     "9) Performance trends 10) Interactive dashboard interface. "
     "Generate comprehensive dashboard solution."),
    ("Notification System", "notification-system",
     "Create notification system for Windows 11 Build 26120. "
     "Include: 1) Windows notifications 2) Email notifications "
     "3) SMS notifications 4) Webhook notifications 5) Mobile app "
     "notifications 6) Desktop notifications 7) Sound alerts "
     "8) Visual alerts 9) Notification scheduling 10) Notification "
     "preferences. Generate comprehensive notification solution."),
]


def is_admin() -> bool:
    try:
        import ctypes
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def generate(idx: int, out_dir: Path, dry: bool) -> None:
    _label, slug, prompt = PROMPTS[idx - 1]
    out = out_dir / f"{slug}-{random.randint(0, 32767)}.bat"
    cmd = [sys.executable, str(HELPER), "--prompt", prompt,
           "--output", str(out)]
    if dry:
        cmd.append("--dry-run")
    subprocess.run(cmd)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--admin", action="store_true")
    p.add_argument("--choice", default="",
                   help="menu choice 1-9 for non-interactive runs")
    p.add_argument("--out-dir", default=str(OUT_DIR))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.admin and not is_admin():
        print("[ERROR] requires Administrator privileges.",
              file=sys.stderr)
        sys.exit(1)

    for i, (label, _s, _p) in enumerate(PROMPTS, 1):
        print(f"{i}. {label}")
    print("0. Exit")
    if args.choice:
        if not args.choice.isdigit() or not 1 <= int(args.choice) <= 9:
            sys.exit(0)
        generate(int(args.choice), Path(args.out_dir), args.dry_run)
        return
    if not sys.stdin.isatty():
        print("(non-interactive: pass --choice N)", file=sys.stderr)
        return
    choice = input("Enter your choice (0-9): ").strip()
    if choice.isdigit() and 1 <= int(choice) <= 9:
        generate(int(choice), Path(args.out_dir), args.dry_run)


if __name__ == "__main__":
    main()
