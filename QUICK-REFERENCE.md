# VS Code Insiders Optimization Suite - Quick Reference Card

## 🎮 Desktop Shortcuts (Just Double-Click!)

```
┌─────────────────────────────────────────────────────────────────┐
│  🎯 VS Code Manager          │  📊 VS Code Monitor              │
│  ─────────────────────────   │  ──────────────────────────      │
│  Interactive menu for all    │  Real-time process tracking      │
│  management tasks            │  with auto-cleanup at 3GB        │
│  • Status checks             │  • Live memory graphs            │
│  • Cleanup options           │  • Trend analysis                │
│  • System health             │  • Auto-cleanup when critical    │
│  • Memory reports            │  • Background monitoring         │
├─────────────────────────────────────────────────────────────────┤
│  🚀 VS Code Optimized        │  🚨 VS Code Emergency Cleanup    │
│  ───────────────────────     │  ────────────────────────────    │
│  Launch with pre-cleanup     │  Instant process termination     │
│  and optimizations           │  for emergency situations        │
│  • Cleans first              │  • No questions asked            │
│  • Reports initial status    │  • Force kill all processes      │
│  • Opens fresh instance      │  • Shows freed memory            │
└─────────────────────────────────────────────────────────────────┘
```

## ⚡ Quick Commands

### Emergency Situations
```powershell
# FASTEST - Just force kill everything now
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force

# Silent mode (no output, for scripts)
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -Silent
```

### Smart Cleanup
```powershell
# Only cleanup if using more than 2.5GB
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -MemoryThreshold 2500

# Interactive with confirmation
.\Cleanup-VSCodeInsiders-Optimized.ps1
```

### Monitoring
```powershell
# Basic monitoring (check every 5 seconds)
.\Monitor-VSCodeInsiders.ps1

# Aggressive auto-cleanup at 2GB
.\Monitor-VSCodeInsiders.ps1 -AutoCleanup -CriticalThreshold 2000

# Passive monitoring (check every 30 seconds, no auto-cleanup)
.\Monitor-VSCodeInsiders.ps1 -MonitorInterval 30
```

### Optimized Launch
```powershell
# Launch with cleanup
.\Start-VSCodeInsidersOptimized.ps1 -CleanFirst

# Launch in low memory mode
.\Start-VSCodeInsidersOptimized.ps1 -LowMemoryMode

# Open specific project with cleanup
.\Start-VSCodeInsidersOptimized.ps1 -CleanFirst -Path "D:\my-project"
```

## 📊 Memory Thresholds Guide

```
╔══════════════════════════════════════════════════════════════════╗
║  MEMORY LEVELS                                                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  🟢  0-2000 MB      │  NORMAL   │  No action needed             ║
║  ────────────────────────────────────────────────────────────   ║
║  Optimal performance                                             ║
║  All systems running smoothly                                    ║
║                                                                  ║
║  🟡  2000-3000 MB   │  WARNING  │  Monitor closely              ║
║  ────────────────────────────────────────────────────────────   ║
║  Elevated usage                                                  ║
║  Consider cleanup if performance degrades                        ║
║  Watch for continued growth                                      ║
║                                                                  ║
║  🟠  3000-4000 MB   │  HIGH     │  Cleanup recommended          ║
║  ────────────────────────────────────────────────────────────   ║
║  System starting to strain                                       ║
║  Performance may be affected                                     ║
║  Cleanup before continuing heavy work                            ║
║                                                                  ║
║  🔴  4000+ MB       │  CRITICAL │  Cleanup immediately!         ║
║  ────────────────────────────────────────────────────────────   ║
║  High memory pressure                                            ║
║  System performance degraded                                     ║
║  Risk of crashes or freezes                                      ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

## 🎯 Recommended Workflows

### Morning Routine
```
1. Double-click "VS Code Optimized"
2. Let it cleanup old processes
3. Start fresh with optimal performance
```

### During Development
```
If system feels slow:
1. Double-click "VS Code Manager"
2. Select Option 1 (Quick Status)
3. Review memory usage
4. Select Option 2 (Emergency Cleanup) if needed
```

### Background Monitoring (Recommended)
```
1. Double-click "VS Code Monitor"
2. Leave it running in background
3. It will auto-cleanup when memory exceeds 3GB
4. Check the visual graph periodically
```

### End of Day
```
1. Double-click "VS Code Emergency Cleanup (Optimized)"
2. Clean shutdown of all processes
3. System ready for next session
```

## 🔍 Troubleshooting Quick Fixes

### Problem: Script won't execute
```powershell
# Fix: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problem: Need admin rights
```powershell
# Right-click PowerShell 7
# Select "Run as Administrator"
# Navigate to D:\DevOptimizer
# Run script again
```

### Problem: Can't find processes
```powershell
# Verify VS Code Insiders is running
Get-Process -Name "Code - Insiders"
```

### Problem: Cleanup not working
```powershell
# Nuclear option - force kill via Task Manager
# Or use Windows Task Manager to end "Code - Insiders" processes
```

