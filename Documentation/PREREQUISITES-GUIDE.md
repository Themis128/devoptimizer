# 🔍 Prerequisites Checker - System Requirements Guide

## 📋 Overview

The **Prerequisites Checker** is a comprehensive system that verifies and installs all required dependencies for the Development Cache Cleaner. This ensures your system is properly configured before running cache cleaning operations.

## 🛡️ **ROBUST FEATURES**

### **Comprehensive Checking**
- **System Requirements**: PowerShell, Windows version, .NET Framework
- **Development Tools**: Node.js, Python, Git, Docker
- **Package Managers**: npm, pnpm, yarn, pip, conda
- **Development IDEs**: VS Code, Cursor
- **System Resources**: Disk space, RAM

### **Automatic Installation**
- **Smart Detection**: Identifies missing tools automatically
- **Silent Installation**: Installs tools without user intervention
- **Version Verification**: Ensures compatible versions are installed
- **Environment Setup**: Configures PATH and system variables

### **Detailed Reporting**
- **Status Tracking**: Real-time progress updates
- **Error Handling**: Comprehensive error reporting
- **Summary Reports**: Detailed operation summaries
- **Logging**: Complete operation logs

## 🚀 **QUICK START**

### **Basic Usage**
```bash
# Run the main launcher
00-LAUNCHER.bat
# Select: 15) Prerequisites Checker
```

### **Direct PowerShell Usage**
```powershell
# Check prerequisites only
.\prerequisites-checker.ps1 -CheckOnly

# Install missing tools
.\prerequisites-checker.ps1 -InstallAll

# Fix all issues
.\prerequisites-checker.ps1 -FixIssues

# Full system preparation
.\prerequisites-checker.ps1 -InstallAll -Verbose
```

## 📊 **PREREQUISITES VERIFIED**

### **🔧 System Requirements**
- **PowerShell 5.1+**: Required for script execution
- **Windows 10+**: Recommended operating system
- **.NET Framework 4.6.2+**: Required for .NET applications
- **Disk Space**: 5GB+ free space recommended
- **RAM**: 4GB+ recommended

### **📦 Development Tools**
- **Node.js**: JavaScript runtime for npm/yarn operations
- **Python 3.x**: Python runtime for pip/conda operations
- **Git**: Version control for repository operations
- **Docker**: Container platform (optional)

### **📋 Package Managers**
- **npm**: Node.js package manager (comes with Node.js)
- **pnpm**: Fast, disk space efficient package manager
- **yarn**: Alternative Node.js package manager
- **pip**: Python package installer
- **conda**: Python package and environment manager

### **🔧 Development IDEs**
- **VS Code**: Microsoft's code editor
- **Cursor**: AI-powered code editor
- **JetBrains IDEs**: Professional development tools

## 🛡️ **INSTALLATION FEATURES**

### **1. Node.js Installation**
```powershell
.\prerequisites-checker.ps1 -InstallAll
```
- **Downloads**: Latest LTS version (v20.10.0)
- **Installation**: Silent MSI installation
- **Configuration**: Automatic PATH setup
- **Verification**: Version check after installation

### **2. Python Installation**
```powershell
.\prerequisites-checker.ps1 -InstallAll
```
- **Downloads**: Python 3.11.8 (latest stable)
- **Installation**: Silent installer with all users option
- **Configuration**: Automatic PATH and pip setup
- **Verification**: Python and pip availability check

### **3. Git Installation**
```powershell
.\prerequisites-checker.ps1 -InstallAll
```
- **Downloads**: Git for Windows v2.43.0
- **Installation**: Silent installation
- **Configuration**: Default settings for Windows
- **Verification**: Git command availability

### **4. Optional Tools Installation**
```powershell
.\prerequisites-checker.ps1 -InstallAll
```
- **pnpm**: `npm install -g pnpm`
- **yarn**: `npm install -g yarn`
- **Verification**: Command availability checks

## 📈 **CHECKING FEATURES**

### **System Health Check**
```powershell
.\prerequisites-checker.ps1 -CheckOnly
```
- **Purpose**: Comprehensive system analysis
- **Output**: Detailed status report
- **Actions**: No installations performed
- **Use Case**: Verify system readiness

### **Smart Installation**
```powershell
.\prerequisites-checker.ps1 -InstallAll
```
- **Purpose**: Install only missing tools
- **Logic**: Checks before installing
- **Safety**: No overwrites of existing installations
- **Verification**: Post-installation checks

### **Comprehensive Fix**
```powershell
.\prerequisites-checker.ps1 -FixIssues
```
- **Purpose**: Address all identified issues
- **Scope**: Critical and optional tools
- **Strategy**: Install missing, update outdated
- **Verification**: Complete system re-check

## ⚙️ **CONFIGURATION**

