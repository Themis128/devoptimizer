#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NVIDIA GPU Optimizer - Activates and optimizes GPU for heavy workloads
.DESCRIPTION
    Configures NVIDIA GPU settings to handle compute-intensive tasks,
    reducing CPU/PSU load by offloading work to the graphics card.
.AUTHOR
    Created for Themistoklis - Cloudless.gr
.NOTES
    Run as Administrator for full functionality
#>

param(
    [switch]$Silent,
    [switch]$RevertToDefault
)

# Colors for output
$colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Header  = "Magenta"
}

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    if (-not $Silent) {
        Write-Host $Message -ForegroundColor $colors[$Type]
    }
}

function Write-Header {
    param([string]$Title)
    if (-not $Silent) {
        Write-Host "`n$("=" * 60)" -ForegroundColor $colors.Header
        Write-Host "  $Title" -ForegroundColor $colors.Header
        Write-Host "$("=" * 60)`n" -ForegroundColor $colors.Header
    }
}

# Check for NVIDIA GPU
function Test-NvidiaGPU {
    Write-Header "Detecting NVIDIA GPU"
    
    $gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }
    
    if ($gpu) {
        Write-Status "Found: $($gpu.Name)" -Type Success
        Write-Status "Driver Version: $($gpu.DriverVersion)" -Type Info
        Write-Status "Video RAM: $([math]::Round($gpu.AdapterRAM / 1GB, 2)) GB" -Type Info
        return $true
    } else {
        Write-Status "No NVIDIA GPU detected!" -Type Error
        return $false
    }
}

# Check and configure NVIDIA driver settings via nvidia-smi
function Set-NvidiaPerformanceMode {
    Write-Header "Configuring NVIDIA Performance Settings"
    
    $nvidiaSmi = "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
    
    if (-not (Test-Path $nvidiaSmi)) {
        # Try alternative path
        $nvidiaSmi = "C:\Windows\System32\nvidia-smi.exe"
    }
    
    if (-not (Test-Path $nvidiaSmi)) {
        Write-Status "nvidia-smi not found. Installing NVIDIA drivers with full features is recommended." -Type Warning
        return $false
    }
    
    try {
        # Set persistence mode (keeps GPU initialized)
        Write-Status "Enabling persistence mode..." -Type Info
        & $nvidiaSmi -pm 1 2>$null
        
        # Set power management to maximum performance
        Write-Status "Setting power management to maximum performance..." -Type Info
        & $nvidiaSmi -pl (& $nvidiaSmi --query-gpu=power.max_limit --format=csv,noheader,nounits 2>$null) 2>$null
        
        # Query current GPU status
        Write-Status "`nCurrent GPU Status:" -Type Info
        $gpuInfo = & $nvidiaSmi --query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory,power.draw,power.limit --format=csv,noheader 2>$null
        
        if ($gpuInfo) {
            $info = $gpuInfo -split ","
            Write-Status "  GPU: $($info[0].Trim())" -Type Success
            Write-Status "  Temperature: $($info[1].Trim())°C" -Type Info
            Write-Status "  GPU Utilization: $($info[2].Trim())" -Type Info
            Write-Status "  Memory Utilization: $($info[3].Trim())" -Type Info
            Write-Status "  Power Draw: $($info[4].Trim())W / $($info[5].Trim())W" -Type Info
        }
        
        return $true
    } catch {
        Write-Status "Error configuring nvidia-smi: $_" -Type Error
        return $false
    }
}

# Configure Windows power plan for GPU optimization
function Set-PowerPlanGPU {
    Write-Header "Optimizing Windows Power Plan"
    
    try {
        # Set to High Performance power plan
        $highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        powercfg /setactive $highPerfGuid 2>$null
        
        if ($?) {
            Write-Status "Switched to High Performance power plan" -Type Success
        } else {
            # Create ultimate performance plan if available
            powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            Write-Status "High Performance plan activated" -Type Success
        }
        
        # Disable USB selective suspend (can interfere with GPU)
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg /setactive SCHEME_CURRENT
        
        Write-Status "USB selective suspend disabled" -Type Success
        
        # Set PCI Express Link State Power Management to Off
        powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg /setactive SCHEME_CURRENT
        
        Write-Status "PCIe Link State Power Management disabled" -Type Success
        
        return $true
    } catch {
        Write-Status "Error configuring power plan: $_" -Type Warning
        return $false
    }
}

