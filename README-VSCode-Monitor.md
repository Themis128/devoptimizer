# VS Code Insiders Intelligent Monitor v4.0

## What's New in v4.0

### 🧠 System-Aware Adaptive Thresholds
Thresholds automatically scale based on available system RAM. When free memory drops below 5GB, limits tighten proportionally. When WSL2 is consuming heavy memory, limits tighten further. Never drops below 50% of your base profile.

### 🎯 Smart Selective Kills
Instead of killing **all** VS Code processes when a threshold is hit, v4.0 surgically targets the heaviest processes first, preserving your main editor window. Only falls back to full kill when process count is exceeded (runaway spawning).

### 🔔 Windows Toast Notifications
Desktop balloon notifications for:
- Memory approaching limits (85%+ of threshold)
- Critical memory events (95%+)
- Process count warnings
- Health score drops below 20
- System RAM critically low (<1.5 GB free)
- After any kill event

### 📉 Compact Logging
Logs only when state **changes**, not every check cycle. Reduces log noise by ~80%. Full status logged every 20th check as a heartbeat. Extension host profiles logged every ~10 minutes.

### 🐧 WSL2 Memory Coordination
Monitors `vmmem` process alongside VS Code. When WSL2 is consuming >8GB, adaptive thresholds tighten to compensate. WSL memory included in health score.

### 🏥 Health Score Dashboard (0-100)
Single composite metric combining:
- Memory usage (35% weight)
- Process count (20%)
- Memory trend (15%)
- System free RAM (20%)
- WSL2 pressure (10%)

Grades: A (80+), B (60-79), C (40-59), D (20-39), F (<20)

### 🔍 Extension Host Profiling
Identifies and classifies VS Code processes as: MainWindow, ExtensionHost, Renderer, GPU, Utility, Worker. Profiles top 3 extension hosts by memory every ~10 minutes.

### 🔧 NODE_OPTIONS Suppression
Temporarily clears `NODE_OPTIONS` env var when launching VS Code to prevent Electron errors. Restores it afterward for Node.js processes in terminals.

### 🐚 Shell Integration
Launch with a specific default terminal shell:
```powershell
.\Launch-VSCode-Optimized.ps1 -Profile Heavy -Shell wsl
```
Options: `pwsh`, `bash`, `wsl`, `cygwin`, `cmd`

---

## Quick Start

### Desktop Shortcuts
- **VS Code Insiders (v4.0 Adaptive)** — Heavy profile with all v4.0 features
- Existing v3.0/Heavy/Light shortcuts now run v4.0 automatically

### Command Line
```powershell
# Heavy profile (recommended for your setup)
.\Launch-VSCode-Optimized.ps1 -Profile Heavy

# With specific workspace
.\Launch-VSCode-Optimized.ps1 -Profile Heavy -WorkspacePath "D:\Projects\my-portfolio-aws"

# Dry run (test mode)
.\Launch-VSCode-Optimized.ps1 -Profile Heavy -DryRun

# Light profile for simple editing
.\Launch-VSCode-Optimized.ps1 -Profile Light

# Show monitor window (visible)
.\Launch-VSCode-Optimized.ps1 -Profile Heavy -ShowMonitorWindow
```

### Monitor Dashboard
```powershell
# Live tail
Get-Content 'D:\DevOptimizer\logs\vscode-monitor-YYYYMMDD.log' -Wait -Tail 20
```

---

## Log Format (v4.0)

Compact format — only logs state changes:
```
[2026-02-15 22:10:10] [HEALTH] Health:72/100(B) | Procs:28/42 | Mem:7014/13926MB | Trend:STABLE(+12MB/chk) | Free:6.4GB | WSL:3.2GB | Scale:0.85x
[2026-02-15 22:15:27] [ADAPT]  Adaptive: scale=0.8x → Memory=13107MB, Procs=40 (Free RAM: 4.8GB, WSL: 3.5GB)
[2026-02-15 22:16:12] [KILL]   Selective cleanup: Total memory exceeds threshold
[2026-02-15 22:16:12] [KILL]     Killed PID 12345 [ExtensionHost] - 1820 MB (freed total: 1820 MB)
[2026-02-15 22:16:13] [SUCCESS] Selective kill complete: 1 processes, 1820 MB freed
```

---

## Profiles

| Setting | Light | Balanced | Heavy |
|---|---|---|---|
| Base Total Memory | 4 GB | 8 GB | 16 GB |
| Base Per-Process | 1 GB | 2 GB | 4 GB |
| Max Processes | 25 | 35 | 50 |
| Check Interval | 20s | 30s | 45s |

*All values adapt dynamically based on available system RAM.*

---

## Architecture

```
Launch-VSCode-Optimized.ps1 (v4.0)
├── Suppress NODE_OPTIONS for Electron
├── System memory pre-flight check
├── WSL2 memory pre-flight check
├── Start VSCode-AutoMonitor-Optimized.ps1 (hidden background)
│   ├── Adaptive threshold engine
│   ├── Process classification & profiling
│   ├── EMA-based trend analysis
│   ├── Health score computation
│   ├── Compact change-only logging
│   ├── Predictive alerts + toast notifications
│   ├── Smart selective kills (heaviest first)
│   └── Full kill (only for runaway process count)
├── Launch VS Code Insiders
└── Restore NODE_OPTIONS
```
