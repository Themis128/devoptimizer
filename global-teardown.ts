/**
 * Global Teardown for Playwright
 * Ensures all browser processes are killed after test run
 */

import { execFileSync } from 'child_process';

async function globalTeardown() {
  console.log('\n🧹 Running global teardown...');

  try {
    // Kill any remaining browser processes (Windows)
    // Argument-list execution (no shell) so no command line is ever concatenated.
    const browserImages = [
      'chrome.exe',
      'chrome-headless-shell.exe',
      'msedge.exe',
      'firefox.exe',
      'WebKitWebProcess.exe',
      'WebKitNetworkProcess.exe',
      'WebKitGPUProcess.exe',
    ];

    for (const image of browserImages) {
      try {
        execFileSync('taskkill', ['/F', '/IM', image, '/T'], { stdio: 'ignore' });
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
