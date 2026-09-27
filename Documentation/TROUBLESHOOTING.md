# DevOptimizer Hub - Troubleshooting Guide

## 🚨 Quick Diagnostics

### Run System Health Check
```batch
06-System-Health-Check.bat
```

### Check Error Logs
```batch
dir logs\*.log
type logs\error.log
```

## 🔧 Common Issues & Solutions

### 1. PowerShell Execution Policy Errors

**Error**: `Execution of scripts is disabled on this system`

**Solution**:
```batch
# Run as Administrator
Set-ExecutionPolicy Bypass -Scope LocalMachine -Force
```

**Alternative**:
```batch
# Run this batch file as Administrator
00-SETUP-GLOBAL-ACCESS.bat
```

### 2. Administrator Privileges Required

**Error**: `Administrator privileges required`

**Solutions**:
- Right-click batch file → "Run as administrator"
- Open Command Prompt as Administrator
- Use `01-Quick-Optimization-NoAdmin.bat` for limited functionality

### 3. PowerShell Script Not Found

**Error**: `Required PowerShell script not found`

**Solutions**:
1. Ensure `dev-optimizer-fixed.ps1` exists in `D:\DevOptimizer\`
2. Check file permissions
3. Verify file integrity

**Check**:
```batch
dir D:\DevOptimizer\dev-optimizer-fixed.ps1
```

### 4. Batch File Execution Fails

**Error**: `Batch file execution failed`

**Solutions**:
1. Check file encoding (should be ANSI/UTF-8)
2. Verify line endings (Windows CRLF)
3. Ensure no special characters in path

**Test**:
```batch
echo Test > test.bat
test.bat
del test.bat
```

### 5. Network/Internet Issues

**Error**: `Network operation failed`

**Solutions**:
1. Run `10-Network-Optimization.bat`
2. Check Windows Firewall settings
3. Verify network connectivity

**Test**:
```batch
ping google.com
```

### 6. Disk Space Issues

**Error**: `Insufficient disk space`

**Solutions**:
1. Run `09-System-Deep-Clean.bat`
2. Use `025-Development-Cache-Cleaner.bat`
3. Check disk space: `dir C:\`

### 7. Registry Access Denied

**Error**: `Registry access denied`

**Solutions**:
1. Ensure running as Administrator
2. Check registry permissions
3. Use `11-Security-Hardening.bat` for security settings

## 🔍 Advanced Diagnostics

### Check System Requirements
```batch
# System information
systeminfo | findstr /C:"OS Name" /C:"OS Version" /C:"Total Physical Memory"

# PowerShell version
powershell -Command "$PSVersionTable.PSVersion"

# Admin privileges
net session >nul 2>&1 && echo Admin OK || echo Not Admin
```

### Verify File Integrity
```batch
# Check all batch files
for %f in (D:\DevOptimizer\*.bat) do (
    echo Checking %f
    type "%f" >nul
    if errorlevel 1 echo ERROR: %f is corrupted
)
```

### Test PowerShell Scripts
```batch
# Test PowerShell execution
powershell -Command "Write-Host 'PowerShell test successful'"

# Test specific script
powershell -ExecutionPolicy Bypass -File "D:\DevOptimizer\dev-optimizer-fixed.ps1" -WhatIf
```

## 📊 Performance Issues

### Slow Execution
1. Run `02-Ultra-Performance.bat`
2. Check system resources: `taskmgr`
3. Use `025-Development-Cache-Cleaner.bat`

### Memory Issues
1. Check available memory: `wmic OS get TotalVisibleMemorySize,FreePhysicalMemory`
2. Run `09-System-Deep-Clean.bat`
3. Restart system if needed

### Disk Performance
1. Check disk health: `wmic diskdrive get status`
2. Run disk cleanup: `cleanmgr`
3. Defragment if needed: `defrag C:`

## 🛡️ Security Issues

### Antivirus Interference
1. Add `D:\DevOptimizer\` to antivirus exclusions
2. Temporarily disable real-time protection
3. Use `11-Security-Hardening.bat` for security settings

### Windows Defender
```batch
# Add exclusion
powershell -Command "Add-MpPreference -ExclusionPath 'D:\DevOptimizer'"
```

## 🔄 Recovery Procedures

### System Restore
1. Create restore point before major changes
2. Use System Restore if issues occur
3. Run `06-System-Health-Check.bat` after restore

### Reset to Default
1. Backup current configuration
2. Run `00-SETUP-GLOBAL-ACCESS.bat` to reset PATH
3. Restart system

### Complete Reinstall
1. Delete `D:\DevOptimizer\` directory
2. Re-extract all files
3. Run `00-SETUP-GLOBAL-ACCESS.bat` as Administrator

## 📋 Error Code Reference

| Error Code | Description | Solution |
|------------|-------------|----------|
| 1 | General error | Check logs, run diagnostics |
| 2 | File not found | Verify file paths and permissions |
| 3 | Access denied | Run as Administrator |
| 4 | PowerShell error | Check execution policy |
| 5 | Network error | Check connectivity and firewall |

## 📞 Getting Help

### Before Contacting Support
1. Run `06-System-Health-Check.bat`
2. Check `logs\` directory for errors
3. Note exact error messages
4. Document steps to reproduce

### Information to Include
- Windows version and build
- Error messages (exact text)
- Log file contents
- Steps to reproduce
- System specifications

### Self-Service Resources
- README.md - Complete documentation
- logs\ directory - Error logs and diagnostics
- Individual batch file help (run with /? or -h)

---

*For additional support, check the main README.md file or run the system health check.*
