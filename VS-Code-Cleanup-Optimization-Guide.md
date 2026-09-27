# VS Code Emergency Cleanup - Optimization Guide

## 📦 What's New

Your VS Code Emergency Cleanup script has been completely rewritten with enterprise-grade features while maintaining simplicity for quick use.

---

## 🆕 New Files Created

| File | Location | Purpose |
|------|----------|---------|
| **Optimized Script** | `D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1` | Main enhanced script |
| **Interactive Shortcut** | Desktop: `VS Code Emergency Cleanup (Optimized).lnk` | With confirmation prompt |
| **Force Kill Shortcut** | Desktop: `VS Code Force Kill.lnk` | Instant kill, no questions |
| **This Guide** | `D:\DevOptimizer\VS-Code-Cleanup-Optimization-Guide.md` | Usage documentation |

---

## ✨ Major Improvements

### 1. **Smart Process Detection**
- Detects multiple process name variants (`Code - Insiders`, `code-insiders`)
- Filters by process path to avoid false positives
- Distinguishes main windows from background workers
- Removes duplicates automatically

### 2. **Enhanced Memory Analysis**
```
📊 Process Analysis
────────────────────────────────────────────────────────
  Total Processes:      15
  Main Windows:         2
  Background Workers:   13
  Total Memory:         2847.32 MB (2.78 GB)

📋 Top Memory Consumers
────────────────────────────────────────────────────────
Id    Memory (MB) CPU (s) Type        Window/Path
----  ----------- ------- ----------- ---------------
12345 456.23      123.4   Main Window my-portfolio-aws...
12346 389.45      45.2    Background  Code - Insiders.exe
```

### 3. **Three-Stage Cleanup Process**
1. **Graceful Shutdown**: Attempts to close main windows cleanly
2. **Force Termination**: Kills all remaining processes
3. **Verification**: Ensures complete cleanup and retries if needed

### 4. **Conditional Execution**
- **Memory Threshold**: Only cleanup if exceeding specified MB
- **Confirmation Safety**: Shows what will be killed before acting
- **Active Window Detection**: Warns about unsaved work

### 5. **Performance Metrics**
```
✓ Cleanup completed successfully!
────────────────────────────────────────────────────────
  Processes terminated:  15
  Memory freed:          ~2847.32 MB
  Execution time:        2.34s
  Throughput:            6.4 processes/sec
```

---

## 🚀 Usage Scenarios

### Scenario 1: Daily Interactive Cleanup (RECOMMENDED)
**Use**: Desktop shortcut "VS Code Emergency Cleanup (Optimized)"

**What happens**:
1. Shows detailed process analysis
2. Warns about unsaved work
3. Asks for confirmation
4. Performs graceful shutdown first
5. Shows completion summary

**When to use**: End of workday, before system restart, when VS Code feels sluggish

---

### Scenario 2: Emergency Force Kill
**Use**: Desktop shortcut "VS Code Force Kill"

**What happens**:
- Immediately kills all processes
- No confirmation, no waiting
- Runs silently in hidden window

**When to use**: VS Code completely frozen, urgent system maintenance needed

---

### Scenario 3: Memory-Based Cleanup (PowerShell)
```powershell
# Only cleanup if using more than 3GB
D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1 -MemoryThreshold 3000
```

**What happens**:
- Checks memory usage first
- Only proceeds if over threshold
- Normal interactive flow if threshold exceeded

**When to use**: Scheduled tasks, startup scripts, automation

---

### Scenario 4: Silent Automated Cleanup
```powershell
# For scripts and scheduled tasks
D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -Silent
```

**What happens**:
- No console output
- No confirmation prompts
- Returns exit code for error handling

**When to use**: Windows Task Scheduler, startup/shutdown scripts, batch operations

---

## 📋 All Command-Line Parameters

```powershell
.\Cleanup-VSCodeInsiders-Optimized.ps1 [parameters]
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Force` | Switch | Off | Skip confirmation, kill immediately |
| `-MemoryThreshold` | Integer | 0 | Only cleanup if using more than X MB (0 = always) |
| `-Silent` | Switch | Off | No console output (requires `-Force`) |
| `-GracefulTimeout` | Integer | 2 | Seconds to wait for graceful close (0-30) |

### Parameter Combinations

```powershell
# Interactive with memory check
.\Cleanup-VSCodeInsiders-Optimized.ps1 -MemoryThreshold 2000

# Force kill with longer graceful period
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -GracefulTimeout 5

# Silent automated cleanup only if >4GB
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -Silent -MemoryThreshold 4000

# Force kill with no graceful period (instant)
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -GracefulTimeout 0
```

---

## 🔧 Advanced Automation

### Create Scheduled Task (Daily Cleanup)
```powershell
$Action = New-ScheduledTaskAction `
    -Execute "C:\Program Files\PowerShell\7\pwsh.exe" `
    -Argument '-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1" -Force -Silent -MemoryThreshold 3000'

$Trigger = New-ScheduledTaskTrigger -Daily -At 6PM

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName "VS Code Daily Cleanup" `
    -Description "Cleanup VS Code Insiders if using >3GB memory" `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -User $env:USERNAME
```

