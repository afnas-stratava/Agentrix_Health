import type { CycleProfile } from '@/schemas/profile';
import type { IsoDay } from '@/schemas/health';
import type { FoodTag } from '@/schemas/nutrition';
import { daysBetween, fromIsoDay, toIsoDay } from '@/lib/date';

/**
 * Menstrual-cycle phase model.
 *
 * Phase is inferred from logged period start dates — HealthKit's menstrual-flow
 * category is not exposed by `react-native-health`, so iOS cannot supply this
 * even though it records it natively. Everything here is calendar arithmetic
 * over the user's own history; no cycle is predicted from telemetry, because
 * HRV-based ovulation detection is not reliable enough to put in front of
 * someone as fact.
 *
 * Boundaries follow the standard four-phase model with a fixed 14-day luteal
 * length (the luteal phase is the stable part of the cycle; variation lives
 * almost entirely in the follicular phase). For a 28-day cycle this reproduces
 * the textbook day numbers, and for a 34-day cycle it correctly places
 * ovulation at day 20 rather than day 14.
 */

export const CYCLE_PHASES = ['menstrual', 'follicular', 'ovulatory', 'luteal'] as const;
export type CyclePhaseName = (typeof CYCLE_PHASES)[number];

/** Days from ovulation to the next period. Physiologically near-constant. */
const LUTEAL_LENGTH_DAYS = 14;

export interface CyclePhase {
  name: CyclePhaseName;
  label: string;
  /** 1-indexed day of the current cycle. */
  dayOfCycle: number;
  /** Cycle length used for the maths, measured where possible. */
  cycleLengthDays: number;
  /** True when the length came from the user's logged history. */
  isMeasuredLength: boolean;
  /** Negative once the expected date has passed. */
  daysUntilNextPeriod: number;
  /**
   * Confidence in the phase call. Drops when only one period has been logged,
   * when the last log is stale, or when hormonal contraception makes the
   * underlying hormonal cycle absent regardless of bleeding pattern.
   */
  confidence: 'high' | 'moderate' | 'low';
  /** One line the brief can quote directly. */
  summary: string;
}

export const PHASE_LABEL: Record<CyclePhaseName, string> = {
  menstrual: 'Menstrual phase',
  follicular: 'Follicular phase',
  ovulatory: 'Ovulatory phase',
  luteal: 'Luteal phase',
};

/**
 * Median gap between consecutive logged periods. Median rather than mean
 * because one skipped log doubles a gap and would drag a mean badly.
 */
function measuredCycleLength(periodStarts: IsoDay[]): number | null {
  if (periodStarts.length < 2) return null;

  const sorted = [...periodStarts].sort();
  const gaps: number[] = [];
  for (let i = 1; i < sorted.length; i += 1) {
    const previous = sorted[i - 1];
    const current = sorted[i];
    if (previous == null || current == null) continue;
    const gap = daysBetween(fromIsoDay(previous), fromIsoDay(current));
    // Reject implausible gaps rather than letting a mis-log distort the model.
    if (gap >= 18 && gap <= 60) gaps.push(gap);
  }

  if (gaps.length === 0) return null;

  const sortedGaps = [...gaps].sort((a, b) => a - b);
  const mid = Math.floor(sortedGaps.length / 2);
  const median =
    sortedGaps.length % 2 === 0
      ? ((sortedGaps[mid - 1] ?? 0) + (sortedGaps[mid] ?? 0)) / 2
      : (sortedGaps[mid] ?? 0);

  return Math.round(median);
}

export function latestPeriodStart(cycle: CycleProfile): IsoDay | null {
  if (cycle.periodStarts.length === 0) return null;
  return [...cycle.periodStarts].sort().at(-1) ?? null;
}

export function computeCyclePhase(cycle: CycleProfile, now: Date = new Date()): CyclePhase | null {
  if (!cycle.tracks) return null;

  const lastStart = latestPeriodStart(cycle);
  if (lastStart == null) return null;

  const measured = measuredCycleLength(cycle.periodStarts);
  const cycleLengthDays = measured ?? cycle.averageCycleDays;

  const elapsed = daysBetween(fromIsoDay(lastStart), now);
  // A log from the future is a data-entry error, not a phase.
  if (elapsed < 0) return null;

  /**
   * Past one full cycle with no new log, the phase is genuinely unknown: the
   * user may be late, pregnant, or simply not logging. Rolling the day number
   * over with a modulo would invent a phase we cannot support, so the model
   * stops instead — but only after a generous grace window, so someone two
   * days late still sees a sensible late-luteal reading.
   */
  if (elapsed > cycleLengthDays + 10) return null;

  const dayOfCycle = elapsed + 1;
  const ovulationDay = cycleLengthDays - LUTEAL_LENGTH_DAYS;

  let name: CyclePhaseName;
  if (dayOfCycle <= cycle.averagePeriodDays) {
    name = 'menstrual';
  } else if (dayOfCycle < ovulationDay - 1) {
    name = 'follicular';
  } else if (dayOfCycle <= ovulationDay + 1) {
    name = 'ovulatory';
  } else {
    name = 'luteal';
  }

  let confidence: CyclePhase['confidence'] = measured != null ? 'high' : 'moderate';
  if (cycle.hormonalContraception) confidence = 'low';
  if (elapsed > cycleLengthDays) confidence = 'low';

  const daysUntilNextPeriod = cycleLengthDays - elapsed;

  return {
    name,
    label: PHASE_LABEL[name],
    dayOfCycle,
    cycleLengthDays,
    isMeasuredLength: measured != null,
    daysUntilNextPeriod,
    confidence,
    summary: phaseSummary(name, dayOfCycle, daysUntilNextPeriod),
  };
}

