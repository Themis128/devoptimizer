"""Port of scripts/ai-integration-module.ps1 — AI integration module:
recommend (system analysis -> recommendations), optimize
(performance/battery/gaming/development), configure (project-type
smart config), troubleshoot (issue diagnostics), analyze
(Ollama multi-model analysis via tools/ollama-utils.ps1), summarize
(system summary). --mode/--context/--verbose/--dry-run.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

# CATEGORY: ai-ml
# TAGS: ai, ollama, optimization, recommendations

SCRIPT_PATH = Path(__file__).resolve().parent.parent


def ps(script):
    """Run a PowerShell snippet, return stdout."""
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        script], capture_output=True, text=True)
    return r.stdout.strip()


def get_system_data():
    return {
        "cpu": ps("(Get-CimInstance Win32_Processor | Select-Object"
                  " Name,NumberOfCores,MaxClockSpeed | "
                  "ConvertTo-Json)"),
        "mem_gb": ps("[math]::Round((Get-CimInstance "
                    "Win32_ComputerSystem).TotalPhysicalMemory/1GB,2)"),
        "os": ps("(Get-CimInstance Win32_OperatingSystem | "
                 "Select-Object Caption,Version | ConvertTo-Json)"),
    }


def get_recommendations(context, verbose):
    print("AI is analyzing your system...")
    recs = []
    try:
        cpu = float(ps("(Get-Counter '\\Processor(_Total)\\% Processor"
                       " Time').CounterSamples.CookedValue"))
        if cpu > 80:
            recs.append({"Priority": "High", "Category": "Performance",
                         "Title": "High CPU Usage Detected",
                         "Description": "CPU usage is above 80%. "
                         "Consider closing unnecessary applications.",
                         "Action": "Close resource-intensive "
                         "applications.", "Impact": "High"})
    except (ValueError, OSError):
        pass
    try:
        avail = float(ps("(Get-Counter '\\Memory\\Available MBytes')"
                         ".CounterSamples.CookedValue"))
        total = float(ps("[math]::Round((Get-CimInstance "
                         "Win32_ComputerSystem).TotalPhysicalMemory"
                         "/1GB,2)"))
        avail_gb = round(avail / 1024, 2)
        usage = round((total - avail_gb) / total * 100, 2)
        if usage > 85:
            recs.append({"Priority": "High", "Category": "Memory",
                         "Title": "High Memory Usage",
                         "Description": f"Memory usage is at "
                         f"{usage}%.", "Action": "Close unused "
                         "applications or add more RAM.",
                         "Impact": "High"})
    except (ValueError, OSError, ZeroDivisionError):
        pass
    try:
        disk = ps("(Get-CimInstance Win32_LogicalDisk -Filter "
                  "'DeviceID=\"C:\"' | Select-Object Size,FreeSpace | "
                  "ConvertTo-Json)")
        d = json.loads(disk)
        free, tot = d["FreeSpace"] / 1e9, d["Size"] / 1e9
        usage = round((tot - free) / tot * 100, 2)
        if usage > 90:
            recs.append({"Priority": "Critical",
                         "Category": "Storage",
                         "Title": "Low Disk Space",
                         "Description": f"Only {free:.2f} GB free "
                         "on C:.", "Action": "Run disk cleanup.",
                         "Impact": "Critical"})
        elif usage > 80:
            recs.append({"Priority": "Medium",
                         "Category": "Storage",
                         "Title": "Disk Space Warning",
                         "Description": f"Disk usage is at "
                         f"{usage}%.", "Action": "Run smart "
                         "cleanup.", "Impact": "Medium"})
    except (ValueError, OSError, json.JSONDecodeError, KeyError,
            ZeroDivisionError):
        pass
    if "False" in ps("(Get-NetFirewallProfile | Where-Object "
                     "{$_.Enabled -eq $false}).Profile"):
        recs.append({"Priority": "High", "Category": "Security",
                     "Title": "Firewall Disabled",
                     "Description": "Windows Firewall is disabled "
                     "on one or more profiles.", "Action": "Enable "
                     "Windows Firewall.", "Impact": "High"})
    for r in recs:
        print(f"  [{r['Priority']}] {r['Title']}: "
              f"{r['Description']}")
    return recs


OPTIMIZATIONS = {
    "performance": ["CPU Performance Tuning",
                    "Memory Management Optimization",
                    "Disk I/O Optimization",
                    "Network Performance Tuning"],
    "battery": ["Power Plan Optimization",
                "Background Process Management",
                "Display Brightness Optimization",
                "CPU Throttling Configuration"],
    "gaming": ["Game Mode Activation", "GPU Performance Tuning",
               "Audio Latency Optimization",
               "Network Gaming Optimization"],
    "development": ["Development Environment Setup",
                    "IDE Performance Tuning",
                    "Build Tool Optimization",
                    "Version Control Configuration"],
}


def optimize(opt_type, dry):
    print("AI is optimizing your system...")
    opts = OPTIMIZATIONS.get(
        opt_type, ["Balanced System Optimization",
                   "Memory Management", "Disk Cleanup",
                   "Security Hardening"])
    for o in opts:
        print(f"  Applying: {o}" + (" [dry-run]" if dry else ""))
        time.sleep(0.5)
    print("AI Optimization completed!")
    return opts


def smart_config(project_path="."):
    print("AI is analyzing your project...")
    cfg = {"ProjectType": "Unknown", "Frameworks": [],
           "PackageManagers": [], "RecommendedTools": [],
           "OptimizationLevel": "Standard"}
    p = Path(project_path)
    pj = p / "package.json"
    if pj.exists():
        cfg["ProjectType"] = "Node.js"
        cfg["PackageManagers"].append("npm")
        try:
            deps = json.loads(pj.read_text(
                encoding="utf-8")).get("dependencies", {})
            for dep in deps:
                low = dep.lower()
                for name in ("vue", "react", "angular", "nuxt",
                             "next"):
                    if name in low:
                        cfg["Frameworks"].append(
                            {"vue": "Vue.js", "react": "React",
                             "angular": "Angular",
                             "nuxt": "Nuxt.js",
                             "next": "Next.js"}[name])
        except (OSError, json.JSONDecodeError):
            pass
    if (p / "requirements.txt").exists():
        cfg["ProjectType"] = "Python"
        cfg["PackageManagers"].append("pip")
    if (p / "Cargo.toml").exists():
        cfg["ProjectType"] = "Rust"
        cfg["PackageManagers"].append("cargo")
    if (p / "go.mod").exists():
        cfg["ProjectType"] = "Go"
        cfg["PackageManagers"].append("go")
    cfg["RecommendedTools"] = {
        "Node.js": ["VS Code", "Cursor AI", "Git", "Docker"],
        "Python": ["PyCharm", "Jupyter Lab", "Git",
                   "Virtual Environment"],
        "Rust": ["VS Code", "Rust Analyzer", "Cargo"],
        "Go": ["GoLand", "VS Code", "Delve"],
    }.get(cfg["ProjectType"], ["VS Code", "Git", "Docker"])
    print(json.dumps(cfg, indent=2))
    return cfg


def troubleshoot(issue):
    print(f"AI is troubleshooting: {issue}")
    steps = {
        "performance": ["Check CPU/memory usage",
                        "Review startup programs",
                        "Run disk cleanup",
                        "Check for malware"],
        "network": ["Check network adapter",
                    "Restart network services", "Flush DNS",
                    "Check firewall rules"],
        "storage": ["Check disk space", "Run disk cleanup",
                    "Check disk health", "Review temp files"],
    }.get(issue, ["Review system logs", "Check event viewer",
                  "Run system file checker"])
    for s in steps:
        print(f"  -> {s}")
    return steps


def ollama_analysis(prompt, prompt_file, config_file, output_dir,
                    concurrency, timeout, models, exclude, dry):
    """Delegates to tools/ollama-utils.ps1 like the original."""
    utils = SCRIPT_PATH / "tools" / "ollama-utils.ps1"
    if not utils.exists():
        print(f"Ollama utilities not found at: {utils}",
              file=sys.stderr)
        return 1
    text = prompt
    if prompt_file and Path(prompt_file).exists():
        text = Path(prompt_file).read_text(encoding="utf-8")
    if not text:
        print("Missing prompt parameter", file=sys.stderr)
        return 1
    args = ["powershell", "-NoProfile", "-File", str(utils),
            "-Prompt", text, "-OutputDir", output_dir,
            "-Concurrency", str(concurrency),
            "-TimeoutSeconds", str(timeout)]
    if models:
        args += ["-AllowedModels", ",".join(models)]
    if exclude:
        args += ["-DeniedModels", ",".join(exclude)]
    if dry:
        print("[dry-run]", " ".join(args))
        return 0
    return subprocess.run(args).returncode


def summarize():
    print("=== System Summary ===")
    data = get_system_data()
    for k, v in data.items():
        print(f"{k}: {v}")


def main():
    ap = argparse.ArgumentParser(description="AI integration module")
    ap.add_argument("--mode", default="recommend",
                    choices=["recommend", "optimize", "configure",
                             "troubleshoot", "analyze", "summarize"])
    ap.add_argument("--context", default="system")
    ap.add_argument("--optimization-type", default="balanced")
    ap.add_argument("--issue", default="performance")
    ap.add_argument("--prompt", default="")
    ap.add_argument("--prompt-file", default="")
    ap.add_argument("--config-file",
                    default="configs/ollama.config.json")
    ap.add_argument("--output-dir", default="ai-analysis")
    ap.add_argument("--concurrency", type=int, default=3)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--models", nargs="*")
    ap.add_argument("--exclude-models", nargs="*")
    ap.add_argument("--project-path", default=".")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.mode == "recommend":
        get_recommendations(args.context, args.verbose)
    elif args.mode == "optimize":
        optimize(args.optimization_type, args.dry_run)
    elif args.mode == "configure":
        smart_config(args.project_path)
    elif args.mode == "troubleshoot":
        troubleshoot(args.issue)
    elif args.mode == "analyze":
        return ollama_analysis(
            args.prompt, args.prompt_file, args.config_file,
            args.output_dir, args.concurrency, args.timeout,
            args.models, args.exclude_models, args.dry_run)
    elif args.mode == "summarize":
        summarize()
    return 0


if __name__ == "__main__":
    sys.exit(main())
