# Intel XTU v7.14.2.67 Hardware Configuration
# Production Release - 22/10/2025
# Generated: 2025-11-16 10:25:29

## Version Information
- **XTU Version:** 7.14.2.67
- **Release Type:** Production Release
- **Release Date:** 22/10/2025
- **Platform Support:** AlderLake (Confirmed - i9-12900H)

## Hardware Information
- CPU: 12th Gen Intel(R) Core(TM) i9-12900H
- Cores: 14 Physical, 20 Logical
- Base Clock: 2500 MHz
- System: LENOVO 82RF
- RAM: 31.73 GB
- OS: Windows 10.0.26220 (Build 26220)

## Intel Specifications (i9-12900H)
- Base Power (PL1): 45W
- Turbo Boost Power Max (PL2): 115W
- Max Turbo Frequency (P-cores): 5.0 GHz
- Max Turbo Frequency (E-cores): 3.8 GHz

## Applied Configuration
- Turbo Boost Power Max (PL1): 55 W (+10 W from base)
- Turbo Boost Short Power Max (PL2): 123 W (+8 W from base)
- Core Voltage Offset: +0.010V
- Turbo Boost Max: 5100 MHz (+100 MHz)

## Configuration Mode
Balanced (Recommended)

## Known Issues (v7.14.2.67)
1. **VBS Compatibility:** Virtualization Based Security (VBS) may prevent XTU from functioning
2. **Undervolt Protection:** Some systems may prevent voltage control to default values
3. **AI Assist:** Don't cancel during characterization - allow to complete
4. **Memory Timing:** Refresh display after sleep events for accurate values

## Important Notes
- Mobile CPU (H-series) has LIMITED overclocking capability
- Focus on power management, not aggressive frequency overclocking
- Monitor temperatures: Core < 90°C, Package < 95°C
- Ensure adequate cooling
- Test stability for 15-30 minutes after applying

## Registry Locations
- HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\HardwareOptimized
- HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Settings
- HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\Profiles\Default
- HKCU:\SOFTWARE\Intel\Extreme Tuning Utility\v7.14.2.67

## Next Steps
1. Launch Intel XTU v7.14.2.67
2. Verify settings in Advanced Tuning section
3. Check for VBS conflicts (if XTU doesn't work)
4. Run Stress Test for 15-30 minutes
5. Monitor temperatures continuously
6. Adjust if throttling occurs
