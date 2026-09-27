# MCP Servers Setup for PowerShell and Batch Scripts

This document describes the MCP (Model Context Protocol) servers configured for managing and executing your `.ps1` and `.bat` scripts.

## 📋 Configured MCP Servers

### 1. **PowerShell Exec MCP Server** (`powershell-exec`)
- **Purpose**: Execute PowerShell scripts and commands
- **Package**: `mcp-powershell-exec`
- **Features**:
  - Execute PowerShell scripts from string inputs
  - Real-time output capture
  - Integration with automated workflows
  - Execution policy: Bypass (configured)

**Usage Example**:
```powershell
# Execute a PowerShell command
Execute-PowerShell -Command "Get-Process | Select-Object Name, CPU"

# Run a script file
Execute-PowerShell -ScriptPath "D:\DevOptimizer\scripts\optimizer.ps1"
```

### 2. **Windows CLI MCP Server** (`windows-cli`)
- **Purpose**: Secure command-line interactions for Windows
- **Package**: `@modelcontextprotocol/server-windows-cli`
- **Features**:
  - Execute PowerShell, CMD, and Git Bash commands
  - Robust security controls (command blocking, path restrictions)
  - Command logging
  - Restricted to `D:\DevOptimizer` directory
  - Multi-shell support

**Usage Example**:
```bash
# Execute a PowerShell command
Execute-Command -Shell "powershell" -Command "Get-Process"

# Run a batch file
Execute-Command -Shell "cmd" -Command "D:\DevOptimizer\portable\optimizer.bat"

# Execute with restrictions
Execute-Command -Shell "powershell" -Command ".\scripts\optimizer.ps1" -WorkingDirectory "D:\DevOptimizer"
```

### 3. **Filesystem MCP Server** (`filesystem`)
- **Purpose**: File and directory management
- **Package**: `@modelcontextprotocol/server-filesystem`
- **Features**:
  - Read/write files (including `.ps1` and `.bat`)
  - Directory navigation and management
  - File search and metadata retrieval
  - Secure, permission-controlled operations
  - Root directory: `D:\DevOptimizer`

**Usage Example**:
```bash
# Read a script file
Read-File -Path "scripts\optimizer.ps1"

# Write to a file
Write-File -Path "scripts\new-script.ps1" -Content "# New script"

# Search for scripts
Search-Files -Pattern "*.ps1" -Directory "scripts"
```

### 4. **Windows CLI MCP Server** (see above)
- Combined functionality for both PowerShell and batch execution

### 5. **Sequential Thinking** (`sequentialthinking`)
- **Purpose**: Advanced reasoning and problem-solving
- **Package**: `@modelcontextprotocol/server-sequential-thinking`
- **Status**: Already configured

## 🔒 Security Scanning

### **Snyk MCP Server** (Available)
- **Purpose**: Security analysis of scripts
- **Features**:
  - Static Application Security Testing (SAST)
  - Command injection detection
  - Vulnerability scanning
  - Code analysis

**To use Snyk**:
```bash
# Scan PowerShell scripts
snyk_code_scan --path "D:\DevOptimizer\scripts" --type powershell

# Scan batch files
snyk_code_scan --path "D:\DevOptimizer\portable" --type batch
```

## 📁 Your Script Structure

Based on your codebase:
- **312 PowerShell scripts** (`.ps1`)
- **1,439 Batch files** (`.bat`)
- **Main directories**:
  - `scripts/` - PowerShell scripts
  - `portable/` - Batch file launchers
  - `config/` - Configuration scripts
  - `tools/` - Utility scripts

## 🚀 Quick Start

### 1. **Execute a PowerShell Script**
```
Use PowerShell Exec MCP Server to run:
- scripts\optimizer.ps1
- scripts\validate-system.ps1
- scripts\DevOptimizer-Core.ps1
```

### 2. **Execute Batch Files and Commands**
```
Use Windows CLI MCP Server to:
- Run .bat files securely
- Execute CMD commands
- Run PowerShell commands
- All within restricted directories
```

### 3. **Read/Edit Script Files**
```
Use Filesystem MCP Server to:
- Read script contents
- Search for specific scripts
- Manage script files
```

### 4. **Run Batch Files**
```
Use Windows CLI MCP Server to:
- Execute .bat files securely
- Run system commands with restrictions
- Monitor script execution
```

## 🔧 Configuration File

The MCP servers are configured in `cline_mcp_settings.json`:

```json
{
  "mcpServers": {
    "powershell-exec": { ... },
    "windows-cli": { ... },
    "filesystem": { ... }
  }
}
```

## 📝 Next Steps

1. **Restart Cursor/IDE** to load the new MCP servers
2. **Test PowerShell execution** with a simple script
3. **Discover scripts** using the Script Runner
4. **Run security scan** using Snyk on your scripts
5. **Set up automation** for script testing and validation

## ⚠️ Notes

- PowerShell execution policy is set to "Bypass" for the PowerShell Exec server
- Windows CLI server is restricted to `D:\DevOptimizer` directory for security
- Filesystem server is restricted to `D:\DevOptimizer` root directory
- All servers use `npx` for automatic package installation
## 🔍 Troubleshooting

If servers don't load:
1. Ensure Node.js and npm are installed
2. Check that `npx` is available in PATH
3. Verify the package names are correct
4. Check Cursor/IDE logs for MCP server errors

For PowerShell issues:
- Verify PowerShell is installed: `pwsh --version` or `powershell --version`
- Check execution policy: `Get-ExecutionPolicy`
