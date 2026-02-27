import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: 'class',
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    // iOS device-specific breakpoints
    screens: {
      // iPhone SE, iPhone 8
      'xs': '375px',
      // iPhone 12/13/14, iPhone 12/13/14 Pro
      'sm': '390px',
      // iPhone 12/13/14 Pro Max, iPhone 14 Plus
      'md': '428px',
      // iPad Mini
      'lg': '744px',
      // iPad Air, iPad Pro 11"
      'xl': '820px',
      // iPad Pro 12.9"
      '2xl': '1024px',
      // Desktop
      '3xl': '1280px',
    },
    extend: {
      colors: {
        // Liquid glass color palette - warm, light tones
        glass: {
          bg: 'rgba(255, 255, 255, 0.7)',
          border: 'rgba(255, 255, 255, 0.3)',
          rose: '#E8D5D5', // Dusty rose
          cream: '#F5F1E8', // Cream
          taupe: '#D9CFC1', // Taupe
          blush: '#F4E4E4', // Light blush
          sand: '#EDE5DC', // Sand
        },
        // Primary colors using CSS variables for dynamic theming
        primary: {
          50: 'var(--color-primary-50)',
          100: 'var(--color-primary-100)',
          200: 'var(--color-primary-200)',
          300: 'var(--color-primary-300)',
          400: 'var(--color-primary-400)',
          500: 'var(--color-primary-500)',
          600: 'var(--color-primary-600)',
          700: 'var(--color-primary-700)',
          800: 'var(--color-primary-800)',
          900: 'var(--color-primary-900)',
        },
      },
      fontFamily: {
        sans: ['"SF Pro Display"', 'Inter', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        glass: '16px',
        'glass-lg': '24px',
      },
      backdropBlur: {
        glass: '20px',
        'glass-strong': '40px',
      },
      boxShadow: {
        glass: '0 8px 32px 0 rgba(31, 38, 135, 0.07)',
        'glass-hover': '0 8px 32px 0 rgba(31, 38, 135, 0.12)',
      },
      animation: {
        'spring-in': 'spring-in 0.5s cubic-bezier(0.68, -0.55, 0.265, 1.55)',
        'fade-in': 'fade-in 0.3s ease-out',
        'slide-up': 'slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1)',
      },
      keyframes: {
        'spring-in': {
          '0%': { transform: 'scale(0.9)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        'slide-up': {
          '0%': { transform: 'translateY(20px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
      },
    },
  },
  plugins: [],
}
export default config
