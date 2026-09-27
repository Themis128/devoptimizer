# VS Code Insiders Intelligent Launcher - Complete Guide

## 📁 What Was Created

### Core Scripts
1. **Launch-VSCode-Optimized.ps1** - Smart launcher with profile support
2. **VSCode-AutoMonitor-Optimized.ps1** - Intelligent monitor with predictive alerts

### Desktop Shortcuts
1. **VS Code Insiders (Optimized v3.0).lnk** - Balanced profile (default)
2. **VS Code Insiders (Light Profile).lnk** - Lightweight (4GB limit)
3. **VS Code Insiders (Heavy Profile).lnk** - Heavy workloads (16GB limit)

---

## 🚀 Quick Start

### Choose Your Profile

| Profile | Best For | Memory Limit | Process Limit |
|---------|----------|--------------|---------------|
| **Light** | Simple editing, few extensions | 4 GB | 25 processes |
| **Balanced** | Standard development work | 8 GB | 35 processes |
| **Heavy** | Large projects, many extensions | 16 GB | 50 processes |

**Recommendation**: Start with Balanced, switch to Light if system is sluggish, or Heavy for intensive work.

---

## ✨ Major Improvements Over v2.0

### 1. Performance Profiles
- **Preset configurations** for different workload types
- Automatically adjusts all thresholds
- Easy switching via shortcuts or command line

### 2. Predictive Alerts
- Warns at **85% of limits** (before problems occur)
- No more sudden crashes
- Example: Alert at 6.8GB when limit is 8GB

### 3. Memory Trend Analysis
- Tracks memory over last 5 checks
- Classifies as: **RISING** / **FALLING** / **STABLE**
- Warns about rising trends before they become critical

### 4. Graceful Cleanup
- **First attempt**: Gracefully close windowed processes
- **Second attempt**: Force kill remaining processes
- **Verification**: Confirms all processes terminated
- **Statistics**: Tracks graceful vs forced kills

### 5. Enhanced Logging
- Detailed session statistics
- Performance metrics
- Alert history
- Automatic log rotation when file exceeds 10MB

### 6. Better User Experience
- Clear visual feedback with Unicode icons
- Color-coded messages
- Profile information display
- Real-time progress updates

### 7. Smarter Detection
- Checks for existing instances
- Prevents duplicate monitors
- Validates VS Code installation
- Auto-stops when VS Code closes

---

## 📊 Usage Examples

### Basic Usage (Double-Click Shortcuts)

```
# Balanced Profile (8GB limit)
Double-click: "VS Code Insiders (Optimized v3.0)"

# Light Profile (4GB limit) 
Double-click: "VS Code Insiders (Light Profile)"

# Heavy Profile (16GB limit)
Double-click: "VS Code Insiders (Heavy Profile)"
```

### Command Line Usage

```powershell
# Default balanced profile
.\Launch-VSCode-Optimized.ps1

# With workspace
.\Launch-VSCode-Optimized.ps1 -WorkspacePath "D:\Projects\my-portfolio-aws"

# Light profile
.\Launch-VSCode-Optimized.ps1 -Profile Light

# Heavy profile for intensive work
.\Launch-VSCode-Optimized.ps1 -Profile Heavy

# Test mode (monitor won't kill)
.\Launch-VSCode-Optimized.ps1 -DryRun

# Without monitor (standalone)
.\Launch-VSCode-Optimized.ps1 -NoMonitor

# Show monitor window (for debugging)
.\Launch-VSCode-Optimized.ps1 -ShowMonitorWindow
```

---

## 📈 What The Monitor Does

### Continuous Monitoring

Every 30 seconds (configurable), the monitor checks:

1. **Process Count** - Are there too many VS Code processes?
2. **Total Memory** - Is combined memory exceeding limits?
3. **Individual Bloat** - Are any single processes too large?
4. **Memory Trend** - Is usage rising, falling, or stable?

### Predictive Alerts (New!)

Alerts trigger at **85% of limits**:

```
🔔 PREDICTIVE ALERT: Memory at 87.3% of limit (7145/8192 MB)
🔔 PREDICTIVE ALERT: Memory trend is RISING - consider closing unused windows
🔔 PREDICTIVE ALERT: Process count at 91.4% of limit (32/35)
```

