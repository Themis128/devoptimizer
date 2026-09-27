# CLI Configuration Guide - MSI Afterburner & Intel XTU

**Yes, both can be configured via CLI!** This guide shows you how.

---

## Intel XTU CLI Configuration

### ✅ Already Working!

You've successfully configured Intel XTU via CLI using registry. The settings were applied to:
- `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\HardwareOptimized`
- `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Settings`
- `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Profiles\Default`

### Quick CLI Commands

**Use existing hardware-based script:**
```powershell
# Run as Administrator
cd D:\DevOptimizer\config\overclocking

# Conservative (recommended start)
.\configure-xtu-hardware-based.ps1 -Conservative

# Moderate (your current settings)
.\configure-xtu-hardware-based.ps1 -UseMaxCapabilities

# Custom values
.\configure-xtu-hardware-based.ps1 -TurboBoostPowerMax 60 -TurboBoostShortPowerMax 125 -CoreVoltageOffset 20 -TurboBoostMax 5200
```

**Simple wrapper:**
```powershell
# Run as Administrator
.\apply-xtu-simple.ps1 -Moderate
.\apply-xtu-simple.ps1 -Conservative
.\apply-xtu-simple.ps1 -Aggressive
```

**Direct CLI (new script):**
```powershell
# Run as Administrator
.\apply-xtu-cli.ps1 -PL1Increase 15 -PL2Increase 10 -VoltageOffset 20 -TurboBoostIncrease 200
```

### Your Current Settings (Applied via CLI)

Based on your output, these settings were successfully applied:

```
Turbo Boost Power Max (PL1): 45W -> 60W (+15W)
Turbo Boost Short Power Max (PL2): 115W -> 125W (+10W)
Core Voltage Offset: +0.020V (20 mV)
Turbo Boost Max: 5000 MHz -> 5200 MHz (+200 MHz)
```

**Status:** ✅ **Applied successfully via CLI/Registry!**

---

## MSI Afterburner CLI Configuration

### Profile Method (Most Reliable)

**Apply existing profile:**
```powershell
# Apply Profile 1
.\apply-msi-profile.ps1 -ProfileNumber 1

# Or direct command
& "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe" -Profile1
```

**Create and apply profile:**
```powershell
.\create-and-apply-profile.ps1 -CoreClock 50 -MemClock 200 -PowerLimit 5
```

### Remote Server API (If Enabled)

```powershell
$msiServerUrl = "http://localhost:13247"
$body = @{
    CoreClk = 50
    MemClk = 200
    PowerLimit = 5
} | ConvertTo-Json

Invoke-WebRequest -Uri "$msiServerUrl/SetOCProfile" -Method POST -Body $body -ContentType "application/json"
```

**Note:** Remote Server must be enabled in MSI Afterburner settings.

---

## Combined CLI Configuration

### Apply Both at Once

**New combined script:**
```powershell
# Run as Administrator
.\apply-all-overclock-cli.ps1
```

**With custom values:**
```powershell
# Run as Administrator
.\apply-all-overclock-cli.ps1 `
    -GPUCoreClock 50 -GPUMemClock 200 -GPUPowerLimit 5 `
    -PL1Increase 15 -PL2Increase 10 -VoltageOffset 20 -TurboBoostIncrease 200
```

**MSI Afterburner only:**
```powershell
.\apply-all-overclock-cli.ps1 -MSIOnly -GPUCoreClock 50 -GPUMemClock 200
```

**Intel XTU only:**
```powershell
# Run as Administrator
.\apply-all-overclock-cli.ps1 -XTUOnly -PL1Increase 15 -PL2Increase 10
```

---

## Complete CLI Workflow

### Step 1: Configure MSI Afterburner

```powershell
# Create profile first (one-time, manual in GUI)
# Then apply via CLI:
.\apply-msi-profile.ps1 -ProfileNumber 1
```

### Step 2: Configure Intel XTU

```powershell
# Run as Administrator
.\configure-xtu-hardware-based.ps1 -UseMaxCapabilities
```

### Step 3: Apply Both

```powershell
# Run as Administrator
.\apply-all-overclock-cli.ps1
```

---

## Verification

### Verify MSI Afterburner

```powershell
.\verify-settings.ps1
```

### Verify Intel XTU

```powershell
# Run as Administrator
.\apply-xtu-cli.ps1 -VerifyOnly
```

Or check registry directly:
```powershell
Get-ItemProperty "HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Settings" | Select-Object TurboBoostPowerMax, TurboBoostShortPowerMax, TurboBoostMax, CoreVoltageOffset
```

---

## Quick Reference

### Intel XTU CLI Commands

| Command | Description |
|---------|-------------|
| `.\configure-xtu-hardware-based.ps1 -Conservative` | Conservative settings (PL1: 50W, PL2: 120W) |
| `.\configure-xtu-hardware-based.ps1 -UseMaxCapabilities` | Your current settings (PL1: 60W, PL2: 125W) |
| `.\apply-xtu-simple.ps1 -Moderate` | Moderate preset |
| `.\apply-xtu-cli.ps1 -PL1Increase 15 -PL2Increase 10` | Custom values |

### MSI Afterburner CLI Commands

| Command | Description |
|---------|-------------|
| `.\apply-msi-profile.ps1 -ProfileNumber 1` | Apply Profile 1 |
| `MSIAfterburner.exe -Profile1` | Direct profile application |
| `.\create-and-apply-profile.ps1` | Create and apply profile |

### Combined Commands

| Command | Description |
|---------|-------------|
| `.\apply-all-overclock-cli.ps1` | Apply both MSI and XTU |
| `.\apply-all-overclock-cli.ps1 -MSIOnly` | MSI Afterburner only |
| `.\apply-all-overclock-cli.ps1 -XTUOnly` | Intel XTU only |

---

## Your Current Configuration

### Intel XTU (Applied via CLI ✅)

- **PL1:** 60W (+15W from base 45W)
- **PL2:** 125W (+10W from base 115W)
- **Voltage Offset:** +20mV
- **Turbo Boost:** 5200 MHz (+200 MHz from base 5000 MHz)

**Status:** ✅ Successfully applied via registry

### MSI Afterburner

- **Profile 1:** Core +50 MHz, Memory +200 MHz, Power +5%
- **Status:** Ready to apply via CLI

---

## Summary

**Yes, both can be configured via CLI!**

- ✅ **Intel XTU:** Via registry (already working for you)
- ✅ **MSI Afterburner:** Via profiles (most reliable method)
- ✅ **Combined:** Use `apply-all-overclock-cli.ps1`

**Your Intel XTU settings are already applied via CLI!** Just launch Intel XTU to verify they're active.

**For MSI Afterburner:** Use profile method - create profile once, then apply via CLI anytime.

---

**All scripts are in:** `D:\DevOptimizer\config\overclocking\`
