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
