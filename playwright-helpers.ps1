# Playwright Helper Scripts Generator
# Creates three essential scripts for Playwright testing

$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

# ============================================================
# Script 1: Quick Cleanup (kills orphaned browsers)
# ============================================================
$quickCleanup = @'
# Quick Playwright Cleanup
# Kills orphaned browser processes before testing

Write-Host ""
Write-Host "Cleaning up Playwright processes..." -ForegroundColor Yellow

$beforeMem = (Get-Process | Where-Object { 
    $_.ProcessName -like "*WebKit*" -or 
    $_.ProcessName -like "*chrome-headless*" -or 
    $_.ProcessName -eq "Playwright" 
} | Measure-Object -Property WorkingSet64 -Sum).Sum / 1GB

Get-Process | Where-Object { 
    $_.ProcessName -like "*WebKit*" -or 
    $_.ProcessName -like "*chrome-headless*" -or 
    $_.ProcessName -eq "Playwright" 
} | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 1

Write-Host "Cleaned up orphaned browsers" -ForegroundColor Green
if ($beforeMem -gt 0) {
    Write-Host "Freed: $([math]::Round($beforeMem, 2)) GB" -ForegroundColor Cyan
}

# Show current RAM
$os = Get-CimInstance Win32_OperatingSystem
$freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
Write-Host "Available RAM: $freeRAM GB" -ForegroundColor White
Write-Host ""
'@

Set-Content -Path "D:\DevOptimizer\quick-cleanup.ps1" -Value $quickCleanup
Write-Host "Created: D:\DevOptimizer\quick-cleanup.ps1" -ForegroundColor Green

# ============================================================
# Script 2: Optimized Playwright Config
# ============================================================
$playwrightConfig = @'
import { defineConfig, devices } from '@playwright/test';

/**
 * Optimized Playwright Configuration for Resource-Constrained Testing
 * Generated: 2026-02-08
 * 
 * Key optimizations:
 * - Serial execution (workers: 1) to prevent memory spikes
 * - Headless mode to reduce resource usage
 * - Minimal artifacts (only on failure)
 * - Global teardown to ensure cleanup
 */

export default defineConfig({
  testDir: './tests',
  
  // CRITICAL: Run tests serially to avoid memory issues
  fullyParallel: false,
  workers: 1,
  
  // No retries during development
  retries: 0,
  
  // Timeouts
  timeout: 30000,
  expect: {
    timeout: 5000
  },
  
  // Minimal reporting
  reporter: [
    ['list'],
    ['html', { open: 'never' }]
  ],
  
  // Global teardown to kill any remaining browsers
  globalTeardown: './global-teardown.ts',
  
  use: {
    // Base URL for your app
    baseURL: 'http://localhost:3000',
    
    // Headless mode uses significantly less memory
    headless: true,
    
    // Only capture artifacts on failure
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    // Optimize browser launch
    launchOptions: {
      args: [
        '--disable-gpu',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-setuid-sandbox',
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
        '--disable-renderer-backgrounding'
      ]
    }
  },
  
  // Use only Chromium by default
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    
    // Uncomment only when cross-browser testing is needed:
    // {
    //   name: 'firefox',
    //   use: { ...devices['Desktop Firefox'] },
    // },
    // {
    //   name: 'webkit',
    //   use: { ...devices['Desktop Safari'] },
    // },
  ],
  
  // Development server configuration
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: true,
    timeout: 120000,
  },
});
'@

Set-Content -Path "D:\DevOptimizer\playwright.config.optimized.ts" -Value $playwrightConfig
Write-Host "Created: D:\DevOptimizer\playwright.config.optimized.ts" -ForegroundColor Green

# ============================================================
# Script 3: Global Teardown (ensures browser cleanup)
# ============================================================
$globalTeardown = @'
/**
 * Global Teardown for Playwright
 * Ensures all browser processes are killed after test run
 */

import { execSync } from 'child_process';

async function globalTeardown() {
  console.log('\n🧹 Running global teardown...');
  
  try {
    // Kill any remaining browser processes (Windows)
    const killCommands = [
      'taskkill /F /IM chrome.exe /T 2>nul',
      'taskkill /F /IM chrome-headless-shell.exe /T 2>nul',
      'taskkill /F /IM msedge.exe /T 2>nul',
      'taskkill /F /IM firefox.exe /T 2>nul',
      'taskkill /F /IM WebKitWebProcess.exe /T 2>nul',
      'taskkill /F /IM WebKitNetworkProcess.exe /T 2>nul',
      'taskkill /F /IM WebKitGPUProcess.exe /T 2>nul',
    ];
    
    for (const cmd of killCommands) {
      try {
        execSync(cmd, { stdio: 'ignore' });
      } catch (e) {
        // Ignore errors (process might not exist)
      }
    }
    
    console.log('✓ Browser cleanup complete');
  } catch (error) {
    console.error('Teardown error:', error);
  }
}

