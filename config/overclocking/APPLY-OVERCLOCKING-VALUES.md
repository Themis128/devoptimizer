# Apply Overclocking Values - Step by Step

**Status:** ✅ Config file saved successfully!
**Next:** Apply overclocking values in MSI Afterburner GUI

---

## Step 1: Restart MSI Afterburner (If Running)

If MSI Afterburner is currently running:
1. Close MSI Afterburner completely
2. Reopen it to load the new configuration
3. The new settings (UnlockVoltageControl, etc.) should now be enabled

---

## Step 2: Verify Settings in MSI Afterburner

1. **Open MSI Afterburner** (if not already open)
2. **Click the Settings icon** (gear icon) in the bottom-left
3. **Verify these settings are enabled:**
   - ✅ **Unlock Voltage Control** (should be checked)
   - ✅ **Unlock Voltage Monitoring** (should be checked)
   - ✅ **Start with Windows** (should be checked)
   - ✅ **Minimize to Tray** (SendToTrayOnClose - should be checked)

If any are not enabled, enable them now.

---

## Step 3: Apply Conservative Overclocking Values

**These are safe, conservative starting values:**

### Core Clock
- **Slider:** Move to **+50 MHz**
- **Location:** Top-left slider in main window
- **Note:** Start low, can increase later if stable

### Memory Clock
- **Slider:** Move to **+200 MHz**
- **Location:** Second slider from top
- **Note:** Memory overclocking is usually more stable than core

### Power Limit
- **Slider:** Move to **+5%** (if available)
- **Location:** Power Limit slider (may not be available on all GPUs)
- **Note:** Only adjust if your GPU supports it

### Temperature Limit
- **Keep at:** **83°C** (default)
- **⚠️ DO NOT increase this value!**
- **Note:** This is a safety limit - don't change it

---

## Step 4: Apply and Save

1. **Click the Apply button** (checkmark icon) in the bottom-right
   - This applies the overclocking values immediately
   - You should see the values take effect

2. **Optional: Save as Profile**
   - Click the **Profile 1** button (or any profile slot)
   - Click **Save** to save these settings
   - This allows you to load them quickly later

3. **Optional: Set Profile to Auto-Apply**
   - Right-click the profile
   - Enable "Apply this profile at startup" (if desired)

---

## Step 5: Test for Stability

**IMPORTANT:** Always test after applying overclocking!

### Quick Test (5 minutes)
1. Run a demanding game or benchmark
2. Monitor temperatures (should stay below 83°C)
3. Watch for:
   - Artifacts (visual glitches)
   - Crashes
   - Freezes
   - Black screens

### Full Stability Test (15-30 minutes)
1. **Use a stress test tool:**
   - MSI Afterburner's built-in benchmark
   - FurMark (free GPU stress test)
   - 3DMark (comprehensive benchmark)
   - Or a demanding game

2. **Monitor continuously:**
   - **GPU Temperature:** Keep below 83°C
   - **GPU Usage:** Should be at 100% during test
   - **Clock Speeds:** Should match your settings
   - **Power Usage:** Should be within limits

3. **Watch for issues:**
   - Temperature spikes
   - Throttling (clock speeds dropping)
   - Visual artifacts
   - System crashes

---

## Step 6: Adjust if Needed

### If Stable (No Issues)
- ✅ Settings are good!
- You can try slightly higher values (+10-20 MHz) if desired
- Test again after each increase
- **Remember:** Small increments, test each time

### If Unstable (Crashes, Artifacts, High Temps)
- ⚠️ Reduce the values
- Try: Core Clock -10 MHz, Memory Clock -50 MHz
- Test again
- Find the highest stable values

### If Too Hot
- ⚠️ Reduce Power Limit or Core Clock
- Ensure adequate cooling
- Check case airflow
- Consider reducing values further

---

## Step 7: Configure Intel XTU (CPU Overclocking)

1. **Launch Intel XTU:**
   - Open Start Menu
   - Search for "Intel Extreme Tuning Utility" or "XTU"
   - Launch the application

2. **Navigate to Advanced Tuning → Power tab:**
   - **Turbo Boost Power Max (PL1):** Increase by **+5W**
     - Example: If default is 45W, set to 50W
   - **Turbo Boost Short Power Max (PL2):** Increase by **+5W**
     - Example: If default is 115W, set to 120W
   - ⚠️ **Monitor temperatures closely!**

3. **Navigate to Advanced Tuning → Core tab (Optional):**
   - **Turbo Boost Max:** +100 MHz (very conservative)
   - ⚠️ Mobile CPUs throttle aggressively - be careful!

4. **Click Apply**

5. **Run Stress Test:**
   - Use XTU's built-in Stress Test
   - Run for 15-30 minutes
   - Monitor:
     - **Core Temperature:** < 90°C
     - **Package Temperature:** < 95°C
     - **Throttling:** Watch for any throttling indicators

---

## Quick Reference

### MSI Afterburner Values
- Core Clock: **+50 MHz**
- Memory Clock: **+200 MHz**
- Power Limit: **+5%** (if available)
- Temp Limit: **83°C** (don't change)

### Intel XTU Values (i9-12900H)
- Turbo Boost Power Max: **+5W**
- Turbo Boost Short Power Max: **+5W**
- Turbo Boost Max: **+100 MHz** (optional)

### Temperature Limits
- GPU: **< 83°C**
- CPU Core: **< 90°C**
- CPU Package: **< 95°C**

---

## Troubleshooting

### MSI Afterburner Settings Not Applied
- Restart MSI Afterburner
- Check if running as Administrator
- Verify GPU driver is up to date

### Overclocking Values Don't Stick
- Save as a profile
- Enable "Apply at startup" in profile settings
- Check if GPU supports the settings

### System Crashes or Artifacts
- Reduce overclocking values
- Reset to defaults if needed
- Test with lower values

### Temperatures Too High
- Reduce Power Limit
- Reduce Core Clock
- Improve cooling (check fans, airflow)
- Consider reducing values further

---

## Safety Checklist

Before applying:
- [ ] Config file saved (✅ Done!)
- [ ] MSI Afterburner restarted
- [ ] Settings verified in GUI
- [ ] Adequate cooling available
- [ ] Power adapter connected (for laptops)

After applying:
- [ ] Values applied successfully
- [ ] Profile saved (optional)
- [ ] Stability test running
- [ ] Temperatures monitored
- [ ] No crashes or artifacts

---

**Remember:** Stability > Performance. A stable system is better than a crashed one!

**Good luck with your overclocking!** 🚀