## 📈 Understanding the Monitor Display

```
╔════════════════════════════════════════════════════════════════╗
║       VS Code Insiders Real-Time Monitor & Auto-Cleanup       ║
╚════════════════════════════════════════════════════════════════╝

  Status: ✓ NORMAL  |  Trend: STABLE →
  
  📊 Processes: 15 total (2 windows, 13 background)
  💾 Memory: 1847.32 MB (1.80 GB)
  
  📈 Memory Trend (Last 50 samples):
  ░░░░░▓▓███████▓▓░░░░░░
  ░░░▓▓███████████▓▓░░░░
  ░▓▓█████████████▓▓░░░░    🟢 = Normal
  ▓██████████████████▓▓░    🟡 = Warning
  ███████████████████▓▓░    🔴 = Critical
  
  🔝 Top Memory Consumers:
    PID   |   MB | Title
   12345 |  456 | my-portfolio-aws - VS Code Insiders
   12346 |  389 | <Background Process>
   
  ⏱️  Next check in 5 seconds... (Ctrl+C to exit)
```

## 🎨 Color Coding Legend

```
🟢 GREEN   = Good / Normal / Success
🟡 YELLOW  = Warning / Elevated / Caution  
🔴 RED     = Critical / Error / Urgent
🔵 CYAN    = Headers / Information
⚪ GRAY    = Details / Secondary info
```

## 💡 Pro Tips

### Tip #1: Baseline Your System
```
Run Manager > Option 7 (System Health) when system is idle
Note your normal memory usage
Use this as reference for "normal" state
```

### Tip #2: Monitor During Heavy Tasks
```
Start Monitor before:
- Opening large projects
- Running multiple debuggers
- Extensive search operations
- Heavy extension usage
```

### Tip #3: Weekly Cleanup
```
Even if not experiencing issues:
- Run cleanup every Friday afternoon
- Keeps system fresh
- Prevents gradual degradation
```

### Tip #4: Check Process Count
```
If you see >20 processes:
- Many are likely orphaned
- Cleanup even if memory looks OK
- Prevents resource leaks
```

### Tip #5: Use Low Memory Mode
```
For large projects (>1GB):
.\Start-VSCodeInsidersOptimized.ps1 -LowMemoryMode
Reduces initial memory footprint by ~30%
```

## 📱 One-Line Commands for Common Tasks

```powershell
# Quick status check
Get-Process "Code - Insiders" | Measure-Object WorkingSet64 -Sum

# Count processes
(Get-Process "Code - Insiders").Count

# Total memory in GB
[math]::Round((Get-Process "Code - Insiders" | Measure-Object WorkingSet64 -Sum).Sum / 1GB, 2)

# Force kill immediately
Stop-Process -Name "Code - Insiders" -Force

# Check if running
Get-Process "Code - Insiders" -ErrorAction SilentlyContinue
```

## 🎓 When to Use What

```
┌────────────────────────────────────────────────────────────┐
│ SITUATION                     │  RECOMMENDED TOOL           │
├────────────────────────────────────────────────────────────┤
│ Daily startup                 │  VS Code Optimized         │
│ System feels slow             │  VS Code Manager           │
│ Need immediate cleanup        │  Emergency Cleanup         │
│ Long coding session           │  VS Code Monitor           │
│ Memory leak suspected         │  Manager > Memory Report   │
│ System health check           │  Manager > System Health   │
│ Automation/Scripting          │  Cleanup with -Force       │
│ Background protection         │  Monitor with -AutoCleanup │
└────────────────────────────────────────────────────────────┘
```

## ⚙️ Configuration Quick Reference

### Monitor Settings
```
-MonitorInterval <seconds>      # How often to check (default: 5)
-WarningThreshold <MB>          # Yellow warning level (default: 2000)
-CriticalThreshold <MB>         # Red critical level (default: 4000)
-AutoCleanup                    # Enable auto-cleanup
-Duration <minutes>             # How long to run (0 = forever)
```

### Cleanup Settings
```
-Force                          # Skip confirmation
-MemoryThreshold <MB>           # Only cleanup if exceeding
-Silent                         # No output (requires -Force)
```

### Launcher Settings
```
-CleanFirst                     # Cleanup before launch
-LowMemoryMode                  # Memory-optimized settings
-Extensions <mode>              # Default|Disable|DisableNonEssential
-Path <path>                    # Workspace to open
```

## 🎯 Exit Codes (for scripting)

```
0 = Success / Cleanup completed / No action needed
1 = Error / Cleanup failed / Script error
2 = User cancelled / Operation aborted
```

Example usage:
```powershell
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -Silent
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Cleanup successful"
} else {
    Write-Host "✗ Cleanup failed with code $LASTEXITCODE"
}
```

---

**💾 Save this document for quick reference!**

**📍 All scripts located in:** `D:\DevOptimizer\`  
**🖥️ All shortcuts located on:** Desktop  
**📚 Full documentation:** `D:\DevOptimizer\README.md`
