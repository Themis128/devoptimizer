# VS Code Emergency Cleanup - Quick Reference

## 📁 Files Created
- **Optimized Script**: `D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1`
- **Desktop Shortcut**: `VS Code Emergency Cleanup (Optimized).lnk`

## 🚀 Usage Options

### 1. Double-Click Shortcut (Interactive Mode)
Just double-click the desktop shortcut for interactive cleanup with confirmation.

### 2. Command Line Options

```powershell
# Interactive mode with confirmation
.\Cleanup-VSCodeInsiders-Optimized.ps1

# Force kill without confirmation
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force

# Only kill if using more than 2GB memory
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -MemoryThreshold 2000

# Silent mode (no output, requires -Force)
.\Cleanup-VSCodeInsiders-Optimized.ps1 -Force -Silent
```

## ✨ Key Improvements

### Smart Detection
- Detects all VS Code Insiders process types
- Distinguishes main windows from background processes
- Filters out regular VS Code to avoid accidental kills

### Memory Intelligence
- Shows detailed memory usage per process
- Optional memory threshold to only cleanup when needed
- Calculates total memory that will be freed

### Safe Cleanup
- Attempts graceful window close first
- Falls back to force kill if needed
- Verifies all processes are terminated
- Shows cleanup duration and statistics

### Better UX
- Color-coded output with icons
- Detailed process analysis before killing
- Top 10 memory consumers list
- Clear warnings about unsaved work

### Automation Ready
- Silent mode for scheduled tasks
- Exit codes for scripting (0=success, 1=error, 2=cancelled)
- Memory threshold for conditional cleanup
- Force mode for emergency situations

## 📊 Output Example

```
╔════════════════════════════════════════════════════╗
║  VS Code Insiders Emergency Cleanup - Optimized   ║
╚════════════════════════════════════════════════════╝

📊 Process Analysis:
  • Total Processes: 15
  • Main Windows: 2
  • Background: 13
  • Total Memory: 2847.32 MB (2.78 GB)

📋 Top Memory Consumers:
Id    Memory (MB) Window
--    ----------- ------
12345 456.23      my-portfolio-aws - VS Code Insiders
12346 389.45      <Background>
12347 245.67      <Background>

⚠️  Warning: This will terminate all VS Code Insiders processes!
   Any unsaved work will be lost!

Do you want to continue? (Y/N): Y

🔄 Terminating processes...
  → Attempting graceful close of main windows...
  → Force killing all processes...

✓ Cleanup completed successfully!
  • Processes terminated: 15
  • Memory freed: ~2847.32 MB
  • Duration: 1.23 seconds
```

## 🔧 Advanced Usage

### Schedule Automatic Cleanup
Create a scheduled task to run when memory is high:

```powershell
$Action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument '-ExecutionPolicy Bypass -File "D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1" -Force -MemoryThreshold 3000 -Silent'
$Trigger = New-ScheduledTaskTrigger -Daily -At 2AM
Register-ScheduledTask -TaskName "VS Code Insiders Cleanup" -Action $Action -Trigger $Trigger
```

### Add to Context Menu
Run VS Code Insiders directly with cleanup on exit:

```powershell
# Create wrapper script
$wrapper = @"
& 'C:\Users\baltz\AppData\Local\Programs\Microsoft VS Code Insiders\Code - Insiders.exe' `$args
& 'D:\DevOptimizer\Cleanup-VSCodeInsiders-Optimized.ps1' -Force -Silent
"@
$wrapper | Out-File "D:\DevOptimizer\Launch-VSCodeInsiders-AutoCleanup.ps1"
```

## 🎯 Best Practices

1. **Before Major Work**: Run cleanup to start fresh
2. **When System Sluggish**: Check if VS Code is consuming too much memory
3. **End of Day**: Run with `-Force` to ensure clean shutdown
4. **Automated**: Set up scheduled task with memory threshold
5. **Troubleshooting**: Use interactive mode to see what's running

## 🆚 Old vs New

| Feature | Old Script | Optimized |
|---------|-----------|-----------|
| Process Detection | Basic | Smart filtering |
| Memory Analysis | Total only | Per-process + top 10 |
| Cleanup Method | Force only | Graceful + force |
| Parameters | None | Force, threshold, silent |
| Verification | None | Checks remaining |
| Output | Basic | Color-coded with icons |
| Automation | Manual only | Scriptable |
| Performance | N/A | Shows duration |

## 💡 Tips

- Use `-MemoryThreshold 2000` to only cleanup when using >2GB
- Add `-Silent -Force` to your startup/shutdown scripts
- The script only targets VS Code Insiders, not regular VS Code
- Exit codes allow integration with other automation tools
- Graceful shutdown gives extensions time to cleanup
