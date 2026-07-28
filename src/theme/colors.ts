import type { BiomarkerFlag } from '@/schemas/labs';
import type { InsightSeverity } from '@/schemas/insights';

/**
 * Hex mirrors of the Tailwind palette.
 *
 * `lucide-react-native` renders SVG and takes a `color` prop rather than a
 * className, so icon colours have to exist as values. Keep this file in lockstep
 * with `tailwind.config.js` — it is the one place duplication is unavoidable.
 */
export const palette = {
  bg: '#5A59AA',
  bgDark: '#47468E',
  cardBg: '#F4F5FC',
  cardText: '#5A59AA',
  accent: '#FCE285',
  mutedIcon: '#8E8DC9',
  onBg: '#FFFFFF',
  onBgMuted: '#CFCEEA',

  optimal: '#10b981',
  normal: '#38bdf8',
  borderline: '#f59e0b',
  abnormal: '#f97316',
  critical: '#ef4444',
} as const;

export const FLAG_COLOR: Record<BiomarkerFlag, string> = {
  'critical-low': palette.critical,
  'critical-high': palette.critical,
  low: palette.abnormal,
  high: palette.abnormal,
  'borderline-low': palette.borderline,
  'borderline-high': palette.borderline,
  optimal: palette.optimal,
  normal: palette.normal,
  unknown: palette.mutedIcon,
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
