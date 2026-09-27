# VS Code Insiders - What Changed

## 🎯 Quick Summary

Your VS Code launcher has been **completely redesigned** with intelligent features:

### ✅ What You Get Now

1. **3 Performance Profiles** - Light (4GB) / Balanced (8GB) / Heavy (16GB)
2. **Predictive Alerts** - Warns at 85% BEFORE hitting limits
3. **Memory Trend Analysis** - Detects RISING/FALLING/STABLE patterns
4. **Graceful Cleanup** - Tries to close windows nicely before force-killing
5. **Session Statistics** - Tracks everything: alerts, kills, runtime
6. **Smart Detection** - Prevents duplicate monitors, validates setup
7. **Auto Log Rotation** - Keeps log files under 10MB

---

## 📊 Desktop Shortcuts - Before & After

### ❌ OLD (Can be deleted)
- `VS Code Emergency Cleanup.lnk` → Basic force kill
- `VS Code Insiders (Enhanced v2.0).lnk` → Empty monitor script

### ✅ NEW (Use these)
- `VS Code Emergency Cleanup (Optimized).lnk` → Smart cleanup with stats
- `VS Code Insiders (Optimized v3.0).lnk` → Balanced profile (8GB)
- `VS Code Insiders (Light Profile).lnk` → Light profile (4GB)
- `VS Code Insiders (Heavy Profile).lnk` → Heavy profile (16GB)

---

## 🚀 Which Shortcut Should I Use?

### Daily Work → Use Optimized v3.0 (Balanced)
- **8GB memory limit**
- **35 process limit**
- Perfect for most development

### Light Editing → Use Light Profile
- **4GB memory limit**
- **25 process limit**
- When running other heavy apps
- For simple editing tasks

### Big Projects → Use Heavy Profile
- **16GB memory limit**
- **50 process limit**
- Large monorepos
- Many extensions
- Complex debugging

---

## 🆕 New Features Explained

### 1. Predictive Alerts (Game Changer!)

**OLD**: Killed when you hit 8GB  
**NEW**: Warns at 6.8GB (85% of 8GB)

Example alert:
```
🔔 PREDICTIVE ALERT: Memory at 87.3% of limit (7145/8192 MB)
🔔 Memory trend is RISING - consider closing unused windows
```

You get **advance warning** to close tabs/windows before forced cleanup!

### 2. Memory Trend Analysis

The monitor now tracks if memory is:
- **RISING** ⬆️ - Memory increasing (potential problem)
- **FALLING** ⬇️ - Memory decreasing (cleanup working)
- **STABLE** ➡️ - Memory steady (all good)

Combines with predictive alerts:
```
Status: 28 processes, 7021 MB (6.86 GB), Trend: RISING
🔔 ALERT: Memory at 85.7% and RISING
```

### 3. Graceful Cleanup

**OLD**: Immediately force-killed everything (data loss risk)  
**NEW**: 
1. Tries to close windows gracefully (saves work)
2. Waits 2 seconds
3. Force-kills only what remains
4. Tracks: "3 graceful closes, 32 forced kills"

### 4. Session Statistics

When VS Code closes, you get a summary:
```
Session Statistics:
  • Runtime: 125.5 minutes
  • Total Checks: 251
  • Alerts Sent: 3
  • Processes Killed: 38
  • Graceful Closes: 3
  • Forced Kills: 35
```

Helps you understand if you need a different profile!

### 5. Smart Startup Validation

Before launching, checks:
- ✅ VS Code Insiders is installed
- ✅ No duplicate monitors running
- ✅ Workspace path exists (if provided)
- ⚠️ Warns if VS Code already running

### 6. Auto Log Rotation

Logs automatically rotate at 10MB:
```
vscode-monitor-20260207.log  (current)
vscode-monitor-20260207-archive-143022.log  (old)
```

No more gigantic log files!

---

## 📈 Performance Impact

### Memory Management
- **Before**: Hard limit at 8GB → crash
- **After**: Alert at 6.8GB → graceful cleanup → only force if needed

### Process Lifecycle
- **Before**: Force kill all 38 processes
- **After**: Graceful close 3 windows → force kill remaining 35

