# Vitest Explorer Extension Configuration

## Overview
The Vitest Explorer extension has been configured for your Nuxt 4 project in the `nuxt4-templates` folder.

## Configuration Files Created

### 1. `.vscode/settings.json` (Root)
Main workspace settings for Vitest Explorer extension.

### 2. `nuxt4-templates/.vscode/settings.json`
Project-specific settings for the Nuxt 4 templates folder.

### 3. `nuxt4-templates/vitest.config.ts`
Updated Vitest configuration with proper test patterns and settings.

## Extension Settings

The extension is configured with:

- **Config File**: `nuxt4-templates/vitest.config.ts`
- **Command Line**: `npm test`
- **Test Patterns**: `**/*.{test,spec}.{js,ts,vue}`
- **Exclude Patterns**: `node_modules`, `.nuxt`, `.output`, `coverage`
- **Watch Mode**: Enabled
- **Coverage**: Disabled by default (can be enabled in settings)

## Usage

### 1. Open Test Explorer
- Open the Test Explorer panel in VS Code (View → Testing)
- Or use the Test Explorer icon in the Activity Bar

### 2. Run Tests
- Click the play button next to any test
- Run all tests in a file
- Run all tests in the workspace

### 3. Watch Mode
- Tests will automatically re-run when files change
- Can be toggled in the Test Explorer panel

### 4. Debug Tests
- Click the debug icon next to any test
- Set breakpoints in test files
- Use VS Code's debugger

## Test File Structure

Create test files with these naming patterns:
- `*.test.ts` or `*.test.js`
- `*.spec.ts` or `*.spec.js`
- `*.test.vue` or `*.spec.vue`

Example locations:
```
nuxt4-templates/
  ├── components/
  │   └── Button.test.vue
  ├── composables/
  │   └── useCounter.test.ts
  ├── utils/
  │   └── helpers.test.ts
  └── test/
      └── example.test.ts
```

## Running Tests Manually

### Via Terminal
```bash
cd nuxt4-templates
npm test
```

### With UI
```bash
cd nuxt4-templates
npm run test:ui
```

### With Coverage
```bash
cd nuxt4-templates
npm run test:coverage
```

## Troubleshooting

### Extension Not Detecting Tests

1. **Reload VS Code Window**
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
   - Type "Reload Window"
   - Select "Developer: Reload Window"

2. **Check Node Modules**
   ```bash
   cd nuxt4-templates
   npm install
   ```

3. **Verify Vitest Installation**
   ```bash
   cd nuxt4-templates
   npm list vitest
   ```

4. **Check Config File**
   - Ensure `vitest.config.ts` exists in `nuxt4-templates/`
   - Verify the config is valid

5. **Check Workspace Folder**
   - The extension looks for tests in `nuxt4-templates/`
   - Ensure you're working in the correct folder

### Tests Not Running

1. **Check Package.json Scripts**
   - Ensure `"test": "vitest"` exists in `package.json`

2. **Check Node Version**
   - Vitest requires Node.js >= 18.0.0
   - Run: `node --version`

3. **Check for Errors**
   - Open the Output panel (View → Output)
   - Select "Vitest" from the dropdown
   - Look for error messages

### Extension Settings Not Applied

1. **Check Settings Location**
   - Root workspace: `.vscode/settings.json`
   - Project folder: `nuxt4-templates/.vscode/settings.json`

2. **Verify Extension Installed**
   - Open Extensions (Ctrl+Shift+X)
   - Search for "Vitest"
   - Ensure "Vitest Explorer" is installed and enabled

## Advanced Configuration

### Custom Test Patterns

Edit `.vscode/settings.json`:
```json
{
  "vitest.include": [
    "**/*.test.{ts,js,vue}",
    "**/tests/**/*.{ts,js,vue}"
  ]
}
```

### Environment Variables

Edit `.vscode/settings.json`:
```json
{
  "vitest.nodeEnv": {
    "NODE_ENV": "test",
    "VITEST": "true"
  }
}
```

### Multiple Workspaces

If you have multiple test projects:
```json
{
  "vitest.workspaceConfig": [
    {
      "extends": "./nuxt4-templates/vitest.config.ts",
      "test": {
        "name": "nuxt4-templates",
        "root": "./nuxt4-templates"
      }
    }
  ]
}
```

## Next Steps

1. **Create Test Files**
   - Add tests for your components, composables, and utilities
   - Use the example test as a template

2. **Run Tests**
   - Use the Test Explorer panel
   - Or run `npm test` in the terminal

3. **Enable Coverage** (Optional)
   - Set `"vitest.showCoverage": true` in settings
   - Or run `npm run test:coverage`

4. **Write More Tests**
   - Test Vue components
   - Test Nuxt composables
   - Test utilities and helpers

## Resources

- [Vitest Documentation](https://vitest.dev/)
- [Vitest Explorer Extension](https://marketplace.visualstudio.com/items?itemName=vitest.explorer)
- [Nuxt Test Utils](https://nuxt.com/docs/getting-started/testing)


