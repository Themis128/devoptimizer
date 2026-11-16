"""Port of tools/Variants/ollama-predictive-maintenance-NoAdmin.bat —
7-mode menu: health-scan, trend-analysis, failure-prediction,
auto-maintenance, performance-tracking, maintenance-plan,
report-generator. Collects WMI/counter JSONs to ai-analysis/ then
calls tools/ollama-batch-helper.bat prompts.
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

VARIANTS_DIR = Path(__file__).resolve().parents[1].parent / "tools" / "Variants"
OUT_DIR = VARIANTS_DIR / "ai-analysis"

SPEC = "Windows 11 Build 26120 with Intel i9-12900H"

MODES = {
    "health-scan": [
        ("Get-WmiObject -Class Win32_PhysicalMemory | Select-Object "
         "Capacity, Speed, Manufacturer", "hardware-health.json"),
        ("Get-WmiObject -Class Win32_DiskDrive | Select-Object "
         "Model, Size, Status", "disk-health.json"),
        ("Get-WmiObject -Class Win32_Processor | Select-Object "
         "Name, MaxClockSpeed, CurrentClockSpeed", "cpu-health.json"),
        ("Get-Counter '\\Processor(_Total)\\% Processor Time', "
         "'\\Memory\\Available MBytes', "
         "'\\PhysicalDisk(_Total)\\% Disk Time'",
         "performance-metrics.json"),
    ],
    "trend-analysis": [
        ("Get-Counter '\\Processor(_Total)\\% Processor Time' "
         "-SampleInterval 1 -MaxSamples 10", "cpu-trend.json"),
        ("Get-Counter '\\Memory\\Available MBytes' "
         "-SampleInterval 1 -MaxSamples 10", "memory-trend.json"),
        ("Get-Counter '\\PhysicalDisk(_Total)\\% Disk Time' "
         "-SampleInterval 1 -MaxSamples 10", "disk-trend.json"),
    ],
    "failure-prediction": [
        ("Get-WmiObject -Class Win32_PhysicalMemory | Select-Object "
         "Capacity, Speed, Manufacturer, Status",
         "memory-failure.json"),
        ("Get-WmiObject -Class Win32_DiskDrive | Select-Object "
         "Model, Size, Status, PowerOnHours", "disk-failure.json"),
        ("Get-WmiObject -Class Win32_Processor | Select-Object "
         "Name, MaxClockSpeed, CurrentClockSpeed, LoadPercentage",
         "cpu-failure.json"),
    ],
}

PROMPTS = {
    "health-scan": [
        ("Analyze Windows 11 Build 26120 system health data and "
         "identify potential issues. Focus on: 1) Hardware "
         "degradation signs 2) Performance bottlenecks 3) System "
         "stability issues 4) Security vulnerabilities 5) "
         "Maintenance requirements. Provide specific "
         "recommendations for each identified issue.",
         "health-analysis.txt"),
        ("Generate comprehensive system health report for "
         + SPEC + ". Include: 1) Overall health score (0-100) "
         "2) Critical issues requiring immediate attention 3) "
         "Warning signs to monitor 4) Preventive maintenance "
         "recommendations 5) Timeline for recommended actions.",
         "health-report.txt"),
    ],
    "trend-analysis": [
        ("Analyze performance trend data for " + SPEC + ". "
         "Identify: 1) Performance degradation trends 2) Peak "
         "usage patterns 3) Resource utilization trends 4) "
         "Potential bottlenecks 5) Optimization opportunities. "
         "Provide predictions for future performance "
         "requirements.", "trend-analysis.txt"),
    ],
    "failure-prediction": [
        ("Analyze Windows 11 Build 26120 system data to predict "
         "potential hardware failures. Focus on: 1) Memory "
         "failure indicators 2) Disk drive failure signs 3) CPU "
         "degradation patterns 4) System stability issues 5) "
         "Performance degradation trends. Provide failure "
         "probability scores and recommended actions.",
         "failure-prediction.txt"),
    ],
    "auto-maintenance": [
        ("Create automated maintenance schedule for " + SPEC +
         ". Include: 1) Daily maintenance tasks 2) Weekly "
         "maintenance routines 3) Monthly maintenance procedures "
         "4) Quarterly maintenance activities 5) Annual "
         "maintenance tasks. Generate batch scripts for each "
         "maintenance task.", "auto-maintenance.txt"),
        ("Generate batch scripts for automated maintenance of "
         "Windows 11 Build 26120. Create scripts for: 1) Disk "
         "cleanup 2) Registry optimization 3) Memory "
         "defragmentation 4) System file checking 5) Performance "
         "optimization. Ensure scripts are safe and reversible.",
         "maintenance-scripts.txt"),
    ],
    "performance-tracking": [
        ("Create performance tracking system for " + SPEC +
         ". Design: 1) Performance baseline establishment 2) "
         "Continuous monitoring setup 3) Performance trend "
         "tracking 4) Alert system for performance degradation "
         "5) Performance reporting dashboard. Generate tracking "
         "scripts and configuration.", "performance-tracking.txt"),
    ],
    "maintenance-plan": [
        ("Create comprehensive maintenance plan for " + SPEC +
         " (20 threads), 32GB RAM. Include: 1) Immediate "
         "maintenance tasks 2) Short-term maintenance schedule "
         "(1-3 months) 3) Long-term maintenance plan (6-12 "
         "months) 4) Hardware upgrade recommendations 5) "
         "Software update schedule. Provide specific timelines "
         "and priorities.", "maintenance-plan.txt"),
    ],
    "report-generator": [
        ("Generate comprehensive maintenance report for " + SPEC +
         ". Include: 1) Executive summary 2) System health "
         "overview 3) Performance analysis 4) Maintenance "
         "recommendations 5) Cost-benefit analysis 6) "
         "Implementation timeline 7) Risk assessment. Format as "
         "professional report.", "maintenance-report.txt"),
    ],
}

SHOW_FILE = {"health-scan": "health-report.txt",
             "trend-analysis": "trend-analysis.txt",
             "failure-prediction": "failure-prediction.txt",
             "auto-maintenance": "auto-maintenance.txt",
             "performance-tracking": "performance-tracking.txt",
             "maintenance-plan": "maintenance-plan.txt",
             "report-generator": "maintenance-report.txt"}


def ps_to_json(ps_cmd, dest):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with open(dest, "w") as f:
        subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass",
             "-Command",
             "try { " + ps_cmd + " | ConvertTo-Json } catch { '{}' }"],
            stdout=f, stderr=subprocess.DEVNULL)


def find_tool(name):
    for cand in (VARIANTS_DIR.parent / name,
                 VARIANTS_DIR / name,
                 VARIANTS_DIR / "tools" / name,
                 VARIANTS_DIR.parent / "tools" / name):
        if cand.exists():
            return cand
    return VARIANTS_DIR / "tools" / name


def helper(prompt, out):
    bat = find_tool("ollama-batch-helper.bat")
    try:
        return subprocess.run(
            ["cmd", "/c", str(bat), "-prompt", prompt,
             "-output", str(OUT_DIR / out)]).returncode
    except FileNotFoundError:
        print(f"[WARNING] not found: {bat}")
        return 127


def main():
    ap = argparse.ArgumentParser(
        description="Ollama predictive maintenance")
    ap.add_argument("mode", nargs="?", choices=list(PROMPTS))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    mode = args.mode
    if not mode:
        print("Modes:")
        for i, m in enumerate(PROMPTS, 1):
            print(f"  {i}) {m}")
        if not sys.stdin.isatty():
            print("Non-interactive launch: pass a mode, e.g. "
                  "`ollama-predictive-maintenance-noadmin.py health-scan`")
            return 0
        sel = input("Enter your choice (0-7): ").strip()
        if sel == "0" or not sel.isdigit() \
                or not 1 <= int(sel) <= 7:
            return 0
        mode = list(PROMPTS)[int(sel) - 1]
    if args.dry_run:
        print(f"[dry-run] mode {mode}")
        return 0
    for ps_cmd, dest in MODES.get(mode, []):
        ps_to_json(ps_cmd, OUT_DIR / dest)
    for prompt, out in PROMPTS[mode]:
        helper(prompt, out)
    show = OUT_DIR / SHOW_FILE[mode]
    if show.exists():
        print(show.read_text(encoding="utf-8", errors="replace"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