# Configure NVIDIA Control Panel settings via registry
function Set-NvidiaRegistrySettings {
    Write-Header "Configuring NVIDIA Registry Settings"
    
    $nvidiaRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    
    if (-not (Test-Path $nvidiaRegPath)) {
        Write-Status "NVIDIA registry path not found, trying alternative..." -Type Warning
        $nvidiaRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0001"
    }
    
    try {
        # Enable maximum pre-rendered frames (reduces CPU load)
        # Value 1 = minimal CPU pre-rendering, GPU does more work
        
        if (Test-Path $nvidiaRegPath) {
            Write-Status "Configuring GPU-first rendering..." -Type Info
            
            # These settings push more work to GPU
            $settings = @{
                "RMDisableGpuASPMFlags" = 1      # Disable GPU power saving
                "EnableMsHybrid"        = 0      # Disable hybrid graphics if applicable
            }
            
            foreach ($setting in $settings.GetEnumerator()) {
                Set-ItemProperty -Path $nvidiaRegPath -Name $setting.Key -Value $setting.Value -Type DWord -ErrorAction SilentlyContinue
            }
            
            Write-Status "Registry settings applied" -Type Success
        }
        
        return $true
    } catch {
        Write-Status "Error modifying registry: $_" -Type Warning
        return $false
    }
}

# Configure CUDA and compute settings
function Set-CudaEnvironment {
    Write-Header "Configuring CUDA Environment"
    
    try {
        # Set environment variables for CUDA optimization
        [Environment]::SetEnvironmentVariable("CUDA_CACHE_DISABLE", "0", "Machine")
        [Environment]::SetEnvironmentVariable("CUDA_FORCE_PTX_JIT", "0", "Machine")
        
        # Enable TCC mode awareness (for compute workloads)
        [Environment]::SetEnvironmentVariable("CUDA_VISIBLE_DEVICES", "0", "Machine")
        
        Write-Status "CUDA environment variables configured" -Type Success
        
        # Check for CUDA installation
        $cudaPath = $env:CUDA_PATH
        if ($cudaPath -and (Test-Path $cudaPath)) {
            Write-Status "CUDA Installation found: $cudaPath" -Type Success
        } else {
            Write-Status "CUDA Toolkit not detected. Consider installing for compute workloads." -Type Warning
            Write-Status "Download from: https://developer.nvidia.com/cuda-downloads" -Type Info
        }
        
        return $true
    } catch {
        Write-Status "Error configuring CUDA: $_" -Type Warning
        return $false
    }
}

# Set preferred GPU for applications
function Set-PreferredGPU {
    Write-Header "Configuring Application GPU Preferences"
    
    $gpuPrefPath = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
    
    try {
        if (-not (Test-Path $gpuPrefPath)) {
            New-Item -Path $gpuPrefPath -Force | Out-Null
        }
        
        # Common applications that benefit from GPU acceleration
        $gpuApps = @(
            "python.exe",
            "pythonw.exe",
            "jupyter.exe",
            "code.exe",           # VS Code
            "cursor.exe",         # Cursor IDE
            "chrome.exe",
            "msedge.exe",
            "firefox.exe",
            "blender.exe",
            "obs64.exe",
            "vlc.exe",
            "ffmpeg.exe"
        )
        
        Write-Status "Setting high-performance GPU preference for common applications..." -Type Info
        
        # GpuPreference=2 means "High performance" (discrete GPU)
        foreach ($app in $gpuApps) {
            $appPaths = Get-ChildItem -Path "C:\", "$env:LOCALAPPDATA", "$env:ProgramFiles", "${env:ProgramFiles(x86)}" -Filter $app -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            
            if ($appPaths) {
                Set-ItemProperty -Path $gpuPrefPath -Name $appPaths.FullName -Value "GpuPreference=2;" -ErrorAction SilentlyContinue
            }
        }
        
        Write-Status "GPU preferences configured for common applications" -Type Success
        Write-Status "Tip: You can also set per-app GPU in Windows Settings > Display > Graphics" -Type Info
        
        return $true
    } catch {
        Write-Status "Error setting GPU preferences: $_" -Type Warning
        return $false
    }
}

