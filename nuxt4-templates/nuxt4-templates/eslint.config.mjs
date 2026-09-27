// ESLint configuration for Nuxt 4 
import { createConfigForNuxt } from '@nuxt/eslint-config/flat' 
 
export default createConfigForNuxt({ 
  features: { 
    tooling: true, 
    stylistic: { 
      indent: 2, 
      quotes: 'single' 
    } 
  } 
}) 
