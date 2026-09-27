# Playwright Performance Diagnostic & Optimization Script
# Run with: powershell -ExecutionPolicy Bypass -File .\playwright-optimizer.ps1

param(
    [switch]$Analyze,
    [switch]$Optimize,
    [switch]$CreateTestProfile,
    [switch]$All
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "$env:USERPROFILE\Desktop\playwright-diagnostics-$timestamp.log"

function Write-Log {
    param($Message, $Color = "White")
    $logMessage = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    Add-Content -Path $logFile -Value $logMessage
}

function Test-WSLMemory {
    Write-Log "=== Checking WSL2 Configuration ===" "Cyan"
    
    $wslConfigPath = "$env:USERPROFILE\.wslconfig"
    
    if (Test-Path $wslConfigPath) {
        Write-Log "Found .wslconfig:" "Green"
        Get-Content $wslConfigPath | ForEach-Object { Write-Log "  $_" }
    } else {
        Write-Log ".wslconfig not found. Creating optimized configuration..." "Yellow"
        
        $wslConfig = @"
[wsl2]
memory=8GB
processors=4
localhostForwarding=true
swap=2GB
swapFile=$env:USERPROFILE\AppData\Local\Temp\wsl-swap.vhdx

[experimental]
autoMemoryReclaim=gradual
"@
        Set-Content -Path $wslConfigPath -Value $wslConfig
        Write-Log "Created .wslconfig. Restart WSL with: wsl --shutdown" "Green"
    }
}

function Get-VSCodeProcesses {
    Write-Log "`n=== VS Code Insiders Process Analysis ===" "Cyan"
    
    $vscodeProcesses = Get-Process | Where-Object { $_.ProcessName -like "*Code*Insiders*" -or $_.ProcessName -eq "node" }
    
    if ($vscodeProcesses) {
        $totalMemory = ($vscodeProcesses | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB
        Write-Log "Total VS Code Insiders memory usage: $([math]::Round($totalMemory, 2)) MB" "Yellow"
        
        $vscodeProcesses | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object {
            $memMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
            Write-Log "  $($_.ProcessName) (PID: $($_.Id)): $memMB MB"
        }
    } else {
        Write-Log "No VS Code Insiders processes currently running" "Gray"
    }
}

function Get-PlaywrightProcesses {
    Write-Log "`n=== Playwright/Browser Process Analysis ===" "Cyan"
    
    $browserProcesses = Get-Process | Where-Object { 
        $_.ProcessName -like "*chrome*" -or 
        $_.ProcessName -like "*firefox*" -or 
        $_.ProcessName -like "*webkit*" -or
        $_.ProcessName -like "*playwright*"
    }
    
    if ($browserProcesses) {
        $totalMemory = ($browserProcesses | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB
        Write-Log "Total Browser/Playwright memory: $([math]::Round($totalMemory, 2)) MB" "Yellow"
        
        $browserProcesses | Group-Object ProcessName | ForEach-Object {
            $groupMemMB = [math]::Round(($_.Group | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
            Write-Log "  $($_.Name): $($_.Count) processes, $groupMemMB MB total"
        }
    } else {
        Write-Log "No Playwright browser processes currently running" "Gray"
    }
}

function Optimize-VSCodeSettings {
    Write-Log "`n=== Creating Optimized VS Code Settings ===" "Cyan"
    
    $vscodeSettingsPath = "$env:APPDATA\Code - Insiders\User"
    $backupSettings = "$env:USERPROFILE\Desktop\vscode-settings-backup-$timestamp.json"
    
    if (Test-Path "$vscodeSettingsPath\settings.json") {
        Copy-Item "$vscodeSettingsPath\settings.json" $backupSettings
        Write-Log "Backed up current settings to: $backupSettings" "Green"
    }
    
    $optimizedSettings = @"
{
  // Playwright Performance Optimizations
  "playwright.reuseBrowser": true,
  "playwright.showTrace": false,
  
  // File Watching - Reduce Resource Usage
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/**": true,
    "**/.next/**": true,
    "**/dist/**": true,
    "**/.amplify/**": true,
    "**/build/**": true,
    "**/.playwright/**": true,
    "**/playwright-report/**": true,
    "**/test-results/**": true
  },
  
  // Search Optimization
  "search.followSymlinks": false,
  "search.exclude": {
    "**/node_modules": true,
    "**/bower_components": true,
    "**/.next": true,
    "**/dist": true,
    "**/.amplify": true
  },
  
  // TypeScript Server Memory
  "typescript.tsserver.maxTsServerMemory": 4096,
  
  // Disable Telemetry
  "telemetry.telemetryLevel": "off",
  
  // Extension Recommendations
  "extensions.autoUpdate": false,
  "extensions.autoCheckUpdates": false,
  
  // Git Performance
  "git.autorefresh": false,
  "git.autofetch": false
}
"@
    
    $optimizedPath = "$env:USERPROFILE\Desktop\vscode-optimized-settings-$timestamp.json"
    Set-Content -Path $optimizedPath -Value $optimizedSettings
    Write-Log "Created optimized settings file: $optimizedPath" "Green"
    Write-Log "Review and merge these settings into your VS Code configuration" "Yellow"
}

function Create-PlaywrightConfig {
    Write-Log "`n=== Creating Optimized Playwright Configuration ===" "Cyan"
    
    $playwrightConfig = @"
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  // Test directory
  testDir: './tests',
  
  // Performance optimizations
  fullyParallel: false,
  workers: 1, // Run tests serially to reduce resource usage
  retries: 0, // No retries during development
  
  // Timeouts
  timeout: 30000,
  expect: {
    timeout: 5000
  },
  
  // Reporter
  reporter: [
    ['list'],
    ['html', { open: 'never' }] // Don't auto-open report
  ],
  
  // Global setup/teardown
  use: {
    // Base URL
    baseURL: 'http://localhost:3000',
    
    // Browser options
    headless: true, // Headless mode uses less resources
    
    // Tracing - only on failure
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    // Reduce browser context overhead
    launchOptions: {
      args: [
        '--disable-gpu',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-setuid-sandbox'
      ]
    }
  },
  
  // Projects - comment out unused browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    // Uncomment only when needed:
    // {
    //   name: 'firefox',
    //   use: { ...devices['Desktop Firefox'] },
    // },
    // {
    //   name: 'webkit',
    //   use: { ...devices['Desktop Safari'] },
    // },
  ],
  
  // Development server
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: true,
    timeout: 120000,
  },
});
"@
    
    $configPath = "$env:USERPROFILE\Desktop\playwright.config.optimized-$timestamp.ts"
    Set-Content -Path $configPath -Value $playwrightConfig
    Write-Log "Created optimized Playwright config: $configPath" "Green"
}