### Alert Cooldown
- Alerts have 5-minute cooldown to prevent spam
- Each alert type tracked separately

### Memory Trend Detection

The monitor tracks the last 5 measurements:

- **RISING**: Memory increasing (>50MB average change)
- **FALLING**: Memory decreasing (<-50MB average change)
- **STABLE**: Memory relatively constant (±50MB)

Example log output:
```
[2026-02-07 14:32:15] [INFO] Status: 28 processes, 6842.32 MB (6.68 GB), Trend: RISING
[2026-02-07 14:32:45] [INFO] Status: 28 processes, 7021.45 MB (6.86 GB), Trend: RISING
[2026-02-07 14:33:15] [ALERT] 🔔 PREDICTIVE ALERT: Memory at 85.7% of limit | Trend: RISING
```

### Cleanup Process

When thresholds are exceeded:

1. **Log the issue** with detailed stats
2. **Attempt graceful close** of windowed processes (2 second wait)
3. **Force kill** any remaining processes
4. **Verify cleanup** was successful
5. **Track statistics** (graceful vs forced kills)

---

## 📋 Monitoring Example

### Startup

```
╔════════════════════════════════════════════════════════════════╗
║      VS Code Insiders Intelligent Launcher v3.0 (Optimized)    ║
╚════════════════════════════════════════════════════════════════╝

📊 Performance Profile: Balanced
   Balanced - Standard resource limits
   • Max Total Memory: 8192 MB (8.0 GB)
   • Max Per-Process: 2048 MB
   • Max Process Count: 35
   • Check Interval: 30s

🛡️  Starting Intelligent Monitor...
   Mode: Active Protection
   ✓ Monitor Started (PID: 12345)
   • Predictive Alerts: Enabled
   • Memory Trend Analysis: Enabled
   • Performance Metrics: Enabled
   • Auto-Stop on VS Code Exit: Enabled
   • Log: vscode-monitor-20260207.log

🚀 Launching VS Code Insiders...
   ✓ VS Code Insiders Started (PID: 12350)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ VS Code Insiders Running with Balanced Protection!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Normal Operation

```log
[2026-02-07 14:30:00] [SUCCESS] VS Code Insiders Intelligent Monitor v3.0 Started
[2026-02-07 14:30:00] [INFO] Configuration: Total Memory: 8192 MB, Single: 2048 MB, Max Processes: 35
[2026-02-07 14:30:30] [INFO] Status: 15 processes, 2847.32 MB (2.78 GB), Trend: STABLE
[2026-02-07 14:31:00] [INFO] Status: 18 processes, 3124.56 MB (3.05 GB), Trend: RISING
[2026-02-07 14:31:30] [INFO] Status: 18 processes, 3298.21 MB (3.22 GB), Trend: RISING
```

### Predictive Alert

```log
[2026-02-07 14:45:00] [INFO] Status: 32 processes, 7012.43 MB (6.85 GB), Trend: RISING
[2026-02-07 14:45:00] [ALERT] 🔔 PREDICTIVE ALERT: Memory at 85.6% of limit (7012/8192 MB) | Trend is RISING
```

### Critical Cleanup

```log
[2026-02-07 15:00:00] [INFO] Status: 38 processes, 8456.78 MB (8.26 GB), Trend: RISING
[2026-02-07 15:00:00] [WARNING] Initiating cleanup: Total memory (8456.78 MB) exceeds threshold (8192 MB)
[2026-02-07 15:00:00] [WARNING] Target: 38 processes totaling 8456.78 MB
[2026-02-07 15:00:00] [INFO] Attempting graceful close of 3 windowed processes...
[2026-02-07 15:00:01] [SUCCESS] Gracefully closed PID 12350 (Memory: 456.23 MB)
[2026-02-07 15:00:02] [WARNING] Force killing 35 remaining processes...
[2026-02-07 15:00:03] [SUCCESS] All processes terminated
```

### Session End

```log
[2026-02-07 16:30:00] [INFO] No VS Code Insiders processes detected
[2026-02-07 16:35:00] [SUCCESS] VS Code Insiders closed. Monitor stopping.
[2026-02-07 16:35:00] [INFO] Session Statistics:
[2026-02-07 16:35:00] [INFO]   • Runtime: 125.5 minutes
[2026-02-07 16:35:00] [INFO]   • Total Checks: 251
[2026-02-07 16:35:00] [INFO]   • Alerts Sent: 3
[2026-02-07 16:35:00] [INFO]   • Processes Killed: 38
[2026-02-07 16:35:00] [INFO]   • Graceful Closes: 3
[2026-02-07 16:35:00] [INFO]   • Forced Kills: 35
```

---

## 🔧 Advanced Configuration

### Custom Profile Creation

Edit the launcher script to add your own profile:

```powershell
$profiles = @{
    # ... existing profiles ...
    
    Custom = @{
        TotalMemoryMB = 12288      # 12 GB
        SingleProcessMB = 3072      # 3 GB
        MaxProcessCount = 40
        CheckIntervalSec = 25
        Description = "Custom - Your specific needs"
    }
}
```

Then use: `.\Launch-VSCode-Optimized.ps1 -Profile Custom`

### Monitor Configuration

Directly configure the monitor:

```powershell
.\VSCode-AutoMonitor-Optimized.ps1 `
    -TotalMemoryThresholdMB 10240 `
    -SingleProcessThresholdMB 2560 `
    -MaxProcessCount 40 `
    -CheckIntervalSeconds 20 `
    -HideWindow
```

