import { z } from 'zod';

/**
 * Canonical telemetry vocabulary. These keys are the join-key between the
 * HealthKit adapter, the correlation engine and the UI, so they are declared
 * once here and never re-typed as bare strings elsewhere.
 */
export const MetricKeySchema = z.enum([
  'hrv',
  'restingHeartRate',
  'sleepDuration',
  'sleepEfficiency',
  'activeEnergy',
  'steps',
]);
export type MetricKey = z.infer<typeof MetricKeySchema>;

export const METRIC_KEYS = MetricKeySchema.options;

/** ISO-8601 calendar day in the device's local timezone: `2026-07-28`. */
export const IsoDaySchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected an ISO calendar day (YYYY-MM-DD)');
export type IsoDay = z.infer<typeof IsoDaySchema>;

export const SleepStagesSchema = z.object({
  /** Minutes in `HKCategoryValueSleepAnalysisAsleepDeep`. */
  deepMinutes: z.number().min(0).max(1440),
  /** Minutes in `...AsleepREM`. */
  remMinutes: z.number().min(0).max(1440),
  /** Minutes in `...AsleepCore` (light). */
  coreMinutes: z.number().min(0).max(1440),
  /** Minutes in bed but classified awake. */
  awakeMinutes: z.number().min(0).max(1440),
  /** Minutes with only `...AsleepUnspecified` — non-Apple-Watch sources. */
  unspecifiedMinutes: z.number().min(0).max(1440),
});
export type SleepStages = z.infer<typeof SleepStagesSchema>;

export const SleepSummarySchema = SleepStagesSchema.extend({
  /** Total asleep minutes (deep + rem + core + unspecified). */
  asleepMinutes: z.number().min(0).max(1440),
  /** Asleep + awake-in-bed. */
  inBedMinutes: z.number().min(0).max(1440),
  /** asleepMinutes / inBedMinutes, 0–1. Null when inBed is unknown. */
  efficiency: z.number().min(0).max(1).nullable(),
  /** Local ISO datetime of sleep onset, used for circadian-drift detection. */
  bedtime: z.string().datetime({ offset: true }).nullable(),
  wakeTime: z.string().datetime({ offset: true }).nullable(),
});
export type SleepSummary = z.infer<typeof SleepSummarySchema>;

/**
 * One calendar day of aggregated telemetry. Every numeric field is nullable
 * because HealthKit legitimately returns nothing for a day the user did not
 * wear the watch — `0` and `null` mean very different things to the
 * correlation engine and must never be conflated.
 */
export const DailySnapshotSchema = z.object({
  day: IsoDaySchema,
  /** SDNN in milliseconds, from `HKQuantityTypeIdentifierHeartRateVariabilitySDNN`. */
  hrv: z.number().positive().max(500).nullable(),
  /** Beats per minute. */
  restingHeartRate: z.number().positive().max(220).nullable(),
  sleep: SleepSummarySchema.nullable(),
  /** Kilocalories from `HKQuantityTypeIdentifierActiveEnergyBurned`. */
  activeEnergy: z.number().min(0).max(20000).nullable(),
  steps: z.number().min(0).max(200000).nullable(),
  /** True when at least one sample in the day came from an Apple Watch. */
  hasWearableSource: z.boolean().default(false),
});
export type DailySnapshot = z.infer<typeof DailySnapshotSchema>;

export const HealthSeriesSchema = z.object({
  from: IsoDaySchema,
  to: IsoDaySchema,
  days: z.array(DailySnapshotSchema),
  syncedAt: z.string().datetime({ offset: true }),
});
export type HealthSeries = z.infer<typeof HealthSeriesSchema>;

/** Direction in which a metric moving *up* is clinically desirable. */
export const METRIC_POLARITY: Record<MetricKey, 'higher-is-better' | 'lower-is-better'> = {
  hrv: 'higher-is-better',
  restingHeartRate: 'lower-is-better',
  sleepDuration: 'higher-is-better',
  sleepEfficiency: 'higher-is-better',
  activeEnergy: 'higher-is-better',
  steps: 'higher-is-better',
};

export const METRIC_META: Record<
  MetricKey,
  { label: string; short: string; unit: string; precision: number }
> = {
  hrv: { label: 'Heart Rate Variability', short: 'HRV', unit: 'ms', precision: 0 },
  restingHeartRate: {
    label: 'Resting Heart Rate',
    short: 'RHR',
    unit: 'bpm',
    precision: 0,
  },
  sleepDuration: { label: 'Sleep Duration', short: 'Sleep', unit: 'h', precision: 1 },
  sleepEfficiency: { label: 'Sleep Efficiency', short: 'Efficiency', unit: '%', precision: 0 },
  activeEnergy: { label: 'Active Energy', short: 'Energy', unit: 'kcal', precision: 0 },
  steps: { label: 'Steps', short: 'Steps', unit: '', precision: 0 },
};

export const HealthPermissionStateSchema = z.enum([
  'undetermined',
  'granted',
  'denied',
  'unavailable',
]);
export type HealthPermissionState = z.infer<typeof HealthPermissionStateSchema>;

/**
 * Projects a snapshot onto a single scalar for the given metric key.
 * Centralised so the engine, charts and cards can never disagree about what
 * "sleep duration" means.
 */
export function readMetric(snapshot: DailySnapshot, key: MetricKey): number | null {
  switch (key) {
    case 'hrv':
      return snapshot.hrv;
    case 'restingHeartRate':
      return snapshot.restingHeartRate;
    case 'sleepDuration':
      return snapshot.sleep ? snapshot.sleep.asleepMinutes / 60 : null;
    case 'sleepEfficiency':
      return snapshot.sleep?.efficiency != null ? snapshot.sleep.efficiency * 100 : null;
    case 'activeEnergy':
      return snapshot.activeEnergy;
    case 'steps':
      return snapshot.steps;
  }
}