function Create-TestProfile {
    Write-Log "`n=== Creating VS Code Insiders Test Profile ===" "Cyan"
    
    $profileScript = @"
# VS Code Insiders Profile Switcher
# Usage: .\switch-vscode-profile.ps1 -Profile [heavy|test]

param(
    [ValidateSet('heavy', 'test')]
    [string]`$Profile = 'test'
)

`$vscodeInsiders = "code-insiders"

if (`$Profile -eq 'test') {
    Write-Host "Switching to TEST profile (lightweight for Playwright)..." -ForegroundColor Green
    & `$vscodeInsiders --profile "Playwright-Test"
} else {
    Write-Host "Switching to HEAVY profile (full development)..." -ForegroundColor Cyan
    & `$vscodeInsiders --profile "Heavy"
}
"@
    
    $switcherPath = "$env:USERPROFILE\Desktop\switch-vscode-profile-$timestamp.ps1"
    Set-Content -Path $switcherPath -Value $profileScript
    Write-Log "Created profile switcher: $switcherPath" "Green"
    
    Write-Log "`nTo create the test profile:" "Yellow"
    Write-Log "1. Open VS Code Insiders" "White"
    Write-Log "2. Press Ctrl+Shift+P" "White"
    Write-Log "3. Type 'Profiles: Create Profile'" "White"
    Write-Log "4. Name it 'Playwright-Test'" "White"
    Write-Log "5. Disable all extensions except: Playwright Test for VS Code" "White"
}

function Get-SystemResources {
    Write-Log "`n=== System Resources Overview ===" "Cyan"
    
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRAM = $totalRAM - $freeRAM
    $ramPercent = [math]::Round(($usedRAM / $totalRAM) * 100, 2)
    
    Write-Log "CPU: $($cpu.Name)" "White"
    Write-Log "CPU Cores: $($cpu.NumberOfCores) | Logical Processors: $($cpu.NumberOfLogicalProcessors)" "White"
    Write-Log "RAM Total: $totalRAM GB" "White"
    Write-Log "RAM Used: $usedRAM GB ($ramPercent%)" $(if ($ramPercent -gt 80) { "Red" } else { "Green" })
    Write-Log "RAM Free: $freeRAM GB" "White"
    
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
    foreach ($drive in $drives) {
        $usedGB = [math]::Round($drive.Used / 1GB, 2)
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        $totalGB = $usedGB + $freeGB
        $usedPercent = [math]::Round(($usedGB / $totalGB) * 100, 2)
        Write-Log "Drive $($drive.Name): $usedGB GB used / $totalGB GB total ($usedPercent%)" "White"
    }
}

function Clean-PlaywrightArtifacts {
    Write-Log "`n=== Cleaning Playwright Artifacts ===" "Cyan"
    
    $cleanDirs = @(
        "test-results",
        "playwright-report",
        ".playwright"
    )
    
    $cleaned = 0
    foreach ($dir in $cleanDirs) {
        if (Test-Path $dir) {
            $size = (Get-ChildItem -Path $dir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
            Remove-Item -Path $dir -Recurse -Force
            Write-Log "Removed $dir (freed $([math]::Round($size, 2)) MB)" "Green"
            $cleaned++
        }
    }
    
    if ($cleaned -eq 0) {
        Write-Log "No Playwright artifacts found to clean" "Gray"
    }
}

# Main execution
Write-Log "=== Playwright Performance Diagnostic Tool ===" "Magenta"
Write-Log "Log file: $logFile`n" "Gray"

if ($All -or $Analyze) {
    Get-SystemResources
    Test-WSLMemory
    Get-VSCodeProcesses
    Get-PlaywrightProcesses
}

if ($All -or $Optimize) {
    Optimize-VSCodeSettings
    Create-PlaywrightConfig
    Clean-PlaywrightArtifacts
}

if ($All -or $CreateTestProfile) {
    Create-TestProfile
}

if (-not ($Analyze -or $Optimize -or $CreateTestProfile -or $All)) {
    Write-Log "Usage:" "Yellow"
    Write-Log "  .\playwright-optimizer.ps1 -Analyze          # Analyze current state" "White"
    Write-Log "  .\playwright-optimizer.ps1 -Optimize         # Create optimized configs" "White"
    Write-Log "  .\playwright-optimizer.ps1 -CreateTestProfile # Create profile switcher" "White"
    Write-Log "  .\playwright-optimizer.ps1 -All              # Run everything" "White"
}

Write-Log "`n=== Diagnostic Complete ===" "Magenta"
Write-Log "Review log file: $logFile" "Cyan"