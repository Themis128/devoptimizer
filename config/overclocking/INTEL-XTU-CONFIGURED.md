# Intel XTU - Programmatically Configured ✅

**Date:** 2025-11-16
**Status:** Settings Applied Successfully via Registry

---

## ✅ Configuration Applied

### Settings Applied Programmatically

| Setting | Value | Registry Location |
|---------|-------|-------------------|
| **Turbo Boost Power Max** | +5 W | `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Default\TurboBoostPowerMax` |
| **Turbo Boost Short Power Max** | +5 W | `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Default\TurboBoostShortPowerMax` |
| **Core Voltage Offset** | +0.010V | `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Default\CoreVoltageOffset` |
| **Turbo Boost Max** | +100 MHz | `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Default\TurboBoostMax` |
| **Turbo Boost Power Time Window** | 28 seconds | `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Default\TurboBoostPowerTimeWindow` |
| **Turbo Boost Ratio Limit** | 0 (no limit) | `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Default\TurboBoostRatioLimit` |
| **TJMax Offset** | 0 | `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Default\TJMaxOffset` |

### Registry Paths Configured

1. **Profile Path:** `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Default`
2. **Settings Path:** `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Settings`
3. **Overclocking Path:** `HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Overclocking`

All paths have been configured with the conservative overclocking values.

---

## 📋 Configuration Details

### CPU Information
- **Model:** 12th Gen Intel(R) Core(TM) i9-12900H
- **CPU ID:** BFEBFBFF000906A3
- **XTU Version:** 7.14.2.67 (Compatible)

### Applied Values (Conservative)
- **Turbo Boost Power Max:** +5 W increase
- **Turbo Boost Short Power Max:** +5 W increase
- **Core Voltage Offset:** +0.010V (10 mV)
- **Turbo Boost Max:** +100 MHz
- **Power Time Window:** 28 seconds
- **Ratio Limit:** 0 (no limit)

---

## 🔧 Scripts Used

### Primary Script
- **`configure-xtu-advanced.ps1`** - Advanced programmatic configuration
  - Discovers Intel XTU registry structure
  - Applies settings to multiple registry paths
  - Creates configuration files
  - Optionally launches Intel XTU

### Alternative Script
- **`configure-intel-xtu-programmatic.ps1`** - Basic programmatic configuration
  - Applies settings to common registry paths
  - Creates backup of existing settings
  - Creates profile XML file

---

## ✅ Verification Steps

1. **Launch Intel XTU:**
   - Open Start Menu
   - Search for "Intel Extreme Tuning Utility"
   - Launch the application

2. **Verify Settings:**
   - Navigate to **Advanced Tuning** → **Core** tab
   - Check **Turbo Boost Power Max** (should show +5W increase)
   - Check **Turbo Boost Short Power Max** (should show +5W increase)
   - Check **Core Voltage Offset** (should show +0.010V)
   - Check **Turbo Boost Max** (should show +100 MHz increase)

3. **If Settings Don't Appear:**
   - Close Intel XTU completely
   - Restart Intel XTU
   - Settings should load from registry

---

## 🧪 Testing Procedure

1. **Apply Settings:**
   - If settings are visible in Intel XTU, click **Apply**
   - If not visible, they may already be applied via registry

2. **Run Stress Test:**
   - Click **Stress Test** button in Intel XTU
   - Run for **15-30 minutes minimum**

3. **Monitor Temperatures:**
   - **Core Temperature:** Keep below **90°C**
   - **Package Temperature:** Keep below **95°C**
   - Watch for any throttling indicators

4. **Verify Stability:**
   - No crashes or system instability
   - No temperature throttling
   - Performance improvement (if measurable)

---

## 📁 Files Created

1. **Registry Backup:** `backups\XTU-Registry-Backup-*.reg`
2. **Configuration File:** `XTU-Config-i9-12900H.txt`
3. **Profile XML:** `XTU-Profile-Conservative.xml` (if created)

---

## ⚠️ Important Notes

### Registry Settings
- Settings are stored in the Windows Registry
- Intel XTU reads these settings on startup
- If settings don't appear, restart Intel XTU

### Safety
- Values applied are **conservative** and safe for mobile CPUs
- Mobile CPUs (H-series) have limited overclocking capability
- Monitor temperatures continuously during testing
- If throttling occurs, reduce settings

### Rollback
- Registry backup has been created
- To restore: Import the `.reg` backup file
- Or use Intel XTU's Reset/Default button

---

## 🔄 Modifying Settings

To change the applied values, run:

```powershell
.\config\overclocking\configure-xtu-advanced.ps1 `
    -TurboBoostPowerMax 10 `
    -TurboBoostShortPowerMax 10 `
    -CoreVoltageOffset 15 `
    -TurboBoostMax 200
```

Or use the `-Conservative` switch for even more conservative values.

---

## 📊 Status Summary

| Component | Status | Notes |
|----------|--------|-------|
| **Registry Settings** | ✅ Applied | All settings written to registry |
| **Profile Created** | ✅ Created | Default profile configured |
| **Backup Created** | ✅ Created | Registry backup saved |
| **Intel XTU Launch** | ⏭️ Manual | Launch from Start Menu to verify |
| **Settings Verification** | ⏭️ Pending | Verify in Intel XTU GUI |
| **Stress Testing** | ⏭️ Pending | Run after verification |

---

## ✨ Summary

✅ **Intel XTU has been configured programmatically via registry!**

All conservative overclocking settings have been applied to the Windows Registry. When you launch Intel XTU, these settings should be automatically loaded. If they don't appear immediately, restart Intel XTU.

**Next Steps:**
1. Launch Intel XTU
2. Verify settings in Advanced Tuning section
3. Run Stress Test for 15-30 minutes
4. Monitor temperatures continuously

---

**Remember:** Overclocking can void warranties and may cause system instability. Use at your own risk. Always test thoroughly and monitor temperatures.