### Add to Windows Startup (Cleanup on Login)
```powershell
# Creates shortcut in Startup folder
$WshShell = New-Object -ComObject WScript.Shell
$Startup = [System.Environment]::GetFolderPath('Startup')
$Shortcut = $WshShell.CreateShortcut("$Startup\VS Code Cleanup.lnk")
$Shortcut.TargetPath = "C:\Program Files\PowerShell\7\pwsh.exe"
$Shortcut.Arguments = '-ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1" -Force -Silent'
$Shortcut.WindowStyle = 7
$Shortcut.Save()
```

### Integration with Other Scripts
```powershell
# Example: Cleanup before backing up
& "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1" -Force -Silent

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ VS Code cleaned up successfully"
    # Continue with backup...
} elseif ($LASTEXITCODE -eq 2) {
    Write-Host "⚠ User cancelled cleanup"
} else {
    Write-Host "✗ Cleanup failed with exit code $LASTEXITCODE"
}
```

---

## 🎯 Exit Codes

| Code | Meaning | When It Happens |
|------|---------|-----------------|
| `0` | Success | All processes terminated successfully |
| `1` | Error | Exception during execution |
| `2` | Cancelled | User declined confirmation prompt |
| `3` | Partial | Some processes couldn't be terminated |

Use these in scripts for error handling:

```powershell
& "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1" -Force

switch ($LASTEXITCODE) {
    0 { Write-Host "Success!" }
    1 { Write-Host "Error occurred"; exit 1 }
    2 { Write-Host "User cancelled" }
    3 { Write-Host "Partial cleanup - reboot may be needed" }
}
```

---

## 📊 Performance Comparison

| Metric | Old Script | Optimized |
|--------|------------|-----------|
| **Process Detection** | Single name only | Multiple variants + path filtering |
| **Memory Analysis** | Total only | Per-process + top 12 breakdown |
| **Cleanup Method** | Force kill only | Graceful → Force → Verify |
| **Output** | Basic text | Color-coded with Unicode icons |
| **Flexibility** | Manual only | 4 parameters + exit codes |
| **Safety** | Basic warning | Detailed analysis + active window list |
| **Automation** | None | Full support with silent mode |
| **Performance Tracking** | None | Duration + throughput metrics |
| **Error Handling** | Basic | Comprehensive with retry logic |

---

## 💡 Pro Tips

### 1. **Quick Access via Run Dialog**
Create a shorter path:
```powershell
New-Item -ItemType SymbolicLink `
    -Path "C:\VSCleanup.ps1" `
    -Target "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1"
```
Then press `Win+R` and type: `pwsh -File C:\VSCleanup.ps1 -Force`

### 2. **Keyboard Shortcut for Force Kill**
Right-click "VS Code Force Kill" shortcut → Properties → Shortcut key: `Ctrl+Alt+K`

### 3. **Monitor Memory Before Cleanup**
```powershell
# Check current memory usage
Get-Process "Code - Insiders" -ErrorAction SilentlyContinue | 
    Measure-Object -Property WorkingSet64 -Sum | 
    Select-Object @{N="TotalMB";E={[math]::Round($_.Sum/1MB,2)}}
```

### 4. **Create Custom Threshold Shortcuts**
Make multiple shortcuts with different thresholds:
- "Cleanup if >1GB" → `-MemoryThreshold 1000`
- "Cleanup if >3GB" → `-MemoryThreshold 3000`
- "Cleanup if >5GB" → `-MemoryThreshold 5000`

### 5. **Combine with System Cleanup**
```powershell
# Full development environment reset
& "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1" -Force -Silent
Stop-Process -Name "node", "npm" -Force -ErrorAction SilentlyContinue
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
```

---

## 🐛 Troubleshooting

### Issue: "Some processes couldn't be terminated"
**Solution**: Run PowerShell as Administrator or restart Windows

### Issue: Script execution blocked
**Solution**: 
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: Shortcut doesn't work
**Solution**: Verify pwsh.exe path:
```powershell
Get-Command pwsh | Select-Object -ExpandProperty Source
```

### Issue: Silent mode not working
**Solution**: Always use `-Force` with `-Silent`:
```powershell
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -Silent
```

---

## 🔄 Updating from Old Script

Your old script continues to work. To fully transition:

1. **Test the new script**: Use the optimized shortcut a few times
2. **Update any automation**: Replace old script paths with new one
3. **Optional**: Delete old shortcut after confirming new one works
4. **Keep this guide**: Reference for all parameters and scenarios

---

## 📞 Quick Reference Card

```
╔════════════════════════════════════════════════════╗
║           VS CODE CLEANUP - QUICK REF             ║
╠════════════════════════════════════════════════════╣
║ Interactive:    Double-click optimized shortcut   ║
║ Force Kill:     Double-click force kill shortcut  ║
║ Memory Check:   -MemoryThreshold 3000             ║
║ Silent Mode:    -Force -Silent                    ║
║ No Graceful:    -GracefulTimeout 0                ║
╠════════════════════════════════════════════════════╣
║ Exit Codes:  0=Success  1=Error  2=Cancel  3=Part ║
╚════════════════════════════════════════════════════╝
```

---

## 🎓 Learning More

Check the script comments for detailed parameter documentation:
```powershell
Get-Help D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1 -Full
```

View all examples:
```powershell
Get-Help D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1 -Examples
```

---

**Last Updated**: February 2026  
**Script Version**: 2.0 (Optimized Edition)  
**Maintained By**: Themistoklis Baltzakis (@baltz)
