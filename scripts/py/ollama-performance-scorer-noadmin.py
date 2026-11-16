"""Port of tools/Variants/ollama-performance-scorer-NoAdmin.bat.

10-mode scoring menu. Mode 1 collects perf-counter JSON into
tools/Variants/ai-analysis/, then every mode calls
tools/ollama-batch-helper.bat with a fixed prompt and prints the
result. Delegation keeps the ollama pipeline identical.
"""

import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
VARIANTS = REPO_ROOT / "tools" / "Variants"
BAT_HUB = VARIANTS
HELPER = VARIANTS / "tools" / "ollama-batch-helper.bat"
if not HELPER.exists():
    HELPER = REPO_ROOT / "tools" / "ollama-batch-helper.bat"
AI_DIR = VARIANTS / "ai-analysis"

MODES = {
    1: ("COMPREHENSIVE-SCORE",
        "Calculate comprehensive performance score for Windows 11 "
        "Build 26120 with Intel i9-12900H (20 threads), 32GB RAM. "
        "Analyze all collected performance data and provide: "
        "1) Overall performance score (0-1000) 2) CPU performance "
        "score (0-1000) 3) Memory performance score (0-1000) "
        "4) Storage performance score (0-1000) 5) Network "
        "performance score (0-1000) 6) System responsiveness score "
        "(0-1000) 7) Detailed analysis of each component "
        "8) Specific improvement recommendations 9) Performance "
        "ranking and comparison. Format as comprehensive "
        "performance report.",
        "comprehensive-score.txt"),
    2: ("CPU-PERFORMANCE",
        "Analyze Intel i9-12900H CPU performance on Windows 11 "
        "Build 26120. Focus on: 1) CPU utilization efficiency "
        "2) Core and thread performance 3) Cache performance "
        "4) Thermal performance 5) Power efficiency 6) Performance "
        "per watt 7) Multitasking capability 8) Single-threaded "
        "performance 9) Multi-threaded performance 10) Performance "
        "consistency. Provide detailed CPU performance score "
        "(0-1000) and optimization recommendations.",
        "cpu-performance-score.txt"),
    3: ("MEMORY-PERFORMANCE",
        "Analyze 32GB RAM performance on Windows 11 Build 26120 "
        "with Intel i9-12900H. Focus on: 1) Memory bandwidth "
        "utilization 2) Memory latency performance 3) Cache "
        "hierarchy efficiency 4) Memory allocation patterns "
        "5) Page file usage 6) Memory compression effectiveness "
        "7) Multi-threaded memory access 8) Memory pool management "
        "9) Garbage collection impact 10) Memory fragmentation. "
        "Provide detailed memory performance score (0-1000) and "
        "optimization recommendations.",
        "memory-performance-score.txt"),
    4: ("STORAGE-PERFORMANCE",
        "Analyze multi-drive storage performance on Windows 11 "
        "Build 26120. Drives: C: 672GB free, D: 145GB free, "
        "E: 135GB free. Focus on: 1) Sequential read/write "
        "performance 2) Random I/O performance 3) IOPS "
        "capabilities 4) Latency characteristics 5) Queue depth "
        "handling 6) Multi-drive coordination 7) File system "
        "efficiency 8) Storage space utilization "
        "9) Defragmentation status 10) Storage health indicators. "
        "Provide detailed storage performance score (0-1000) and "
        "optimization recommendations.",
        "storage-performance-score.txt"),
    5: ("NETWORK-PERFORMANCE",
        "Analyze network performance on Windows 11 Build 26120. "
        "Focus on: 1) Network bandwidth utilization 2) Latency "
        "characteristics 3) Packet loss rates 4) Connection "
        "stability 5) DNS resolution speed 6) Network adapter "
        "performance 7) TCP/IP stack optimization 8) Network "
        "security performance 9) Wireless vs wired performance "
        "10) Network congestion handling. Provide detailed network "
        "performance score (0-1000) and optimization "
        "recommendations.",
        "network-performance-score.txt"),
    6: ("SECURITY-PERFORMANCE",
        "Analyze security performance on Windows 11 Build 26120. "
        "Focus on: 1) Windows Defender effectiveness 2) Firewall "
        "configuration 3) User account security 4) System security "
        "policies 5) Network security posture 6) Application "
        "security 7) Data protection measures 8) Security update "
        "status 9) Vulnerability assessment 10) Security "
        "monitoring capabilities. Provide detailed security "
        "performance score (0-1000) and improvement "
        "recommendations.",
        "security-performance-score.txt"),
    7: ("RESPONSIVENESS-SCORE",
        "Analyze system responsiveness on Windows 11 Build 26120 "
        "with Intel i9-12900H. Focus on: 1) Boot time performance "
        "2) Application launch speed 3) System response time "
        "4) UI responsiveness 5) Context switching speed "
        "6) Process scheduling efficiency 7) System stability "
        "8) Error recovery time 9) Resource allocation speed "
        "10) Overall user experience. Provide detailed "
        "responsiveness score (0-1000) and optimization "
        "recommendations.",
        "responsiveness-score.txt"),
    8: ("BENCHMARK-COMPARISON",
        "Compare Windows 11 Build 26120 performance with Intel "
        "i9-12900H against industry benchmarks. Include: 1) CPU "
        "benchmark comparison 2) Memory benchmark comparison "
        "3) Storage benchmark comparison 4) Network benchmark "
        "comparison 5) Overall system benchmark comparison "
        "6) Performance ranking 7) Competitive analysis "
        "8) Optimization potential 9) Performance gaps "
        "10) Improvement opportunities. Provide detailed benchmark "
        "comparison report.",
        "benchmark-comparison.txt"),
    9: ("TREND-ANALYSIS",
        "Analyze performance trends for Windows 11 Build 26120 "
        "with Intel i9-12900H over time. Focus on: 1) Performance "
        "degradation trends 2) Improvement opportunities "
        "3) Seasonal performance patterns 4) Usage-based "
        "performance changes 5) Maintenance impact on performance "
        "6) Performance prediction models 7) Trend-based "
        "optimization recommendations 8) Performance "
        "sustainability 9) Long-term performance outlook "
        "10) Performance investment priorities. Provide detailed "
        "trend analysis report.",
        "trend-analysis.txt"),
}

