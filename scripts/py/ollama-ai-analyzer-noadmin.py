"""Port of tools/Variants/ollama-ai-analyzer-NoAdmin.bat — collects
CPU/memory/disk/process metrics to ai-analysis/*.json, then runs 4
ollama-batch-helper prompts (performance analysis, maintenance
predictions, optimization scripts, performance score).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

VARIANTS_DIR = Path(__file__).resolve().parents[1].parent / "tools" / "Variants"
OUT_DIR = VARIANTS_DIR / "ai-analysis"


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, **kw).returncode
    except FileNotFoundError:
        print(f"[WARNING] tool not found: {cmd[0]}")
        return 127


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
    return run(["cmd", "/c", str(bat), "-prompt", prompt,
                "-output", str(OUT_DIR / out)])

METRICS = [
    ("Get-WmiObject -Class Win32_Processor | Select-Object "
     "Name, LoadPercentage", "cpu-metrics.json"),
    ("Get-WmiObject -Class Win32_OperatingSystem | Select-Object "
     "TotalVisibleMemorySize, FreePhysicalMemory",
     "memory-metrics.json"),
    ("Get-WmiObject -Class Win32_LogicalDisk | Select-Object "
     "DeviceID, Size, FreeSpace", "disk-metrics.json"),
    ("Get-Process | Sort-Object CPU -Descending | Select-Object "
     "-First 10 Name, CPU, WorkingSet", "process-metrics.json"),
]

PROMPTS = [
    ("Analyze this Windows 11 system performance data and provide "
     "optimization recommendations. System: Intel i9-12900H, 32GB "
     "RAM, Windows 11 Build 26120. Focus on: 1) CPU optimization for "
     "20-thread processor 2) Memory management for 32GB RAM 3) "
     "Storage optimization across multiple drives 4) Process "
     "prioritization 5) Background service optimization. Provide "
     "specific actionable recommendations.",
     "performance-analysis.txt"),
    ("Based on Windows 11 Build 26120 system data, predict "
     "potential issues and maintenance needs. Consider: 1) Hardware "
     "health trends 2) Software update requirements 3) Performance "
     "degradation patterns 4) Security vulnerabilities 5) Storage "
     "optimization opportunities. Provide timeline-based "
     "recommendations for proactive maintenance.",
     "maintenance-predictions.txt"),
    ("Generate optimized batch scripts for Windows 11 Build 26120 "
     "with Intel i9-12900H. Create scripts for: 1) CPU performance "
     "optimization 2) Memory management 3) Storage optimization 4) "
     "Network optimization 5) Security hardening. Include specific "
     "registry tweaks, service configurations, and performance "
     "settings tailored for this exact system configuration.",
     "optimization-scripts.txt"),
    ("Calculate a comprehensive performance score for this Windows "
     "11 Build 26120 system with Intel i9-12900H and 32GB RAM. "
     "Consider: 1) CPU utilization efficiency (0-100) 2) Memory "
     "management effectiveness (0-100) 3) Storage performance "
     "(0-100) 4) System responsiveness (0-100) 5) Security posture "
     "(0-100). Provide overall score and specific improvement "
     "areas.", "performance-score.txt"),
]


def main():
    ap = argparse.ArgumentParser(
        description="Ollama AI System Analyzer")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.dry_run:
        print("[dry-run] collect 4 metric JSONs + 4 helper prompts")
        return 0
    for ps_cmd, dest in METRICS:
        ps_to_json(ps_cmd, OUT_DIR / dest)
    for prompt, out in PROMPTS:
        helper(prompt, out)
    score = OUT_DIR / "performance-score.txt"
    if score.exists():
        print(score.read_text(encoding="utf-8", errors="replace"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
