/** @type {import('tailwindcss').Config} */
module.exports = {
  // ===== CONTENT PATHS =====
  content: [
    "./components/**/*.{js,vue,ts}",
    "./layouts/**/*.vue",
    "./pages/**/*.vue",
    "./plugins/**/*.{js,ts}",
    "./composables/**/*.{js,ts}",
    "./utils/**/*.{js,ts}",
    "./app.vue",
    "./error.vue"
  ],

  // ===== DARK MODE =====
  darkMode: 'class', // or 'media' for system preference

  // ===== THEME CUSTOMIZATION =====
  theme: {
    extend: {
      // Custom Colors
      colors: {
        primary: {
          50: '#f0f9ff',
          100: '#e0f2fe',
          200: '#bae6fd',
          300: '#7dd3fc',
          400: '#38bdf8',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
          800: '#075985',
          900: '#0c4a6e',
          950: '#082f49'
        },
        secondary: {
          50: '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          300: '#cbd5e1',
          400: '#94a3b8',
          500: '#64748b',
          600: '#475569',
          700: '#334155',
          800: '#1e293b',
          900: '#0f172a',
          950: '#020617'
        },
        accent: {
          50: '#fef7ee',
          100: '#fdedd7',
          200: '#fbd7ae',
          300: '#f8bb7a',
          400: '#f59544',
          500: '#f37621',
          600: '#e45d17',
          700: '#bd4515',
          800: '#973818',
          900: '#7a3016',
          950: '#42160a'
        },
        success: {
          50: '#f0fdf4',
          100: '#dcfce7',
          200: '#bbf7d0',
          300: '#86efac',
          400: '#4ade80',
          500: '#22c55e',
          600: '#16a34a',
          700: '#15803d',
          800: '#166534',
          900: '#14532d',
          950: '#052e16'
        },
        warning: {
          50: '#fffbeb',
          100: '#fef3c7',
          200: '#fde68a',
          300: '#fcd34d',
          400: '#fbbf24',
          500: '#f59e0b',
          600: '#d97706',
          700: '#b45309',
          800: '#92400e',
          900: '#78350f',
          950: '#451a03'
        },
        error: {
          50: '#fef2f2',
          100: '#fee2e2',
          200: '#fecaca',
          300: '#fca5a5',
          400: '#f87171',
          500: '#ef4444',
          600: '#dc2626',
          700: '#b91c1c',
          800: '#991b1b',
          900: '#7f1d1d',
          950: '#450a0a'
        }
      },

      // Custom Fonts
      fontFamily: {
        sans: [
          'Inter',
          '-apple-system',
          'BlinkMacSystemFont',
          '"Segoe UI"',
          'Roboto',
          '"Helvetica Neue"',
          'Arial',
          'sans-serif'
        ],
        serif: [
          'Georgia',
          'Cambria',
          '"Times New Roman"',
          'Times',
          'serif'
        ],
        mono: [
          '"JetBrains Mono"',
          'Menlo',
          'Monaco',
          'Consolas',
          '"Liberation Mono"',
          '"Courier New"',
          'monospace'
        ]
      },

      // Custom Spacing
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
        '128': '32rem'
      },

      // Custom Border Radius
      borderRadius: {
        '4xl': '2rem',
        '5xl': '2.5rem'
      },

      // Custom Shadows
      boxShadow: {
        'soft': '0 2px 15px -3px rgba(0, 0, 0, 0.07), 0 10px 20px -2px rgba(0, 0, 0, 0.04)',
        'medium': '0 4px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
        'hard': '0 10px 40px -10px rgba(0, 0, 0, 0.15), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
        'glow': '0 0 20px rgba(59, 130, 246, 0.5)',
        'glow-lg': '0 0 40px rgba(59, 130, 246, 0.6)'
      },

      // Custom Animations
      animation: {
        'fade-in': 'fadeIn 0.5s ease-in-out',
        'fade-out': 'fadeOut 0.5s ease-in-out',
        'slide-in': 'slideIn 0.3s ease-out',
        'slide-out': 'slideOut 0.3s ease-out',
        'bounce-soft': 'bounceSoft 1s infinite',
        'pulse-soft': 'pulseSoft 2s infinite',
        'spin-slow': 'spin 3s linear infinite',
        'wiggle': 'wiggle 1s ease-in-out infinite'
      },

      // Custom Keyframes
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' }
        },
        fadeOut: {
          '0%': { opacity: '1' },
          '100%': { opacity: '0' }
        },
        slideIn: {
          '0%': { transform: 'translateX(-100%)' },
          '100%': { transform: 'translateX(0)' }
        },
        slideOut: {
          '0%': { transform: 'translateX(0)' },
          '100%': { transform: 'translateX(100%)' }
        },
        bounceSoft: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-5px)' }
        },
        pulseSoft: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.7' }
        },
        wiggle: {
          '0%, 100%': { transform: 'rotate(-3deg)' },
          '50%': { transform: 'rotate(3deg)' }
        }
      },

      // Custom Gradients
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'gradient-conic': 'conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))',
        'gradient-primary': 'linear-gradient(135deg, var(--tw-gradient-stops))',
        'mesh-gradient': 'radial-gradient(at 40% 20%, hsla(28,100%,74%,1) 0px, transparent 50%), radial-gradient(at 80% 0%, hsla(189,100%,56%,1) 0px, transparent 50%), radial-gradient(at 0% 50%, hsla(355,100%,93%,1) 0px, transparent 50%), radial-gradient(at 80% 50%, hsla(340,100%,76%,1) 0px, transparent 50%), radial-gradient(at 0% 100%, hsla(22,100%,77%,1) 0px, transparent 50%), radial-gradient(at 80% 100%, hsla(242,100%,70%,1) 0px, transparent 50%), radial-gradient(at 0% 0%, hsla(343,100%,76%,1) 0px, transparent 50%)'
      },

      // Custom Typography
      fontSize: {
        '2xs': ['0.625rem', { lineHeight: '0.75rem' }],
        '3xl': ['1.875rem', { lineHeight: '2.25rem' }],
        '4xl': ['2.25rem', { lineHeight: '2.5rem' }],
        '5xl': ['3rem', { lineHeight: '1' }],
        '6xl': ['3.75rem', { lineHeight: '1' }],
        '7xl': ['4.5rem', { lineHeight: '1' }],
        '8xl': ['6rem', { lineHeight: '1' }],
        '9xl': ['8rem', { lineHeight: '1' }]
      },

      // Custom Line Heights
      lineHeight: {
        '12': '3rem',
        '16': '4rem'
      },

      // Custom Z-Index
      zIndex: {
        '60': '60',
        '70': '70',
        '80': '80',
        '90': '90',
        '100': '100'
      },

      // Custom Screens (Breakpoints)
      screens: {
        'xs': '475px',
        '3xl': '1600px'
      }
    }
  },

  // ===== PLUGINS =====
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/container-queries'),
    
    // Custom Plugin for Utilities
    function({ addUtilities, addComponents, theme }) {
      // Custom Utilities
      const newUtilities = {
        '.text-shadow': {
          textShadow: '2px 2px 4px rgba(0, 0, 0, 0.1)'
        },
        '.text-shadow-md': {
          textShadow: '4px 4px 8px rgba(0, 0, 0, 0.12), 2px 2px 4px rgba(0, 0, 0, 0.08)'
        },
        '.text-shadow-lg': {
          textShadow: '15px 15px 30px rgba(0, 0, 0, 0.11), 5px 5px 15px rgba(0, 0, 0, 0.08)'
        },
        '.text-shadow-none': {
          textShadow: 'none'
        }
      }

      // Custom Components
      const newComponents = {
        '.btn': {
          padding: `${theme('spacing.2')} ${theme('spacing.4')}`,
          borderRadius: theme('borderRadius.md'),
          fontWeight: theme('fontWeight.medium'),
          fontSize: theme('fontSize.sm'),
          lineHeight: theme('lineHeight.5'),
          cursor: 'pointer',
          transition: 'all 0.2s ease-in-out',
          '&:focus': {
            outline: 'none',
            boxShadow: `0 0 0 3px ${theme('colors.primary.500')}40`
          }
        },
        '.btn-primary': {
          backgroundColor: theme('colors.primary.500'),
          color: theme('colors.white'),
          '&:hover': {
            backgroundColor: theme('colors.primary.600')
          },
          '&:active': {
            backgroundColor: theme('colors.primary.700')
          }
        },
        '.btn-secondary': {
          backgroundColor: theme('colors.secondary.500'),
          color: theme('colors.white'),
          '&:hover': {
            backgroundColor: theme('colors.secondary.600')
          },
          '&:active': {
            backgroundColor: theme('colors.secondary.700')
          }
        },
        '.card': {
          backgroundColor: theme('colors.white'),
          borderRadius: theme('borderRadius.lg'),
          boxShadow: theme('boxShadow.soft'),
          padding: theme('spacing.6')
        },
        '.card-hover': {
          transition: 'all 0.3s ease-in-out',
          '&:hover': {
            transform: 'translateY(-2px)',
            boxShadow: theme('boxShadow.medium')
          }
        }
      }

      addUtilities(newUtilities)
      addComponents(newComponents)
    }
  ],

  // ===== COREPLUGINS OPTIMIZATION =====
  corePlugins: {
    // Disable unused features for smaller bundle size
    // Uncomment any you don't need:
    // preflight: false,
    // container: false,
    // accessibility: false,
    // pointerEvents: false,
    // visibility: false,
    // position: false,
    // inset: false,
    // isolation: false,
    // zIndex: false,
    // order: false,
    // gridColumn: false,
    // gridColumnStart: false,
    // gridColumnEnd: false,
    // gridRow: false,
    // gridRowStart: false,
    // gridRowEnd: false,
    // float: false,
    // clear: false,
    // margin: false,
    // boxSizing: false,
    // display: false,
    // aspectRatio: false,
    // height: false,
    // maxHeight: false,
    // minHeight: false,
    // width: false,
    // minWidth: false,
    // maxWidth: false,
    // flex: false,
    // flexShrink: false,
    // flexGrow: false,
    // flexBasis: false,
    // tableLayout: false,
    // borderCollapse: false,
    // borderSpacing: false,
    // transformOrigin: false,
    // translate: false,
    // rotate: false,
    // skew: false,
    // scale: false,
    // transform: false,
    // animation: false,
    // cursor: false,
    // touchAction: false,
    // userSelect: false,
    // resize: false,
    // scrollSnapType: false,
    // scrollSnapAlign: false,
    // scrollSnapStop: false,
    // scrollMargin: false,
    // scrollPadding: false,
    // listStylePosition: false,
    // listStyleType: false,
    // appearance: false,
    // columns: false,
    // breakBefore: false,
    // breakInside: false,
    // breakAfter: false,
    // gridAutoColumns: false,
    // gridAutoFlow: false,
    // gridAutoRows: false,
    // gridTemplateColumns: false,
    // gridTemplateRows: false,
    // flexDirection: false,
    // flexWrap: false,
    // placeContent: false,
    // placeItems: false,
    // alignContent: false,
    // alignItems: false,
    // justifyContent: false,
    // justifyItems: false,
    // gap: false,
    // space: false,
    // divideWidth: false,
    // divideStyle: false,
    // divideColor: false,
    // divideOpacity: false,
    // placeSelf: false,
    // alignSelf: false,
    // justifySelf: false,
    // overflow: false,
    // overscrollBehavior: false,
    // scrollBehavior: false,
    // textOverflow: false,
    // whitespace: false,
    // wordBreak: false,
    // borderRadius: false,
    // borderWidth: false,
    // borderStyle: false,
    // borderColor: false,
    // borderOpacity: false,
    // backgroundColor: false,
    // backgroundOpacity: false,
    // backgroundImage: false,
    // gradientColorStops: false,
    // backgroundSize: false,
    // backgroundAttachment: false,
    // backgroundClip: false,
    // backgroundPosition: false,
    // backgroundRepeat: false,
    // backgroundOrigin: false,
    // fill: false,
    // stroke: false,
    // strokeWidth: false,
    // objectFit: false,
    // objectPosition: false,
    // padding: false,
    // textAlign: false,
    // textColor: false,
    // textOpacity: false,
    // textDecoration: false,
    // textDecorationColor: false,
    // textDecorationStyle: false,
    // textDecorationThickness: false,
    // textUnderlineOffset: false,
    // textTransform: false,
    // textIndent: false,
    // verticalAlign: false,
    // fontFamily: false,
    // fontSize: false,
    // fontWeight: false,
    // textRendering: false,
    // lineHeight: false,
    // letterSpacing: false,
    // textColor: false,
    // textOpacity: false,
    // placeholderColor: false,
    // placeholderOpacity: false,
    // caretColor: false,
    // accentColor: false,
    // opacity: false,
    // boxShadow: false,
    // boxShadowColor: false,
    // outlineWidth: false,
    // outlineStyle: false,
    // outlineColor: false,
    // outlineOffset: false,
    // ringWidth: false,
    // ringColor: false,
    // ringOpacity: false,
    // ringOffsetWidth: false,
    // ringOffsetColor: false,
    // blur: false,
    // brightness: false,
    // contrast: false,
    // dropShadow: false,
    // grayscale: false,
    // hueRotate: false,
    // invert: false,
    // saturate: false,
    // sepia: false,
    // filter: false,
    // backdropBlur: false,
    // backdropBrightness: false,
    // backdropContrast: false,
    // backdropGrayscale: false,
    // backdropHueRotate: false,
    // backdropInvert: false,
    // backdropOpacity: false,
    // backdropSaturate: false,
    // backdropSepia: false,
    // backdropFilter: false,
    // transitionProperty: false,
    // transitionDelay: false,
    // transitionDuration: false,
    // transitionTimingFunction: false,
    // willChange: false,
    // content: false
  }
}
