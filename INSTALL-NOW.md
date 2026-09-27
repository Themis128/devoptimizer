# Quick Installation Instructions

## Run in Elevated PowerShell (Run as Administrator)

### Step 1: Open Elevated PowerShell
1. Press `Win + X`
2. Select "Windows PowerShell (Admin)" or "Terminal (Admin)"

### Step 2: Navigate to DevOptimizer folder
```powershell
cd D:\DevOptimizer
```

### Step 3: Run the installation script
```powershell
.\install-and-configure-overclocking.ps1
```

## Manual Installation (Alternative)

If the script doesn't work, install manually:

### MSI Afterburner:
1. Extract `C:\Users\baltz\Downloads\MSIAfterburnerSetup.zip`
2. Run the extracted installer as Administrator
3. Follow the installation wizard

### Intel XTU:
1. Right-click `C:\Users\baltz\Downloads\XTUSetup_10.0.1.31.exe`
2. Select "Run as Administrator"
3. Follow the installation wizard

## After Installation

1. **Restart your computer** (recommended)
2. Launch MSI Afterburner from Start Menu
3. Launch Intel XTU from Start Menu
4. Follow the configuration guide created in `config\overclocking\configuration-guide.txt`
