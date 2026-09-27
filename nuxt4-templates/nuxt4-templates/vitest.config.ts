import { defineVitestConfig } from '@nuxt/test-utils/config'

export default defineVitestConfig({
  test: {
    // Use Nuxt test environment
    environment: 'nuxt',

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
      '**/*.d.ts'
    ],

    // Global test setup
    globals: true,

    // Coverage configuration
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        '.nuxt/',
        '.output/',
        'coverage/',
        '**/*.d.ts',
        '**/*.config.*',
        '**/types/**'
      ]
    },

    // Test timeout
    testTimeout: 10000,

    // Watch mode
    watch: false,

    // Reporter configuration
    reporters: ['verbose'],

    // Output file for test results
    outputFile: {
      json: './test-results.json'
    }
  }
})
