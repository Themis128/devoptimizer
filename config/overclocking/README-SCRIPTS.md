# Intel XTU Configuration Scripts - Quick Reference

## ✅ Configuration Complete!

Intel XTU has been configured programmatically. Settings have been applied to the Windows Registry.

---

## 🚀 How to Run the Scripts

### Quick Method (Recommended)
```powershell
.\configure-xtu.ps1
```

### With Options
```powershell
.\configure-xtu.ps1 -LaunchXTU          # Configure and launch Intel XTU
.\configure-xtu.ps1 -Conservative        # Use extra conservative values
.\configure-xtu.ps1 -Help                # Show help message
```

### Advanced Scripts
```powershell
.\configure-xtu-advanced.ps1              # Advanced configuration with profile discovery
.\configure-intel-xtu-programmatic.ps1   # Basic programmatic configuration
```

---

## ⚠️ Important: PowerShell Syntax

**Always use `.\` prefix when running scripts in PowerShell:**

```powershell
# ✅ Correct
.\configure-xtu.ps1

# ❌ Wrong (will give error)
configure-xtu.ps1
```

PowerShell requires the `.\` prefix to run scripts from the current directory for security reasons.

---

## 📋 Available Scripts

### 1. `configure-xtu.ps1` (Simplest)
- Easy-to-remember name
- Wrapper around advanced script
- Supports all options
- Includes help (`-Help`)

### 2. `configure-xtu-advanced.ps1` (Recommended)
- Discovers Intel XTU registry structure
- Creates profiles automatically
- Applies settings to multiple registry paths
- Most comprehensive

### 3. `configure-intel-xtu-programmatic.ps1` (Basic)
- Basic programmatic configuration
- Applies settings to common registry paths
- Creates backup automatically

---

## 🎯 Common Usage Examples

### Default Configuration
```powershell
.\configure-xtu.ps1
```
Applies conservative values:
- Turbo Boost Power Max: +5W
- Turbo Boost Short Power Max: +5W
- Core Voltage Offset: +0.010V
- Turbo Boost Max: +100MHz

### Extra Conservative
```powershell
.\configure-xtu.ps1 -Conservative
```
Applies more conservative values:
- Turbo Boost Power Max: +3W
- Turbo Boost Short Power Max: +3W
- Core Voltage Offset: +0.005V
- Turbo Boost Max: +50MHz

### Configure and Launch
```powershell
.\configure-xtu.ps1 -LaunchXTU
```
Configures settings and automatically launches Intel XTU.

### Custom Values
```powershell
.\configure-xtu.ps1 -TurboBoostPowerMax 10 -TurboBoostShortPowerMax 10 -TurboBoostMax 200
```
Apply custom overclocking values.

---

## ✅ Current Status

**Settings Applied:**
- ✅ Turbo Boost Power Max: +5W
- ✅ Turbo Boost Short Power Max: +5W
- ✅ Core Voltage Offset: +0.010V
- ✅ Turbo Boost Max: +100MHz

**Registry Locations:**
- `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Default`
- `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Settings`
- `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Overclocking`

---

## 🔍 Verify Configuration

1. **Launch Intel XTU:**
   ```powershell
   # Or launch from Start Menu
   ```

2. **Check Settings:**
   - Navigate to **Advanced Tuning** → **Core** tab
   - Verify the values are applied
   - If not visible, restart Intel XTU

3. **Run Stress Test:**
   - Click **Stress Test** in Intel XTU
   - Run for 15-30 minutes
   - Monitor temperatures (Core < 90°C, Package < 95°C)

---

## 📚 Documentation Files

- **`INTEL-XTU-CONFIGURED.md`** - Complete configuration documentation
- **`CONFIGURATION-APPLIED.md`** - Overall configuration status
- **`QUICK-START-GUIDE.md`** - Step-by-step guide
- **`README-SCRIPTS.md`** - This file

---

## 🔄 Re-running Configuration

You can re-run the scripts anytime to:
- Change overclocking values
- Apply different settings
- Reset to conservative values

The scripts will:
- ✅ Backup existing registry settings
- ✅ Apply new values
- ✅ Create configuration files

---

## 💡 Tips

1. **Always use `.\` prefix** when running scripts
2. **Use `-LaunchXTU`** to automatically launch Intel XTU after configuration
3. **Use `-Conservative`** for extra safe values
4. **Check Intel XTU GUI** to verify settings were applied
5. **Restart Intel XTU** if settings don't appear immediately

---

## 🆘 Troubleshooting

### Script won't run
- Make sure you're in the correct directory: `D:\DevOptimizer\config\overclocking`
- Use `.\` prefix: `.\configure-xtu.ps1`
- Check execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Settings don't appear in Intel XTU
- Restart Intel XTU (it reads registry on startup)
- Check Advanced Tuning section
- Verify registry paths exist

### Need to reset
- Import the `.reg` backup file from `backups\` folder
- Or use Intel XTU's Reset/Default button

---

**Remember:** Overclocking can void warranties. Always test thoroughly and monitor temperatures!
