import type { DailySnapshot, IsoDay, MetricKey } from '@/schemas/health';
import { METRIC_KEYS, readMetric } from '@/schemas/health';
import type { Correlation } from '@/schemas/insights';
import type { Biomarker, BiomarkerCode } from '@/schemas/labs';
import type { BiologicalSex } from '@/features/labs/reference-ranges';
import {
  classifyStrength,
  compact,
  correlationPValue,
  linearSlope,
  mean,
  pairSeries,
  pearson,
  percentChange,
  zScore,
} from './stats';

/** Trailing window treated as "now". */
export const RECENT_WINDOW_DAYS = 7;
/** Window immediately preceding `recent`, used as the personal baseline. */
export const BASELINE_WINDOW_DAYS = 28;
/** Below this, a baseline is too thin to make claims from. */
export const MIN_BASELINE_DAYS = 7;

export interface MetricStats {
  key: MetricKey;
  /** Day-aligned series, null where telemetry is missing. */
  values: Array<number | null>;
  latest: number | null;
  recentMean: number | null;
  baselineMean: number | null;
  /** Latest value expressed in baseline standard deviations. */
  z: number;
  /** Recent mean vs. baseline mean, as a percentage. */
  deltaPct: number | null;
  /** OLS slope across the recent window, in units per day. */
  slopePerDay: number;
  /** Fraction of days in the window that carry a value, 0–1. */
  coverage: number;
  baselineDays: number;
}

export interface EngineContext {
  days: IsoDay[];
  series: DailySnapshot[];
  metrics: Record<MetricKey, MetricStats>;
  biomarkers: Map<BiomarkerCode, Biomarker>;
  labReportId: string | null;
  labCollectedAt: string | null;
  sex: BiologicalSex;
  now: string;
  /** Correlates two metrics with an optional lag; null when under-powered. */
  correlate(a: MetricKey, b: MetricKey, lagDays?: number): Correlation | null;
}

function buildMetricStats(series: DailySnapshot[], key: MetricKey): MetricStats {
  const values = series.map((snapshot) => readMetric(snapshot, key));

  const recentSlice = values.slice(-RECENT_WINDOW_DAYS);
  const baselineSlice = values.slice(
    Math.max(0, values.length - RECENT_WINDOW_DAYS - BASELINE_WINDOW_DAYS),
    Math.max(0, values.length - RECENT_WINDOW_DAYS),
  );

  const recent = compact(recentSlice);
  const baseline = compact(baselineSlice);
  const present = compact(values);

  const latest = [...values].reverse().find((v) => v != null) ?? null;
  const recentMean = recent.length > 0 ? mean(recent) : null;
  const baselineMean = baseline.length >= MIN_BASELINE_DAYS ? mean(baseline) : null;

  return {
    key,
    values,
    latest,
    recentMean,
    baselineMean,
    z: latest != null && baseline.length >= MIN_BASELINE_DAYS ? zScore(latest, baseline) : 0,
    deltaPct:
      recentMean != null && baselineMean != null ? percentChange(baselineMean, recentMean) : null,
    slopePerDay: linearSlope(recent),
    coverage: values.length === 0 ? 0 : present.length / values.length,
    baselineDays: baseline.length,
  };
}

export interface BuildContextInput {
  series: DailySnapshot[];
  biomarkers: Biomarker[];
  labReportId: string | null;
  labCollectedAt: string | null;
  sex: BiologicalSex;
  now?: string;
}

export function buildEngineContext({
  series,
  biomarkers,
  labReportId,
  labCollectedAt,
  sex,
  now = new Date().toISOString(),
}: BuildContextInput): EngineContext {
  const metrics = Object.fromEntries(
    METRIC_KEYS.map((key) => [key, buildMetricStats(series, key)]),
  ) as Record<MetricKey, MetricStats>;

  const byCode = new Map<BiomarkerCode, Biomarker>();
  for (const biomarker of biomarkers) {
    if (biomarker.code == null) continue;
    // Later reports win; callers pass biomarkers in chronological order.
    byCode.set(biomarker.code, biomarker);
  }

  const correlationCache = new Map<string, Correlation | null>();

  return {
    days: series.map((s) => s.day),
    series,
    metrics,
    biomarkers: byCode,
    labReportId,
    labCollectedAt,
    sex,
    now,
    correlate(a, b, lagDays = 0) {
      const cacheKey = `${a}|${b}|${lagDays}`;
      const cached = correlationCache.get(cacheKey);
      if (cached !== undefined) return cached;

      const { x, y } = pairSeries(metrics[a].values, metrics[b].values, lagDays);
      const n = x.length;
      const r = pearson(x, y);

      if (!Number.isFinite(r) || n < 10) {
        correlationCache.set(cacheKey, null);
        return null;
      }

      const p = correlationPValue(r, n);
      const strength = classifyStrength(r, p, n);

      const result: Correlation = {
        metric: a,
        r: Math.round(r * 1000) / 1000,
        p: Math.round(p * 10000) / 10000,
        n,
        lagDays,
        strength,
        direction: strength === 'none' ? 'none' : r > 0 ? 'positive' : 'negative',
      };

      correlationCache.set(cacheKey, result);
      return result;
    },
  };
}

/** True when the window has enough signal for the engine to say anything. */
export function hasSufficientTelemetry(context: EngineContext): boolean {
  return METRIC_KEYS.some((key) => context.metrics[key].baselineDays >= MIN_BASELINE_DAYS);
}