export default globalTeardown;
'@

Set-Content -Path "D:\DevOptimizer\global-teardown.ts" -Value $globalTeardown
Write-Host "Created: D:\DevOptimizer\global-teardown.ts" -ForegroundColor Green

# ============================================================
# Script 4: VS Code Profile Switcher
# ============================================================
$profileSwitcher = @'
# VS Code Insiders Profile Switcher
# Usage: .\switch-profile.ps1 -Profile [test|heavy]

param(
    [ValidateSet('test', 'heavy')]
    [string]$Profile = 'test'
)

$vscode = "code-insiders"

Write-Host ""
Write-Host "Switching VS Code Insiders profile..." -ForegroundColor Cyan

if ($Profile -eq 'test') {
    Write-Host "Profile: Playwright-Test (lightweight)" -ForegroundColor Green
    Write-Host "- Minimal extensions" -ForegroundColor Gray
    Write-Host "- Reduced MCP servers" -ForegroundColor Gray
    Write-Host "- Optimized for testing" -ForegroundColor Gray
    Write-Host ""
    
    & $vscode --profile "Playwright-Test"
} else {
    Write-Host "Profile: Heavy (full development)" -ForegroundColor Yellow
    Write-Host "- All extensions enabled" -ForegroundColor Gray
    Write-Host "- Full MCP server stack" -ForegroundColor Gray
    Write-Host "- Complete development environment" -ForegroundColor Gray
    Write-Host ""
    
    & $vscode --profile "Heavy"
}
'@

Set-Content -Path "D:\DevOptimizer\switch-profile.ps1" -Value $profileSwitcher
Write-Host "Created: D:\DevOptimizer\switch-profile.ps1" -ForegroundColor Green

# ============================================================
# Create README with usage instructions
# ============================================================
$readme = @'
# Playwright Testing Helper Scripts

## Quick Reference

### Before Each Test Run
```powershell
.\quick-cleanup.ps1
```
Kills orphaned browser processes and shows available RAM.

### Switch to Test Profile
```powershell
.\switch-profile.ps1 -Profile test
```
Launches VS Code Insiders with minimal extensions for testing.

### Switch to Heavy Profile
```powershell
.\switch-profile.ps1 -Profile heavy
```
Returns to full development environment.

## Setup Instructions

### 1. Copy Playwright Config
Copy the optimized config to your project:
```powershell
Copy-Item D:\DevOptimizer\playwright.config.optimized.ts <your-project>\playwright.config.ts
```

### 2. Copy Global Teardown
Copy to your project root:
```powershell
Copy-Item D:\DevOptimizer\global-teardown.ts <your-project>\global-teardown.ts
```

### 3. Create Test Profile in VS Code
1. Open VS Code Insiders
2. Press Ctrl+Shift+P
3. Type "Profiles: Create Profile"
4. Name it "Playwright-Test"
5. Disable all extensions except:
   - Playwright Test for VS Code
   - (optional) Error Lens
   - (optional) ESLint

## Recommended Testing Workflow

1. Run cleanup: `.\quick-cleanup.ps1`
2. Switch to test profile: `.\switch-profile.ps1 -Profile test`
3. Open your project in VS Code Insiders
4. Run Playwright tests
5. After testing, switch back: `.\switch-profile.ps1 -Profile heavy`

## Tips

- Always run quick-cleanup.ps1 before testing
- Use test profile to reduce VS Code memory from 10GB to ~2-3GB
- Monitor RAM in Task Manager during tests
- If tests still freeze, reduce WSL memory further to 10GB

'@

Set-Content -Path "D:\DevOptimizer\README.md" -Value $readme
Write-Host "Created: D:\DevOptimizer\README.md" -ForegroundColor Green

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "All helper scripts created successfully!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Location: D:\DevOptimizer\" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: .\quick-cleanup.ps1 (before each test)" -ForegroundColor White
Write-Host "2. Create 'Playwright-Test' profile in VS Code Insiders" -ForegroundColor White
Write-Host "3. Copy playwright.config.optimized.ts to your project" -ForegroundColor White
Write-Host "4. Copy global-teardown.ts to your project" -ForegroundColor White
Write-Host ""
Write-Host "See README.md for complete instructions" -ForegroundColor Gray