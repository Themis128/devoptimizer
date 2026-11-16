"""Port of scripts/fix-bom.ps1.

Re-saves a fixed list of D:\\DevOptimizer scripts as
UTF-8 with BOM (skips files already BOM'd; validates as
strict UTF-8 before rewriting).
"""

import sys
from pathlib import Path

TARGETS = [
    r"D:\DevOptimizer\ps\Bootstrap-DevEnvironment.ps1",
    r"D:\DevOptimizer\ps\Collect-Metrics.ps1",
    r"D:\DevOptimizer\ps\Register-ScheduledTasks.ps1",
    r"D:\DevOptimizer\ps\Rollback-Changes.ps1",
    r"D:\DevOptimizer\ps\Run-Analysis.ps1",
    r"D:\DevOptimizer\ps\Security-Hardening.ps1",
    r"D:\DevOptimizer\ps\Uninstall-DevOptimizer.ps1",
    r"D:\DevOptimizer\ps\Verify-Installation.ps1",
    r"D:\DevOptimizer\scripts\ADVANCED-DIAGNOSTICS.ps1",
    r"D:\DevOptimizer\scripts\automation-module.ps1",
    r"D:\DevOptimizer\scripts\enhanced-event-log-checker.ps1",
    r"D:\DevOptimizer\scripts\enhanced-system-health.ps1",
    r"D:\DevOptimizer\scripts\overclocking-manager.ps1",
    r"D:\DevOptimizer\scripts\real-time-monitoring.ps1",
    r"D:\DevOptimizer\scripts\UNIFIED-LAUNCHER.ps1",
    r"D:\DevOptimizer\tools\normalize-bat-files-fixed.ps1",
    r"D:\DevOptimizer\tools\normalize-bat-files.ps1",
    r"D:\DevOptimizer\tools\ollama-analytics-dashboard.ps1",
    r"D:\DevOptimizer\tools\update-all-ollama-scripts.ps1",
    r"D:\DevOptimizer\Monitor-VSCodeInsiders.ps1",
    r"D:\DevOptimizer\VS-Code-Cleanup-Launcher.ps1",
    r"D:\DevOptimizer\vs.ps1",
    r"D:\DevOptimizer\vscode-insiders-extension-config.ps1",
    r"D:\DevOptimizer\Workspace-Launcher.ps1",
    r"D:\DevOptimizer\wsl.ps1",
]


def main():
    fixed = 0
    for f in TARGETS:
        p = Path(f)
        try:
            raw = p.read_bytes()
            if raw[:3] == b"\xef\xbb\xbf":
                print(f"skip (already BOM): {f}")
                continue
            text = raw.decode("utf-8")  # strict re-validate
            p.write_bytes(b"\xef\xbb\xbf"
                          + text.encode("utf-8"))
            fixed += 1
            print("BOM added: "
                  + f.replace("D:\\DevOptimizer\\", ""))
        except Exception as e:
            print(f"FAILED: {f} -> {e}")
    print(f"\n{fixed} files re-saved as UTF-8 with BOM")
    return 0


if __name__ == "__main__":
    sys.exit(main())
