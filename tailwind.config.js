const plugin = require('tailwindcss/plugin');

/**
 * Weight utility -> Inter Tight face. React Native resolves a font by family
 * name only, so `font-bold` has to swap the family rather than lean on
 * `font-weight`. Core Tailwind still emits the numeric weight alongside, which
 * matches the face and keeps the CSS honest.
 *
 * Mirrors the faces loaded in `src/theme/fonts.ts` — a utility listed here with
 * no matching face there renders as the system font.
 */
const FONT_FACES = {
  normal: 'InterTight_400Regular',
  medium: 'InterTight_500Medium',
  semibold: 'InterTight_600SemiBold',
  bold: 'InterTight_700Bold',
  extrabold: 'InterTight_800ExtraBold',
  black: 'InterTight_900Black',
};

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{ts,tsx}', './src/**/*.{ts,tsx}'],
  presets: [require('nativewind/preset')],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        /**
         * Static hex, deliberately NOT CSS variables.
         *
         * `rgb(var(--token) / <alpha-value>)` compiles to
         * `rgb(var(--x) / var(--tw-bg-opacity))`, which NativeWind cannot
         * statically evaluate — a `var()` holding a space-separated RGB triple
         * nested inside `rgb()` resolves to nothing on native, so every surface
         * and text colour silently renders transparent. Keep these literal.
         *
         * Re-introducing a dark theme means adding a `dark:` variant per token
         * (NativeWind handles that natively), not reviving the variable layer.
         */
        canvas: '#F4FAF1',
        surface: '#FFFFFF',
        elevated: '#FFFFFF',
        hairline: '#E0ECDA',
        ink: '#13281C',
        muted: '#5C6E63',
        faint: '#8D9E92',

        /**
         * Deep forest green — the brand. Carries the hero surface and active
         * navigation. Deliberately darker and less saturated than the `optimal`
         * status green, so "brand" and "this biomarker is healthy" never read
         * as the same signal.
         */
        brand: {
          50: '#EFF8F1',
          100: '#D9EEDF',
          200: '#B4DDC1',
          300: '#84C69C',
          400: '#4FA873',
          500: '#2E8455',
          600: '#226A44',
          700: '#1B5436',
          800: '#16412B',
          900: '#0F2E1E',
        },

        /** Lime accent — CTAs, active pills, gauge fill. Always paired with ink. */
        accent: {
          DEFAULT: '#BFF049',
          soft: '#E8FAC4',
          strong: '#A6D934',
        },

        // Semantic status ramp — used by biomarker flags and metric deltas.
        optimal: '#16A34A',
        normal: '#0EA5E9',
        borderline: '#F59E0B',
        abnormal: '#F97316',
        critical: '#E11D48',

        /**
         * Legacy aliases from the original purple mockup, repointed at the
         * green system so any call site not yet migrated still renders
         * coherently instead of reverting to purple.
         */
        'mockup-bg': '#F4FAF1',
        'mockup-bg-dark': '#FFFFFF',
        'mockup-card-bg': '#FFFFFF',
        'mockup-card-text': '#13281C',
        'mockup-accent': '#BFF049',
        'mockup-muted-icon': '#8D9E92',
      },
      fontFamily: {
        sans: [FONT_FACES.normal],
        mono: ['Menlo'],
      },
      fontSize: {
        // Numeric readouts need tighter tracking than body copy.
        metric: ['34px', { lineHeight: '36px', letterSpacing: '-1.2px' }],
        'metric-sm': ['22px', { lineHeight: '24px', letterSpacing: '-0.6px' }],
        'metric-lg': ['46px', { lineHeight: '48px', letterSpacing: '-1.8px' }],
      },
      borderRadius: {
        card: '24px',
        pill: '999px',
      },
      /**
       * Fine-grained tints below Tailwind's default 5% step.
       *
       * This scale also drives the `/N` colour-opacity modifier, so a value
       * missing here makes `bg-ink/8` compile to NOTHING — a silently
       * transparent surface rather than a build error. On a light theme the
       * 4–12% band is where most subtle fills live, so it has to exist.
       */
      opacity: {
        4: '0.04',
        6: '0.06',
        8: '0.08',
        12: '0.12',
        14: '0.14',
        18: '0.18',
      },
    },
  },
  plugins: [
    // Declared after the core plugins so these win the cascade on `font-family`
    // while core keeps ownership of the numeric `font-weight`.
    plugin(({ addUtilities }) => {
      addUtilities(
        Object.fromEntries(
          Object.entries(FONT_FACES).map(([weight, family]) => [
            `.font-${weight}`,
            { 'font-family': family },
          ]),
        ),
      );
    }),
  ],
};
