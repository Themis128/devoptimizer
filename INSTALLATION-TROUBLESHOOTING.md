# Installation Troubleshooting Guide

## Intel XTU Installation Error 0x80070643

### Problem
The installation of Intel XTU version 10.0.1.31 failed with error `0x80070643`.

### Root Cause
- **Your CPU**: 12th Gen Intel Core i9-12900H
- **Installed Version**: 10.0.1.31 (for Core Ultra Series 2 and newer)
- **Required Version**: 7.14.2.67 (for 12th gen and older processors)

Version 10.0.1.31 is incompatible with 12th generation processors.

### Solution

#### Step 1: Download the Correct Version
1. Visit: https://www.intel.com/content/www/us/en/download/17881/intel-extreme-tuning-utility-intel-xtu.html
2. **Look for version 7.14.2.67** (not 10.0.1.31)
3. Download the installer for 12th gen processors

#### Step 2: Clean Up Failed Installation
Run the fix script:
```powershell
.\fix-intel-xtu-installation.ps1
```

Or manually:
1. Open Settings > Apps
2. Search for "Intel XTU" or "Extreme Tuning Utility"
3. If found, uninstall it
4. Restart your computer

#### Step 3: Install Correct Version
1. Right-click the downloaded installer (version 7.14.2.67)
2. Select "Run as Administrator"
3. Follow the installation wizard

### Alternative Installation Methods

#### Method 1: Extract and Install MSI Directly
If the bundle installer fails, you can extract and install the MSI directly:

1. The installer is a WiX bundle - it contains an MSI file
2. Use 7-Zip or similar to extract `XTUSetup_7.14.2.67.exe`
3. Find `Intel_XtuInstaller.msi` inside
4. Run as Administrator:
   ```powershell
   msiexec /i "path\to\Intel_XtuInstaller.msi" /qn
   ```

#### Method 2: Use Chocolatey (if package is updated)
```powershell
choco install intel-xtu --version=7.13.1.5 -y
```
Note: Chocolatey version may be older but should work.

### Version Compatibility

| CPU Generation | Intel XTU Version |
|---------------|-------------------|
| 12th Gen and older | 7.14.2.67 |
| Core Ultra Series 2+ | 10.0.1.31 |

Your CPU (i9-12900H) is 12th generation, so use **7.14.2.67**.

## MSI Afterburner Installation

### If MSI Afterburner Installation Fails

1. **Extract the ZIP file manually:**
   - Right-click `MSIAfterburnerSetup.zip`
   - Select "Extract All"
   - Run the extracted installer as Administrator

2. **Check for conflicts:**
   - Uninstall any existing GPU overclocking software
   - Close any running GPU monitoring tools
   - Disable antivirus temporarily during installation

3. **Install dependencies:**
   - Ensure Visual C++ Redistributables are installed
   - Update Windows to latest version

## General Troubleshooting

### Error 0x80070652 (Another installation is in progress)

This error means Windows Installer service is locked or another installation is running.

**Quick Fix:**
1. Run the fix script:
   ```powershell
   .\fix-windows-installer-error.ps1
   ```

2. Or manually:
   - Close all installer windows
   - Open Services (services.msc)
   - Restart "Windows Installer" service
   - Wait 30 seconds
   - Try installation again

3. If still failing:
   - Restart your computer
   - Try installation immediately after restart

### Error 0x80070643
- **Cause**: Incompatible version, corrupted installer, or system conflict
- **Fix**:
  - Download correct version for your CPU
  - Run installer as Administrator
  - Disable antivirus temporarily
  - Check Windows Event Viewer for detailed errors

### Installation Requires Restart
- Some installations require a system restart
- Save your work and restart when prompted
- After restart, verify installation

### Tools Not Detected After Installation
1. Restart your computer
2. Check if tools appear in Start Menu
3. Verify installation in Settings > Apps
4. Check installation paths:
   - MSI Afterburner: `C:\Program Files (x86)\MSI Afterburner\`
   - Intel XTU: `C:\Program Files (x86)\Intel\Intel(R) Extreme Tuning Utility\`

## Next Steps After Successful Installation

1. **Restart your computer** (highly recommended)
2. **Launch both tools** from Start Menu
3. **Run configuration script:**
   ```powershell
   .\configure-overclocking-tools.ps1
   ```
4. **Follow the configuration guide** in `config\overclocking\configuration-guide.txt`

## Getting Help

If installation continues to fail:
1. Check Windows Event Viewer for detailed error messages
2. Review installation logs in `%TEMP%` folder
3. Ensure you're running as Administrator
4. Try installing on a clean system or after a restart