### User Experience
- **Before**: No warning, sudden kill
- **After**: Predictive alert → time to save → cleanup

---

## 🎮 Quick Start Guide

### First Time Setup

1. **Delete old shortcuts** (optional but recommended):
   - VS Code Emergency Cleanup.lnk
   - VS Code Insiders (Enhanced v2.0).lnk

2. **Choose your default**:
   - Most users: `VS Code Insiders (Optimized v3.0)`
   - Low-resource PC: `VS Code Insiders (Light Profile)`
   - Power user: `VS Code Insiders (Heavy Profile)`

3. **Double-click** your chosen shortcut

4. **Monitor logs** (first day):
   ```powershell
   Get-Content "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log" -Wait -Tail 20
   ```

5. **Adjust if needed**:
   - Getting alerts? → Switch to Heavy
   - System slow? → Switch to Light

---

## 💡 Real-World Scenarios

### Scenario 1: Large Project Work
**Problem**: Working on `my-portfolio-aws` with 100+ files, memory grows to 12GB  
**Solution**: Use Heavy profile (16GB limit)  
**Result**: No interruptions during work session

### Scenario 2: Multiple Apps Running
**Problem**: Running Docker, Chrome, VS Code → system slow  
**Solution**: Use Light profile (4GB limit)  
**Result**: VS Code stays lean, system responsive

### Scenario 3: Extension Testing
**Problem**: Testing new extensions, memory spikes  
**Solution**: Get predictive alert at 85%  
**Action**: Close unused windows before hitting limit  
**Result**: Avoid forced cleanup, save work

### Scenario 4: Background Monitoring
**Problem**: VS Code running all day, memory creeps up  
**Solution**: Monitor detects RISING trend  
**Action**: Alert prompts closing unused tabs  
**Result**: Proactive memory management

---

## 🔍 How to Check It's Working

### 1. Launch VS Code
Double-click `VS Code Insiders (Optimized v3.0).lnk`

### 2. Open Task Manager
- Look for `Code - Insiders` processes
- Check memory usage

### 3. Open Log File
```powershell
notepad "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log"
```

You should see:
```
[2026-02-07 14:30:00] [SUCCESS] VS Code Insiders Intelligent Monitor v3.0 Started
[2026-02-07 14:30:30] [INFO] Status: 15 processes, 2847.32 MB (2.78 GB), Trend: STABLE
```

### 4. Test Predictive Alerts (Optional)
```powershell
# Launch with low threshold to trigger alert quickly
.\Launch-VSCode-Optimized.ps1 -DryRun -ShowMonitorWindow
# Then edit the monitor script to use TotalMemoryThresholdMB = 3000
```

---

## ⚡ Command Line Power User Guide

### Launch with Custom Settings
```powershell
cd D:\DevOptimizer

# Balanced profile
.\Launch-VSCode-Optimized.ps1

# With workspace
.\Launch-VSCode-Optimized.ps1 -WorkspacePath "\\wsl.localhost\Ubuntu\home\tbaltzakis\my-portfolio-aws"

# Light profile
.\Launch-VSCode-Optimized.ps1 -Profile Light

# Heavy profile
.\Launch-VSCode-Optimized.ps1 -Profile Heavy

# Test mode (monitor visible, no killing)
.\Launch-VSCode-Optimized.ps1 -DryRun -ShowMonitorWindow

# Without monitor (standalone VS Code)
.\Launch-VSCode-Optimized.ps1 -NoMonitor
```

### Manual Cleanup
```powershell
# Interactive cleanup with stats
.\Cleanup-VSCodeInsiders-Optimized.ps1

# Force kill immediately
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force

# Only cleanup if using >10GB
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -MemoryThreshold 10000

# Silent cleanup (no output)
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -Silent
```

### View Logs
```powershell
# Real-time tail
Get-Content "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log" -Wait -Tail 20

# View all alerts
Get-Content "D:\DevOptimizer\logs\vscode-monitor-*.log" | Select-String "ALERT"

# Session summaries
Get-Content "D:\DevOptimizer\logs\vscode-monitor-*.log" | Select-String "Session Statistics" -Context 0,10

# Today's activity
Get-Content "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log" | Select-String "Status:"
```

---

## 🎯 Profile Selection Decision Tree

