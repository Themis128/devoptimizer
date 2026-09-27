// =====================================================
// NUXT 4 OPTIMIZED CONFIGURATION - 2024/2025 BEST PRACTICES
// Maximum performance, development experience, and production optimization
// =====================================================

export default defineNuxtConfig({
  // ===== CORE CONFIGURATION =====
  future: {
    compatibilityVersion: 4,
  },
  
  // Enable experimental features for Nuxt 4
  experimental: {
    // Nuxt 4 features
    scanPageMeta: 'after-resolve',
    sharedPrerenderData: false,
    compileTemplate: true,
    resetAsyncDataToUndefined: true,
    templateUtils: true,
    relativeWatchPaths: true,
    defaults: {
      useAsyncData: {
        deep: true
      }
    },
    // Performance optimizations
    payloadExtraction: false,
    clientNodeCompat: false,
    componentIslands: true,
    configSchema: true,
    polyfillVueUseHead: false,
    respectNoSSRHeader: true,
    renderJsonPayloads: true,
    noVueServer: false,
    asyncEntry: true,
    externalVue: true,
    treeshakeClientOnly: true,
    emitRouteChunkError: 'automatic',
    restoreState: true,
    inlineRouteRules: true,
    viewTransition: true,
    writeEarlyHints: false,
    crossOriginPrefetch: false,
    appManifest: true,
    headNext: true,
    typedPages: true
  },

  // ===== DEVELOPMENT CONFIGURATION =====
  devtools: { 
    enabled: true,
    timeline: {
      enabled: true
    }
  },
  
  devServer: {
    host: process.env.NUXT_HOST || 'localhost',
    port: process.env.NUXT_PORT ? parseInt(process.env.NUXT_PORT) : 3000,
    https: false,
    // Enable hot reloading optimizations
    watch: {
      usePolling: false,
      ignoreInitial: true,
      ignored: [
        '**/node_modules/**',
        '**/.git/**',
        '**/dist/**',
        '**/.nuxt/**',
        '**/coverage/**'
      ]
    }
  },

  // ===== TYPESCRIPT CONFIGURATION =====
  typescript: {
    strict: true,
    typeCheck: 'build'
  },

  // ===== ESSENTIAL MODULES =====
  modules: [
    // Core modules
    '@pinia/nuxt',
    '@nuxt/image',
    '@nuxtjs/tailwindcss',
    '@nuxt/content',
    '@vueuse/nuxt',
    
    // Performance modules
    '@nuxtjs/critters',
    '@nuxtjs/web-vitals',
    
    // Development modules
    '@nuxt/devtools',
    '@nuxt/eslint',
    
    // SEO and PWA
    '@nuxtjs/seo',
    '@vite-pwa/nuxt'
  ],

  // ===== CSS AND STYLING =====
  css: [
    '~/assets/css/main.css'
  ],
  
  tailwindcss: {
    // Tailwind CSS optimizations
    exposeConfig: true,
    viewer: true,
    configPath: '~/tailwind.config.js',
    cssPath: '~/assets/css/tailwind.css',
    config: {
      darkMode: 'class',
      content: [
        'components/**/*.{vue,js,ts}',
        'layouts/**/*.vue',
        'pages/**/*.vue',
        'composables/**/*.{js,ts}',
        'plugins/**/*.{js,ts}',
        'app.vue'
      ]
    }
  },

  // ===== IMAGE OPTIMIZATION =====
  image: {
    quality: 80,
    format: ['webp', 'avif'],
    screens: {
      xs: 320,
      sm: 640,
      md: 768,
      lg: 1024,
      xl: 1280,
      xxl: 1536,
    },
    domains: [],
    alias: {},
    densities: [1, 2],
    presets: {
      avatar: {
        modifiers: {
          format: 'webp',
          width: 50,
          height: 50
        }
      },
      cover: {
        modifiers: {
          format: 'webp',
          width: 800,
          height: 600,
          fit: 'cover'
        }
      }
    }
  },

  // ===== CONTENT MANAGEMENT =====
  content: {
    highlight: {
      theme: {
        default: 'github-light',
        dark: 'github-dark'
      },
      preload: ['json', 'js', 'ts', 'html', 'css', 'vue', 'diff', 'shell', 'markdown', 'yaml', 'bash', 'ini']
    },
    markdown: {
      mdc: true,
      toc: {
        depth: 5,
        searchDepth: 5
      }
    }
  },

  // ===== PWA CONFIGURATION =====
  pwa: {
    registerType: 'autoUpdate',
    workbox: {
      globPatterns: ['**/*.{js,css,html,png,svg,ico}'],
      navigateFallback: '/offline',
      runtimeCaching: [
        {
          urlPattern: /^https:\/\/fonts\.googleapis\.com\/.*/i,
          handler: 'CacheFirst',
          options: {
            cacheName: 'google-fonts-cache',
            expiration: {
              maxEntries: 10,
              maxAgeSeconds: 60 * 60 * 24 * 365 // <== 365 days
            },
            cacheableResponse: {
              statuses: [0, 200]
            }
          }
        },
        {
          urlPattern: /^https:\/\/fonts\.gstatic\.com\/.*/i,
          handler: 'CacheFirst',
          options: {
            cacheName: 'gstatic-fonts-cache',
            expiration: {
              maxEntries: 10,
              maxAgeSeconds: 60 * 60 * 24 * 365 // <== 365 days
            },
            cacheableResponse: {
              statuses: [0, 200]
            }
          }
        }
      ]
    },
    client: {
      installPrompt: true,
      periodicSyncForUpdates: 20
    },
    devOptions: {
      enabled: true,
      suppressWarnings: true,
      navigateFallbackAllowlist: [/^\/$/],
      type: 'module'
    }
  },

  // ===== SEO OPTIMIZATION =====
  seo: {
    redirectToCanonicalSiteUrl: true
  },

  site: {
    url: process.env.NUXT_PUBLIC_SITE_URL || 'http://localhost:3000',
    name: 'Your App Name',
    description: 'Your app description',
    defaultLocale: 'en'
  },

  // ===== RUNTIME CONFIGURATION =====
  runtimeConfig: {
    // Private keys (only available on server-side)
    apiSecret: process.env.API_SECRET,
    
    // Public keys (exposed to client-side)
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || '/api',
      siteUrl: process.env.NUXT_PUBLIC_SITE_URL || 'http://localhost:3000',
      gtag: {
        id: process.env.NUXT_PUBLIC_GTAG_ID
      }
    }
  },

  // ===== APP CONFIGURATION =====
  app: {
    head: {
      charset: 'utf-8',
      viewport: 'width=device-width, initial-scale=1',
      title: 'Your App Name',
      titleTemplate: '%s - Your App Name',
      meta: [
        { name: 'description', content: 'Your app description' },
        { name: 'format-detection', content: 'telephone=no' },
        { name: 'theme-color', content: '#ffffff' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' }
      ],
      link: [
        { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' },
        { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
        { rel: 'manifest', href: '/manifest.json' }
      ],
      script: [
        // Add any global scripts here
      ]
    },
    // Page transitions
    pageTransition: { 
      name: 'page', 
      mode: 'out-in' 
    },
    layoutTransition: { 
      name: 'layout', 
      mode: 'out-in' 
    }
  },

  // ===== COMPONENT CONFIGURATION =====
  components: [
    {
      path: '~/components',
      pathPrefix: false,
    },
    {
      path: '~/components/ui',
      prefix: 'Ui'
    }
  ],

  // ===== IMPORTS CONFIGURATION =====
  imports: {
    dirs: [
      'composables/**',
      'stores/**',
      'utils/**',
      'types/**'
    ]
  },

  // ===== ROUTING =====
  router: {
    options: {
      strict: false,
      sensitive: false,
      hashMode: false,
      scrollBehaviorType: 'auto'
    }
  },

  // ===== NITRO SERVER CONFIGURATION =====
  nitro: {
    compatibilityDate: '2024-11-01',
    experimental: {
      wasm: true,
      openAPI: true
    },
    preset: 'node-server',
    
    // Compression
    compressPublicAssets: true,
    
    // Minification
    minify: true,
    
    // Route rules for caching
    routeRules: {
      // Homepage pre-rendered at build time
      '/': { prerender: true },
      
      // Admin dashboard rendered on-demand, revalidates in background, cached for 1 hour (3600s)
      '/admin/**': { ssr: false },
      
      // Blog posts generated on-demand, revalidates in background, cached until changed
      '/blog/**': { isr: true },
      
      // API routes
      '/api/**': { 
        cors: true,
        headers: { 
          'Access-Control-Allow-Methods': 'GET,HEAD,PUT,PATCH,POST,DELETE',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Credentials': 'true',
          'Access-Control-Allow-Headers': '*',
          'Access-Control-Expose-Headers': '*'
        }
      },
      
      // Static assets cached for 1 year
      '/assets/**': { 
        headers: { 
          'Cache-Control': 'max-age=31536000' 
        } 
      }
    },
    
    // Storage configuration
    storage: {
      redis: {
        driver: 'redis',
        // Redis configuration
      }
    },
    
    // Development
    devStorage: {
      db: {
        driver: 'fs',
        base: './data/db'
      }
    }
  },

  // ===== VITE CONFIGURATION =====
  vite: {
    logLevel: 'info',
    clearScreen: false,
    
    // Build optimizations
    build: {
      target: 'esnext',
      cssCodeSplit: true,
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ['vue', 'vue-router'],
            utils: ['lodash-es', 'date-fns']
          }
        }
      }
    },
    
    // Development optimizations
    optimizeDeps: {
      include: [
        'vue',
        'vue-router',
        '@vue/runtime-core',
        '@vue/shared'
      ]
    },
    
    // SSR configuration
    ssr: {
      noExternal: [
        // Add packages that need to be processed by Vite in SSR
      ]
    },
    
    // Define global constants
    define: {
      __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: 'false'
    }
  },

  // ===== BUILD CONFIGURATION =====
  build: {
    analyze: process.env.ANALYZE === 'true',
    transpile: [
      // Add packages that need transpilation
    ]
  },

  // ===== ESLINT CONFIGURATION =====
  eslint: {
    config: {
      standalone: false,
      stylistic: true
    }
  },

  // ===== HOOKS =====
  hooks: {
    'build:before': () => {
      console.log('🚀 Building optimized Nuxt 4 application...')
    },
    'build:done': () => {
      console.log('✅ Build completed successfully!')
    }
  },

  // ===== WATCHERS =====
  watch: [
    '~/server/**/*.ts'
  ],

  // ===== IGNORE PATTERNS =====
  ignore: [
    '**/*.test.*',
    '**/*.spec.*',
    '**/__tests__/**'
  ]
})
