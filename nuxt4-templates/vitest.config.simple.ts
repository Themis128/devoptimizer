import { defineConfig } from 'vitest/config'
import { resolve } from 'path'

export default defineConfig({
  // Resolve configuration
  resolve: {
    alias: {
      '~': resolve(__dirname, '.'),
      '@': resolve(__dirname, '.')
    }
  },

  // Use inline TypeScript config to bypass the problematic tsconfig.json
  // The tsconfig.json extends .nuxt/tsconfig.json which doesn't exist
  esbuild: {
    tsconfigRaw: {
      compilerOptions: {
        target: 'ES2020',
        module: 'ESNext',
        lib: ['ES2020', 'DOM'],
        moduleResolution: 'bundler',
        resolveJsonModule: true,
        allowJs: true,
        strict: true,
        esModuleInterop: true,
        skipLibCheck: true,
        allowSyntheticDefaultImports: true,
        types: ['vitest/globals', 'node']
      }
    }
  },

  test: {
    // Test file patterns
    include: [
      '**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx,vue}',
      '**/__tests__/**/*.{js,mjs,cjs,ts,mts,cts,jsx,tsx,vue}'
    ],

    // Exclude patterns
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      '**/.nuxt/**',
      '**/.output/**',
      '**/coverage/**',
      '**/*.d.ts',
      'nuxt4-templates/**' // Exclude nested folder
    ],

    // Global test setup
    globals: true,

    // Test timeout
    testTimeout: 10000,

    // Watch mode
    watch: false,

    // Reporter configuration
    reporters: ['verbose'],

    // Environment (use node for simple tests, or happy-dom for DOM tests)
    environment: 'node'
  }
})
