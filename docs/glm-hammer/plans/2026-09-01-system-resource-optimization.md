# System Resource Optimization Plan

**Goal**: Create a comprehensive system resource optimization framework for GPU, CPU, WSL2, and monitoring with profile-based configuration for development workloads

**Architecture**: A modular PowerShell-based optimization system with four profiles (Light, Balanced, Heavy, WSL-Heavy) that orchestrates existing optimization scripts (nvidia.ps1, optimize-wsl-memory.ps1, power-management.ps1, real-time-monitoring.ps1) through a master integrated optimizer script. All scripts are modified to support silent/automated execution. Configuration is driven by a JSON profiles file enabling silent, automated execution.

**Tech Stack**: PowerShell 5.1+, Windows 10/11, WSL2 (Ubuntu-26.04), NVIDIA GPU (nvidia-smi), Docker Desktop WSL2 backend

**Work Scope**: 
- IN: Profile configuration, integrated orchestrator, script parameter enhancements for all 4 scripts, validation script with profile-specific checks, documentation
- OUT: Hardware overclocking, BIOS modifications, kernel-level changes, third-party tool installation

**Preconditions**:
- Tasks 6-8 (and any execution of nvidia.ps1 or power-management.ps1) MUST run from an elevated (Run as Administrator) PowerShell session. nvidia.ps1 line 1 is `#Requires -RunAsAdministrator` (non-elevated child aborts before Main with non-zero exit) and Task 4's Main exits 1 without admin rights. The live session may not be elevated — the worker must verify with the admin check in Task 8 Step 2 and launch elevated if needed.

**Verification Strategy**
**Level**: Integration testing with build-only validation
**Exact Command**: 
```powershell
# Pre-execution baseline
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfLogicalProcessors, MaxClockSpeed
Get-WmiObject Win32_VideoController | Where-Object {$_.Name -match "NVIDIA"} | Select-Object Name, DriverVersion, AdapterRAM
wsl.exe -d Ubuntu-26.04 -e free -h
wsl.exe -d Ubuntu-26.04 -e cat /proc/meminfo | Select-String "MemTotal"
wsl.exe -d Ubuntu-26.04 -e nproc

# Execute optimization plan (will be defined in tasks)

# Post-execution validation
Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 5 -MaxSamples 3
Get-WmiObject Win32_VideoController | Where-Object {$_.Name -match "NVIDIA"} | Select-Object Name, DriverVersion
wsl.exe -d Ubuntu-26.04 -e free -h
Test-Path "D:\DevOptimizer\logs\system-optimization.log" | Select-Object -First 1

# Run validation script
& "D:\DevOptimizer\tests\resource-optimization-validation.ps1" -Detailed
```
**What Passing Proofs**: 
- GPU is detected and nvidia-smi responds with valid data (GPU name, driver version, power.max_limit; power.limit and persistence_mode report [N/A] on WDDM and are skipped)
- CPU shows optimized power plan settings (active scheme = High Performance or Ultimate Performance, minimum processor state = 100%)
- WSL reports allocated memory and processor counts match WSL-Heavy profile targets (memory ≥ 12GB, processors ≥ 6)
- Optimization log file is created with "Optimization complete for profile: WSL-Heavy"
- Validation script exits with code 0
- System remains stable post-optimization (no crashes/hangs)

### Declared Paths
- Create: `D:\DevOptimizer\config\optimization-profiles.json`
- Create: `D:\DevOptimizer\scripts\integrated-resource-optimizer.ps1`
- Modify: `D:\DevOptimizer\nvidia.ps1`
- Modify: `D:\DevOptimizer\optimize-wsl-memory.ps1`
- Modify: `D:\DevOptimizer\scripts\power-management.ps1`
- Modify: `D:\DevOptimizer\scripts\real-time-monitoring.ps1`
- Create: `D:\DevOptimizer\logs\system-optimization.log`
- Create: `D:\DevOptimizer\reports\optimization-results.md`
- Create: `D:\DevOptimizer\reports\baseline-pre-optimization.json`
- Create: `D:\DevOptimizer\tests\resource-optimization-validation.ps1`

### Task 1: Create Optimization Profiles Configuration
**Goal**: Create a JSON configuration file defining different optimization profiles for various use cases
**Dependencies:** None
**Files:**
- Create: `D:\DevOptimizer\config\optimization-profiles.json`
**Acceptance Criteria:**
- [ ] File contains valid JSON parsable by ConvertFrom-Json
- [ ] Defines exactly four profiles: Light, Balanced, Heavy, WSL-Heavy
- [ ] Each profile specifies GPU, CPU, WSL, and Monitoring optimization booleans
- [ ] WSL-Heavy profile enables all optimizations including WSL-specific enhancements
- [ ] WSL-Heavy profile specifies expected WSL memory ≥ 12GB and processors ≥ 6
**Step 1:** Create the optimization profiles configuration file:
```json
{
  "Light": {
    "description": "Basic optimization for light workloads and battery preservation",
    "GPU": false,
    "CPU": true,
    "WSL": false,
    "Monitoring": true,
    "memoryGB": 4,
    "processors": 4,
    "swapGB": 2,
    "expectedWSLMemoryGB": 4,
    "expectedWSLProcessors": 4,
    "notes": "Only enables CPU power management and monitoring. Suitable for web browsing, office work, and battery-powered scenarios."
  },
  "Balanced": {
    "description": "Standard optimization for general development work",
    "GPU": true,
    "CPU": true,
    "WSL": false,
    "Monitoring": true,
    "memoryGB": 8,
    "processors": 6,
    "swapGB": 4,
    "expectedWSLMemoryGB": 8,
    "expectedWSLProcessors": 6,
    "notes": "Enables GPU optimization, CPU power management, and monitoring. Good balance for most development tasks without heavy WSL usage."
  },
  "Heavy": {
    "description": "Maximum optimization for intensive local workloads",
    "GPU": true,
    "CPU": true,
    "WSL": true,
    "Monitoring": true,
    "memoryGB": 12,
    "processors": 8,
    "swapGB": 6,
    "expectedWSLMemoryGB": 12,
    "expectedWSLProcessors": 8,
    "notes": "Enables all optimizations including WSL memory allocation. Ideal for heavy local development, gaming, or content creation."
  },
  "WSL-Heavy": {
    "description": "Maximum optimization for WSL-centric heavy workloads",
    "GPU": true,
    "CPU": true,
    "WSL": true,
    "Monitoring": true,
    "memoryGB": 12,
    "processors": 6,
    "swapGB": 8,
    "expectedWSLMemoryGB": 12,
    "expectedWSLProcessors": 6,
    "notes": "Maximum WSL allocation sized to this machine (12 logical processors, 6 available to WSL, 24GB+ system RAM): 12GB memory, 6 processors, 8GB swap. expectedWSLProcessors matches the live Ubuntu-26.04 nproc baseline of 6."
  }
}
```
**Note**: `expectedWSLProcessors` for WSL-Heavy is 6 because this machine exposes 6 logical processors to WSL (verified via `wsl.exe -d Ubuntu-26.04 -e nproc` = 6). The validation script compares actual values against these `expected*` fields.

