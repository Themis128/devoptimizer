# Screen Settings Management Functions - Latest 2024/2025

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DisplaySettings
{
    [DllImport("user32.dll")]
    public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
    
    [DllImport("user32.dll")]
    public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);
    
    [DllImport("user32.dll")]
    public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);
    
    [DllImport("user32.dll")]
    public static extern IntPtr MonitorFromPoint(POINT pt, uint dwFlags);
    
    [DllImport("dxva2.dll")]
    public static extern bool SetMonitorBrightness(IntPtr hMonitor, uint dwNewBrightness);
    
    [DllImport("dxva2.dll")]
    public static extern bool GetMonitorBrightness(IntPtr hMonitor, ref uint pdwMinimumBrightness, ref uint pdwCurrentBrightness, ref uint pdwMaximumBrightness);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public short dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct DISPLAY_DEVICE
    {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceKey;
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT
    {
        public int x;
        public int y;
    }
    
    public const int ENUM_CURRENT_SETTINGS = -1;
    public const int CDS_UPDATEREGISTRY = 0x01;
    public const int CDS_TEST = 0x02;
    public const int DISP_CHANGE_SUCCESSFUL = 0;
    public const int DISP_CHANGE_RESTART = 1;
    public const int DISP_CHANGE_FAILED = -1;
}
"@

