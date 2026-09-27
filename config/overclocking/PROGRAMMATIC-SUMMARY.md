# Programmatic Overclocking Configuration - Summary

## ✅ What's Working

### MSI Afterburner - Profile Method (Recommended)

**Status:** ✅ **Fully Working**

MSI Afterburner supports loading profiles programmatically via command-line. This is the most reliable method.

**How it works:**
1. Create a profile manually (one-time setup)
2. Apply the profile programmatically anytime using: `MSIAfterburner.exe -Profile1`

**Scripts Available:**
- `apply-msi-profile.ps1` - Apply saved profile
- `setup-and-apply-overclock.ps1` - Complete setup and application workflow

**Usage:**
```powershell
# Apply Profile 1
.\apply-msi-profile.ps1 -ProfileNumber 1

# Or use the complete script
.\setup-and-apply-overclock.ps1 -ApplyOnly
```

**Desktop Shortcut:**
A shortcut has been created on your desktop: "Apply Overclock Profile 1.lnk"
- Double-click to apply the profile anytime
- No need to open MSI Afterburner GUI

## ⚠️ Limitations

### MSI Afterburner - Direct Value Setting

**Status:** ⚠️ **Partially Working**

- **Remote Server API:** Works if enabled, but API format is undocumented
- **Command-Line Arguments:** Limited support, varies by version
- **Profile Method:** ✅ Most reliable (recommended)

### Intel XTU

**Status:** ⚠️ **Manual Configuration Recommended**

- No official programmatic interface
- Registry modification is possible but complex and risky
- Manual GUI configuration is strongly recommended

## 📋 Complete Workflow

### Initial Setup (One-Time)

1. **Create MSI Afterburner Profile:**
   ```powershell
   # Run setup script (will guide you through manual profile creation)
   .\setup-and-apply-overclock.ps1
   ```

   Or manually:
   - Open MSI Afterburner
   - Set Core Clock: +50 MHz
   - Set Memory Clock: +200 MHz
   - Set Power Limit: +5%
   - Click Apply
   - Click Profile 1 → Save

2. **Configure Intel XTU (Manual):**
   - Open Intel XTU
   - Set Turbo Boost Power Max: +5W
   - Set Turbo Boost Short Power Max: +5W
   - Click Apply

### Daily Use

**Apply MSI Afterburner Profile:**
- **Option 1:** Double-click desktop shortcut "Apply Overclock Profile 1.lnk"
- **Option 2:** Run script: `.\apply-msi-profile.ps1 -ProfileNumber 1`
- **Option 3:** Command-line: `MSIAfterburner.exe -Profile1`

**Intel XTU:**
- Settings persist after manual configuration
- No programmatic application needed

## 🚀 Quick Start

### Apply Overclocking Now

```powershell
cd D:\DevOptimizer\config\overclocking
.\apply-msi-profile.ps1 -ProfileNumber 1
```

Or simply double-click the desktop shortcut: **"Apply Overclock Profile 1.lnk"**

### Setup New Profile

```powershell
cd D:\DevOptimizer\config\overclocking
.\setup-and-apply-overclock.ps1
```

## 📁 Available Scripts

| Script | Purpose | Status |
|--------|---------|--------|
| `apply-msi-profile.ps1` | Apply saved MSI Afterburner profile | ✅ Working |
| `setup-and-apply-overclock.ps1` | Complete setup and application | ✅ Working |
| `apply-overclock-programmatic.ps1` | Attempt all programmatic methods | ⚠️ Partial |
| `apply-overclock-admin.ps1` | Admin version for registry access | ⚠️ Advanced |
| `create-msi-profile.ps1` | Helper for profile creation | ⚠️ Instructions |

## 🎯 Recommended Approach

**For MSI Afterburner:**
1. ✅ Create profile manually (one-time)
2. ✅ Use `apply-msi-profile.ps1` or desktop shortcut to apply
3. ✅ Most reliable and safe method

**For Intel XTU:**
1. ✅ Configure manually via GUI (one-time)
2. ✅ Settings persist automatically
3. ✅ No programmatic application needed

## 📝 Example Usage

### Apply Profile on Startup

Create a startup script or add to Task Scheduler:

```powershell
& "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe" -Profile1
```

### Apply Profile via Script

```powershell
# Simple application
.\apply-msi-profile.ps1 -ProfileNumber 1

# With custom values (requires profile to exist with those values)
.\setup-and-apply-overclock.ps1 -CoreClock 75 -MemClock 300 -ProfileNumber 1 -ApplyOnly
```

## 🔧 Troubleshooting

### Profile Not Applying

1. **Check if profile exists:**
   - Open MSI Afterburner
   - Verify Profile 1 is saved
   - Check profile values

2. **Ensure MSI Afterburner is running:**
   - Profile application requires MSI Afterburner to be running
   - Start MSI Afterburner first if needed

3. **Try manual application:**
   - Open MSI Afterburner
   - Click Profile 1 button manually
   - If it works, the profile exists

### Desktop Shortcut Not Working

1. Check if shortcut target is correct
2. Verify MSI Afterburner path
3. Recreate shortcut if needed:
   ```powershell
   .\setup-and-apply-overclock.ps1 -ApplyOnly
   ```

## ✨ Summary

**Programmatic Configuration Status:**

- ✅ **MSI Afterburner Profile Loading:** Fully working
- ⚠️ **MSI Afterburner Direct Setting:** Partially working (API dependent)
- ⚠️ **Intel XTU:** Manual configuration recommended

**Best Practice:**
- Create MSI Afterburner profile manually (one-time)
- Use programmatic profile loading for daily use
- Configure Intel XTU manually (settings persist)

**You're all set!** Use the desktop shortcut or `apply-msi-profile.ps1` to apply overclocking programmatically.

---

**Files Created:**
- Desktop shortcut: "Apply Overclock Profile 1.lnk"
- Scripts in: `D:\DevOptimizer\config\overclocking\`
- Documentation: `PROGRAMMATIC-CONFIGURATION.md`