### Task 2: Modify nvidia.ps1 for Silent/Automated Execution
**Goal**: Extend nvidia.ps1's existing parameter support with -WhatIf/-DryRun, silent-mode guards, and exit codes while preserving all existing functions
**Dependencies:** Task 1
**Files:**
- Modify: `D:\DevOptimizer\nvidia.ps1`
**Acceptance Criteria:**
- [ ] Script param block (lines 14-17) accepts -Silent, -RevertToDefault, -WhatIf, -DryRun
- [ ] All existing functions preserved (Write-Status, Write-Header, Test-NvidiaGPU, Set-NvidiaPerformanceMode, Set-PowerPlanGPU, Set-NvidiaRegistrySettings, Set-CudaEnvironment, Set-PreferredGPU, Enable-HardwareGPUScheduling, Show-GPUStatus, Main)
- [ ] When -Silent is specified, the Read-Host prompt in the admin-fail path (line 327) is suppressed
- [ ] When -WhatIf or -DryRun is specified, optimization functions are skipped and [WHATIF]/[DRYRUN] messages logged instead
- [ ] Script exits 0 after successful optimization run, 1 on admin-failure
- [ ] Running without parameters still works (backward compatible)
- [ ] Final bare `Main` call at end of file retained (Main has no param block and reads script-scope switches)
- [ ] No dead code remains between the new optimization block and Main's closing brace
**Step 1:** Read the existing nvidia.ps1 to confirm structure:
```powershell
Get-Content "D:\DevOptimizer\nvidia.ps1"
# Expected: param block at lines 14-17 (Silent, RevertToDefault), function Main at line 307, "Main" call at line 362
```
**Step 2:** Replace the param block at lines 14-17:
```powershell
# REPLACE lines 14-17:
param(
    [switch]$Silent,
    [switch]$RevertToDefault,
    [switch]$WhatIf,
    [switch]$DryRun
)
```
**Step 3:** In function Main, guard the admin-fail Read-Host and add WhatIf/DryRun handling around the optimization calls. The existing optimization functions already read script-scope `$RevertToDefault` internally (e.g. Enable-HardwareGPUScheduling line 267), so the call sequence stays unchanged for revert mode. Replace lines 324-358 — this also deletes the original trailing silent-prompt block (lines 355-358), which would otherwise be dead code after `exit 0`; line 359's `}` still closes Main:
```powershell
# REPLACE lines 324-358 (inside Main) with:
    if (-not $isAdmin) {
        Write-Status "`nThis script requires Administrator privileges!" -Type Error
        Write-Status "Right-click and select 'Run as Administrator'" -Type Warning
        if (-not $Silent) { Read-Host "Press Enter to exit" }
        exit 1
    }
    
    # Run optimizations (functions read script-scope $RevertToDefault where applicable)
    if (Test-NvidiaGPU) {
        if ($WhatIf -or $DryRun) {
            $mode = if ($WhatIf) { "WHATIF" } else { "DRYRUN" }
            Write-Status "[$mode] Would run: Set-NvidiaPerformanceMode, Set-PowerPlanGPU, Set-NvidiaRegistrySettings, Set-CudaEnvironment, Set-PreferredGPU, Enable-HardwareGPUScheduling" -Type Info
        } else {
            Set-NvidiaPerformanceMode
            Set-PowerPlanGPU
            Set-NvidiaRegistrySettings
            Set-CudaEnvironment
            Set-PreferredGPU
            Enable-HardwareGPUScheduling
        }
        
        Write-Header "Optimization Complete"
        Write-Status "Your NVIDIA GPU is now configured for maximum performance." -Type Success
        Show-GPUStatus
    } else {
        Write-Status "`nNo NVIDIA GPU found. This script is designed for NVIDIA graphics cards." -Type Error
        Write-Status "If you have an AMD GPU, different optimization methods apply." -Type Info
    }
    
    if (-not $Silent) {
        Write-Host "`n"
        Read-Host "Press Enter to exit"
    }
    exit 0
