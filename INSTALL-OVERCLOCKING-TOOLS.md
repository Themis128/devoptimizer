# Install Overclocking Tools via Chocolatey

## Quick Installation Commands

Run these commands in an **elevated PowerShell terminal** (Run as Administrator):

### Step 1: Open Elevated PowerShell
1. Press `Win + X`
2. Select "Windows PowerShell (Admin)" or "Terminal (Admin)"
3. Or search for "PowerShell" in Start Menu, right-click, and select "Run as Administrator"

### Step 2: Install MSI Afterburner
```powershell
choco install msiafterburner -y
```

### Step 3: Install Intel XTU
```powershell
choco install intel-xtu -y
```

### Alternative: Run the Automated Script
```powershell
cd D:\DevOptimizer
.\install-overclocking-tools-choco.ps1
```

## Manual Commands (Copy & Paste)

If you prefer to run commands manually, here are the exact commands:

```powershell
# Install MSI Afterburner
choco install msiafterburner -y

# Install Intel XTU
choco install intel-xtu -y
```

## After Installation

1. **Configure the tools:**
   ```powershell
   cd D:\DevOptimizer
   .\configure-overclocking-tools.ps1
   ```

2. **Launch the applications:**
   - MSI Afterburner: Search "MSI Afterburner" in Start Menu
   - Intel XTU: Search "Intel Extreme Tuning Utility" in Start Menu

## Troubleshooting

### If Chocolatey installation fails (Access Denied / 403 Forbidden):

The Chocolatey packages may fail due to download URL restrictions. Use manual installation:

```powershell
# Run the manual installation helper
.\install-overclocking-manual.ps1
```

Or manually:
1. Download MSI Afterburner from: https://www.msi.com/Landing/afterburner/graphics-cards
2. Download Intel XTU from: https://www.intel.com/content/www/us/en/download/17881/intel-extreme-tuning-utility-intel-xtu.html
3. Run each installer as Administrator

### If installation fails with lock file errors:
```powershell
# Clean Chocolatey lock files (run as Administrator)
Remove-Item "C:\ProgramData\chocolatey\lib\*" -Recurse -Force -ErrorAction SilentlyContinue
choco install msiafterburner -y
choco install intel-xtu -y
```

### If Chocolatey is not installed:
```powershell
# Install Chocolatey (run as Administrator)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

## System Information
- **CPU:** 12th Gen Intel Core i9-12900H
- **Recommended Intel XTU Version:** 7.14.2.67 (for 12th gen and older)
- **Note:** Mobile H-series CPUs have limited overclocking capability
