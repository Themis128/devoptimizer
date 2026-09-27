# Quick Start Guide - Overclocking Configuration

**Last Updated:** 2025-11-16

## ✅ Configuration Status

### MSI Afterburner
- ✅ **Settings Applied:** UnlockVoltageControl, UnlockVoltageMonitoring, StartWithWindows, SendToTrayOnClose
- ⏭️ **Next:** Configure overclocking values in GUI

### Intel XTU
- ✅ **Version:** 7.14.2.67 (Compatible with i9-12900H)
- ⏭️ **Next:** Configure power limits and turbo boost settings in GUI

---

## MSI Afterburner - Step-by-Step Configuration

### 1. Verify Applied Settings
MSI Afterburner should now have these settings enabled:
- ✅ Unlock Voltage Control
- ✅ Unlock Voltage Monitoring
- ✅ Start with Windows
- ✅ Minimize to Tray

**To verify:**
1. Click the **Settings** icon (gear) in MSI Afterburner
2. Check that the above options are enabled
3. If not, enable them manually

### 2. Configure Conservative Overclocking Values

**Start with these conservative values:**

| Setting | Recommended Value | Notes |
|---------|------------------|-------|
| **Core Clock** | +50 to +75 MHz | Start low, increase gradually |
| **Memory Clock** | +200 to +300 MHz | Start low, increase gradually |
| **Power Limit** | +5% to +10% | If available on your GPU |
| **Temperature Limit** | 83°C (default) | **DO NOT increase** |

**How to apply:**
1. Adjust the sliders in MSI Afterburner
2. Click the **Apply** button (checkmark icon)
3. **IMPORTANT:** Test stability before increasing!

### 3. Testing Procedure

1. **Apply settings** in MSI Afterburner
2. **Run a stress test:**
   - Use MSI Afterburner's built-in benchmark
   - Or use FurMark, 3DMark, or a demanding game
3. **Monitor for 15-30 minutes:**
   - Watch temperatures (keep below 83°C)
   - Watch for artifacts, crashes, or instability
4. **If stable:** Try slightly higher values (+10-20 MHz)
5. **If unstable:** Reduce values or reset to defaults

---

## Intel XTU - Step-by-Step Configuration

### 1. Launch Intel XTU
- Open **Start Menu**
- Search for **"Intel Extreme Tuning Utility"** or **"XTU"**
- Launch the application
- Accept terms and conditions if prompted

### 2. Recommended Settings for i9-12900H (Mobile CPU)

**⚠️ IMPORTANT:** Mobile CPUs have limited overclocking capability. Focus on power management, not aggressive overclocking.

#### Power Limits (Most Important)

1. Navigate to **Advanced Tuning** → **Core** or **Power** tab
2. Find **Turbo Boost Power Max** (PL1)
   - **Current Value:** Check default
   - **Recommended:** Increase by **5-10W** if cooling allows
   - **Example:** If default is 45W, try 50-55W
3. Find **Turbo Boost Short Power Max** (PL2)
   - **Current Value:** Check default
   - **Recommended:** Increase by **5-10W** if cooling allows
   - **Example:** If default is 115W, try 120-125W

**⚠️ Monitor temperatures closely when adjusting power limits!**

#### Core Settings (Very Conservative)

1. Navigate to **Advanced Tuning** → **Core** tab
2. Find **Core Voltage Offset**
   - **Recommended:** +0.010V to +0.020V (if needed for stability)
   - **⚠️ DO NOT increase voltage significantly on mobile CPUs!**
   - Only adjust if experiencing instability at default settings

#### Turbo Boost Settings

1. Navigate to **Advanced Tuning** → **Core** tab
2. Find **Turbo Boost Max** or **Max Turbo Frequency**
   - **Recommended:** Leave at default OR increase by **100-200 MHz max**
   - **⚠️ Mobile CPUs will throttle if too aggressive**

### 3. Testing Procedure

1. **Apply settings** in Intel XTU
2. **Use XTU's built-in Stress Test:**
   - Click **Stress Test** button
   - Run for **15-30 minutes minimum**
