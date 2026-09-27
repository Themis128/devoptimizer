# MSI Afterburner & Intel XTU Configuration Summary

**Generated:** 2025-01-15

## Installation Status ✅

- **MSI Afterburner:** Installed (Version 4.6.6)
  - Location: `C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe`
  - Status: ✅ Ready to configure

- **Intel XTU:** Installed (Version 7.14.2.67)
  - CPU: 12th Gen Intel(R) Core(TM) i9-12900H
  - Version Compatibility: ✅ Correct version for 12th Gen processors
  - Status: ✅ Ready to configure

## Quick Start Configuration

### MSI Afterburner Configuration

1. **Launch MSI Afterburner** (already launched by script)

2. **Initial Settings:**
   - Click the **Settings** icon (gear) in MSI Afterburner
   - Enable these options:
     - ✅ **Unlock Voltage Control** (if available)
     - ✅ **Unlock Voltage Monitoring**
     - ✅ **Apply overclocking at system startup**
     - ✅ **Start with Windows** (optional)
     - ✅ **Minimize to tray**

3. **Conservative Overclocking Settings (Start Here):**
   - **Core Clock:** +50 to +100 MHz (start low)
   - **Memory Clock:** +200 to +400 MHz (start low)
   - **Power Limit:** +5% to +10% (if available)
   - **Temperature Limit:** 83°C (default - don't increase)

4. **Testing Procedure:**
   - Click **Apply** (checkmark icon)
   - Run a stress test (FurMark, 3DMark, or game)
   - Monitor temperatures (keep below 83°C)
   - If stable for 15-30 minutes, try slightly higher settings
   - If crashes/artifacts occur, reduce settings

### Intel XTU Configuration

1. **Launch Intel XTU:**
   - Open **Start Menu**
   - Search for **"Intel Extreme Tuning Utility"** or **"XTU"**
   - Launch the application

2. **Initial Setup:**
   - Accept terms and conditions
   - The tool will detect your CPU (i9-12900H)

3. **Important Notes for Mobile CPUs (H-series):**
   - ⚠️ Mobile CPUs have **LIMITED overclocking capability**
   - Focus on **power management** and **thermal optimization**, not aggressive overclocking
   - Ensure adequate cooling before making changes

4. **Recommended Settings for i9-12900H:**

   **Power Limits (Most Important):**
   - **Turbo Boost Power Max:** Increase by 5-10W if cooling allows
   - **Turbo Boost Short Power Max:** Increase by 5-10W if cooling allows
   - ⚠️ Monitor temperatures closely!

   **Core Settings (Very Conservative):**
   - **Core Voltage Offset:** +0.010V to +0.020V (if needed for stability)
   - ⚠️ Do NOT increase voltage significantly on mobile CPUs!

   **Turbo Boost Settings:**
   - **Turbo Boost Max:** Leave at default or increase by 100-200 MHz max
   - ⚠️ Mobile CPUs will throttle if too aggressive

5. **Testing Procedure:**
   - Use XTU's built-in **Stress Test**
   - Monitor **Core Temperature** (keep below 90°C)
   - Monitor **Package Temperature** (keep below 95°C)
   - Test for at least 15-30 minutes
   - If throttling occurs, reduce settings

## Safety Guidelines

1. **Start Conservative:** Always start with small changes
2. **Test Thoroughly:** Run stress tests after each change
3. **Monitor Temperatures:**
   - CPU: Keep below 90°C
   - GPU: Keep below 83°C
4. **Watch for Throttling:** Mobile systems will throttle if too hot
5. **Document Settings:** Save profiles for easy rollback
6. **Know How to Reset:** Both tools have "Reset" or "Default" buttons

## Laptop-Specific Considerations

- **Power Limits:** Laptops have strict power limits
- **Thermal Throttling:** More aggressive than desktop systems
- **Battery Impact:** Overclocking reduces battery life
- **Cooling:** Ensure adequate airflow and cooling
- **BIOS Limits:** Some settings may be locked in BIOS

## Troubleshooting

### MSI Afterburner Issues
- If settings don't apply: Check if GPU driver is up to date
- If voltage control is locked: Enable in settings
- If tool doesn't start: Run as Administrator

### Intel XTU Issues
- If tool doesn't detect CPU: Check if CPU is supported (✅ Your CPU is supported)
- If settings don't apply: Check BIOS settings
- If version incompatibility: ✅ Your version (7.14.2.67) is correct for 12th Gen

## Next Steps

1. ✅ Both tools are installed and ready
2. ✅ MSI Afterburner has been launched
3. ⏭️ Launch Intel XTU from Start Menu
4. ⏭️ Follow the configuration steps above
5. ⏭️ Start with conservative settings and test thoroughly

**Remember:** Stability > Performance. A stable system is better than a crashed one!