### Scheduled Task Integration

Create a task to launch VS Code with monitoring on login:

```powershell
$Action = New-ScheduledTaskAction `
    -Execute "pwsh.exe" `
    -Argument '-ExecutionPolicy Bypass -File "D:\DevOptimizer\Launch-VSCode-Optimized.ps1" -Profile Light'

$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

Register-ScheduledTask `
    -TaskName "Launch VS Code Insiders with Monitor" `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "Auto-launch VS Code Insiders with intelligent monitoring"
```

---

## 📊 View Real-Time Logs

### Tail the log file:

```powershell
Get-Content "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log" -Wait -Tail 20
```

### View today's alerts only:

```powershell
Get-Content "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log" | 
    Select-String "ALERT"
```

### Session statistics:

```powershell
Get-Content "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log" | 
    Select-String "Session Statistics" -Context 0,10
```

---

## 🎯 Profile Recommendations

### When to Use Light Profile (4GB)
- ✅ Simple text editing
- ✅ Reading documentation
- ✅ Small projects
- ✅ Older/slower machines
- ✅ Running alongside other heavy apps

### When to Use Balanced Profile (8GB) - DEFAULT
- ✅ Typical development work
- ✅ Multiple files open
- ✅ Standard extension load
- ✅ Most day-to-day tasks
- ✅ Good balance of performance and protection

### When to Use Heavy Profile (16GB)
- ✅ Large monorepo projects
- ✅ Many extensions installed
- ✅ Multiple workspace folders
- ✅ Heavy linting/formatting
- ✅ Debugging complex applications
- ✅ System has 32GB+ RAM

---

## 💡 Tips & Best Practices

### 1. Choose the Right Profile
Start with **Balanced** and adjust based on experience:
- Getting alerts? → Switch to **Heavy**
- System sluggish? → Switch to **Light**

### 2. Monitor Your Logs
Check logs occasionally to see patterns:
```powershell
notepad "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log"
```

### 3. Use Predictive Alerts
When you see a predictive alert:
- Close unused editor tabs
- Disable heavy extensions temporarily
- Close unused workspace folders
- Restart VS Code to clean up

### 4. Test Mode for Debugging
Use `-DryRun` to see what would be killed without actually killing:
```powershell
.\Launch-VSCode-Optimized.ps1 -DryRun -ShowMonitorWindow
```

### 5. Workspace-Specific Profiles
Create shortcuts for different projects:
- **Small project**: Use Light profile
- **Large project**: Use Heavy profile

### 6. Emergency Cleanup
If VS Code freezes or monitor fails:
```powershell
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force
```

---

## 🆚 Comparison: v2.0 vs v3.0