```
**Step 4:** Replace the final script invocation at line 362:
```powershell
# REPLACE line 362 ("Main") with:
Main
```

### Task 3: Modify optimize-wsl-memory.ps1 for Silent/Automated Execution
**Goal**: Add parameter support to optimize-wsl-memory.ps1 for silent, what-if, dry-run modes
**Dependencies:** Task 1
**Files:**
- Modify: `D:\DevOptimizer\optimize-wsl-memory.ps1`
**Acceptance Criteria:**
- [ ] Script accepts -Silent, -WhatIf, -DryRun switch parameters at top level
- [ ] Main function accepts these parameters and passes them through
- [ ] When -Silent is specified, no Read-Host prompts are shown
- [ ] When -DryRun is specified, no system changes are made, only logged
- [ ] When -WhatIf is specified, shows what would be done without executing
- [ ] Script calculates WSL resources based on profile (uses optimization-profiles.json)
- [ ] Script returns exit code 0 on success, 1 on error
- [ ] Running the script without parameters still works (defaults to Balanced profile)
**Step 1:** Read the existing optimize-wsl-memory.ps1 to understand its structure:
```powershell
Get-Content "D:\DevOptimizer\optimize-wsl-memory.ps1"
```
**Step 2:** Replace the entire file with a version that adds parameter support and profile-based configuration. The `# CATEGORY:` marker on line 3 is preserved — Discover-Scripts.ps1 (line 183) parses it for hub categorization:
```powershell
# DevOptimizer WSL2 Memory Optimization
# CATEGORY: cleanup
<#
.SYNOPSIS
    WSL2 Memory and Resource Optimization Script
.DESCRIPTION
    Optimizes WSL2 memory allocation, processor count, swap, and other settings
    based on the selected optimization profile.
.NOTES
    Requires Administrator privileges for some operations.
#>

param(
    [ValidateSet('Light','Balanced','Heavy','WSL-Heavy')]
    [string]$Profile = 'Balanced',
    [switch]$Silent,
    [switch]$WhatIf,
    [switch]$DryRun
)

# Logging function
function Write-WslLog {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "$timestamp [$Level] $Message"
    if (-not $Silent) { 
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARN'  { 'Yellow' }
            'SUCCESS' { 'Green' }
            default { 'White' }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
    if ($global:LogFile) { Add-Content -Path $global:LogFile -Value $logEntry }
}

# Load profile configuration
function Get-ProfileConfig {
    param([string]$ProfileName)
    $profilesPath = "D:\DevOptimizer\config\optimization-profiles.json"
    if (Test-Path $profilesPath) {
        $profiles = Get-Content $profilesPath -Raw | ConvertFrom-Json
        if ($profiles.$ProfileName) {
            return $profiles.$ProfileName
        }
    }
    # Fallback defaults (must match config/optimization-profiles.json)
    return @{
        Light = @{ memoryGB = 4; processors = 4; swapGB = 2 }
        Balanced = @{ memoryGB = 8; processors = 6; swapGB = 4 }
        Heavy = @{ memoryGB = 12; processors = 8; swapGB = 6 }
        'WSL-Heavy' = @{ memoryGB = 12; processors = 6; swapGB = 8 }
    }[$ProfileName]
}

# Main execution function
function Optimize-WSLMemory {
    param(
        [ValidateSet('Light','Balanced','Heavy','WSL-Heavy')]
        [string]$Profile = 'Balanced',
        [switch]$Silent,
        [switch]$WhatIf,
        [switch]$DryRun
    )

    $global:LogFile = "D:\DevOptimizer\logs\wsl-optimization-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    New-Item -ItemType Directory -Path (Split-Path $global:LogFile) -Force | Out-Null

    Write-WslLog "Starting WSL2 Memory Optimization - Profile: $Profile"

    # Load profile config
    $config = Get-ProfileConfig -ProfileName $Profile
    $targetMemoryGB = $config.memoryGB
    $targetProcessors = $config.processors
    $targetSwapGB = $config.swapGB

    Write-WslLog "Target configuration: Memory=${targetMemoryGB}GB, Processors=$targetProcessors, Swap=${targetSwapGB}GB"

    # Backup existing .wslconfig
    $wslConfigPath = "$env:USERPROFILE\.wslconfig"
    $backupPath = "$wslConfigPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (Test-Path $wslConfigPath) {
        Write-WslLog "Backing up existing .wslconfig to $backupPath"
        if (-not $WhatIf -and -not $DryRun) {
            Copy-Item -Path $wslConfigPath -Destination $backupPath -Force
        } elseif ($WhatIf) {
            Write-WslLog "[WHATIF] Would backup .wslconfig to $backupPath"
        }
    }

    # Generate new .wslconfig
    $wslConfigContent = @"
[wsl2]
memory=${targetMemoryGB}GB
processors=$targetProcessors
swap=${targetSwapGB}GB
localhostForwarding=true
nestedVirtualization=true
kernelCommandLine=cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
"@

    if ($Profile -eq 'WSL-Heavy') {
        $wslConfigContent += @"


[experimental]
sparseVhd=true
autoMemoryReclaim=gradual
"@
    }

    Write-WslLog "Generated .wslconfig content:"
    if (-not $Silent) { Write-Host $wslConfigContent }

    if (-not $WhatIf -and -not $DryRun) {
        # Write without BOM (ascii) — some WSL versions misparse UTF-8 BOM
        Set-Content -Path $wslConfigPath -Value $wslConfigContent -Encoding Ascii
        Write-WslLog "Successfully wrote .wslconfig" 'SUCCESS'
    } elseif ($WhatIf) {
        Write-WslLog "[WHATIF] Would write .wslconfig to $wslConfigPath"
    } elseif ($DryRun) {
        Write-WslLog "[DRYRUN] Skipping .wslconfig write"
    }

    # Apply WSL shutdown to reload configuration
    Write-WslLog "Shutting down WSL to apply configuration..."
    if (-not $WhatIf -and -not $DryRun) {
        wsl.exe --shutdown
        Start-Sleep -Seconds 3
        Write-WslLog "WSL shutdown complete." 'SUCCESS'
    } elseif ($WhatIf) {
        Write-WslLog "[WHATIF] Would run: wsl.exe --shutdown"
    }

    # Verify configuration by starting WSL and checking
    if (-not $WhatIf -and -not $DryRun) {
        Write-WslLog "Verifying WSL configuration..."
        Start-Sleep -Seconds 2
        $memInfo = wsl.exe -d Ubuntu-26.04 -e free -h 2>$null
        if ($memInfo) {
            $memLines = $memInfo -split "`n"
            $memTotalLine = $memLines | Where-Object { $_ -match '^Mem:' }
            if ($memTotalLine) {
                $memParts = $memTotalLine -split '\s+'
                $actualMem = $memParts[1].Trim()
                Write-WslLog "Verified WSL Memory: $actualMem"
            }
        }
        $procCount = wsl.exe -d Ubuntu-26.04 -e nproc 2>$null
        if ($procCount) {
            Write-WslLog "Verified WSL Processors: $($procCount.Trim())"
        }
    }

    Write-WslLog "WSL2 Memory Optimization complete for profile: $Profile" 'SUCCESS'

    if (-not $Silent) {
        Write-Host "`n"
        Read-Host "Press Enter to exit"
    }
    exit 0
}

# Execute main
try {
    Optimize-WSLMemory -Profile $Profile -Silent:$Silent -WhatIf:$WhatIf -DryRun:$DryRun
} catch {
    Write-WslLog "Fatal error during WSL optimization: $($_.Exception.Message)" 'ERROR'
    exit 1
}
```

### Task 4: Modify power-management.ps1 for Silent/Automated Execution
**Goal**: Add parameter support and executable main entry point to power-management.ps1, keeping all existing functions intact
**Dependencies:** Task 1
**Files:**
- Modify: `D:\DevOptimizer\scripts\power-management.ps1`
**Acceptance Criteria:**
- [ ] Script accepts -Silent, -WhatIf, -DryRun switch parameters at top level
- [ ] Script has a Main function that can be called directly
- [ ] When -Silent is specified, no interactive prompts are shown
- [ ] When -DryRun is specified, no system changes are made, only logged
- [ ] When -WhatIf is specified, shows what would be done without executing
- [ ] Script includes Write-Log function internally (does not depend on external module)
- [ ] Script uses existing Optimize-PowerSettings with "Maximum" profile for max performance
- [ ] Script sets power scheme to High Performance or Ultimate Performance
- [ ] Script sets minimum processor state to 100%
- [ ] Script returns exit code 0 on success, 1 on error
- [ ] All existing functions (Get-PowerPlans, Set-PowerPlan, Optimize-PowerSettings, Get-PowerReport) preserved
**Step 1:** Read the existing power-management.ps1 to understand its functions:
```powershell
Get-Content "D:\DevOptimizer\scripts\power-management.ps1"
```
**Step 2:** Prepend the parameter block and self-contained Write-Log function at the top of the file (before Get-PowerPlans). The Main function itself is appended in Step 3:
```powershell
<#
.SYNOPSIS
    Windows Power Management Optimization
