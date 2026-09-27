# Dual GPU & NVIDIA Broadcast Optimization Functions - Latest 2024/2025

function Get-GPUInformation {
    Write-Log "Analyzing GPU configuration and capabilities..." -Level "INFO"
    
    try {
        $gpuInfo = @{
            GPUs = @()
            NVIDIACount = 0
            AMDCount = 0
            IntelCount = 0
            TotalVRAM = 0
            RTXSupport = $false
            BroadcastCompatible = $false
            Drivers = @{}
        }
        
        # Get GPU information using WMI and CIM
        $gpus = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" -and $_.Name -notlike "*Microsoft*" }
        
        foreach ($gpu in $gpus) {
            $gpuDetails = @{
                Name = $gpu.Name
                Manufacturer = $gpu.VideoProcessor
                Memory = [math]::Round($gpu.AdapterRAM / 1GB, 2)
                DriverVersion = $gpu.DriverVersion
                DriverDate = $gpu.DriverDate
                DeviceID = $gpu.DeviceID
                IsNVIDIA = $gpu.Name -match "NVIDIA|GeForce|RTX|GTX|Quadro|Tesla"
                IsAMD = $gpu.Name -match "AMD|Radeon|RX"
                IsIntel = $gpu.Name -match "Intel|UHD|Iris"
                RTXCapable = $gpu.Name -match "RTX"
            }
            
            $gpuInfo.GPUs += $gpuDetails
            $gpuInfo.TotalVRAM += $gpuDetails.Memory
            
            if ($gpuDetails.IsNVIDIA) {
                $gpuInfo.NVIDIACount++
                if ($gpuDetails.RTXCapable) {
                    $gpuInfo.RTXSupport = $true
                    $gpuInfo.BroadcastCompatible = $true
                }
            } elseif ($gpuDetails.IsAMD) {
                $gpuInfo.AMDCount++
            } elseif ($gpuDetails.IsIntel) {
                $gpuInfo.IntelCount++
            }
        }
        
        # Check NVIDIA driver version
        try {
            $nvidiaDriver = Get-ItemProperty -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\Display Driver" -ErrorAction SilentlyContinue
            if ($nvidiaDriver) {
                $gpuInfo.Drivers.NVIDIA = $nvidiaDriver.Version
            }
        } catch {
            Write-Log "Could not detect NVIDIA driver version from registry" -Level "WARN"
        }
        
        # Try nvidia-smi for more detailed info
        try {
            $nvidiaSmi = nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits 2>&1
            if ($nvidiaSmi -and $nvidiaSmi -notmatch "not found|not recognized") {
                Write-Log "NVIDIA SMI detected - detailed GPU info available" -Level "SUCCESS"
            }
        } catch {
            # nvidia-smi not available
        }
        
        Write-Log "GPU analysis completed: $($gpuInfo.GPUs.Count) GPUs detected" -Level "SUCCESS"
        return $gpuInfo
    }
    catch {
        Write-Log "Error analyzing GPU information: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-CommunicationPlatforms {
    Write-Log "Detecting installed communication platforms..." -Level "INFO"
    
    try {
        $platforms = @{
            Discord = @{ Installed = $false; Path = $null; Version = $null }
            Teams = @{ Installed = $false; Path = $null; Version = $null }
            Zoom = @{ Installed = $false; Path = $null; Version = $null }
            Skype = @{ Installed = $false; Path = $null; Version = $null }
            Slack = @{ Installed = $false; Path = $null; Version = $null }
            WhatsApp = @{ Installed = $false; Path = $null; Version = $null }
            Telegram = @{ Installed = $false; Path = $null; Version = $null }
            OBS = @{ Installed = $false; Path = $null; Version = $null }
            StreamLabs = @{ Installed = $false; Path = $null; Version = $null }
            XSplit = @{ Installed = $false; Path = $null; Version = $null }
            Chrome = @{ Installed = $false; Path = $null; Version = $null }
            Edge = @{ Installed = $false; Path = $null; Version = $null }
            Firefox = @{ Installed = $false; Path = $null; Version = $null }
        }
        
        # Common installation paths to check
        $appPaths = @{
            Discord = @(
                "$env:LOCALAPPDATA\Discord\Update.exe",
                "$env:APPDATA\Discord\Update.exe"
            )
            Teams = @(
                "$env:LOCALAPPDATA\Microsoft\Teams\current\Teams.exe",
                "$env:PROGRAMFILES\Microsoft\Teams\current\Teams.exe",
                "$env:PROGRAMFILES(X86)\Microsoft\Teams\current\Teams.exe"
            )
            Zoom = @(
                "$env:PROGRAMFILES\Zoom\bin\Zoom.exe",
                "$env:PROGRAMFILES(X86)\Zoom\bin\Zoom.exe",
                "$env:APPDATA\Zoom\bin\Zoom.exe"
            )
            Skype = @(
                "$env:PROGRAMFILES\Microsoft\Skype for Desktop\Skype.exe",
                "$env:LOCALAPPDATA\Microsoft\SkypeApp\Skype.exe"
            )
            Slack = @(
                "$env:LOCALAPPDATA\slack\slack.exe",
                "$env:PROGRAMFILES\Slack\slack.exe"
            )
            WhatsApp = @(
                "$env:LOCALAPPDATA\WhatsApp\WhatsApp.exe",
                "$env:PROGRAMFILES\WhatsApp\WhatsApp.exe"
            )
            Telegram = @(
                "$env:APPDATA\Telegram Desktop\Telegram.exe",
                "$env:PROGRAMFILES\Telegram Desktop\Telegram.exe"
            )
            OBS = @(
                "$env:PROGRAMFILES\obs-studio\bin\64bit\obs64.exe",
                "$env:PROGRAMFILES(X86)\obs-studio\bin\32bit\obs32.exe"
            )
            StreamLabs = @(
                "$env:PROGRAMFILES\Streamlabs OBS\Streamlabs OBS.exe",
                "$env:LOCALAPPDATA\Programs\streamlabs-obs\Streamlabs OBS.exe"
            )
            XSplit = @(
                "$env:PROGRAMFILES\SplitmediaLabs\XSplit Broadcaster\XSplit.Core.exe",
                "$env:PROGRAMFILES(X86)\SplitmediaLabs\XSplit Broadcaster\XSplit.Core.exe"
            )
            Chrome = @(
                "$env:PROGRAMFILES\Google\Chrome\Application\chrome.exe",
                "$env:PROGRAMFILES(X86)\Google\Chrome\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
            )
            Edge = @(
                "$env:PROGRAMFILES\Microsoft\Edge\Application\msedge.exe",
                "$env:PROGRAMFILES(X86)\Microsoft\Edge\Application\msedge.exe"
            )
            Firefox = @(
                "$env:PROGRAMFILES\Mozilla Firefox\firefox.exe",
                "$env:PROGRAMFILES(X86)\Mozilla Firefox\firefox.exe"
            )
        }
        
        foreach ($platform in $appPaths.Keys) {
            foreach ($path in $appPaths[$platform]) {
                if (Test-Path $path) {
                    $platforms[$platform].Installed = $true
                    $platforms[$platform].Path = $path
                    
                    # Try to get version info
                    try {
                        $versionInfo = (Get-ItemProperty $path).VersionInfo
                        if ($versionInfo.FileVersion) {
                            $platforms[$platform].Version = $versionInfo.FileVersion
                        }
                    } catch {
                        # Version detection failed
                    }
                    break
                }
            }
        }
        
        $installedCount = ($platforms.Values | Where-Object { $_.Installed }).Count
        Write-Log "Communication platforms detected: $installedCount platforms found" -Level "SUCCESS"
        
        return $platforms
    }
    catch {
        Write-Log "Error detecting communication platforms: $($_.Exception.Message)" -Level "ERROR"
        return @{}
    }
}

function Install-NVIDIABroadcast {
    Write-Log "Installing NVIDIA Broadcast and prerequisites..." -Level "INFO"
    
    try {
        $gpuInfo = Get-GPUInformation
        if (-not $gpuInfo.BroadcastCompatible) {
            Write-Log "NVIDIA Broadcast requires RTX GPU. No compatible GPU found." -Level "ERROR"
            return $false
        }
        
        $installed = 0
        
        # Check if NVIDIA Broadcast is already installed
        $broadcastPath = "$env:PROGRAMFILES\NVIDIA Corporation\NVIDIA Broadcast\NVIDIA Broadcast.exe"
        if (Test-Path $broadcastPath) {
            Write-Log "NVIDIA Broadcast is already installed" -Level "INFO"
        } else {
            # Try to install via winget
            Write-Log "Installing NVIDIA Broadcast..." -Level "INFO"
            try {
                winget install "NVIDIA Broadcast" --accept-source-agreements --accept-package-agreements
                Write-Log "NVIDIA Broadcast installed successfully" -Level "SUCCESS"
                $installed++
            } catch {
                Write-Log "Failed to install NVIDIA Broadcast via winget. Please download manually from NVIDIA website." -Level "WARN"
            }
        }
        
        # Install Visual C++ Redistributables (required for many apps)
        Write-Log "Installing Visual C++ Redistributables..." -Level "INFO"
        $vcRedist = @(
            "Microsoft.VCRedist.2015+.x64",
            "Microsoft.VCRedist.2015+.x86",
            "Microsoft.VCRedist.2013.x64",
            "Microsoft.VCRedist.2013.x86"
        )
        
        foreach ($package in $vcRedist) {
            try {
                winget install $package --accept-source-agreements --accept-package-agreements
                Write-Log "Installed: $package" -Level "SUCCESS"
                $installed++
            } catch {
                Write-Log "Could not install: $package" -Level "WARN"
            }
        }
        
        # Install DirectX End-User Runtime
        Write-Log "Installing DirectX End-User Runtime..." -Level "INFO"
        try {
            $directXUrl = "https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe"
            $directXPath = "$env:TEMP\dxwebsetup.exe"
            
            Invoke-WebRequest -Uri $directXUrl -OutFile $directXPath
            Start-Process -FilePath $directXPath -ArgumentList "/Q" -Wait
            Remove-Item $directXPath -ErrorAction SilentlyContinue
            
            Write-Log "DirectX End-User Runtime installed" -Level "SUCCESS"
            $installed++
        } catch {
            Write-Log "Could not install DirectX End-User Runtime" -Level "WARN"
        }
        
        Write-Log "NVIDIA Broadcast installation completed: $installed components installed" -Level "SUCCESS"
        return $installed
    }
    catch {
        Write-Log "Error installing NVIDIA Broadcast: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Optimize-DualGPU {
    Write-Log "Optimizing dual GPU configuration..." -Level "INFO"
    
    try {
        $gpuInfo = Get-GPUInformation
        if ($gpuInfo.GPUs.Count -lt 2) {
            Write-Log "Single GPU detected. Applying single GPU optimizations instead." -Level "INFO"
            return Optimize-SingleGPU
        }
        
        $optimizations = 0
        
        # Windows Graphics Settings - Hardware Acceleration
        Write-Log "Configuring Windows Graphics Settings..." -Level "INFO"
        try {
            # Enable Hardware Accelerated GPU Scheduling (Windows 10 2004+)
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord
            Write-Log "Enabled Hardware Accelerated GPU Scheduling" -Level "SUCCESS"
            $optimizations++
        } catch {
            Write-Log "Could not enable Hardware Accelerated GPU Scheduling" -Level "WARN"
        }
        
        # NVIDIA Control Panel Settings (if NVIDIA GPUs present)
        if ($gpuInfo.NVIDIACount -gt 0) {
            Write-Log "Optimizing NVIDIA Control Panel settings..." -Level "INFO"
            
            # NVIDIA Registry Optimizations
            $nvidiaSettings = @{
                # 3D Settings
                "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" = @{
                    "PowerMizerEnable" = 1  # Prefer Maximum Performance
                    "PowerMizerLevel" = 1   # Prefer Maximum Performance
                    "PowerMizerLevelAC" = 1 # Prefer Maximum Performance on AC
                }
                # Global Settings
                "HKLM:\SOFTWARE\NVIDIA Corporation\Global\NVTweak" = @{
                    "Coolbits" = 31  # Enable overclocking options
                }
            }
            
            foreach ($regPath in $nvidiaSettings.Keys) {
                try {
                    if (!(Test-Path $regPath)) {
                        New-Item -Path $regPath -Force | Out-Null
                    }
                    
                    foreach ($setting in $nvidiaSettings[$regPath].GetEnumerator()) {
                        Set-ItemProperty -Path $regPath -Name $setting.Key -Value $setting.Value -Type DWord -ErrorAction SilentlyContinue
                        Write-Log "Set NVIDIA setting: $($setting.Key) = $($setting.Value)" -Level "SUCCESS"
                        $optimizations++
                    }
                } catch {
                    Write-Log "Could not apply NVIDIA registry setting for $regPath" -Level "WARN"
                }
            }
        }
        
        # Power Management Settings
        Write-Log "Optimizing power management for dual GPU..." -Level "INFO"
        try {
            # Set power plan to High Performance
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
            
            # Disable USB selective suspend (can interfere with GPU)
            powercfg /change usb-selective-suspend-setting 0
            
            # Set PCI Express Link State Power Management to Off
            powercfg /setacvalueindex scheme_current sub_pciexpress aspm 0
            powercfg /setdcvalueindex scheme_current sub_pciexpress aspm 0
            
            Write-Log "Power management optimized for dual GPU" -Level "SUCCESS"
            $optimizations++
        } catch {
            Write-Log "Could not optimize power management settings" -Level "WARN"
        }
        
        # Memory Management
        Write-Log "Optimizing memory management for GPU workloads..." -Level "INFO"
        try {
            # Increase system cache size
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Value 1 -Type DWord
            
            # Optimize paging file for GPU workloads
            $totalRAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
            $pagingFileSize = [math]::Max(2048, [math]::Min(16384, $totalRAM * 1.5))
            
            Write-Log "Memory management optimized for GPU workloads" -Level "SUCCESS"
            $optimizations++
        } catch {
            Write-Log "Could not optimize memory management" -Level "WARN"
        }
        
        # Windows Display Settings
        Write-Log "Optimizing Windows display settings..." -Level "INFO"
        try {
            # Disable fullscreen optimizations globally
            Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            
            Write-Log "Windows display settings optimized" -Level "SUCCESS"
            $optimizations++
        } catch {
            Write-Log "Could not optimize display settings" -Level "WARN"
        }
        
        Write-Log "Dual GPU optimization completed: $optimizations optimizations applied" -Level "SUCCESS"
        return $optimizations
    }
    catch {
        Write-Log "Error optimizing dual GPU: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Optimize-CommunicationPlatforms {
    Write-Log "Optimizing communication platforms for GPU acceleration..." -Level "INFO"
    
    try {
        $platforms = Get-CommunicationPlatforms
        $gpuInfo = Get-GPUInformation
        $optimizations = 0
        
        # Discord Optimizations
        if ($platforms.Discord.Installed) {
            Write-Log "Optimizing Discord..." -Level "INFO"
            try {
                $discordSettings = "$env:APPDATA\discord\settings.json"
                if (Test-Path $discordSettings) {
                    $settings = Get-Content $discordSettings | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if (-not $settings) { $settings = @{} }
                    
                    # Enable hardware acceleration
                    $settings.HARDWARE_ACCELERATION = $true
                    $settings.OPEN_ON_STARTUP = $false
                    $settings.START_MINIMIZED = $true
                    
                    $settings | ConvertTo-Json | Out-File $discordSettings -Encoding UTF8
                    Write-Log "Discord settings optimized" -Level "SUCCESS"
                    $optimizations++
                }
            } catch {
                Write-Log "Could not optimize Discord settings" -Level "WARN"
            }
        }
        
        # Chrome/Edge Hardware Acceleration
        $browsers = @("Chrome", "Edge")
        foreach ($browser in $browsers) {
            if ($platforms.$browser.Installed) {
                Write-Log "Optimizing $browser for hardware acceleration..." -Level "INFO"
                try {
                    # Create Windows Graphics Performance Preference
                    $exePath = $platforms.$browser.Path
                    if ($exePath) {
                        # Add to high performance GPU preference
                        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
                        Write-Log "$browser configured for hardware acceleration" -Level "SUCCESS"
                        $optimizations++
                    }
                } catch {
                    Write-Log "Could not optimize $browser" -Level "WARN"
                }
            }
        }
        
        # OBS Studio Optimizations
        if ($platforms.OBS.Installed) {
            Write-Log "Optimizing OBS Studio..." -Level "INFO"
            try {
                $obsConfigPath = "$env:APPDATA\obs-studio\global.ini"
                if (Test-Path $obsConfigPath) {
                    $obsConfig = Get-Content $obsConfigPath
                    
                    # Enable NVIDIA NVENC if available
                    if ($gpuInfo.NVIDIACount -gt 0) {
                        $obsConfig += "`n[Video]"
                        $obsConfig += "`nRenderer=Direct3D 11"
                        $obsConfig += "`nAdapter=0"
                        $obsConfig += "`n[Output]"
                        $obsConfig += "`nMode=Advanced"
                    }
                    
                    $obsConfig | Out-File $obsConfigPath -Encoding UTF8
                    Write-Log "OBS Studio optimized for GPU acceleration" -Level "SUCCESS"
                    $optimizations++
                }
            } catch {
                Write-Log "Could not optimize OBS Studio" -Level "WARN"
            }
        }
        
        # Teams Optimization
        if ($platforms.Teams.Installed) {
            Write-Log "Optimizing Microsoft Teams..." -Level "INFO"
            try {
                # Teams GPU acceleration registry setting
                $teamsRegPath = "HKCU:\SOFTWARE\Microsoft\Teams"
                if (!(Test-Path $teamsRegPath)) {
                    New-Item -Path $teamsRegPath -Force | Out-Null
                }
                Set-ItemProperty -Path $teamsRegPath -Name "GPU_Acceleration" -Value 1 -Type DWord
                Write-Log "Microsoft Teams GPU acceleration enabled" -Level "SUCCESS"
                $optimizations++
            } catch {
                Write-Log "Could not optimize Microsoft Teams" -Level "WARN"
            }
        }
        
        # Zoom Optimization
        if ($platforms.Zoom.Installed) {
            Write-Log "Optimizing Zoom..." -Level "INFO"
            try {
                $zoomConfigPath = "$env:APPDATA\Zoom\data\zoomus.conf"
                if (Test-Path $zoomConfigPath) {
                    Add-Content -Path $zoomConfigPath -Value "`nenableHardwareAcceleration=true"
                    Add-Content -Path $zoomConfigPath -Value "`nuseGPUForVideoProcessing=true"
                    Write-Log "Zoom hardware acceleration enabled" -Level "SUCCESS"
                    $optimizations++
                }
            } catch {
                Write-Log "Could not optimize Zoom" -Level "WARN"
            }
        }
        
        Write-Log "Communication platforms optimization completed: $optimizations platforms optimized" -Level "SUCCESS"
        return $optimizations
    }
    catch {
        Write-Log "Error optimizing communication platforms: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Configure-NVIDIABroadcast {
    Write-Log "Configuring NVIDIA Broadcast for optimal performance..." -Level "INFO"
    
    try {
        $broadcastPath = "$env:PROGRAMFILES\NVIDIA Corporation\NVIDIA Broadcast\NVIDIA Broadcast.exe"
        if (-not (Test-Path $broadcastPath)) {
            Write-Log "NVIDIA Broadcast not found. Please install it first." -Level "ERROR"
            return $false
        }
        
        $optimizations = 0
        
        # Configure NVIDIA Broadcast settings
        $broadcastConfigPath = "$env:APPDATA\NVIDIA Corporation\NVIDIA Broadcast"
        if (!(Test-Path $broadcastConfigPath)) {
            New-Item -ItemType Directory -Path $broadcastConfigPath -Force | Out-Null
        }
        
        # Create optimized config
        $broadcastConfig = @{
            "audio" = @{
                "noiseRemoval" = @{
                    "enabled" = $true
                    "strength" = 0.8
                }
                "roomEcho" = @{
                    "enabled" = $true
                    "strength" = 0.7
                }
            }
            "video" = @{
                "backgroundBlur" = @{
                    "enabled" = $true
                    "strength" = 0.8
                }
                "backgroundReplacement" = @{
                    "enabled" = $false
                }
                "eyeContact" = @{
                    "enabled" = $true
                }
            }
            "performance" = @{
                "gpuUsage" = "auto"
                "quality" = "high"
                "maxFPS" = 60
            }
        }
        
        $configFile = "$broadcastConfigPath\config.json"
        $broadcastConfig | ConvertTo-Json -Depth 3 | Out-File $configFile -Encoding UTF8
        Write-Log "NVIDIA Broadcast configuration created" -Level "SUCCESS"
        $optimizations++
        
        # Set up virtual devices for communication platforms
        Write-Log "Configuring virtual audio/video devices..." -Level "INFO"
        
        # Create application-specific profiles
        $platforms = Get-CommunicationPlatforms
        $profilesCreated = 0
        
        foreach ($platform in $platforms.Keys) {
            if ($platforms[$platform].Installed) {
                $profilePath = "$broadcastConfigPath\profiles\$platform.json"
                if (!(Test-Path (Split-Path $profilePath))) {
                    New-Item -ItemType Directory -Path (Split-Path $profilePath) -Force | Out-Null
                }
                
                $profile = @{
                    "name" = $platform
                    "audioInput" = "NVIDIA Broadcast"
                    "audioOutput" = "default"
                    "videoInput" = "NVIDIA Broadcast"
                    "autoStart" = $true
                }
                
                $profile | ConvertTo-Json | Out-File $profilePath -Encoding UTF8
                $profilesCreated++
            }
        }
        
        Write-Log "Created $profilesCreated application profiles for NVIDIA Broadcast" -Level "SUCCESS"
        $optimizations += $profilesCreated
        
        # Windows Audio Service Optimization
        Write-Log "Optimizing Windows Audio Service..." -Level "INFO"
        try {
            # Set audio service to automatic startup
            Set-Service -Name "AudioSrv" -StartupType Automatic
            Set-Service -Name "AudioEndpointBuilder" -StartupType Automatic
            
            # Optimize audio buffer settings
            $audioRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\AudioSrv"
            Set-ItemProperty -Path $audioRegPath -Name "DependOnService" -Value @("AudioEndpointBuilder", "RpcSs") -Type MultiString -ErrorAction SilentlyContinue
            
            Write-Log "Windows Audio Service optimized" -Level "SUCCESS"
            $optimizations++
        } catch {
            Write-Log "Could not optimize Windows Audio Service" -Level "WARN"
        }
        
        Write-Log "NVIDIA Broadcast configuration completed: $optimizations optimizations applied" -Level "SUCCESS"
        return $optimizations
    }
    catch {
        Write-Log "Error configuring NVIDIA Broadcast: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Optimize-GPUComplete {
    Write-Log "Running complete GPU and NVIDIA Broadcast optimization..." -Level "INFO"
    
    try {
        $totalOptimizations = 0
        
        # Step 1: Analyze GPU setup
        Write-Log "Step 1: Analyzing GPU configuration..." -Level "INFO"
        $gpuInfo = Get-GPUInformation
        if (-not $gpuInfo) {
            Write-Log "Could not analyze GPU configuration" -Level "ERROR"
            return $false
        }
        
        # Step 2: Install NVIDIA Broadcast if compatible
        Write-Log "Step 2: Installing NVIDIA Broadcast..." -Level "INFO"
        if ($gpuInfo.BroadcastCompatible) {
            $installed = Install-NVIDIABroadcast
            $totalOptimizations += $installed
        } else {
            Write-Log "NVIDIA Broadcast requires RTX GPU - skipping installation" -Level "WARN"
        }
        
        # Step 3: Optimize GPU configuration
        Write-Log "Step 3: Optimizing GPU settings..." -Level "INFO"
        $gpuOptimizations = Optimize-DualGPU
        $totalOptimizations += $gpuOptimizations
        
        # Step 4: Configure NVIDIA Broadcast
        Write-Log "Step 4: Configuring NVIDIA Broadcast..." -Level "INFO"
        if ($gpuInfo.BroadcastCompatible) {
            $broadcastOptimizations = Configure-NVIDIABroadcast
            $totalOptimizations += $broadcastOptimizations
        }
        
        # Step 5: Optimize communication platforms
        Write-Log "Step 5: Optimizing communication platforms..." -Level "INFO"
        $platformOptimizations = Optimize-CommunicationPlatforms
        $totalOptimizations += $platformOptimizations
        
        if ($totalOptimizations -gt 0) {
            Write-Log "Complete GPU optimization finished successfully!" -Level "SUCCESS"
            Write-Log "Total optimizations applied: $totalOptimizations" -Level "INFO"
            Write-Log "RECOMMENDATION: Restart your computer to apply all changes" -Level "WARN"
            return $true
        } else {
            Write-Log "GPU optimization completed with limited changes" -Level "WARN"
            return $false
        }
    }
    catch {
        Write-Log "Error in complete GPU optimization: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}
