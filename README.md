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