.DESCRIPTION
    Optimizes Windows power settings for maximum performance including
    power plan selection and processor state management.
.NOTES
    Requires Administrator privileges.
#>

param(
    [switch]$Silent,
    [switch]$WhatIf,
    [switch]$DryRun
)

# Internal logging function (self-contained) - REPLACES external dependency
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "$timestamp [$Level] $Message"
    if (-not $Silent) { 
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARN'  { 'Yellow' }
            'SUCCESS' { 'Green' }
            default { 'White' }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
    if ($global:LogFile) { Add-Content -Path $global:LogFile -Value $logEntry }
}

# ===== EXISTING FUNCTIONS BELOW - KEPT AS-IS =====
```
**Step 3:** Append Main execution function at the END of the file (after Get-PowerReport):
```powershell
# ===== MAIN EXECUTION FUNCTION - ADDED AT END =====
function Main {
    param(
        [switch]$Silent,
        [switch]$WhatIf,
        [switch]$DryRun
    )

    $global:LogFile = "D:\DevOptimizer\logs\power-optimization-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    New-Item -ItemType Directory -Path (Split-Path $global:LogFile) -Force | Out-Null

    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "ERROR: This script requires Administrator privileges." 'ERROR'
        exit 1
    }

    Write-Log "Starting Power Management Optimization"

    # Use existing Optimize-PowerSettings with Maximum profile for best performance
    if (-not $WhatIf -and -not $DryRun) {
        $result = Optimize-PowerSettings -Profile "Maximum"
        if ($result) {
            Write-Log "Power optimization completed successfully" 'SUCCESS'
        } else {
            Write-Log "Power optimization failed" 'ERROR'
            exit 1
        }
    } elseif ($WhatIf) {
        Write-Log "[WHATIF] Would run: Optimize-PowerSettings -Profile 'Maximum'"
    } elseif ($DryRun) {
        Write-Log "[DRYRUN] Skipping power optimization"
    }

    Write-Log "Power Management Optimization complete." 'SUCCESS'

    if (-not $Silent) {
        Write-Host "`n"
        Read-Host "Press Enter to exit"
    }
    exit 0
}

# Execute main unconditionally (invocation-name guards are unreliable: under
# `powershell -File` ScriptName is empty, under `&` InvocationName is "&")
Main -Silent:$Silent -WhatIf:$WhatIf -DryRun:$DryRun
```

### Task 5: Modify real-time-monitoring.ps1 for Silent/Background Operation
**Goal**: Add parameter support and background/daemon mode to real-time-monitoring.ps1, keeping all existing functions intact
**Dependencies:** Task 1
**Files:**
- Modify: `D:\DevOptimizer\scripts\real-time-monitoring.ps1`
**Acceptance Criteria:**
- [ ] Script accepts -Silent, -Mode (Dashboard|Metrics|Daemon), -DurationSec, -LogToFile, -LogPath parameters
- [ ] When -Mode Daemon is specified, runs without interactive dashboard (no ReadKey, no Console::KeyAvailable)
- [ ] When -Silent is specified, Write-MonitorLog suppresses all console output (all levels)
- [ ] When -LogToFile is specified, writes metrics to specified log file in CSV format
- [ ] Script can be started in background via Start-Process -WindowStyle Hidden
- [ ] Script ends with explicit `exit 0` after the mode switch
- [ ] Backward compatibility maintained (default Mode=Dashboard still works interactively)
- [ ] All existing functions (Get-SystemMetrics, Show-RealtimeDashboard, Show-SystemOverview, Show-PerformanceCharts, Show-ProcessMonitor, Show-Alerts, Show-ProgressBar, Show-ASCIIChart, Show-AlertHistory, Generate-PerformanceReport) preserved
**Step 1:** Read the existing real-time-monitoring.ps1 to understand its structure:
```powershell
Get-Content "D:\DevOptimizer\scripts\real-time-monitoring.ps1"
```
**Step 2:** Replace the parameter block at the top (lines 4-9) with enhanced parameters, and add a daemon mode handler in the main execution switch:
```powershell
# REPLACE lines 4-9 with:
param(
    [ValidateSet('Dashboard','Metrics','Daemon','Report','Alerts')]
    [string]$Mode = 'Dashboard',
    [int]$RefreshInterval = 2,
    [switch]$LogToFile,
    [string]$LogPath = "D:\DevOptimizer\logs\system-metrics-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv",
    [int]$DurationSec = 0,
    [switch]$Silent
)

# Logging function for daemon mode
function Write-MonitorLog {
    param([string]$Message, [string]$Level = 'INFO')
    if (-not $Silent) { 
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARN'  { 'Yellow' }
            'SUCCESS' { 'Green' }
            default { 'White' }
        }
        Write-Host $Message -ForegroundColor $color 
    }
}

# ===== ALL EXISTING FUNCTIONS KEPT AS-IS (Get-SystemMetrics, Show-RealtimeDashboard, etc.) =====

# REPLACE the main execution switch (lines 411-425) with:
# Main execution
switch ($Mode) {
    'Dashboard' {
        Show-RealtimeDashboard -RefreshInterval $RefreshInterval
    }
    'Metrics' {
        $metrics = Get-SystemMetrics
        $metrics | ConvertTo-Json -Depth 3
    }
    'Report' {
        Generate-PerformanceReport
    }
    'Alerts' {
        Show-AlertHistory
    }
    'Daemon' {
        Write-MonitorLog "Starting monitoring daemon mode..."
        
        if ($LogToFile) {
            New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
            # Write CSV header
            "Timestamp,CPU_Usage,Memory_Usage,Memory_Available_GB,Memory_Total_GB,Disk_Usage,Disk_Free_GB,Disk_Total_GB,Network_Sent_KBps,Network_Received_KBps,Process_Count,Thread_Count,Uptime_Days,Uptime_Hours,Uptime_Minutes,Temperature_C" | Out-File -FilePath $LogPath -Encoding UTF8
        }
        
        $startTime = Get-Date
        $running = $true
        
        while ($running) {
            # Check duration limit
            if ($DurationSec -gt 0 -and ((Get-Date) - $startTime).TotalSeconds -ge $DurationSec) {
                $running = $false
                break
            }
            
            # Collect metrics using EXISTING Get-SystemMetrics function
            $metrics = Get-SystemMetrics
            
            # Write to log file
            if ($LogToFile) {
                $uptime = $metrics.Uptime
                $temp = if ($metrics.Temperature) { $metrics.Temperature } else { '' }
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$($metrics.CPU_Usage),$($metrics.Memory_Usage),$($metrics.Memory_Available),$($metrics.Memory_Total),$($metrics.Disk_Usage),$($metrics.Disk_Free),$($metrics.Disk_Total),$($metrics.Network_Sent),$($metrics.Network_Received),$($metrics.Process_Count),$($metrics.Thread_Count),$($uptime.Days),$($uptime.Hours),$($uptime.Minutes),$temp" | Add-Content -Path $LogPath
            }
            
            Start-Sleep -Seconds $RefreshInterval
        }
        
        Write-MonitorLog "Monitoring daemon stopped." 'SUCCESS'
    }
}