| Feature | v2.0 (Old) | v3.0 (Optimized) |
|---------|------------|------------------|
| **Profiles** | None | Light/Balanced/Heavy |
| **Predictive Alerts** | No | Yes (85% threshold) |
| **Trend Analysis** | No | Yes (RISING/FALLING/STABLE) |
| **Cleanup Method** | Force only | Graceful → Force |
| **Statistics Tracking** | Basic | Detailed (graceful vs forced) |
| **Log Rotation** | No | Yes (10MB limit) |
| **Alert Cooldown** | No | Yes (5 minutes) |
| **Process Verification** | No | Yes (confirms cleanup) |
| **Startup Validation** | Basic | Comprehensive |
| **User Feedback** | Minimal | Rich with colors/icons |
| **Command Line Options** | Limited | Extensive |
| **Documentation** | None | Comprehensive |

---

## 🔍 Troubleshooting

### Monitor Not Starting
```powershell
# Check if script exists
Test-Path "D:\DevOptimizer\VSCode-AutoMonitor-Optimized.ps1"

# Try manual launch with visible window
.\Launch-VSCode-Optimized.ps1 -ShowMonitorWindow
```

### VS Code Still Consuming Too Much Memory
```powershell
# Use Light profile
.\Launch-VSCode-Optimized.ps1 -Profile Light

# Or manually set lower limits
.\VSCode-AutoMonitor-Optimized.ps1 -TotalMemoryThresholdMB 4096
```

### Multiple Monitors Running
```powershell
# The script prevents this, but if it happens:
Get-Process pwsh | Where-Object { $_.CommandLine -like "*VSCode-AutoMonitor*" } | Stop-Process -Force
```

### Log File Too Large
The monitor automatically rotates logs at 10MB, but you can manually clean:
```powershell
Remove-Item "D:\DevOptimizer\logs\vscode-monitor-*.log" -Force
```

---

## 📁 File Locations

- **Launcher**: `D:\DevOptimizer\Launch-VSCode-Optimized.ps1`
- **Monitor**: `D:\DevOptimizer\VSCode-AutoMonitor-Optimized.ps1`
- **Cleanup**: `D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1`
- **Logs**: `D:\DevOptimizer\logs\vscode-monitor-YYYYMMDD.log`
- **Shortcuts**: `Desktop\VS Code Insiders (Optimized v3.0).lnk` + profile variants

---

## 🎓 Understanding the Metrics

### Memory Usage
- **Working Set** (what's displayed) = Physical RAM used
- **Private Bytes** (not displayed) = Process-specific memory
- We track Working Set because it affects system performance

### Process Count
VS Code spawns multiple processes:
- **Main window** - The editor UI
- **Extension host** - Runs extensions
- **Language servers** - TypeScript, ESLint, etc.
- **Terminal** - Integrated terminal
- **Background tasks** - File watching, indexing

Normal: 15-25 processes  
High: 30-40 processes  
Critical: 40+ processes

### Trend Analysis
Based on last 5 measurements (2.5 minutes of history):
- **STABLE**: ±50MB variation
- **RISING**: >50MB increase per interval
- **FALLING**: >50MB decrease per interval

---

## 🚦 Exit Codes

The launcher returns these exit codes for scripting:

- **0**: Success
- **1**: Error (VS Code failed to launch, monitor error)

The monitor logs but doesn't exit with error codes.

---

## 📞 Quick Reference Commands

```powershell
# Launch with balanced profile (default)
.\Launch-VSCode-Optimized.ps1

# Launch with workspace
.\Launch-VSCode-Optimized.ps1 -WorkspacePath "D:\Projects\my-app"

# Use light profile (4GB limit)
.\Launch-VSCode-Optimized.ps1 -Profile Light

# Use heavy profile (16GB limit)
.\Launch-VSCode-Optimized.ps1 -Profile Heavy

# Test mode (no killing)
.\Launch-VSCode-Optimized.ps1 -DryRun

# Without monitor protection
.\Launch-VSCode-Optimized.ps1 -NoMonitor

# View real-time logs
Get-Content "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log" -Wait -Tail 20

# Emergency cleanup
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force

# Check current VS Code processes
Get-Process "Code - Insiders" | Select-Object Id, @{N="MemoryMB";E={[math]::Round($_.WS/1MB,2)}}
```

---

**Created**: February 7, 2026  
**Version**: 3.0  
**Author**: Optimized for Themistoklis Baltzakis  
**Location**: Athens, Greece
