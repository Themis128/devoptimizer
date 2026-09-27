# Next Steps Guide - Overclocking Verification

After applying overclocking settings, follow these three essential steps to ensure stability and safety.

---

## Step 1: Verify Settings in MSI Afterburner GUI

### Quick Verification

Run the verification script:
```powershell
.\verify-settings.ps1
```

### Manual Verification Checklist

Open MSI Afterburner and verify:

- [ ] **Core Clock:** Set to +50 MHz
- [ ] **Memory Clock:** Set to +200 MHz
- [ ] **Power Limit:** Set to +5% (if available)
- [ ] **Temperature Limit:** At 83°C (default - don't change)
- [ ] **Apply Button:** Shows checkmark (settings applied)
- [ ] **Profile 1:** Is active/highlighted
- [ ] **Hotkey A:** Is assigned (if configured)

### If Settings Are Incorrect

1. Adjust sliders in MSI Afterburner
2. Click Apply (checkmark icon)
3. Save to Profile 1
4. Run verification script again

---

## Step 2: Monitor Temperatures During Use

### Quick Monitoring

Run the monitoring script:
```powershell
.\monitor-temperatures.ps1 -DurationMinutes 5
```

### Temperature Limits

**Critical Limits:**
- **GPU Temperature:** < 83°C (default limit)
- **CPU Core Temperature:** < 90°C
- **CPU Package Temperature:** < 95°C

**Target Temperatures (Ideal):**
- **GPU:** < 80°C
- **CPU Core:** < 85°C
- **CPU Package:** < 90°C

### Monitoring Methods

#### Method 1: MSI Afterburner OSD (Recommended)

1. Open MSI Afterburner
2. Click Settings (gear icon)
3. Go to "Monitoring" tab
4. Enable "Show in On-Screen Display" for:
   - GPU temperature
   - GPU usage
   - GPU clock
   - Memory clock
   - CPU temperature (if available)
5. Enable OSD (RivaTuner Statistics Server)
6. Temperatures will display during games/applications

#### Method 2: HWiNFO64 (Comprehensive)

1. Download and install HWiNFO64
2. Run HWiNFO64
3. View real-time temperatures for:
   - CPU cores
   - CPU package
   - GPU
   - GPU memory

#### Method 3: Task Manager

1. Open Task Manager (Ctrl+Shift+Esc)
2. Go to "Performance" tab
3. Select GPU to see basic temperature
4. Note: CPU temperature not shown in standard Task Manager

### What to Watch For

- **Temperature Spikes:** Sudden increases above limits
- **Throttling:** Clock speeds dropping due to heat
- **High Idle Temps:** Should be 30-50°C at idle
- **Sustained High Load:** Monitor during gaming/stress tests

---

## Step 3: Test Stability with Stress Test

### Quick Test Guide

Run the stability test script:
```powershell
.\run-stability-test.ps1 -TestDurationMinutes 30
```

### Recommended Test Duration

- **Quick Test:** 15 minutes (minimum)
- **Standard Test:** 30 minutes (recommended)
- **Thorough Test:** 60 minutes (for final validation)

### GPU Stress Test Options

#### Option 1: MSI Afterburner Built-in Benchmark

1. Open MSI Afterburner
2. Click the "K" icon (Kombustor benchmark)
3. Select a preset (e.g., 1080p)
4. Click "Run" and monitor for 30 minutes
5. Watch for:
   - Artifacts (visual glitches)
   - Crashes or freezes
   - Temperature above 83°C
   - Throttling (clock speeds dropping)

#### Option 2: FurMark

1. Download and install FurMark
2. Launch FurMark
3. Select resolution (e.g., 1920x1080)
4. Click "GPU stress test"
5. Run for 30 minutes
6. Monitor temperatures and watch for issues

#### Option 3: Demanding Game

1. Launch a demanding game
2. Play at maximum settings
3. Play for 30 minutes
4. Monitor for:
   - Crashes
   - Artifacts
   - High temperatures
   - Performance drops

### CPU Stress Test Options

#### Option 1: Intel XTU Stress Test

1. Open Intel XTU
2. Click "Stress Test" button
3. Run for 30 minutes
4. Monitor:
   - Core Temperature (< 90°C)
   - Package Temperature (< 95°C)
   - Throttling indicators
   - System stability

#### Option 2: Prime95

1. Launch Prime95
2. Select "Just stress testing"
3. Choose "Small FFTs" or "Blend"
4. Run for 30 minutes
5. Monitor temperatures and watch for errors

### Combined CPU + GPU Test

For comprehensive testing:

1. Run GPU stress test (FurMark, MSI Afterburner benchmark)
2. Simultaneously run CPU stress test (Intel XTU, Prime95)
3. Run both for 30 minutes
4. Monitor all temperatures and system stability
5. This tests power sharing between CPU and GPU

### Test Checklist

**Before Testing:**
- [ ] Overclocking settings applied
- [ ] Temperature monitoring enabled (MSI Afterburner OSD)
- [ ] Adequate cooling available
- [ ] System is stable at idle

**During Testing:**
- [ ] Monitor GPU temperature (< 83°C)
- [ ] Monitor CPU temperature (< 90°C)
- [ ] Watch for artifacts or visual glitches
- [ ] Watch for crashes or freezes
- [ ] Monitor clock speeds (watch for throttling)
- [ ] Check power consumption

**After Testing:**
- [ ] System remained stable (no crashes)
- [ ] No artifacts observed
- [ ] Temperatures stayed within limits
- [ ] No throttling occurred
- [ ] Performance is as expected

---

## Complete Workflow

Run all three steps in sequence:

```powershell
.\next-steps-complete.ps1
```

Or run individual steps:

```powershell
# Step 1: Verify
.\verify-settings.ps1

# Step 2: Monitor (5 minutes)
.\monitor-temperatures.ps1 -DurationMinutes 5

# Step 3: Test (30 minutes)
.\run-stability-test.ps1 -TestDurationMinutes 30
```

---

## Interpreting Results

### Test Passed ✅

**If all tests pass:**
- ✅ Settings are stable
- ✅ Temperatures are within limits
- ✅ No crashes or artifacts
- ✅ No throttling occurred

**Action:** You can use Profile 1 with confidence. Monitor temperatures during normal use.

### Test Failed ❌

**If tests fail:**
- ❌ Crashes or freezes
- ❌ Visual artifacts
- ❌ Temperatures too high
- ❌ Throttling occurred

**Action:**
1. Reduce overclocking values
2. Test again with lower settings
3. Find the highest stable values
4. Document working configuration

### Partial Success ⚠️

**If some issues occur:**
- ⚠️ High temperatures but no crashes
- ⚠️ Occasional throttling
- ⚠️ Minor artifacts

**Action:**
1. Reduce values slightly
2. Improve cooling if possible
3. Test again
4. Find balance between performance and stability

---

## Safety Reminders

1. **Never exceed temperature limits**
2. **Stop testing immediately if temperatures spike**
3. **Watch for throttling - it reduces performance**
4. **Test thoroughly before daily use**
5. **Monitor during initial use after overclocking**
6. **Know how to reset to defaults**

---

## Troubleshooting

### High Temperatures
- Reduce overclocking values
- Improve cooling (cooling pad, clean heatsinks)
- Check thermal paste
- Reduce power limits

### Instability
- Reduce core clock first
- Then reduce memory clock
- Test after each change
- Find stable values gradually

### Throttling
- Reduce power limits
- Reduce frequency overclocks
- Improve cooling
- Check for dust accumulation

---

## Summary

**Three Essential Steps:**
1. ✅ **Verify** - Check settings are correct
2. ✅ **Monitor** - Watch temperatures
3. ✅ **Test** - Run stability tests

**Remember:** Stability > Performance. A stable system is better than a crashed one!

---

**Scripts Available:**
- `verify-settings.ps1` - Verify MSI Afterburner settings
- `monitor-temperatures.ps1` - Monitor temperatures
- `run-stability-test.ps1` - Stability test guide
- `next-steps-complete.ps1` - Run all steps in sequence

All scripts are in: `D:\DevOptimizer\config\overclocking\`