exit 0
# NOTE: because the unconditional `exit 0` above precedes it, the existing final line
# 'Write-Host "`n📊 Real-time Monitoring Module completed!"' (line 427) becomes unreachable
# in ALL modes. It is harmless dead code; no criterion depends on it — leave it in place.
```

### Task 6: Foundation - Integrated Resource Optimizer Script
**Goal**: Create a master orchestrator script that coordinates GPU, CPU, WSL, and monitoring optimizations
**Dependencies:** Task 1, Task 2, Task 3, Task 4, Task 5
**Files:**
- Create: `D:\DevOptimizer\scripts\integrated-resource-optimizer.ps1`
- Create: `D:\DevOptimizer\logs\system-optimization.log`
**Acceptance Criteria:**
- [ ] Script executes without syntax errors
- [ ] Script accepts profile parameter (Light/Balanced/Heavy/WSL-Heavy)
- [ ] Script calls all four optimization scripts in correct order via process-isolated `powershell.exe -NoProfile -File` invocations (child `exit` statements must not terminate the orchestrator)
- [ ] Script creates comprehensive log file at D:\DevOptimizer\logs\system-optimization.log
- [ ] Script handles errors gracefully and continues with remaining optimizations
- [ ] Script returns exit code 0 if all optimizations succeed, 1 if any fail
**Step 1:** Create the integrated resource optimizer script:
```powershell
<#
.SYNOPSIS
    Integrated System Resource Optimizer
.DESCRIPTION
    Orchestrates GPU, CPU, WSL, and Monitoring optimizations based on profile configuration.
#>

param(
    [ValidateSet('Light','Balanced','Heavy','WSL-Heavy')]
    [string]$Profile = 'Balanced',
    [switch]$Silent,
    [switch]$WhatIf,
    [switch]$DryRun
)

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "$timestamp [$Level] $Message"
    if (-not $Silent) { Write-Host $logEntry }
    Add-Content -Path $global:LogFile -Value $logEntry
}

# Main execution
try {
    $global:LogFile = "D:\DevOptimizer\logs\system-optimization.log"
    New-Item -ItemType Directory -Path (Split-Path $global:LogFile) -Force | Out-Null
    
    Write-Log "Starting System Resource Optimization - Profile: $Profile"
    
    # Load optimization profiles
    $profilesPath = "D:\DevOptimizer\config\optimization-profiles.json"
    if (Test-Path $profilesPath) {
        $profiles = Get-Content $profilesPath -Raw | ConvertFrom-Json
    } else {
        Write-Log "Profile config not found, using defaults" 'WARN'
        $profiles = @{
            Light = @{ GPU = $false; CPU = $true; WSL = $false; Monitoring = $true }
            Balanced = @{ GPU = $true; CPU = $true; WSL = $false; Monitoring = $true }
            Heavy = @{ GPU = $true; CPU = $true; WSL = $true; Monitoring = $true }
            'WSL-Heavy' = @{ GPU = $true; CPU = $true; WSL = $true; Monitoring = $true }
        }
    }
    
    $profileConfig = $profiles.$Profile
    $hasErrors = $false
    
    # Child scripts are invoked via `powershell.exe -NoProfile -File` (process isolation)
    # because Tasks 2/3/4 end their main paths with `exit 0`/`exit 1` — an in-process `&`
    # call would terminate THIS orchestrator at the first child exit. Exit codes are read
    # from $LASTEXITCODE, which -File invocations set reliably.
    # Build a switch args array from the boolean switches (-File cannot use -Switch:$bool syntax).
    $childSwitches = @()
    if ($Silent) { $childSwitches += '-Silent' }
    if ($WhatIf) { $childSwitches += '-WhatIf' }
    if ($DryRun) { $childSwitches += '-DryRun' }
    
    # Execute optimizations based on profile
    if ($profileConfig.GPU) { 
        Write-Log "Executing GPU optimization..."
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\..\nvidia.ps1" @childSwitches
        if ($LASTEXITCODE -ne 0) { 
            Write-Log "GPU optimization failed with exit code $LASTEXITCODE" 'ERROR'
            $hasErrors = $true
        }
    }
    
    if ($profileConfig.CPU) { 
        Write-Log "Executing CPU power management optimization..."
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\power-management.ps1" @childSwitches
        if ($LASTEXITCODE -ne 0) { 
            Write-Log "CPU optimization failed with exit code $LASTEXITCODE" 'ERROR'
            $hasErrors = $true
        }
    }
    
    if ($profileConfig.WSL) { 
        Write-Log "Executing WSL memory optimization..."
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\..\optimize-wsl-memory.ps1" -Profile $Profile @childSwitches
        if ($LASTEXITCODE -ne 0) { 
            Write-Log "WSL optimization failed with exit code $LASTEXITCODE" 'ERROR'
            $hasErrors = $true
        }
    }
    
    if ($profileConfig.Monitoring) { 
        Write-Log "Starting system monitoring in background..."
        $monitorArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$PSScriptRoot\real-time-monitoring.ps1", '-Mode', 'Daemon', '-LogToFile', '-LogPath', "D:\DevOptimizer\logs\system-metrics-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv")
        if ($Silent) { $monitorArgs += '-Silent' }
        Start-Process powershell.exe -ArgumentList $monitorArgs -WindowStyle Hidden
        Write-Log "Monitoring started in background (Daemon mode)" 'SUCCESS'
    }
    
    if ($hasErrors) {
        Write-Log "Optimization completed with errors for profile: $Profile" 'WARN'
        exit 1
    } else {
        Write-Log "Optimization complete for profile: $Profile" 'SUCCESS'
        exit 0
    }
} catch {
    Write-Log "Fatal error during optimization: $($_.Exception.Message)" 'ERROR'
    exit 1
}
```

### Task 7: Create Validation and Testing Script
**Goal**: Create a test script to validate that optimizations have been applied correctly with profile-specific expectations
**Dependencies:** Task 1, Task 6
**Files:**
- Create: `D:\DevOptimizer\tests\resource-optimization-validation.ps1`
**Acceptance Criteria:**
- [ ] Script executes without syntax errors
- [ ] Script validates GPU availability and functionality (nvidia-smi query using valid fields name,driver_version,power.limit,power.max_limit returns GPU name and max power limit; [N/A] fields on WDDM are skipped with a note, not treated as failure — verified live: power.limit and persistence_mode report [N/A] on this driver 610.62 WDDM GPU)
- [ ] Script validates CPU power management settings (active scheme = High Performance/Ultimate, min processor state = 100%)
- [ ] Script validates WSL resource allocation matches profile expectations (memory ≥ expectedWSLMemoryGB, processors ≥ expectedWSLProcessors)
- [ ] Script validates optimization log exists and contains "Optimization complete"
- [ ] Script returns exit code 0 if all validations pass, 1 if any fail
- [ ] Script accepts -Profile parameter to validate against specific profile expectations
**Step 1:** Create the resource optimization validation script:
```powershell
<#
.SYNOPSIS
    Resource Optimization Validation Script
