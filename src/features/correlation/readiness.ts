import type { MetricKey } from '@/schemas/health';
import { METRIC_POLARITY } from '@/schemas/health';
import type { Readiness } from '@/schemas/insights';
import type { EngineContext } from './context';
import { MIN_BASELINE_DAYS } from './context';

/**
 * Composite readiness, expressed against the user's *own* baseline rather than
 * a population norm — a 42 ms HRV is excellent for one person and a red flag
 * for another.
 *
 * Weights reflect how much each signal independently predicts next-day
 * capacity. HRV dominates, resting heart rate confirms it, sleep supplies the
 * mechanism, and load is a modest negative when it outruns recovery.
 */
const WEIGHTS: Partial<Record<MetricKey, number>> = {
  hrv: 0.4,
  restingHeartRate: 0.25,
  sleepDuration: 0.2,
  sleepEfficiency: 0.15,
};

/** z-scores beyond this are almost always artefacts (missed strap, illness). */
const Z_CLAMP = 2.5;

/**
 * Bands are symmetric about 50, because 50 *is* "exactly at your own
 * baseline". An asymmetric ramp would tell a perfectly average day it was a
 * bad one, which erodes trust in the number faster than any inaccuracy.
 */
function band(score: number): Readiness['band'] {
  if (score < 30) return 'compromised';
  if (score < 45) return 'low';
  if (score < 65) return 'moderate';
  return 'primed';
}

export function computeReadiness(context: EngineContext): Readiness | null {
  const drivers: Readiness['drivers'] = [];
  let weighted = 0;
  let weightUsed = 0;
  let baselineDays = 0;

  for (const [key, weight] of Object.entries(WEIGHTS) as Array<[MetricKey, number]>) {
    const stats = context.metrics[key];
    if (stats.baselineDays < MIN_BASELINE_DAYS || stats.latest == null) continue;

    baselineDays = Math.max(baselineDays, stats.baselineDays);

    const clamped = Math.max(-Z_CLAMP, Math.min(Z_CLAMP, stats.z));
    // Flip the sign for metrics where lower is better, so a positive
    // contribution always means "this is helping you today".
    const oriented = METRIC_POLARITY[key] === 'lower-is-better' ? -clamped : clamped;

    weighted += oriented * weight;
    weightUsed += weight;

    drivers.push({
      metric: key,
      contribution: Math.round(((oriented * weight) / Z_CLAMP) * 50 * 10) / 10,
      z: Math.round(clamped * 100) / 100,
    });
  }

  // With no usable baseline, showing a number would be inventing one.
  if (weightUsed === 0 || baselineDays < MIN_BASELINE_DAYS) return null;

  // Normalise to the weight actually available, then map z ∈ [−2.5, 2.5] onto
  // 0–100 centred at 50 (= exactly at your own baseline).
  const normalisedZ = weighted / weightUsed;
  const score = Math.round(Math.min(100, Math.max(0, 50 + (normalisedZ / Z_CLAMP) * 50)));

  drivers.sort((a, b) => Math.abs(b.contribution) - Math.abs(a.contribution));

  return {
    score,
    band: band(score),
    drivers,
    baselineDays,
    computedAt: context.now,
  };
}

export const READINESS_COPY: Record<Readiness['band'], { label: string; blurb: string }> = {
  compromised: {
    label: 'Compromised',
    blurb: 'Your autonomic markers are well below baseline. Treat today as recovery.',
  },
  low: {
    label: 'Low',
    blurb: 'Below your normal. Keep intensity conversational and protect sleep tonight.',
  },
  moderate: {
    label: 'Moderate',
    blurb: 'Around your baseline. A normal training day is well within range.',
  },
  primed: {
    label: 'Primed',
    blurb: 'Recovery markers are above baseline — a good day for hard work.',
  },
};
