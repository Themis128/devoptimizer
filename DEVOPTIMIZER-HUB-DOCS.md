# DevOptimizer Script Hub - Complete Documentation

## Overview

The DevOptimizer Script Hub is a unified execution platform that consolidates 400+ PowerShell scripts, Python CLI tools, batch files, and utilities into a single, easily accessible interface. It provides category-based organization, search functionality, favorites management, health monitoring, and self-updating capabilities.

## Table of Contents
- [Overview](#overview)
- [Getting Started](#getting-started)
- [Installation & Setup](#installation--setup)
- [User Interface](#user-interface)
- [Command Reference](#command-reference)
- [Examples](#examples)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

## Getting Started

### 1. Desktop Access (Recommended)
Double-click the `DevOptimizer.bat` file on your desktop to launch the interactive menu.

### 2. Command Line Access
Once added to your system PATH (see Installation below), you can use:
```powershell
devoptimizer.ps1 [options]
```

### 3. Direct Execution
You can also run the script directly:
```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\DevOptimizer\devoptimizer.ps1" [options]
```

## Installation & Setup

### Adding to System PATH (Recommended)
To access `devoptimizer.ps1` from any command prompt:

1. **Open PowerShell as Administrator**
2. **Run this command:**
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";D:\DevOptimizer", "Machine")
   ```
3. **Restart your command prompts** for the change to take effect

### Manual PATH Addition
If you prefer to add it manually:
1. Press `Win + R`, type `sysdm.cpl`, press Enter
2. Go to **Advanced** tab → **Environment Variables**
3. Under **System Variables**, find `Path`, click **Edit**
4. Click **New** and add: `D:\DevOptimizer`
5. Click OK on all dialogs
6. Restart command prompts

### Verifying Installation
After adding to PATH, verify by running:
```powershell
devoptimizer.ps1 -Quick | head -5
```
(You should see a list of available commands)

## User Interface

### Interactive Menu (-Menu)
Launch the hub's interactive menu:
```powershell
devoptimizer.ps1 -Menu
```

**Navigation:**
- **Numbers 1-10**: Select category
- **F**: View/manage favorites
- **S**: Search commands
- **A**: Show all commands
- **R**: Rebuild command registry
- **Q**: Quit

### Quick List (-Quick)
Display a flat list of all available commands:
```powershell
devoptimizer.ps1 -Quick
```

### Category View (-Category)
Show commands in a specific category:
```powershell
devoptimizer.ps1 -Category maintenance
```

### Search (-Search)
Find commands by keyword:
```powershell
devoptimizer.ps1 -Search cleanup
```

## Command Reference

### Execution Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Command <name>` | Execute a specific command by name | `-Command check-braces` |
| `-Parameters @{...}` | Parameters for command execution | `-Parameters @{Path="C:\Temp"}` |

### Menu & Discovery

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Menu` | Launch interactive menu | `-Menu` |
| `-Quick` | Show flat command list | `-Quick` |
| `-Category <name>` | Show commands in category | `-Category utilities` |
| `-Search <term>` | Search commands | `-Search optimize` |
| `-Favorites` | Show favorite commands | `-Favorites` |

### Favorites Management

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-AddFavorite <name>` | Add command to favorites | `-AddFavorite check-braces` |
| `-RemoveFavorite <name>` | Remove command from favorites | `-RemoveFavorite check-braces` |
| `-ListFavorites` | List all favorite commands | `-ListFavorites` |

### Health & Maintenance

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Health` | Run health check | `-Health` |
| `-AutoFix` | Auto-fix issues (with -Health) | `-Health -AutoFix` |
| `-BuildRegistry` | Rebuild command registry | `-BuildRegistry` |
| `-Validate` | Validate registry (with -BuildRegistry) | `-BuildRegistry -Validate` |

### Update & Backup

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Update` | Check/update from source | `-Update` |
| `-UpdateSource <type>` | Update source: git\|local\|release (default: git) | `-UpdateSource git` |
| `-LocalPath <path>` | Local source path for update | `-LocalPath "C:\DevOptimizer-Local"` |
| `-Rollback` | Rollback to previous version | `-Rollback` |
| `-ListBackups` | List available backups | `-ListBackups` |

### Shortcut Management

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-CreateShortcut` | Create desktop shortcut | `-CreateShortcut` |
| `-RemoveShortcut` | Remove desktop shortcut | `-RemoveShortcut` |

### General

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Force` | Skip confirmations | `-Force` |
| `-AsAdmin` | Run as Administrator | `-AsAdmin` |
| `-PassThru` | Return result object instead of exiting | `-PassThru` |

## Examples

### Basic Usage
```powershell
# Launch interactive menu
devoptimizer.ps1 -Menu

# Show all utilities commands
devoptimizer.ps1 -Category utilities

# Search for cleanup-related commands
devoptimizer.ps1 -Search cleanup

# Execute a specific script
devoptimizer.ps1 -Command check-braces

# Run health check with auto-fix
devoptimizer.ps1 -Health -AutoFix
```

### Advanced Usage
```powershell
# Add frequently used commands to favorites
devoptimizer.ps1 -AddFavorite "check-braces"
devoptimizer.ps1 -AddFavorite "check-syntax"
devoptimizer.ps1 -AddFavorite "devoptimizer-core"

# View your favorites
devoptimizer.ps1 -ListFavorites

# Run a command with parameters
devoptimizer.ps1 -Command "some-script" -Parameters @{Verbose=$true; Path="C:\Temp"}

# Create desktop shortcut (if not already created)
devoptimizer.ps1 -CreateShortcut

# Check for updates
devoptimizer.ps1 -Update
```

## Architecture

The DevOptimizer Script Hub implements a **5-layer architecture**:

### 1. Core Layer
- **DevOptimizer-Master.psm1**: Main module loader
- **DevOptimizer-Config.psm1**: Configuration management
- **DevOptimizer-Path.psm1**: Path resolution utilities
- **DevOptimizer-Admin.psm1**: Admin privilege handling
- **DevOptimizer-Hub.psm1**: Hub coordination

### 2. Discovery Layer
- **Discover-Scripts.ps1**: Discovers available scripts
- **Build-Registry.ps1**: Builds hub-registry.json
- **hub-registry.json**: Validated command registry (JSON Schema draft-07)
- **hub-config.json**: Hub-specific configuration overlay
- **devoptimizer-config.json**: Base configuration

### 3. Execution Layer
- **Execute-Command.ps1**: Unified script/function execution
- **Show-Menu.ps1**: Interactive menu system
- **Get-Category.ps1**: Category browsing
- **Check-Health.ps1**: Health monitoring
- **Update-Hub.ps1**: Self-update mechanism

### 4. Integration Layer
- **devoptimizer.ps1**: PowerShell CLI (12 parameter sets)
- **hub.py**: Python CLI bridge (Typer/Rich, subprocess)

### 5. Verification Layer
- **validate-all-scripts.ps1**: Validation script
- **12 test files**: Binary-decidable validation tests

## Key Features

### Smart Module Loading
- Single loader: `Import-Module DevOptimizer-Master -ArgumentList @{LoadHub=$true}`
- Loads modules in order: Path → Admin → Hub
- Config overlay: hub-config.json merges over devoptimizer-config.json
- Custom JSON validator: Validate-JsonSchema.ps1 (uses NJsonSchema .NET)

### Python Integration
- Bidirectional bridge between PowerShell and Python
- subprocess.run(["powershell", "-ExecutionPolicy", "Bypass", "-File", "devoptimizer.ps1", ...])
- Typer/Rich for beautiful Python CLI

### Registry System
- JSON file + optional HKCU:\SOFTWARE\DevOptimizer\Hub registry
- JSON Schema validation for integrity
- Automatic discovery of new scripts

### Health Monitoring
- Comprehensive system checks (Admin rights, Git, WSL, etc.)
- 96% baseline score on test system
- Auto-fix capabilities for common issues

### Extensibility
- Easy to add new scripts via discovery mechanism
- Category-based organization
- Favorites system for quick access
- Self-updating capability

## Troubleshooting

### Common Issues

#### "Command not found" Errors
1. **Run `-BuildRegistry`** to rebuild the command registry
2. **Check script naming**: Commands should follow naming conventions
3. **Verify script location**: Scripts must be in discoverable locations

#### Execution Failures
1. **Check health**: Run `devoptimizer.ps1 -Health`
2. **Admin requirements**: Some scripts need elevation (use `-AsAdmin`)
3. **Dependencies**: Ensure required tools are installed (Git, Node.js, etc.)

#### Performance Issues
1. **Registry rebuild**: Run `-BuildRegistry` if hub feels slow
2. **Clear cache**: Temporary files in `%TEMP%` can be cleared
3. **Check logs**: Look in `D:\DevOptimizer\logs\` for detailed logs

### Specific Error Solutions

#### Environment:AdminRights Error
- **Cause**: Script requires administrator privileges
- **Solution**: Re-run with `-AsAdmin` parameter or right-click → "Run as administrator"

#### Environment:Git Error
- **Cause**: Git not found in system PATH
- **Solution**: Install Git from https://git-scm.com/ and restart command prompts

#### Execution Policy Errors
- **Cause**: PowerShell execution policy prevents script running
- **Solution**: The hub automatically uses `-ExecutionPolicy Bypass`

#### Module Loading Failures
- **Cause**: Missing dependencies or corrupted modules
- **Solution**: Run `devoptimizer.ps1 -BuildRegistry -Validate` to verify integrity

## FAQ

### Q: How do I add my own scripts to the hub?
A: Place your scripts in appropriate directories under `D:\DevOptimizer\` (scripts\, modules\, etc.) then run `devoptimizer.ps1 -BuildRegistry` to rediscover them.

### Q: Where are logs stored?
A: Logs are stored in `D:\DevOptimizer\logs\` with timestamped filenames.

### Q: Can I use this on multiple computers?
A: Yes! Simply copy the entire `D:\DevOptimizer\` folder to another computer and follow the installation steps.

### Q: How often should I rebuild the registry?
A: After adding/removing scripts, or if you notice missing commands. Monthly is recommended for maintenance.

### Q: Is it safe to run auto-fix on health check?
A: Yes, the auto-fix only applies safe, non-destructive changes like fixing execution policies or setting environment variables.

### Q: How do I uninstall the hub?
A: Simply delete the `D:\DevOptimizer\` folder and remove `D:\DevOptimizer` from your system PATH if you added it.

### Q: Can I customize the categories?
A: Yes! Modify the discovery scripts or hub configuration to reorganize categories as needed.

### Q: What happens if I lose my desktop shortcut?
A: Simply run `devoptimizer.ps1 -CreateShortcut` to recreate it, or double-click the DevOptimizer.bat on your desktop.

## Contact & Support

For issues, questions, or contributions:
- Check the existing `.md` files in `D:\DevOptimizer\` for specific script documentation
- Review `INSTALL-NOW.md` and `INSTALLATION-TROUBLESHOOTING.md` for setup help
- Look at `NEXT-STEPS.md` for planned features
- Visit the `.glm-hammer\plans\` directory for implementation details

---

*Documentation generated for DevOptimizer Script Hub v1.0*
*Last updated: $(Get-Date -Format 'yyyy-MM-dd')*
*To regenerate this documentation, run the documentation generator script*
## Windows App (WPF GUI)

DevOptimizer ships as a native Windows desktop app built on the hub registry:

- **Launch:** double-click `DevOptimizer App` on the desktop, or run `DevOptimizer-App.vbs` / `DevOptimizer-App.bat` in the hub root.
- **Features:** category browsing, live search, favorites (shared with `config/favorites.json`), parameter dialogs, elevated runs via UAC, dry-run mode, live output pane.
- **Execution:** runs commands through `Execute-Command.ps1` in a background PowerShell process; run logs land in `logs/app-runs/*.log.txt` with a `*.done.txt` completion marker.
- **Self-test:** `$env:DOAPP_SELFTEST='1'` runs the data/filter pipeline headless (no window) and logs PASS/FAIL to `logs/app-runs/app-debug.log`.
- **Note:** `DevOptimizer-App.ps1` must stay UTF-8 **with BOM** (PowerShell 5.1 requirement for its unicode glyphs).