# mode 1's Get-Counter/Get-WmiObject collection commands ->
# (step label, output filename, command)
COLLECT = [
    ("1/6", "cpu-score-data.json",
     r"try { Get-Counter '\Processor(_Total)\% Processor Time' "
     r"-SampleInterval 1 -MaxSamples 5 | ConvertTo-Json } "
     r"catch { '{}' }"),
    ("1/6", "cpu-detailed.json",
     r"try { Get-WmiObject -Class Win32_Processor | Select-Object "
     r"Name, MaxClockSpeed, CurrentClockSpeed, LoadPercentage "
     r"| ConvertTo-Json } catch { '{}' }"),
    ("2/6", "memory-score-data.json",
     r"try { Get-Counter '\Memory\Available MBytes', "
     r"'\Memory\Committed Bytes', '\Memory\Pool Nonpaged Bytes' "
     r"-SampleInterval 1 -MaxSamples 5 | ConvertTo-Json } "
     r"catch { '{}' }"),
    ("2/6", "memory-detailed.json",
     r"try { Get-WmiObject -Class Win32_PhysicalMemory | "
     r"Select-Object Capacity, Speed, Manufacturer | "
     r"ConvertTo-Json } catch { '{}' }"),
    ("3/6", "storage-score-data.json",
     r"try { Get-Counter '\PhysicalDisk(_Total)\% Disk Time', "
     r"'\PhysicalDisk(_Total)\Avg. Disk Queue Length', "
     r"'\PhysicalDisk(_Total)\Disk Read Bytes/sec', "
     r"'\PhysicalDisk(_Total)\Disk Write Bytes/sec' "
     r"-SampleInterval 1 -MaxSamples 5 | ConvertTo-Json } "
     r"catch { '{}' }"),
    ("3/6", "storage-detailed.json",
     r"try { Get-WmiObject -Class Win32_LogicalDisk | "
     r"Select-Object DeviceID, Size, FreeSpace, FileSystem | "
     r"ConvertTo-Json } catch { '{}' }"),
    ("4/6", "network-score-data.json",
     r"try { Get-Counter '\Network Interface(*)\Bytes Total/sec', "
     r"'\Network Interface(*)\Packets/sec' -SampleInterval 1 "
     r"-MaxSamples 5 | ConvertTo-Json } catch { '{}' }"),
    ("5/6", "responsiveness-data.json",
     r"try { Get-Counter '\System\Processor Queue Length', "
     r"'\System\Context Switches/sec' -SampleInterval 1 "
     r"-MaxSamples 5 | ConvertTo-Json } catch { '{}' }"),
]


def run_helper(prompt, out_name):
    out = AI_DIR / out_name
    AI_DIR.mkdir(exist_ok=True)
    if not HELPER.exists():
        print(f"  helper not found: {HELPER}")
        return 1
    rc = subprocess.run(
        ["cmd", "/c", str(HELPER), "-prompt", prompt,
         "-output", str(out)], cwd=str(VARIANTS)).returncode
    if out.exists():
        print(out.read_text(encoding="utf-8-sig",
                            errors="replace"))
    return rc


def comprehensive():
    for step, fname, cmd in COLLECT:
        print(f"[{step}] Collecting {fname} ...")
        pwsh = shutil.which("powershell") or "powershell"
        r = subprocess.run(
            [pwsh, "-ExecutionPolicy", "Bypass", "-Command", cmd],
            capture_output=True, text=True)
        AI_DIR.mkdir(exist_ok=True)
        (AI_DIR / fname).write_text(r.stdout or "{}",
                                    encoding="utf-8")
    print("[6/6] Calculating comprehensive performance score...")
    name, prompt, out_name = MODES[1]
    return run_helper(prompt, out_name)


def main():
    print("=" * 60)
    print("[INFO] Running in standard mode without Administrator "
          "privileges")
    print("[INFO] Some system-level features may be limited")
    print("        OLLAMA MULTI-MODEL PERFORMANCE SCORER")
    print("=" * 60)
    if not sys.stdin.isatty():
        for k in sorted(MODES):
            print(f"  [{k}] {MODES[k][0]}")
        return 0
    print()
    for k in sorted(MODES):
        print(f" [{k}]  {MODES[k][0]}")
    print(" [0] Back to main menu")
    sel = input("Enter your choice (0-9): ").strip()
    if sel == "0":
        return 0
    try:
        k = int(sel)
    except ValueError:
        print("Invalid choice.")
        return 1
    if k not in MODES:
        print("Invalid choice.")
        return 1
    name, prompt, out_name = MODES[k]
    print(f"\n {name} MODE")
    print("=" * 60)
    if k == 1:
        return comprehensive()
    return run_helper(prompt, out_name)


if __name__ == "__main__":
    sys.exit(main())