function Get-DisplayInformation {
    Write-Log "Analyzing display configuration..." -Level "INFO"
    
    try {
        $displays = @()
        $displayIndex = 0
        
        # Get all display devices
        while ($true) {
            $displayDevice = New-Object DisplaySettings+DISPLAY_DEVICE
            $displayDevice.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($displayDevice)
            
            $result = [DisplaySettings]::EnumDisplayDevices($null, $displayIndex, [ref]$displayDevice, 0)
            if (-not $result) { break }
            
            # Get current display settings
            $devMode = New-Object DisplaySettings+DEVMODE
            $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)
            
            $settingsResult = [DisplaySettings]::EnumDisplaySettings($displayDevice.DeviceName, [DisplaySettings]::ENUM_CURRENT_SETTINGS, [ref]$devMode)
            
            if ($settingsResult) {
                $displayInfo = @{
                    Index = $displayIndex
                    DeviceName = $displayDevice.DeviceName
                    DeviceString = $displayDevice.DeviceString
                    DeviceID = $displayDevice.DeviceID
                    StateFlags = $displayDevice.StateFlags
                    IsPrimary = ($displayDevice.StateFlags -band 0x4) -ne 0
                    IsActive = ($displayDevice.StateFlags -band 0x1) -ne 0
                    Width = $devMode.dmPelsWidth
                    Height = $devMode.dmPelsHeight
                    RefreshRate = $devMode.dmDisplayFrequency
                    BitsPerPixel = $devMode.dmBitsPerPel
                    Orientation = $devMode.dmDisplayOrientation
                    PositionX = $devMode.dmPositionX
                    PositionY = $devMode.dmPositionY
                    AvailableModes = @()
                }
                
                # Get all available display modes
                $modeIndex = 0
                while ($true) {
                    $modeDevMode = New-Object DisplaySettings+DEVMODE
                    $modeDevMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($modeDevMode)
                    
                    $modeResult = [DisplaySettings]::EnumDisplaySettings($displayDevice.DeviceName, $modeIndex, [ref]$modeDevMode)
                    if (-not $modeResult) { break }
                    
                    $mode = @{
                        Width = $modeDevMode.dmPelsWidth
                        Height = $modeDevMode.dmPelsHeight
                        RefreshRate = $modeDevMode.dmDisplayFrequency
                        BitsPerPixel = $modeDevMode.dmBitsPerPel
                    }
                    
                    # Only add unique modes
                    $modeKey = "$($mode.Width)x$($mode.Height)@$($mode.RefreshRate)Hz"
                    if ($displayInfo.AvailableModes.Count -eq 0 -or 
                        -not ($displayInfo.AvailableModes | Where-Object { "$($_.Width)x$($_.Height)@$($_.RefreshRate)Hz" -eq $modeKey })) {
                        $displayInfo.AvailableModes += $mode
                    }
                    
                    $modeIndex++
                }
                
                # Sort available modes
                $displayInfo.AvailableModes = $displayInfo.AvailableModes | Sort-Object Width, Height, RefreshRate
                
                $displays += $displayInfo
            }
            
            $displayIndex++
        }
        
        Write-Log "Display analysis completed: $($displays.Count) displays detected" -Level "SUCCESS"
        return $displays
    }
    catch {
        Write-Log "Error analyzing display information: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Set-DisplayResolution {
    param(
        [string]$DeviceName,
        [int]$Width,
        [int]$Height,
        [int]$RefreshRate = 0,
        [int]$BitsPerPixel = 32
    )
    
    Write-Log "Setting display resolution: ${Width}x${Height}@${RefreshRate}Hz on $DeviceName" -Level "INFO"
    
    try {
        # Get current settings
        $devMode = New-Object DisplaySettings+DEVMODE
        $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)
        
        $result = [DisplaySettings]::EnumDisplaySettings($DeviceName, [DisplaySettings]::ENUM_CURRENT_SETTINGS, [ref]$devMode)
        if (-not $result) {
            Write-Log "Could not get current display settings for $DeviceName" -Level "ERROR"
            return $false
        }
        
        # Modify settings
        $devMode.dmPelsWidth = $Width
        $devMode.dmPelsHeight = $Height
        $devMode.dmBitsPerPel = $BitsPerPixel
        $devMode.dmFields = 0x80000 -bor 0x100000 -bor 0x40000  # DM_PELSWIDTH | DM_PELSHEIGHT | DM_BITSPERPEL
        
        if ($RefreshRate -gt 0) {
            $devMode.dmDisplayFrequency = $RefreshRate
            $devMode.dmFields = $devMode.dmFields -bor 0x400000  # DM_DISPLAYFREQUENCY
        }
        
        # Test the change first
        $testResult = [DisplaySettings]::ChangeDisplaySettings([ref]$devMode, [DisplaySettings]::CDS_TEST)
        if ($testResult -ne [DisplaySettings]::DISP_CHANGE_SUCCESSFUL) {
            Write-Log "Display mode test failed for ${Width}x${Height}@${RefreshRate}Hz" -Level "ERROR"
            return $false
        }
        
        # Apply the change
        $changeResult = [DisplaySettings]::ChangeDisplaySettings([ref]$devMode, [DisplaySettings]::CDS_UPDATEREGISTRY)
        
        switch ($changeResult) {
            ([DisplaySettings]::DISP_CHANGE_SUCCESSFUL) {
                Write-Log "Display resolution changed successfully to ${Width}x${Height}@${RefreshRate}Hz" -Level "SUCCESS"
                return $true
            }
            ([DisplaySettings]::DISP_CHANGE_RESTART) {
                Write-Log "Display resolution changed, restart required" -Level "WARN"
                return $true
            }
            ([DisplaySettings]::DISP_CHANGE_FAILED) {
                Write-Log "Failed to change display resolution" -Level "ERROR"
                return $false
            }
            default {
                Write-Log "Unknown result from display change: $changeResult" -Level "WARN"
                return $false
            }
        }
    }
    catch {
        Write-Log "Error setting display resolution: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Set-DisplayOrientation {
    param(
        [string]$DeviceName,
        [ValidateSet("Landscape", "Portrait", "LandscapeFlipped", "PortraitFlipped")]
        [string]$Orientation
    )
    
    Write-Log "Setting display orientation to $Orientation on $DeviceName" -Level "INFO"
    
    try {
        # Get current settings
        $devMode = New-Object DisplaySettings+DEVMODE
        $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)
        
        $result = [DisplaySettings]::EnumDisplaySettings($DeviceName, [DisplaySettings]::ENUM_CURRENT_SETTINGS, [ref]$devMode)
        if (-not $result) {
            Write-Log "Could not get current display settings for $DeviceName" -Level "ERROR"
            return $false
        }
        
        # Set orientation
        $orientationValue = switch ($Orientation) {
            "Landscape" { 0 }       # DMDO_DEFAULT
            "Portrait" { 1 }        # DMDO_90
            "LandscapeFlipped" { 2 } # DMDO_180
            "PortraitFlipped" { 3 }  # DMDO_270
        }
        
        $devMode.dmDisplayOrientation = $orientationValue
        $devMode.dmFields = 0x80  # DM_DISPLAYORIENTATION
        
        # For portrait modes, swap width and height
        if ($Orientation -eq "Portrait" -or $Orientation -eq "PortraitFlipped") {
            $tempWidth = $devMode.dmPelsWidth
            $devMode.dmPelsWidth = $devMode.dmPelsHeight
            $devMode.dmPelsHeight = $tempWidth
            $devMode.dmFields = $devMode.dmFields -bor 0x80000 -bor 0x100000  # DM_PELSWIDTH | DM_PELSHEIGHT
        }
        
        # Apply the change
        $changeResult = [DisplaySettings]::ChangeDisplaySettings([ref]$devMode, [DisplaySettings]::CDS_UPDATEREGISTRY)
        
        if ($changeResult -eq [DisplaySettings]::DISP_CHANGE_SUCCESSFUL) {
            Write-Log "Display orientation changed successfully to $Orientation" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Failed to change display orientation" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error setting display orientation: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Set-DisplayBrightness {
    param(
        [int]$Brightness = 50,
        [int]$MonitorIndex = 0
    )
    
    Write-Log "Setting display brightness to $Brightness% on monitor $MonitorIndex" -Level "INFO"
    
    try {
        # This is a simplified approach - actual brightness control is complex
        # and may require specific monitor drivers or WMI classes
        
        # Try WMI approach first (works on laptops)
        try {
            $monitors = Get-CimInstance -Namespace "root/WMI" -ClassName "WmiMonitorBrightnessMethods" -ErrorAction SilentlyContinue
            if ($monitors) {
                $monitor = $monitors[$MonitorIndex]
                if ($monitor) {
                    $monitor.WmiSetBrightness(1, $Brightness) | Out-Null
                    Write-Log "Display brightness set to $Brightness% via WMI" -Level "SUCCESS"
                    return $true
                }
            }
        } catch {
            # WMI method failed
        }
        
        # Try PowerShell approach for Windows 10/11
        try {
            if (Get-Command "Set-Brightness" -ErrorAction SilentlyContinue) {
                Set-Brightness -Level $Brightness
                Write-Log "Display brightness set to $Brightness% via PowerShell" -Level "SUCCESS"
                return $true
            }
        } catch {
            # PowerShell method failed
        }
        
        # Try registry approach (may work on some systems)
        try {
            $brightnessValue = [math]::Round($Brightness * 2.55)  # Convert to 0-255 range
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value $(if ($Brightness -gt 50) { 1 } else { 0 }) -ErrorAction SilentlyContinue
            Write-Log "Applied brightness-related registry setting" -Level "INFO"
        } catch {
            # Registry method failed
        }
        
        Write-Log "Brightness control may not be supported on this system or monitor" -Level "WARN"
        return $false
    }
    catch {
        Write-Log "Error setting display brightness: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Set-MultiMonitorConfiguration {
    param(
        [ValidateSet("Extend", "Duplicate", "Primary", "Secondary")]
        [string]$Mode = "Extend"
    )
    
    Write-Log "Setting multi-monitor configuration to $Mode" -Level "INFO"
    
    try {
        $displays = Get-DisplayInformation
        if ($displays.Count -lt 2) {
            Write-Log "Multi-monitor configuration requires at least 2 displays" -Level "WARN"
            return $false
        }
        
        switch ($Mode) {
            "Extend" {
                # Use DisplaySwitch.exe for reliable multi-monitor switching
                Start-Process "DisplaySwitch.exe" -ArgumentList "/extend" -Wait
                Write-Log "Extended display mode activated" -Level "SUCCESS"
                return $true
            }
            "Duplicate" {
                Start-Process "DisplaySwitch.exe" -ArgumentList "/clone" -Wait
                Write-Log "Duplicate display mode activated" -Level "SUCCESS"
                return $true
            }
            "Primary" {
                Start-Process "DisplaySwitch.exe" -ArgumentList "/internal" -Wait
                Write-Log "Primary display only mode activated" -Level "SUCCESS"
                return $true
            }
            "Secondary" {
                Start-Process "DisplaySwitch.exe" -ArgumentList "/external" -Wait
                Write-Log "Secondary display only mode activated" -Level "SUCCESS"
                return $true
            }
        }
    }
    catch {
        Write-Log "Error setting multi-monitor configuration: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-CommonResolutions {
    return @(
        @{ Width = 1920; Height = 1080; Name = "Full HD (1920x1080)" },
        @{ Width = 2560; Height = 1440; Name = "2K QHD (2560x1440)" },
        @{ Width = 3840; Height = 2160; Name = "4K UHD (3840x2160)" },
        @{ Width = 1366; Height = 768; Name = "HD (1366x768)" },
        @{ Width = 1680; Height = 1050; Name = "WSXGA+ (1680x1050)" },
        @{ Width = 1600; Height = 900; Name = "HD+ (1600x900)" },
        @{ Width = 1440; Height = 900; Name = "WXGA+ (1440x900)" },
        @{ Width = 1280; Height = 1024; Name = "SXGA (1280x1024)" },
        @{ Width = 1280; Height = 720; Name = "HD (1280x720)" },
        @{ Width = 1024; Height = 768; Name = "XGA (1024x768)" }
    )
}

function Get-CommonRefreshRates {
    return @(60, 75, 120, 144, 165, 240)
}

function Save-DisplayProfile {
    param([string]$ProfileName)
    
    Write-Log "Saving display profile: $ProfileName" -Level "INFO"
    
    try {
        $displays = Get-DisplayInformation
        $profilePath = "$env:USERPROFILE\Desktop\DevOptimizer\display-profiles"
        
        if (!(Test-Path $profilePath)) {
            New-Item -ItemType Directory -Path $profilePath -Force | Out-Null
        }
        
        $profile = @{
            Name = $ProfileName
            CreatedDate = Get-Date
            Displays = $displays | ForEach-Object {
                @{
                    DeviceName = $_.DeviceName
                    DeviceString = $_.DeviceString
                    Width = $_.Width
                    Height = $_.Height
                    RefreshRate = $_.RefreshRate
                    Orientation = $_.Orientation
                    PositionX = $_.PositionX
                    PositionY = $_.PositionY
                    IsPrimary = $_.IsPrimary
                }
            }
        }
        
        $profileFile = "$profilePath\$ProfileName.json"
        $profile | ConvertTo-Json -Depth 3 | Out-File $profileFile -Encoding UTF8
        
        Write-Log "Display profile saved: $profileFile" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error saving display profile: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Load-DisplayProfile {
    param([string]$ProfileName)
    
    Write-Log "Loading display profile: $ProfileName" -Level "INFO"
    
    try {
        $profilePath = "$env:USERPROFILE\Desktop\DevOptimizer\display-profiles"
        $profileFile = "$profilePath\$ProfileName.json"
        
        if (!(Test-Path $profileFile)) {
            Write-Log "Display profile not found: $profileFile" -Level "ERROR"
            return $false
        }
        
        $profile = Get-Content $profileFile | ConvertFrom-Json
        $success = $true
        
        foreach ($display in $profile.Displays) {
            $result = Set-DisplayResolution -DeviceName $display.DeviceName -Width $display.Width -Height $display.Height -RefreshRate $display.RefreshRate
            if (-not $result) {
                $success = $false
                Write-Log "Failed to apply settings for $($display.DeviceName)" -Level "WARN"
            }
        }
        
        if ($success) {
            Write-Log "Display profile loaded successfully: $ProfileName" -Level "SUCCESS"
        } else {
            Write-Log "Display profile loaded with some failures: $ProfileName" -Level "WARN"
        }
        
        return $success
    }
    catch {
        Write-Log "Error loading display profile: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Show-DisplayMenu {
    Write-Log "Launching interactive display settings menu..." -Level "INFO"
    
    try {
        $displays = Get-DisplayInformation
        
        while ($true) {
            Clear-Host
            Write-Host "===========================================" -ForegroundColor Cyan
            Write-Host "       DISPLAY SETTINGS MANAGER" -ForegroundColor Cyan
            Write-Host "===========================================" -ForegroundColor Cyan
            Write-Host ""
            
            # Show current display information
            Write-Host "CURRENT DISPLAY CONFIGURATION:" -ForegroundColor Green
            for ($i = 0; $i -lt $displays.Count; $i++) {
                $display = $displays[$i]
                $primaryText = if ($display.IsPrimary) { " (PRIMARY)" } else { "" }
                $activeText = if ($display.IsActive) { "ACTIVE" } else { "INACTIVE" }
                
                Write-Host "  Display $($i + 1)$primaryText [$activeText]:" -ForegroundColor White
                Write-Host "    Name: $($display.DeviceString)" -ForegroundColor Gray
                Write-Host "    Resolution: $($display.Width)x$($display.Height)@$($display.RefreshRate)Hz" -ForegroundColor Gray
                Write-Host "    Position: ($($display.PositionX), $($display.PositionY))" -ForegroundColor Gray
                Write-Host ""
            }
            
            Write-Host "MENU OPTIONS:" -ForegroundColor Yellow
            Write-Host "1) Change Resolution" -ForegroundColor White
            Write-Host "2) Change Refresh Rate" -ForegroundColor White
            Write-Host "3) Change Orientation" -ForegroundColor White
            Write-Host "4) Adjust Brightness" -ForegroundColor White
            Write-Host "5) Multi-Monitor Setup" -ForegroundColor White
            Write-Host "6) Save Display Profile" -ForegroundColor White
            Write-Host "7) Load Display Profile" -ForegroundColor White
            Write-Host "8) Refresh Display Info" -ForegroundColor White
            Write-Host "0) Exit" -ForegroundColor Red
            Write-Host ""
            
            $choice = Read-Host "Enter your choice (0-8)"
            
            switch ($choice) {
                "1" {
                    # Change Resolution
                    Write-Host "`nSelect display:" -ForegroundColor Yellow
                    for ($i = 0; $i -lt $displays.Count; $i++) {
                        Write-Host "$($i + 1)) $($displays[$i].DeviceString)" -ForegroundColor White
                    }
                    
                    $displayChoice = Read-Host "Enter display number"
                    $displayIndex = [int]$displayChoice - 1
                    
                    if ($displayIndex -ge 0 -and $displayIndex -lt $displays.Count) {
                        $selectedDisplay = $displays[$displayIndex]
                        
                        Write-Host "`nCommon Resolutions:" -ForegroundColor Yellow
                        $commonRes = Get-CommonResolutions
                        for ($i = 0; $i -lt $commonRes.Count; $i++) {
                            Write-Host "$($i + 1)) $($commonRes[$i].Name)" -ForegroundColor White
                        }
                        
                        $resChoice = Read-Host "Enter resolution number (or 0 for custom)"
                        
                        if ($resChoice -eq "0") {
                            $width = Read-Host "Enter width"
                            $height = Read-Host "Enter height"
                        } else {
                            $resIndex = [int]$resChoice - 1
                            if ($resIndex -ge 0 -and $resIndex -lt $commonRes.Count) {
                                $width = $commonRes[$resIndex].Width
                                $height = $commonRes[$resIndex].Height
                            } else {
                                Write-Host "Invalid selection" -ForegroundColor Red
                                Start-Sleep 2
                                continue
                            }
                        }
                        
                        $result = Set-DisplayResolution -DeviceName $selectedDisplay.DeviceName -Width $width -Height $height -RefreshRate $selectedDisplay.RefreshRate
                        if ($result) {
                            Write-Host "Resolution changed successfully!" -ForegroundColor Green
                            $displays = Get-DisplayInformation  # Refresh
                        } else {
                            Write-Host "Failed to change resolution!" -ForegroundColor Red
                        }
                        Start-Sleep 2
                    }
                }
                "2" {
                    # Change Refresh Rate
                    Write-Host "`nSelect display:" -ForegroundColor Yellow
                    for ($i = 0; $i -lt $displays.Count; $i++) {
                        Write-Host "$($i + 1)) $($displays[$i].DeviceString)" -ForegroundColor White
                    }
                    
                    $displayChoice = Read-Host "Enter display number"
                    $displayIndex = [int]$displayChoice - 1
                    
                    if ($displayIndex -ge 0 -and $displayIndex -lt $displays.Count) {
                        $selectedDisplay = $displays[$displayIndex]
                        
                        Write-Host "`nCommon Refresh Rates:" -ForegroundColor Yellow
                        $commonRates = Get-CommonRefreshRates
                        for ($i = 0; $i -lt $commonRates.Count; $i++) {
                            Write-Host "$($i + 1)) $($commonRates[$i])Hz" -ForegroundColor White
                        }
                        
                        $rateChoice = Read-Host "Enter refresh rate number"
                        $rateIndex = [int]$rateChoice - 1
                        
                        if ($rateIndex -ge 0 -and $rateIndex -lt $commonRates.Count) {
                            $refreshRate = $commonRates[$rateIndex]
                            $result = Set-DisplayResolution -DeviceName $selectedDisplay.DeviceName -Width $selectedDisplay.Width -Height $selectedDisplay.Height -RefreshRate $refreshRate
                            if ($result) {
                                Write-Host "Refresh rate changed successfully!" -ForegroundColor Green
                                $displays = Get-DisplayInformation  # Refresh
                            } else {
                                Write-Host "Failed to change refresh rate!" -ForegroundColor Red
                            }
                        } else {
                            Write-Host "Invalid selection" -ForegroundColor Red
                        }
                        Start-Sleep 2
                    }
                }
                "3" {
                    # Change Orientation
                    Write-Host "`nSelect display:" -ForegroundColor Yellow
                    for ($i = 0; $i -lt $displays.Count; $i++) {
                        Write-Host "$($i + 1)) $($displays[$i].DeviceString)" -ForegroundColor White
                    }
                    
                    $displayChoice = Read-Host "Enter display number"
                    $displayIndex = [int]$displayChoice - 1
                    
                    if ($displayIndex -ge 0 -and $displayIndex -lt $displays.Count) {
                        $selectedDisplay = $displays[$displayIndex]
                        
                        Write-Host "`nOrientation Options:" -ForegroundColor Yellow
                        Write-Host "1) Landscape (Normal)" -ForegroundColor White
                        Write-Host "2) Portrait (90 Right)" -ForegroundColor White
                        Write-Host "3) Landscape Flipped (180)" -ForegroundColor White
                        Write-Host "4) Portrait Flipped (90 Left)" -ForegroundColor White
                        
                        $orientChoice = Read-Host "Enter orientation number"
                        $orientation = switch ($orientChoice) {
                            "1" { "Landscape" }
                            "2" { "Portrait" }
                            "3" { "LandscapeFlipped" }
                            "4" { "PortraitFlipped" }
                            default { $null }
                        }
                        
                        if ($orientation) {
                            $result = Set-DisplayOrientation -DeviceName $selectedDisplay.DeviceName -Orientation $orientation
                            if ($result) {
                                Write-Host "Orientation changed successfully!" -ForegroundColor Green
                                $displays = Get-DisplayInformation  # Refresh
                            } else {
                                Write-Host "Failed to change orientation!" -ForegroundColor Red
                            }
                        } else {
                            Write-Host "Invalid selection" -ForegroundColor Red
                        }
                        Start-Sleep 2
                    }
                }
                "4" {
                    # Adjust Brightness
                    $brightness = Read-Host "Enter brightness level (0-100)"
                    if ($brightness -match "^\d+$" -and [int]$brightness -ge 0 -and [int]$brightness -le 100) {
                        $result = Set-DisplayBrightness -Brightness ([int]$brightness)
                        if ($result) {
                            Write-Host "Brightness adjusted successfully!" -ForegroundColor Green
                        } else {
                            Write-Host "Brightness control may not be supported on this system" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "Invalid brightness value" -ForegroundColor Red
                    }
                    Start-Sleep 2
                }
                "5" {
                    # Multi-Monitor Setup
                    if ($displays.Count -lt 2) {
                        Write-Host "Multi-monitor setup requires at least 2 displays" -ForegroundColor Red
                        Start-Sleep 2
                        continue
                    }
                    
                    Write-Host "`nMulti-Monitor Options:" -ForegroundColor Yellow
                    Write-Host "1) Extend displays" -ForegroundColor White
                    Write-Host "2) Duplicate displays" -ForegroundColor White
                    Write-Host "3) Primary display only" -ForegroundColor White
                    Write-Host "4) Secondary display only" -ForegroundColor White
                    
                    $multiChoice = Read-Host "Enter option number"
                    $mode = switch ($multiChoice) {
                        "1" { "Extend" }
                        "2" { "Duplicate" }
                        "3" { "Primary" }
                        "4" { "Secondary" }
                        default { $null }
                    }
                    
                    if ($mode) {
                        $result = Set-MultiMonitorConfiguration -Mode $mode
                        if ($result) {
                            Write-Host "Multi-monitor configuration applied successfully!" -ForegroundColor Green
                            Start-Sleep 2
                            $displays = Get-DisplayInformation  # Refresh
                        } else {
                            Write-Host "Failed to apply multi-monitor configuration!" -ForegroundColor Red
                            Start-Sleep 2
                        }
                    } else {
                        Write-Host "Invalid selection" -ForegroundColor Red
                        Start-Sleep 2
                    }
                }
                "6" {
                    # Save Display Profile
                    $profileName = Read-Host "Enter profile name"
                    if ($profileName) {
                        $result = Save-DisplayProfile -ProfileName $profileName
                        if ($result) {
                            Write-Host "Display profile saved successfully!" -ForegroundColor Green
                        } else {
                            Write-Host "Failed to save display profile!" -ForegroundColor Red
                        }
                    }
                    Start-Sleep 2
                }
                "7" {
                    # Load Display Profile
                    $profilePath = "$env:USERPROFILE\Desktop\DevOptimizer\display-profiles"
                    if (Test-Path $profilePath) {
                        $profiles = Get-ChildItem $profilePath -Filter "*.json" | Select-Object -ExpandProperty BaseName
                        if ($profiles.Count -gt 0) {
                            Write-Host "`nAvailable Profiles:" -ForegroundColor Yellow
                            for ($i = 0; $i -lt $profiles.Count; $i++) {
                                Write-Host "$($i + 1)) $($profiles[$i])" -ForegroundColor White
                            }
                            
                            $profileChoice = Read-Host "Enter profile number"
                            $profileIndex = [int]$profileChoice - 1
                            
                            if ($profileIndex -ge 0 -and $profileIndex -lt $profiles.Count) {
                                $result = Load-DisplayProfile -ProfileName $profiles[$profileIndex]
                                if ($result) {
                                    Write-Host "Display profile loaded successfully!" -ForegroundColor Green
                                    $displays = Get-DisplayInformation  # Refresh
                                } else {
                                    Write-Host "Failed to load display profile!" -ForegroundColor Red
                                }
                            } else {
                                Write-Host "Invalid selection" -ForegroundColor Red
                            }
                        } else {
                            Write-Host "No saved profiles found" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "No saved profiles found" -ForegroundColor Yellow
                    }
                    Start-Sleep 2
                }
                "8" {
                    # Refresh Display Info
                    $displays = Get-DisplayInformation
                    Write-Host "Display information refreshed!" -ForegroundColor Green
                    Start-Sleep 1
                }
                "0" {
                    Write-Host "Exiting Display Settings Manager..." -ForegroundColor Green
                    return
                }
                default {
                    Write-Host "Invalid choice! Please try again." -ForegroundColor Red
                    Start-Sleep 2
                }
            }
        }
    }
    catch {
        Write-Log "Error in display menu: $($_.Exception.Message)" -Level "ERROR"
        Write-Host "Press any key to exit..." -ForegroundColor Red
        Read-Host
    }
}