.DESCRIPTION
    Validates that GPU, CPU, and WSL optimizations have been applied correctly
    against the expected values from the optimization profile.
.NOTES
    Created for DevOptimizer System Resource Optimization Plan
#>

param(
    [ValidateSet('Light','Balanced','Heavy','WSL-Heavy')]
    [string]$Profile = 'WSL-Heavy',
    [switch]$Detailed,
    [switch]$Silent
)

function Write-ValidationLog {
    param(
        [string]$Message,
        [string]$Level = 'INFO',
        [string]$ForegroundColor = 'White'
    )
    if (-not $Silent) { 
        Write-Host $Message -ForegroundColor $ForegroundColor 
    }
}

$ValidationPassed = $true
$FailedChecks = @()

# Load profile expectations
$profilesPath = "D:\DevOptimizer\config\optimization-profiles.json"
if (Test-Path $profilesPath) {
    $profiles = Get-Content $profilesPath -Raw | ConvertFrom-Json
    $expectedMemGB = $profiles.$Profile.expectedWSLMemoryGB
    $expectedProcs = $profiles.$Profile.expectedWSLProcessors
    $expectGPU = $profiles.$Profile.GPU
    $expectCPU = $profiles.$Profile.CPU
} else {
    # WSL-Heavy defaults (must match config/optimization-profiles.json)
    $expectedMemGB = 12
    $expectedProcs = 6
    $expectGPU = $true
    $expectCPU = $true
}

Write-ValidationLog "`n=== SYSTEM RESOURCE OPTIMIZATION VALIDATION (Profile: $Profile) ===" -ForegroundColor Cyan

# 1. Validate GPU Optimization
Write-ValidationLog "`n1. Checking GPU Optimization Status..." -ForegroundColor Yellow
try {
    $nvidiaSmi = "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
    if (-not (Test-Path $nvidiaSmi)) { $nvidiaSmi = "C:\Windows\System32\nvidia-smi.exe" }
    
    if (Test-Path $nvidiaSmi) {
        # Fields verified valid on driver 610.62 (dot-separated form).
        # NOTE: power.limit and persistence_mode report [N/A] on this WDDM GPU —
        # they are skipped with a note, never treated as failure.
        $gpuStatus = & $nvidiaSmi --query-gpu=name,driver_version,power.limit,power.max_limit --format=csv,noheader,nounits 2>$null
        if ($LASTEXITCODE -eq 0 -and $gpuStatus) {
            $statusParts = $gpuStatus -split ','
            $gpuName = $statusParts[0].Trim()
            $driverVersion = $statusParts[1].Trim()
            $powerLimit = $statusParts[2].Trim()
            $maxPowerLimit = $statusParts[3].Trim()
            
            Write-ValidationLog "   ✓ GPU Detected: $gpuName (driver $driverVersion, max power limit $maxPowerLimit W)" -ForegroundColor Green
            
            if ($expectGPU) {
                if ($powerLimit -ne '[N/A]') {
                    if ($powerLimit -eq $maxPowerLimit) {
                        Write-ValidationLog "   ✓ GPU Power Limit: MAXIMUM ($powerLimit W)" -ForegroundColor Green
                    } else {
                        Write-ValidationLog "   ⚠ GPU Power Limit: $powerLimit W (max: $maxPowerLimit W)" -ForegroundColor Yellow
                    }
                } else {
                    Write-ValidationLog "   ⊘ GPU Power Limit: [N/A] on WDDM — comparison skipped" -ForegroundColor Gray
                }
            } else {
                Write-ValidationLog "   ⊘ GPU Optimization: NOT EXPECTED FOR THIS PROFILE" -ForegroundColor Gray
            }
        } else {
            Write-ValidationLog "   ✗ Unable to query GPU status (exit code $LASTEXITCODE)" -ForegroundColor Red
            $ValidationPassed = $false
            $FailedChecks += "GPU status query failed"
        }
    } else {
        Write-ValidationLog "   ✗ nvidia-smi not found" -ForegroundColor Red
        $ValidationPassed = $false
        $FailedChecks += "nvidia-smi not found - NVIDIA drivers may not be installed"
    }
} catch {
    Write-ValidationLog "   ✗ Error checking GPU: $_" -ForegroundColor Red
    $ValidationPassed = $false
    $FailedChecks += "GPU validation error: $($_.Exception.Message)"
}

# 2. Validate CPU Power Management
Write-ValidationLog "`n2. Checking CPU Power Management Settings..." -ForegroundColor Yellow
try {
    $powerScheme = powercfg /getactivescheme
    if ($expectCPU) {
        if ($powerScheme -match 'High Performance|Ultimate Performance') {
            Write-ValidationLog "   ✓ Active Power Scheme: HIGH PERFORMANCE" -ForegroundColor Green
        } else {
            Write-ValidationLog "   ✗ Active Power Scheme: NOT HIGH PERFORMANCE (Current: $($powerScheme.Trim()))" -ForegroundColor Red
            $ValidationPassed = $false
            $FailedChecks += "Active power scheme is not High Performance or Ultimate Performance"
        }
        
        # Check minimum processor state via PROCTHROTTLEMIN query
        # (powercfg /getacvalueindex is not supported on this machine; /query is)
        $queryOutput = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 2>$null
        $acLine = $queryOutput | Select-String 'Current AC Power Setting Index'
        if ($acLine -and $acLine.ToString() -match '0x([0-9a-fA-F]+)') {
            $minState = [Convert]::ToInt32($matches[1], 16)
            if ($minState -eq 100) {
                Write-ValidationLog "   ✓ Minimum Processor State: 100%" -ForegroundColor Green
            } else {
                Write-ValidationLog "   ✗ Minimum Processor State: $minState% (expected 100%)" -ForegroundColor Red
                $ValidationPassed = $false
                $FailedChecks += "Minimum processor state is $minState%, expected 100%"
            }
        } else {
            Write-ValidationLog "   ? Unable to determine Minimum Processor State" -ForegroundColor Yellow
        }
    } else {
        Write-ValidationLog "   ⊘ CPU Optimization: NOT EXPECTED FOR THIS PROFILE" -ForegroundColor Gray
    }
} catch {
    Write-ValidationLog "   ✗ Error checking CPU power management: $_" -ForegroundColor Red
    $ValidationPassed = $false
    $FailedChecks += "CPU power management validation error: $($_.Exception.Message)"
}

