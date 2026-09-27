# Programmatic Overclocking Configuration Guide

This guide explains how to configure overclocking programmatically for both MSI Afterburner and Intel XTU.

## MSI Afterburner Programmatic Configuration

### Method 1: Using Profiles (Recommended)

MSI Afterburner supports loading profiles via command-line arguments. This is the most reliable method.

#### Step 1: Create a Profile (One-time setup)

1. **Manually create the profile first:**
   - Open MSI Afterburner
   - Set Core Clock: +50 MHz
   - Set Memory Clock: +200 MHz
   - Set Power Limit: +5% (if available)
   - Click Apply
   - Click Profile 1 button
   - Click Save

#### Step 2: Apply Profile Programmatically

Once the profile is saved, you can apply it programmatically:

```powershell
# Apply Profile 1
& "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe" -Profile1

# Apply Profile 2
& "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe" -Profile2
```

**Script:** Use `apply-msi-profile.ps1`:
```powershell
.\apply-msi-profile.ps1 -ProfileNumber 1
```

### Method 2: Remote Server API (If Enabled)

MSI Afterburner has an optional Remote Server that can be controlled via HTTP API.

#### Enable Remote Server

1. Open MSI Afterburner
2. Click Settings (gear icon)
3. Go to "General" tab
4. Check "Enable hardware control and monitoring"
5. Check "Enable low-level hardware access interface"
6. Click OK

#### Use Remote Server API

```powershell
$msiServerUrl = "http://localhost:13247"

# Get status
Invoke-WebRequest -Uri "$msiServerUrl/GetStatus"

# Set overclocking (format may vary by version)
$body = @{
    CoreClk = 50
    MemClk = 200
    PowerLimit = 5
} | ConvertTo-Json

Invoke-WebRequest -Uri "$msiServerUrl/SetOCProfile" -Method POST -Body $body -ContentType "application/json"
```

**Note:** The Remote Server API format is not officially documented and may vary by MSI Afterburner version.

### Method 3: Command-Line Arguments (Limited Support)

Some versions of MSI Afterburner support direct command-line arguments:

```powershell
# These may not work on all versions
& "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe" -CoreClkOffset=50 -MemClkOffset=200
```

**Note:** This method is not reliable across all versions.

## Intel XTU Programmatic Configuration

Intel XTU configuration is more complex and CPU-specific. Registry modification is possible but risky.

### Method 1: Registry Modification (Advanced - Use with Caution)

Intel XTU stores settings in the Windows registry, but the structure is complex and CPU-specific.

**Registry Location:**
```
HKEY_LOCAL_MACHINE\SOFTWARE\Intel\Extreme Tuning Utility
```

**Warning:** Direct registry modification can cause system instability. Manual GUI configuration is strongly recommended.

### Method 2: Configuration File (If Available)

Some Intel XTU versions store settings in configuration files. Check:
```
C:\Program Files (x86)\Intel\Intel(R) Extreme Tuning Utility\Client\
```

### Method 3: Manual Configuration (Recommended)

Due to the complexity and risks, manual configuration via GUI is recommended for Intel XTU.

## Automated Scripts

### Quick Apply Profile

```powershell
# Apply MSI Afterburner Profile 1
.\apply-msi-profile.ps1 -ProfileNumber 1
```

### Full Programmatic Configuration

```powershell
# Attempts all programmatic methods
.\apply-overclock-programmatic.ps1
```

### Admin Version (For Registry Access)

```powershell
# Run as Administrator
.\apply-overclock-admin.ps1
```

## Complete Workflow

### Initial Setup (One-time)

1. **Create MSI Afterburner Profile:**
   - Open MSI Afterburner
   - Set conservative values (Core: +50, Memory: +200, Power: +5%)
   - Save as Profile 1
   - (Optional) Enable "Apply at startup" in profile settings

2. **Configure Intel XTU:**
   - Open Intel XTU
   - Set power limits (+5W each)
   - Apply settings
   - Save profile if available

### Daily Use

**Apply MSI Afterburner Profile:**
```powershell
.\apply-msi-profile.ps1 -ProfileNumber 1
```

Or create a shortcut with:
```
Target: "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe" -Profile1
```

## Scripts Available

1. **`apply-overclock-programmatic.ps1`** - Main programmatic configuration script
   - Tries Remote Server API
   - Tries command-line methods
   - Launches tools with instructions

2. **`apply-msi-profile.ps1`** - Apply saved MSI Afterburner profile
   - Most reliable method
   - Requires profile to be created first

3. **`create-msi-profile.ps1`** - Helper script for profile creation
   - Provides instructions
   - Attempts API method if available

4. **`apply-overclock-admin.ps1`** - Admin version for registry access
   - Requires administrator privileges
   - For advanced Intel XTU registry modification

5. **`run-programmatic-config.bat`** - Easy batch file launcher
   - Double-click to run
   - Prompts for admin if needed

## Limitations

### MSI Afterburner
- ✅ Profile loading works reliably
- ⚠️ Remote Server API format is undocumented
- ⚠️ Direct command-line arguments vary by version
- ⚠️ Some settings require GUI interaction

### Intel XTU
- ⚠️ Registry structure is complex and CPU-specific
- ⚠️ Direct programmatic configuration is risky
- ✅ Manual GUI configuration is recommended
- ⚠️ No official API or command-line interface

## Best Practices

1. **Create Profiles First:** Set up profiles manually, then use programmatic loading
2. **Test Thoroughly:** Always test programmatic changes
3. **Have Fallbacks:** Know how to reset to defaults
4. **Monitor Temperatures:** Watch temps after programmatic changes
5. **Start Conservative:** Use conservative values for automation

## Troubleshooting

### MSI Afterburner Profile Not Applying
- Ensure MSI Afterburner is running
- Verify profile exists and is saved
- Check if profile is locked or corrupted
- Try manual application first

### Remote Server API Not Working
- Enable Remote Server in MSI Afterburner settings
- Check if port 13247 is accessible
- Verify MSI Afterburner version supports API
- Check firewall settings

### Intel XTU Registry Modification Fails
- Ensure running as Administrator
- Verify registry path exists
- Check CPU-specific registry structure
- Consider manual GUI configuration instead

## Summary

**For MSI Afterburner:**
- ✅ Use Profile method (most reliable)
- ⚠️ Remote Server API (if enabled, format varies)
- ❌ Direct CLI arguments (unreliable)

**For Intel XTU:**
- ✅ Manual GUI configuration (recommended)
- ⚠️ Registry modification (advanced, risky)
- ❌ No official programmatic interface

**Recommended Approach:**
1. Create MSI Afterburner profile manually
2. Use `apply-msi-profile.ps1` to apply it programmatically
3. Configure Intel XTU manually (one-time setup)
4. Use profiles/shortcuts for daily application

---

**Remember:** Overclocking can cause system instability. Always test thoroughly and monitor temperatures!