### **Installation Sources**
The script uses official sources for all installations:
- **Node.js**: https://nodejs.org/dist/
- **Python**: https://www.python.org/ftp/python/
- **Git**: https://github.com/git-for-windows/git/releases/

### **Version Requirements**
- **PowerShell**: 5.1 or higher
- **Windows**: 10.0 or higher (recommended)
- **Node.js**: 18.0 or higher (LTS preferred)
- **Python**: 3.8 or higher
- **Git**: 2.30 or higher

### **System Requirements**
- **Disk Space**: 5GB free space minimum
- **RAM**: 4GB minimum, 8GB recommended
- **Network**: Internet connection for downloads
- **Permissions**: Administrator privileges required

## 📊 **REPORTING AND LOGGING**

### **Status Categories**
- **OK**: Tool is installed and working
- **WARNING**: Tool exists but may have issues
- **ERROR**: Critical error preventing operation
- **MISSING**: Required tool not installed
- **OPTIONAL**: Tool not installed but not required

### **Installation Results**
- **SUCCESS**: Tool installed successfully
- **FAILED**: Installation failed with error details

### **Summary Reports**
- **Start/End Times**: Operation duration
- **Success/Failure Counts**: Installation statistics
- **System Readiness**: Overall system status
- **Recommendations**: Next steps and actions

## 🔧 **ADVANCED USAGE**

### **Verbose Mode**
```powershell
.\prerequisites-checker.ps1 -InstallAll -Verbose
```
- **Purpose**: Detailed operation logging
- **Output**: Step-by-step progress
- **Use Case**: Troubleshooting and debugging

### **Force Mode**
```powershell
.\prerequisites-checker.ps1 -InstallAll -Force
```
- **Purpose**: Override safety checks
- **Warning**: May overwrite existing installations
- **Use Case**: Advanced users only

### **Check Only Mode**
```powershell
.\prerequisites-checker.ps1 -CheckOnly
```
- **Purpose**: Verification without installation
- **Output**: Status report only
- **Use Case**: System assessment

## 🚨 **TROUBLESHOOTING**

### **Common Issues**

#### **Permission Errors**
```powershell
# Run as Administrator
Start-Process PowerShell -Verb RunAs -ArgumentList "-File prerequisites-checker.ps1 -CheckOnly"
```

#### **Network Issues**
- **Cause**: Firewall or proxy blocking downloads
- **Solution**: Check internet connection and firewall settings
- **Alternative**: Manual download and installation

#### **Installation Failures**
- **Cause**: Insufficient disk space or permissions
- **Solution**: Free up space and run as Administrator
- **Recovery**: Check logs for specific error details

#### **Version Conflicts**
- **Cause**: Multiple versions of same tool
- **Solution**: Use -Force flag or manual cleanup
- **Prevention**: Check existing installations first

### **Error Recovery**
- **Log Analysis**: Review detailed error logs
- **Manual Installation**: Install tools manually if needed
- **System Restore**: Use system restore point if necessary
- **Clean Installation**: Remove and reinstall problematic tools

## 📋 **BEST PRACTICES**

### **Before Running**
1. **Backup System**: Create system restore point
2. **Close Applications**: Close development tools
3. **Check Disk Space**: Ensure sufficient free space
4. **Run as Administrator**: Ensure proper permissions

### **During Installation**
1. **Monitor Progress**: Watch for error messages
2. **Don't Interrupt**: Let installations complete
3. **Check Logs**: Review operation logs
4. **Verify Results**: Confirm successful installations

### **After Installation**
1. **Test Tools**: Verify all tools work correctly
2. **Update PATH**: Restart terminal if needed
3. **Check Versions**: Confirm correct versions installed
4. **Document Changes**: Note any system modifications

## 🔮 **FUTURE ENHANCEMENTS**

### **Planned Features**
- **Web Interface**: Browser-based configuration
- **Real-time Monitoring**: Live system health tracking
- **Cloud Integration**: Remote system management
- **Machine Learning**: Intelligent issue prediction
- **Cross-platform Support**: Linux and macOS versions

### **Community Features**
- **Plugin System**: Third-party tool support
- **Community Presets**: Shared configuration templates
- **Performance Benchmarks**: Installation performance metrics
- **Integration APIs**: Programmatic access to checker functions

## 📞 **SUPPORT**

### **Getting Help**
1. **Check Logs**: Review operation logs for details
2. **Run Check Only**: Verify current system status
3. **Check Documentation**: Refer to this guide
4. **System Information**: Provide Windows version and details

### **Reporting Issues**
- **Log Files**: Include relevant log files
- **System Information**: Windows version and system details
- **Reproduction Steps**: Exact commands and parameters used
- **Expected vs Actual**: Describe expected and actual behavior

---

**⚠️ DISCLAIMER**: This tool modifies system installations and configurations. Always backup important data before use. The authors are not responsible for system issues resulting from improper use of this tool.