# 3. Validate WSL Resource Allocation
Write-ValidationLog "`n3. Checking WSL Resource Allocation..." -ForegroundColor Yellow
try {
    wsl.exe --list --quiet 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $wslMemInfo = wsl.exe -d Ubuntu-26.04 -e free -h 2>$null
        if ($wslMemInfo) {
            $memLines = $wslMemInfo -split "`n"
            $memTotalLine = $memLines | Where-Object { $_ -match '^Mem:' }
            if ($memTotalLine) {
                $memParts = $memTotalLine -split '\s+'
                $memTotal = $memParts[1].Trim()
                # Parse GB value (e.g., "15Gi" -> 15)
                $memGB = [int]($memTotal -replace '[^\d]', '')
                if ($memGB -ge $expectedMemGB) {
                    Write-ValidationLog "   ✓ WSL Total Memory: $memTotal (≥ ${expectedMemGB}GB expected)" -ForegroundColor Green
                } else {
                    Write-ValidationLog "   ✗ WSL Total Memory: $memTotal (expected ≥ ${expectedMemGB}GB)" -ForegroundColor Red
                    $ValidationPassed = $false
                    $FailedChecks += "WSL memory $memGB GB is below expected ${expectedMemGB}GB"
                }
            }
        }
        
        $wslProcCount = wsl.exe -d Ubuntu-26.04 -e nproc 2>$null
        if ($wslProcCount) {
            $procCount = [int]$wslProcCount.Trim()
            if ($procCount -ge $expectedProcs) {
                Write-ValidationLog "   ✓ WSL Processor Count: $procCount (≥ $expectedProcs expected)" -ForegroundColor Green
            } else {
                Write-ValidationLog "   ✗ WSL Processor Count: $procCount (expected ≥ $expectedProcs)" -ForegroundColor Red
                $ValidationPassed = $false
                $FailedChecks += "WSL processor count $procCount is below expected $expectedProcs"
            }
        }
        
        # Check .wslconfig
        $wslConfigPath = "$env:USERPROFILE\.wslconfig"
        if (Test-Path $wslConfigPath) {
            $configTime = (Get-Item $wslConfigPath).LastWriteTime
            $timeDiff = (Get-Date) - $configTime
            if ($timeDiff.TotalHours -lt 24) {
                Write-ValidationLog "   ✓ WSL Configuration: UPDATED WITHIN 24 HOURS" -ForegroundColor Green
            } else {
                Write-ValidationLog "   ⚠ WSL Configuration: NOT RECENTLY UPDATED" -ForegroundColor Yellow
            }
        } else {
            Write-ValidationLog "   ✗ WSL Configuration File: NOT FOUND" -ForegroundColor Red
            $ValidationPassed = $false
            $FailedChecks += ".wslconfig not found"
        }
    } else {
        Write-ValidationLog "   ✗ WSL not installed or not accessible" -ForegroundColor Red
        $ValidationPassed = $false
        $FailedChecks += "WSL not installed or not accessible"
    }
} catch {
    Write-ValidationLog "   ✗ Error checking WSL: $_" -ForegroundColor Red
    $ValidationPassed = $false
    $FailedChecks += "WSL validation error: $($_.Exception.Message)"
}

# 4. Check for Optimization Log File
Write-ValidationLog "`n4. Checking Optimization Log..." -ForegroundColor Yellow
try {
    $logFiles = Get-ChildItem -Path "D:\DevOptimizer\logs\" -Filter "system-optimization.log" -ErrorAction SilentlyContinue
    if ($logFiles) {
        $latestLog = $logFiles | Sort-Object CreationTime -Descending | Select-Object -First 1
        if (Test-Path $latestLog.FullName) {
            $logContent = Get-Content $latestLog.FullName -Tail 10
            if ($logContent -match "Optimization complete for profile: $Profile") {
                Write-ValidationLog "   ✓ Optimization Log: SUCCESSFUL EXECUTION DETECTED FOR PROFILE $Profile" -ForegroundColor Green
                if ($Detailed) {
                    Write-ValidationLog "      Log file: $($latestLog.Name)" -ForegroundColor DarkGray
                    $logContent | ForEach-Object { Write-ValidationLog "         $_" -ForegroundColor DarkGray }
                }
            } else {
                Write-ValidationLog "   ✗ Optimization Log: COMPLETION NOT CONFIRMED FOR PROFILE $Profile" -ForegroundColor Red
                $ValidationPassed = $false
                $FailedChecks += "Optimization log does not confirm completion for profile $Profile"
                if ($Detailed) {
                    Write-ValidationLog "      Log file: $($latestLog.Name)" -ForegroundColor DarkGray
                    $logContent | ForEach-Object { Write-ValidationLog "         $_" -ForegroundColor DarkGray }
                }
            }
        } else {
            Write-ValidationLog "   ✗ Optimization Log File: NOT READABLE" -ForegroundColor Red
            $ValidationPassed = $false
            $FailedChecks += "Optimization log file not readable"
        }
    } else {
        Write-ValidationLog "   ✗ No optimization log files found" -ForegroundColor Red
        $ValidationPassed = $false
        $FailedChecks += "Optimization log file not found"
    }
} catch {
    Write-ValidationLog "   ✗ Error checking optimization log: $_" -ForegroundColor Red
    $ValidationPassed = $false
    $FailedChecks += "Optimization log validation error: $($_.Exception.Message)"
}

