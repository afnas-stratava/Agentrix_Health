/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{ts,tsx}', './src/**/*.{ts,tsx}'],
  presets: [require('nativewind/preset')],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Surfaces are driven by CSS variables so the palette flips with the
        // `dark` class applied at the root layout.
        canvas: 'rgb(var(--color-canvas) / <alpha-value>)',
        surface: 'rgb(var(--color-surface) / <alpha-value>)',
        elevated: 'rgb(var(--color-elevated) / <alpha-value>)',
        hairline: 'rgb(var(--color-hairline) / <alpha-value>)',
        ink: 'rgb(var(--color-ink) / <alpha-value>)',
        muted: 'rgb(var(--color-muted) / <alpha-value>)',
        faint: 'rgb(var(--color-faint) / <alpha-value>)',

        // Mockup theme colors matching the design system
        'mockup-bg': '#5A59AA',
        'mockup-bg-dark': '#47468E',
        'mockup-card-text': '#5A59AA',
        'mockup-card-bg': '#F4F5FC',
        'mockup-accent': '#FCE285',
        'mockup-muted-icon': '#8E8DC9',

        // Semantic status ramp — used by biomarker flags and metric deltas.
        optimal: '#10b981',
        normal: '#38bdf8',
        borderline: '#f59e0b',
        abnormal: '#f97316',
        critical: '#ef4444',

        brand: {
          50: '#eef7ff',
          100: '#d9edff',
          200: '#bce0ff',
          300: '#8ecdff',
          400: '#59b0ff',
          500: '#338dff',
          600: '#1c6df5',
          700: '#1557e1',
          800: '#1848b6',
          900: '#19408f',
        },
      },
      fontFamily: {
        sans: ['System'],
        mono: ['Menlo'],
      },
      fontSize: {
        // Numeric readouts need tighter tracking than body copy.
        metric: ['34px', { lineHeight: '36px', letterSpacing: '-1.2px' }],
        'metric-sm': ['22px', { lineHeight: '24px', letterSpacing: '-0.6px' }],
      },
      borderRadius: {
        card: '20px',
        pill: '999px',
      },
    },
  },
  plugins: [],
};
