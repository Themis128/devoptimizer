# Vitest Explorer Extension - Setup Complete ✅

## Installation Status

✅ **Vitest installed** in `nuxt4-templates/` folder (version 3.2.4)  
✅ **Configuration files** created  
✅ **VS Code settings** configured  
✅ **Sample test file** created  

## Configuration Summary

### Files Created/Updated:

1. **`.vscode/settings.json`** - Main workspace settings for Vitest Explorer
2. **`nuxt4-templates/.vscode/settings.json`** - Project-specific settings
3. **`nuxt4-templates/vitest.config.ts`** - Enhanced Vitest configuration
4. **`nuxt4-templates/test/example.test.ts`** - Sample test file
5. **`nuxt4-templates/package.json`** - Added Vitest dependency

### Extension Settings:

- **Config File**: `nuxt4-templates/vitest.config.ts`
- **Command**: `npm test`
- **Test Patterns**: `**/*.{test,spec}.{js,ts,vue}`
- **Root**: `./nuxt4-templates`

## Next Steps

### 1. Reload VS Code Window
Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac) and run:
```
Developer: Reload Window
```

### 2. Open Test Explorer
- Click the **Test Explorer** icon in the Activity Bar (beaker icon)
- Or go to: **View → Testing**

### 3. Verify Detection
The extension should now:
- Detect Vitest in `nuxt4-templates/` folder
- Find the `vitest.config.ts` file
- Discover test files (like `test/example.test.ts`)
- Show tests in the Test Explorer panel

### 4. Run Tests
- Click the play button (▶️) next to any test
- Run all tests in a file
- Run all tests in the workspace

## Troubleshooting

### If Extension Still Shows "Vitest not found":

1. **Check Installation**:
   ```bash
   cd nuxt4-templates
   npm list vitest
   ```
   Should show: `vitest@3.2.4`

2. **Verify Config File**:
   - Ensure `nuxt4-templates/vitest.config.ts` exists
   - Check that it's a valid TypeScript file

3. **Check VS Code Output**:
   - Go to **View → Output**
   - Select **"Vitest"** from the dropdown
   - Look for error messages

4. **Restart Extension**:
   - Press `Ctrl+Shift+P`
   - Run: `Vitest: Restart`

### If Tests Don't Appear:

1. **Check Test File Location**:
   - Tests should be in `nuxt4-templates/` or subfolders
   - Files should match pattern: `*.test.ts` or `*.spec.ts`

2. **Verify Test File**:
   ```typescript
   import { describe, it, expect } from 'vitest'
   
   describe('My Test', () => {
     it('should work', () => {
       expect(true).toBe(true)
     })
   })
   ```

3. **Run Tests Manually**:
   ```bash
   cd nuxt4-templates
   npm test
   ```

## Test File Examples

### Component Test (Vue)
```typescript
import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import MyComponent from '~/components/MyComponent.vue'

describe('MyComponent', () => {
  it('renders correctly', () => {
    const wrapper = mount(MyComponent)
    expect(wrapper.text()).toContain('Hello')
  })
})
```

### Composable Test
```typescript
import { describe, it, expect } from 'vitest'
import { useCounter } from '~/composables/useCounter'

describe('useCounter', () => {
  it('increments count', () => {
    const { count, increment } = useCounter()
    expect(count.value).toBe(0)
    increment()
    expect(count.value).toBe(1)
  })
})
```

### Utility Test
```typescript
import { describe, it, expect } from 'vitest'
import { formatDate } from '~/utils/date'

describe('formatDate', () => {
  it('formats date correctly', () => {
    const date = new Date('2024-01-01')
    expect(formatDate(date)).toBe('01/01/2024')
  })
})
```

## Useful Commands

### Run Tests
```bash
# Run all tests
npm test

# Run in watch mode
npm test

# Run with UI
npm run test:ui

# Run with coverage
npm run test:coverage
```

### VS Code Commands
- `Ctrl+Shift+P` → `Vitest: Run All Tests`
- `Ctrl+Shift+P` → `Vitest: Run Current Test`
- `Ctrl+Shift+P` → `Vitest: Restart`

## Configuration Files

### vitest.config.ts
Located at: `nuxt4-templates/vitest.config.ts`

Key settings:
- Environment: `nuxt` (Nuxt test environment)
- Globals: Enabled
- Coverage: v8 provider
- Timeout: 10 seconds

### VS Code Settings
Located at: `.vscode/settings.json`

Key settings:
- Test patterns: `**/*.{test,spec}.{js,ts,vue}`
- Exclude: `node_modules`, `.nuxt`, `.output`
- Command: `npm test`

## Support

If you encounter issues:
1. Check the [Vitest Explorer documentation](https://marketplace.visualstudio.com/items?itemName=vitest.explorer)
2. Review the [Vitest documentation](https://vitest.dev/)
3. Check VS Code Output panel for error messages

---

**Setup completed successfully!** 🎉

The Vitest Explorer extension should now be fully configured and ready to use.