```
Start Here
    |
    ├─ Do you have 32GB+ RAM?
    |   ├─ Yes → Heavy Profile (16GB limit)
    |   └─ No → Continue
    |
    ├─ Is your PC struggling with performance?
    |   ├─ Yes → Light Profile (4GB limit)
    |   └─ No → Continue
    |
    ├─ Working on large project with 50+ extensions?
    |   ├─ Yes → Heavy Profile (16GB limit)
    |   └─ No → Continue
    |
    └─ Normal development work
        └─ Balanced Profile (8GB limit) ← START HERE
```

---

## 📝 Configuration Files

All files are in `D:\DevOptimizer\`:

```
D:\DevOptimizer\
├── Launch-VSCode-Optimized.ps1          # Main launcher (NEW)
├── Launch-VSCode-Enhanced.ps1            # Old launcher (can delete)
├── VSCode-AutoMonitor-Optimized.ps1     # Monitor script (NEW)
├── VSCode-AutoMonitor-Enhanced.ps1      # Empty old monitor (can delete)
├── VSCode-AutoMonitor.ps1               # Basic old monitor (keep as fallback)
├── Cleanup-VSCodeInsiders-Optimized.ps1 # Smart cleanup (NEW)
├── Cleanup-VSCodeInsiders.ps1           # Basic cleanup (can delete)
├── VS-Code-Launcher-Guide.md            # Full guide (NEW)
├── VS-Code-Cleanup-Guide.md             # Cleanup guide (NEW)
└── logs\
    └── vscode-monitor-YYYYMMDD.log      # Daily logs (auto-created)
```

---

## 🚨 When to Use Emergency Cleanup

The separate cleanup tool is for emergencies:

### Use When:
- ✅ VS Code frozen/unresponsive
- ✅ Monitor stopped working
- ✅ Need to force restart
- ✅ Memory critically low
- ✅ System hanging

### Don't Use When:
- ❌ Normal shutdown (just close VS Code)
- ❌ Monitor is working fine
- ❌ Want to test something (use -DryRun instead)

**Quick Access**: Desktop shortcut `VS Code Emergency Cleanup (Optimized).lnk`

---

## 📞 Quick Help

### "I'm getting too many alerts"
→ Switch to **Heavy Profile** (16GB limit)

### "My system is slow"
→ Switch to **Light Profile** (4GB limit)

### "Monitor isn't starting"
→ Try: `.\Launch-VSCode-Optimized.ps1 -ShowMonitorWindow`

### "I want to see what's happening"
→ View logs: `Get-Content "D:\DevOptimizer\logs\vscode-monitor-$(Get-Date -Format 'yyyyMMdd').log" -Wait -Tail 20`

### "VS Code was force-killed and I lost work"
→ Use **Heavy Profile** to avoid cleanups, or respond to predictive alerts earlier

### "How do I go back to the old way?"
→ Use: `.\Launch-VSCode-Optimized.ps1 -NoMonitor`

---

## ✅ Recommended: Clean Up Old Files

Once you're happy with the new version:

```powershell
# Backup old files
New-Item -ItemType Directory -Path "D:\DevOptimizer\old" -Force
Move-Item "D:\DevOptimizer\Launch-VSCode-Enhanced.ps1" "D:\DevOptimizer\old\" -Force
Move-Item "D:\DevOptimizer\VSCode-AutoMonitor-Enhanced.ps1" "D:\DevOptimizer\old\" -Force
Move-Item "D:\DevOptimizer\Cleanup-VSCodeInsiders.ps1" "D:\DevOptimizer\old\" -Force

# Delete old desktop shortcuts
Remove-Item "C:\Users\baltz\OneDrive - University of Bolton\Desktop\VS Code Emergency Cleanup.lnk" -Force
Remove-Item "C:\Users\baltz\OneDrive - University of Bolton\Desktop\VS Code Insiders (Enhanced v2.0).lnk" -Force
```

---

**Quick Start**: Double-click `VS Code Insiders (Optimized v3.0).lnk` on your desktop!

**Need Help?**: Read `VS-Code-Launcher-Guide.md` for complete documentation.

**Created**: February 7, 2026  
**Version**: 3.0
