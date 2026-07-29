import type { BiomarkerFlag } from '@/schemas/labs';
import type { InsightSeverity } from '@/schemas/insights';

/**
 * Hex mirrors of the Tailwind palette.
 *
 * `lucide-react-native` and `react-native-svg` render SVG and take a `color`
 * prop rather than a className, so every colour has to exist as a value. Keep
 * this file in lockstep with `tailwind.config.js` and `global.css` — it is the
 * one place duplication is unavoidable.
 */
export const palette = {
  /** Near-white canvas with a green cast. */
  canvas: '#F4FAF1',
  surface: '#FFFFFF',
  hairline: '#E0ECDA',

  ink: '#13281C',
  muted: '#5C6E63',
  faint: '#8D9E92',

  /** Deep forest brand green — the hero surface and active navigation. */
  brand: '#226A44',
  brandDeep: '#0F2E1E',
  brandLight: '#4FA873',

  /** Lime accent. Always paired with `ink`, never with white text. */
  accent: '#BFF049',
  accentSoft: '#E8FAC4',
  accentStrong: '#A6D934',

  /** Text and icons that sit on the deep-green hero surface. */
  onBrand: '#FFFFFF',
  onBrandMuted: 'rgba(255,255,255,0.72)',
  onBrandFaint: 'rgba(255,255,255,0.45)',

  optimal: '#16A34A',
  normal: '#0EA5E9',
  borderline: '#F59E0B',
  abnormal: '#F97316',
  critical: '#E11D48',

  // ---------------------------------------------------------------------
  // Aliases retained from the original purple mockup, repointed at the
  // green system. Kept as keys on `palette` (rather than a separate object)
  // so existing call sites re-theme automatically instead of failing to
  // compile — `palette.cardText` is referenced in ~20 files.
  // ---------------------------------------------------------------------
  /** @deprecated use `canvas` */
  bg: '#F4FAF1',
  /** @deprecated use `surface` */
  bgDark: '#FFFFFF',
  /** @deprecated use `surface` */
  cardBg: '#FFFFFF',
  /** @deprecated use `ink` */
  cardText: '#13281C',
  /** @deprecated use `faint` */
  mutedIcon: '#8D9E92',
  /** @deprecated use `ink` — canvas is light now, so this is ink, not white */
  onBg: '#13281C',
  /** @deprecated use `muted` */
  onBgMuted: '#5C6E63',
} as const;

/** Gradient stops for the deep-green hero card, light to dark. */
export const HERO_GRADIENT = ['#2E8455', '#1B5436'] as const;

export const FLAG_COLOR: Record<BiomarkerFlag, string> = {
  'critical-low': palette.critical,
  'critical-high': palette.critical,
  low: palette.abnormal,
  high: palette.abnormal,
  'borderline-low': palette.borderline,
  'borderline-high': palette.borderline,
  optimal: palette.optimal,
  normal: palette.normal,
  unknown: palette.faint,
};

export const FLAG_LABEL: Record<BiomarkerFlag, string> = {
  'critical-low': 'Critically low',
  'critical-high': 'Critically high',
  low: 'Low',
  high: 'High',
  'borderline-low': 'Below optimal',
  'borderline-high': 'Above optimal',
  optimal: 'Optimal',
  normal: 'In range',
  unknown: 'Unclassified',
};

export const SEVERITY_COLOR: Record<InsightSeverity, string> = {
  urgent: palette.critical,
  action: palette.abnormal,
  watch: palette.borderline,
  info: palette.normal,
};

export const SEVERITY_LABEL: Record<InsightSeverity, string> = {
  urgent: 'See a clinician',
  action: 'Act on this',
  watch: 'Keep an eye on',
  info: 'For context',
};