function phaseSummary(name: CyclePhaseName, dayOfCycle: number, daysUntil: number): string {
  switch (name) {
    case 'menstrual':
      return `Day ${dayOfCycle} — iron demand is at its highest point of the month.`;
    case 'follicular':
      return `Day ${dayOfCycle} — rising oestrogen, the best window for hard training.`;
    case 'ovulatory':
      return `Day ${dayOfCycle} — peak strength and power, and peak injury risk.`;
    case 'luteal':
      return daysUntil >= 0
        ? `Day ${dayOfCycle} — ${daysUntil} day${daysUntil === 1 ? '' : 's'} until your next period; resting heart rate normally runs higher here.`
        : `Day ${dayOfCycle} — your period is ${Math.abs(daysUntil)} day${Math.abs(daysUntil) === 1 ? '' : 's'} later than your average cycle.`;
  }
}

// ---------------------------------------------------------------------------
// Phase-aware guidance
// ---------------------------------------------------------------------------

export interface PhaseGuidance {
  /** Multiplier applied to the training-intensity recommendation. */
  trainingBias: 'push' | 'maintain' | 'ease';
  training: string;
  nutrition: string;
  /** Food tags to float up in dish and restaurant ranking during this phase. */
  favourTags: FoodTag[];
  /** Telemetry the user should expect to look worse, so it is not read as illness. */
  expectedTelemetryNote: string | null;
}

export const PHASE_GUIDANCE: Record<CyclePhaseName, PhaseGuidance> = {
  menstrual: {
    trainingBias: 'ease',
    training: 'Keep it easy — walking, mobility or a light session. Match effort to how you feel rather than to the plan.',
    nutrition:
      'Iron losses peak now. Pair an iron source with vitamin C at the same meal, and keep caffeine away from it by an hour or so — both change how much you actually absorb.',
    favourTags: ['iron-rich', 'vitamin-c-rich', 'high-protein'],
    expectedTelemetryNote:
      'A slightly lower HRV and higher resting heart rate during your period is normal and not a sign of overtraining.',
  },
  follicular: {
    trainingBias: 'push',
    training:
      'Rising oestrogen improves carbohydrate use and recovery. This is the window for your hardest sessions and any strength progression.',
    nutrition:
      'Carbohydrate tolerance is at its best — put your bigger, starchier meals around training here rather than later in the month.',
    favourTags: ['wholegrain', 'high-protein'],
    expectedTelemetryNote: null,
  },
  ovulatory: {
    trainingBias: 'push',
    training:
      'Peak strength and power. Worth a heavy session — with a proper warm-up, since ligament laxity is also at its highest.',
    nutrition: 'Keep protein high to make use of the recovery window, and hydrate deliberately.',
    favourTags: ['high-protein', 'leafy-green'],
    expectedTelemetryNote: null,
  },
  luteal: {
    trainingBias: 'maintain',
    training:
      'Hold volume, drop intensity a notch. Core temperature runs higher, so the same session will feel harder than it did two weeks ago.',
    nutrition:
      'Resting expenditure is genuinely higher — roughly 5% — so a slightly larger appetite is physiology, not a lapse. Magnesium and fibre help with the bloating and the cravings.',
    favourTags: ['high-fibre', 'calcium-rich', 'omega3-rich'],
    expectedTelemetryNote:
      'Resting heart rate typically sits a few beats higher and HRV a little lower across the luteal phase.',
  },
};

/** Convenience for the brief: the phase's day-count position as a fraction. */
export function cycleProgress(phase: CyclePhase): number {
  return Math.min(1, Math.max(0, phase.dayOfCycle / phase.cycleLengthDays));
}

/** Records a new period start, keeping the list sorted and de-duplicated. */
export function withPeriodStart(cycle: CycleProfile, day: IsoDay): CycleProfile {
  const next = new Set(cycle.periodStarts);
  next.add(day);
  return { ...cycle, periodStarts: [...next].sort() };
}

export function todayIsoDay(now: Date = new Date()): IsoDay {
  return toIsoDay(now);
}