# Final Result
Write-ValidationLog "`n=== VALIDATION RESULTS ===" -ForegroundColor Cyan
if ($ValidationPassed) {
    Write-ValidationLog "   OVERALL RESULT: PASSED" -ForegroundColor Green
    Write-ValidationLog "   All critical optimizations verified against profile $Profile expectations." -ForegroundColor Green
    exit 0
} else {
    Write-ValidationLog "   OVERALL RESULT: FAILED" -ForegroundColor Red
    Write-ValidationLog "   Failed checks:" -ForegroundColor Red
    $FailedChecks | ForEach-Object { Write-ValidationLog "      - $_" -ForegroundColor Red }
    Write-ValidationLog "`n   Please review the errors above and re-run optimization if needed." -ForegroundColor Yellow
    exit 1
}
```

### Task 8: Final Verification and Documentation
**Goal**: Execute the complete optimization plan and document results
**Dependencies:** Task 2, Task 3, Task 4, Task 5, Task 6, Task 7
**Files:**
- Create: `D:\DevOptimizer\reports\optimization-results.md`
- Create: `D:\DevOptimizer\reports\baseline-pre-optimization.json`
- Modify: `D:\DevOptimizer\logs\system-optimization.log` (will be written to by execution)
**Acceptance Criteria:**
- [ ] Integrated optimizer script executes successfully with WSL-Heavy profile
- [ ] All selected optimizations apply without errors (exit code 0)
- [ ] Validation script confirms optimizations are active with exit code 0
- [ ] Results report is generated at D:\DevOptimizer\reports\optimization-results.md
- [ ] Full Verification Strategy executed: pre-execution baseline (CPU, GPU, WSL meminfo MemTotal, free, nproc) captured BEFORE optimization, and post-execution state (Get-Counter CPU sample, GPU, WSL free, nproc, log Test-Path) captured AFTER
- [ ] Optimizer and validation exit codes captured via $LASTEXITCODE after `powershell.exe -File` invocations (exit codes do not flow through the pipeline with `&` in-process calls)
**Step 1:** Capture the pre-execution baseline required by the Verification Strategy:
```powershell
# ===== PRE-EXECUTION BASELINE (Verification Strategy) =====
$baseline = @{}
$baseline.cpu = Get-CimInstance Win32_Processor | Select-Object Name, NumberOfLogicalProcessors, MaxClockSpeed
$baseline.gpu = Get-WmiObject Win32_VideoController | Where-Object {$_.Name -match "NVIDIA"} | Select-Object Name, DriverVersion, AdapterRAM
$baseline.wslMemTotal = wsl.exe -d Ubuntu-26.04 -e cat /proc/meminfo | Select-String "MemTotal"
$baseline.wslFree = wsl.exe -d Ubuntu-26.04 -e free -h
$baseline.wslNproc = wsl.exe -d Ubuntu-26.04 -e nproc
$baseline.wslConfigTime = if (Test-Path "$env:USERPROFILE\.wslconfig") { (Get-Item "$env:USERPROFILE\.wslconfig").LastWriteTime } else { $null }

New-Item -ItemType Directory -Path "D:\DevOptimizer\reports" -Force | Out-Null
$baseline | ConvertTo-Json -Depth 3 | Set-Content -Path "D:\DevOptimizer\reports\baseline-pre-optimization.json" -Encoding UTF8
Write-Host "Baseline captured:" -ForegroundColor Cyan
Write-Host "  WSL MemTotal: $($baseline.wslMemTotal)"
Write-Host "  WSL nproc: $($baseline.wslNproc)"
```
**Step 2:** Execute the integrated resource optimizer with WSL-Heavy profile (as requested by the user for optimal WSL performance) via process-isolated invocation:
```powershell
# ===== EXECUTE OPTIMIZATION =====
# Elevation precondition (see Preconditions): nvidia.ps1 #Requires -RunAsAdministrator,
# power-management.ps1 Main exits 1 without admin. Fail fast with a clear message.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Task 8 must run from an elevated (Run as Administrator) PowerShell session." -ForegroundColor Red
    exit 1
}

# -File invocation: child exit codes flow to $LASTEXITCODE (in-process `&` does not)
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\integrated-resource-optimizer.ps1" -Profile WSL-Heavy -Silent
$optimizationResult = $LASTEXITCODE

# Wait for WSL to restart and processes to settle after wsl --shutdown
Start-Sleep -Seconds 10
```
**Step 3:** Run the validation script:
```powershell
# ===== VALIDATION =====
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\tests\resource-optimization-validation.ps1" -Profile WSL-Heavy -Detailed
$validationResult = $LASTEXITCODE
```
**Step 4:** Capture the post-execution Verification Strategy state and generate the results report:
```powershell
# ===== POST-EXECUTION CAPTURE (Verification Strategy) =====
$postCpuSample = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 5 -MaxSamples 3
$postGpu = Get-WmiObject Win32_VideoController | Where-Object {$_.Name -match "NVIDIA"} | Select-Object Name, DriverVersion
$postWslFree = wsl.exe -d Ubuntu-26.04 -e free -h
$postWslNproc = wsl.exe -d Ubuntu-26.04 -e nproc
$logExists = Test-Path "D:\DevOptimizer\logs\system-optimization.log"

# Generate report
$reportPath = "D:\DevOptimizer\reports\optimization-results.md"
New-Item -ItemType Directory -Path (Split-Path $reportPath) -Force | Out-Null

@"
# System Resource Optimization Results
**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Profile**: WSL-Heavy
**Optimization Exit Code**: $optimizationResult
**Validation Exit Code**: $validationResult
**Overall**: $(if ($optimizationResult -eq 0 -and $validationResult -eq 0) { 'PASSED' } else { 'FAILED' })

## Optimization Summary
- GPU Optimization: $(if ($optimizationResult -eq 0) { 'APPLIED' } else { 'FAILED' }) via nvidia.ps1
- CPU Optimization: $(if ($optimizationResult -eq 0) { 'APPLIED' } else { 'FAILED' }) via power-management.ps1
- WSL Optimization: $(if ($optimizationResult -eq 0) { 'APPLIED' } else { 'FAILED' }) via optimize-wsl-memory.ps1
- Monitoring: ACTIVATED via real-time-monitoring.ps1 (Daemon mode)

## Pre-Execution Baseline
- CPU: $($baseline.cpu.Name), $($baseline.cpu.NumberOfLogicalProcessors) logical processors
- GPU: $($baseline.gpu.Name) (driver $($baseline.gpu.DriverVersion))
- WSL MemTotal: $($baseline.wslMemTotal)
- WSL nproc: $($baseline.wslNproc)

## Post-Execution State
- CPU sample (3x5s): $([math]::Round(($postCpuSample.CounterSamples | Measure-Object CookedValue -Average).Average, 2))% average
- GPU: $($postGpu.Name) (driver $($postGpu.DriverVersion))
- WSL free -h: $($postWslFree -join ' | ')
- WSL nproc: $($postWslNproc)
- Optimization log exists: $logExists

## Validation Details
See validation output above for specific check results.

## Next Steps
1. Monitor system performance under heavy loads
2. Re-run validation periodically to ensure settings persist
3. Adjust profile as needed based on workload characteristics
"@ | Set-Content -Path $reportPath -Encoding UTF8

Write-Host "Optimization complete. Report saved to: $reportPath" -ForegroundColor Green
Write-Host "Optimizer exit: $optimizationResult | Validation exit: $validationResult" -ForegroundColor $(if ($optimizationResult -eq 0 -and $validationResult -eq 0) { 'Green' } else { 'Red' })
```