3. **Monitor these values:**
   - **Core Temperature:** Keep below **90°C**
   - **Package Temperature:** Keep below **95°C**
   - **Throttling:** Watch for any throttling indicators
4. **If stable:** Settings are good
5. **If throttling occurs:** Reduce power limits or turbo boost
6. **If temperatures too high:** Reduce all settings

---

## Safety Checklist

Before applying any overclocking:

- [ ] Adequate cooling (laptop cooling pad, good airflow)
- [ ] Power adapter connected (for laptops)
- [ ] System is stable at default settings
- [ ] Backup of current settings created
- [ ] Know how to reset to defaults

During testing:

- [ ] Monitor temperatures continuously
- [ ] Watch for throttling indicators
- [ ] Test for at least 15-30 minutes
- [ ] Test with real workloads (games, applications)

After testing:

- [ ] Document working settings
- [ ] Save profiles in both tools
- [ ] Keep backup of stable configuration

---

## Troubleshooting

### MSI Afterburner Issues

**Settings don't apply:**
- Check if GPU driver is up to date
- Try running MSI Afterburner as Administrator
- Verify voltage control is unlocked in settings

**Voltage control locked:**
- Settings should already be applied (UnlockVoltageControl = 1)
- If still locked, check GPU compatibility
- Some GPUs don't support voltage control

### Intel XTU Issues

**Settings don't apply:**
- Check BIOS settings (some settings may be locked in BIOS)
- Verify you're running as Administrator
- Check if CPU supports the settings

**Tool doesn't detect CPU:**
- Your CPU (i9-12900H) is supported
- Version 7.14.2.67 is correct for 12th Gen processors
- Try restarting the application

**Temperatures too high:**
- Reduce power limits
- Reduce turbo boost frequencies
- Ensure adequate cooling
- Check thermal paste (if applicable)

---

## Recommended Testing Workflow

### Phase 1: Baseline (Default Settings)
1. Run stress test at default settings
2. Record temperatures and performance
3. Verify system is stable

### Phase 2: Conservative Overclocking
1. Apply conservative settings (from this guide)
2. Test for 30 minutes
3. Monitor temperatures and stability
4. If stable, proceed to Phase 3
5. If unstable, reduce settings or return to defaults

### Phase 3: Gradual Increase (Optional)
1. Increase settings by small increments (+10-20 MHz)
2. Test after each change
3. Stop when you reach:
   - Temperature limits
   - Stability issues
   - Diminishing returns

### Phase 4: Final Configuration
1. Document final stable settings
2. Save profiles in both tools
3. Create backup of configuration
4. Test with real workloads (games, applications)

---

## Important Reminders

1. **Stability > Performance:** A stable system is better than a crashed one
2. **Mobile CPUs have limitations:** Don't expect desktop-level overclocking
3. **Temperature is critical:** Monitor continuously, especially on laptops
4. **Start conservative:** Small changes, test thoroughly
5. **Document everything:** Save working configurations
6. **Know how to reset:** Both tools have reset/default buttons

---

## Quick Reference

### MSI Afterburner Quick Settings
- **Core Clock:** +50-75 MHz (start)
- **Memory Clock:** +200-300 MHz (start)
- **Power Limit:** +5-10% (if available)
- **Temp Limit:** 83°C (don't change)

### Intel XTU Quick Settings (i9-12900H)
- **Turbo Boost Power Max:** +5-10W
- **Turbo Boost Short Power Max:** +5-10W
- **Core Voltage Offset:** +0.010-0.020V (if needed)
- **Turbo Boost Max:** +100-200 MHz (max)

### Temperature Limits
- **CPU Core:** < 90°C
- **CPU Package:** < 95°C
- **GPU:** < 83°C

---

## Documentation Files

- **Full Configuration Summary:** `CONFIGURATION-SUMMARY.md`
- **Applied Settings Documentation:** `documentation\applied-configuration-*.md`
- **Backups:** `backups\backup-*`

---

**Remember:** Overclocking can void warranties and may cause system instability. Use at your own risk. Always test thoroughly and monitor temperatures.
