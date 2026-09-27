# Overclocking Configuration Tools

This directory contains scripts and documentation for configuring MSI Afterburner and Intel XTU overclocking tools.

## Quick Start

### 1. Apply MSI Afterburner Configuration

**Option A: Use the batch file (easiest)**
```powershell
.\save-msi-config.bat
```
This will prompt for admin privileges and copy the config file.

**Option B: Use PowerShell script (run as admin)**
```powershell
# Right-click PowerShell -> Run as Administrator
cd D:\DevOptimizer\config\overclocking
.\save-msi-config-to-program-files.ps1
```

### 2. Configure Overclocking Values

**Master Configuration Script:**
```powershell
.\configure-overclocking.ps1
```

This will:
- Update MSI Afterburner config (if run as admin)
- Launch MSI Afterburner with configuration instructions
- Launch Intel XTU with configuration instructions

**Apply Conservative Overclocking:**
```powershell
.\apply-conservative-overclock.ps1
```

**Individual Tools:**
```powershell
# MSI Afterburner only
.\configure-overclocking.ps1 -ApplyMSI

# Intel XTU only
.\configure-overclocking.ps1 -ApplyXTU
```

## Scripts Overview

### Main Configuration Scripts

1. **`configure-overclocking.ps1`** - Master script that configures both tools
   - Parameters:
     - `-CoreClock <MHz>` - GPU core clock offset (default: 50)
     - `-MemClock <MHz>` - GPU memory clock offset (default: 200)
     - `-PowerLimit <%>` - GPU power limit increase (default: 5)
     - `-TurboBoostPowerMax <W>` - CPU power limit increase (default: 5)
     - `-TurboBoostShortPowerMax <W>` - CPU short power limit (default: 5)
     - `-TurboBoostMax <MHz>` - CPU turbo boost increase (default: 100)
     - `-ApplyMSI` - Only configure MSI Afterburner
     - `-ApplyXTU` - Only configure Intel XTU
     - `-LaunchOnly` - Launch tools without applying config

2. **`apply-conservative-overclock.ps1`** - Applies conservative overclocking values
   - Attempts to use MSI Afterburner Remote Server API
   - Falls back to manual instructions if API unavailable

3. **`save-msi-config-to-program-files.ps1`** - Saves MSI Afterburner config
   - Requires administrator privileges
   - Creates backup before overwriting
   - Copies from workspace to Program Files location

### Legacy Scripts

- `auto-configure-msi.ps1` - Legacy MSI Afterburner configuration
- `auto-configure-xtu.ps1` - Legacy Intel XTU configuration
- `apply-msi-overclock.ps1` - Legacy overclocking application
- `apply-xtu-overclock.ps1` - Legacy XTU configuration

## Configuration Values

### MSI Afterburner (Conservative Starting Values)

- **Core Clock:** +50 to +75 MHz
- **Memory Clock:** +200 to +300 MHz
- **Power Limit:** +5% to +10% (if available)
- **Temperature Limit:** 83°C (DO NOT increase)

### Intel XTU (i9-12900H Mobile CPU)

- **Turbo Boost Power Max:** +5-10W
- **Turbo Boost Short Power Max:** +5-10W
- **Core Voltage Offset:** +0.010-0.020V (if needed)
- **Turbo Boost Max:** +100-200 MHz (max, very conservative)

### Temperature Limits

- **CPU Core:** < 90°C
- **CPU Package:** < 95°C
- **GPU:** < 83°C

## Safety Guidelines

1. **Start Conservative:** Always start with small changes
2. **Test Thoroughly:** Run stress tests after each change (15-30 minutes)
3. **Monitor Temperatures:** Keep within safe limits
4. **Watch for Throttling:** Mobile systems throttle aggressively
5. **Document Settings:** Save profiles for easy rollback
6. **Know How to Reset:** Both tools have reset/default buttons

## Testing Procedure

### MSI Afterburner
1. Apply settings in GUI
2. Run stress test (FurMark, 3DMark, or demanding game)
3. Monitor for 15-30 minutes
4. Watch temperatures (keep below 83°C)
5. Watch for artifacts or crashes
6. If stable, try slightly higher values
7. If unstable, reduce or reset

### Intel XTU
1. Apply settings in GUI
2. Use XTU's built-in Stress Test
3. Monitor Core Temperature (< 90°C)
4. Monitor Package Temperature (< 95°C)
5. Test for 15-30 minutes
6. Watch for throttling indicators
7. If throttling occurs, reduce settings

## Troubleshooting

### MSI Afterburner
- **Settings don't apply:** Update GPU driver, run as admin
- **Voltage control locked:** Check settings (should be enabled in config)
- **Tool doesn't start:** Run as Administrator

### Intel XTU
- **Settings don't apply:** Check BIOS settings, run as admin
- **Tool doesn't detect CPU:** Restart application
- **Temperatures too high:** Reduce power limits and frequencies

## Files Structure

```
config/overclocking/
├── configure-overclocking.ps1          # Master configuration script
├── apply-conservative-overclock.ps1     # Apply conservative values
├── save-msi-config-to-program-files.ps1 # Save config (admin required)
├── save-msi-config.bat                  # Batch file for saving config
├── auto-configure-msi.ps1               # Legacy MSI script
├── auto-configure-xtu.ps1               # Legacy XTU script
├── apply-msi-overclock.ps1              # Legacy apply script
├── apply-xtu-overclock.ps1              # Legacy XTU apply script
├── CONFIGURATION-SUMMARY.md              # Original summary
├── CONFIGURATION-COMPLETE.md             # Completion status
├── CONFIGURATION-APPLIED.md              # Applied settings
├── QUICK-START-GUIDE.md                  # Step-by-step guide
├── README.md                             # This file
├── backups/                              # Configuration backups
└── documentation/                        # Detailed documentation
```

## Next Steps

1. ✅ Config files updated with proper settings
2. ✅ Scripts created for easy configuration
3. ⏭️ Run `configure-overclocking.ps1` to apply settings
4. ⏭️ Configure overclocking values in GUI
5. ⏭️ Test for stability
6. ⏭️ Document working settings

## Important Notes

- **Mobile CPU Limitations:** i9-12900H is a mobile CPU with limited overclocking capability
- **Focus on Power Management:** For mobile CPUs, power limits are more important than frequency
- **Thermal Throttling:** Laptops throttle aggressively - monitor temperatures closely
- **Stability > Performance:** A stable system is better than a crashed one

---

**Remember:** Overclocking can void warranties and may cause system instability. Use at your own risk. Always test thoroughly and monitor temperatures.