# Enable hardware-accelerated GPU scheduling
function Enable-HardwareGPUScheduling {
    Write-Header "Configuring Hardware-Accelerated GPU Scheduling"
    
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    
    try {
        $currentValue = Get-ItemProperty -Path $regPath -Name "HwSchMode" -ErrorAction SilentlyContinue
        
        if ($RevertToDefault) {
            Set-ItemProperty -Path $regPath -Name "HwSchMode" -Value 1 -Type DWord
            Write-Status "Hardware GPU scheduling disabled (reverted to default)" -Type Info
        } else {
            Set-ItemProperty -Path $regPath -Name "HwSchMode" -Value 2 -Type DWord
            Write-Status "Hardware-accelerated GPU scheduling enabled" -Type Success
            Write-Status "Note: A restart may be required for this to take effect" -Type Warning
        }
        
        return $true
    } catch {
        Write-Status "Error configuring GPU scheduling: $_" -Type Warning
        return $false
    }
}

# Display current GPU workload
function Show-GPUStatus {
    Write-Header "Current GPU Workload Status"
    
    $nvidiaSmi = "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
    if (-not (Test-Path $nvidiaSmi)) {
        $nvidiaSmi = "C:\Windows\System32\nvidia-smi.exe"
    }
    
    if (Test-Path $nvidiaSmi) {
        Write-Status "Running GPU diagnostics..." -Type Info
        & $nvidiaSmi
    } else {
        # Fallback to WMI
        $gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }
        if ($gpu) {
            Write-Status "GPU: $($gpu.Name)" -Type Info
            Write-Status "Status: $($gpu.Status)" -Type Info
            Write-Status "Driver Date: $($gpu.DriverDate)" -Type Info
        }
    }
}

# Main execution
function Main {
    $Host.UI.RawUI.WindowTitle = "NVIDIA GPU Optimizer"
    
    Write-Host @"

    ███╗   ██╗██╗   ██╗██╗██████╗ ██╗ █████╗ 
    ████╗  ██║██║   ██║██║██╔══██╗██║██╔══██╗
    ██╔██╗ ██║██║   ██║██║██║  ██║██║███████║
    ██║╚██╗██║╚██╗ ██╔╝██║██║  ██║██║██╔══██║
    ██║ ╚████║ ╚████╔╝ ██║██████╔╝██║██║  ██║
    ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝
                GPU OPTIMIZER v1.0
"@ -ForegroundColor Green

    # Check admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Status "`nThis script requires Administrator privileges!" -Type Error
        Write-Status "Right-click and select 'Run as Administrator'" -Type Warning
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    # Run optimizations
    if (Test-NvidiaGPU) {
        Set-NvidiaPerformanceMode
        Set-PowerPlanGPU
        Set-NvidiaRegistrySettings
        Set-CudaEnvironment
        Set-PreferredGPU
        Enable-HardwareGPUScheduling
        
        Write-Header "Optimization Complete"
        Write-Status "Your NVIDIA GPU is now configured for maximum performance." -Type Success
        Write-Status "This will help offload heavy workloads from your CPU/PSU to the GPU." -Type Info
        Write-Status "`nRecommendations:" -Type Info
        Write-Status "  1. Restart your computer for all changes to take effect" -Type Info
        Write-Status "  2. Keep NVIDIA drivers updated via GeForce Experience" -Type Info
        Write-Status "  3. Monitor GPU temps during heavy workloads" -Type Info
        Write-Status "  4. Ensure adequate PSU wattage for your GPU model" -Type Warning
        
        Show-GPUStatus
    } else {
        Write-Status "`nNo NVIDIA GPU found. This script is designed for NVIDIA graphics cards." -Type Error
        Write-Status "If you have an AMD GPU, different optimization methods apply." -Type Info
    }
    
    if (-not $Silent) {
        Write-Host "`n"
        Read-Host "Press Enter to exit"
    }
}

# Run
Main