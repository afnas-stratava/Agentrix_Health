import type { DailySnapshot, IsoDay, SleepSummary } from '@/schemas/health';
import { enumerateDays, toIsoDay } from '@/lib/date';
import type { QuantitySample, RawTelemetry, SleepSample, SleepStageValue } from './types';

/**
 * Sleep that crosses midnight belongs to the day the user *woke up*, which is
 * how Apple Health presents it. A session ending after 18:00 is treated as a
 * pre-midnight bedtime for the following day rather than an evening nap.
 */
const EVENING_CUTOFF_HOUR = 18;

/** Higher wins when two sources describe the same minute differently. */
const STAGE_PRIORITY: Record<SleepStageValue, number> = {
  DEEP: 5,
  REM: 4,
  CORE: 3,
  ASLEEP: 2,
  UNSPECIFIED: 2,
  AWAKE: 1,
  INBED: 0,
};

const WEARABLE_HINTS = ['watch', 'oura', 'whoop', 'ultrahuman'];

function isWearable(sourceName: string | undefined): boolean {
  if (!sourceName) return false;
  const lower = sourceName.toLowerCase();
  return WEARABLE_HINTS.some((hint) => lower.includes(hint));
}

function mean(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

function sum(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((total, v) => total + v, 0);
}

function bucketByDay(samples: QuantitySample[]): Map<IsoDay, QuantitySample[]> {
  const map = new Map<IsoDay, QuantitySample[]>();
  for (const sample of samples) {
    const day = toIsoDay(new Date(sample.startDate));
    const bucket = map.get(day);
    if (bucket) bucket.push(sample);
    else map.set(day, [sample]);
  }
  return map;
}

function sleepDayFor(sample: SleepSample): IsoDay {
  const end = new Date(sample.endDate);
  if (end.getHours() >= EVENING_CUTOFF_HOUR) {
    const next = new Date(end);
    next.setDate(next.getDate() + 1);
    return toIsoDay(next);
  }
  return toIsoDay(end);
}

interface ResolvedInterval {
  start: number;
  end: number;
  stage: SleepStageValue;
}

/**
 * Overlapping sleep samples are the norm — the iPhone writes `INBED` while the
 * Watch writes staged sleep, and a third-party ring may write its own take on
 * the same night. Summing raw durations would report 14 hours of sleep.
 *
 * This does an interval sweep: every distinct boundary becomes an elementary
 * segment, and each segment is credited to the single highest-priority stage
 * covering it. Total minutes can therefore never exceed wall-clock time.
 */
function resolveTimeline(samples: SleepSample[]): ResolvedInterval[] {
  const staged = samples.filter((s) => s.value !== 'INBED');
  if (staged.length === 0) return [];

  const boundaries = new Set<number>();
  const spans = staged.map((s) => ({
    start: new Date(s.startDate).getTime(),
    end: new Date(s.endDate).getTime(),
    stage: s.value,
  }));

  for (const span of spans) {
    if (span.end <= span.start) continue;
    boundaries.add(span.start);
    boundaries.add(span.end);
  }

  const points = [...boundaries].sort((a, b) => a - b);
  const resolved: ResolvedInterval[] = [];

  for (let i = 0; i < points.length - 1; i += 1) {
    const start = points[i]!;
    const end = points[i + 1]!;
    if (end <= start) continue;

    let winner: SleepStageValue | null = null;
    for (const span of spans) {
      if (span.start <= start && span.end >= end) {
        if (winner === null || STAGE_PRIORITY[span.stage] > STAGE_PRIORITY[winner]) {
          winner = span.stage;
        }
      }
    }

    if (winner === null) continue;

    const previous = resolved[resolved.length - 1];
    if (previous && previous.stage === winner && previous.end === start) {
      previous.end = end;
    } else {
      resolved.push({ start, end, stage: winner });
    }
  }

  return resolved;
}

function unionMinutes(samples: SleepSample[]): number {
  const spans = samples
    .map((s) => ({ start: new Date(s.startDate).getTime(), end: new Date(s.endDate).getTime() }))
    .filter((s) => s.end > s.start)
    .sort((a, b) => a.start - b.start);

  let total = 0;
  let cursorStart = -1;
  let cursorEnd = -1;

  for (const span of spans) {
    if (cursorEnd < span.start) {
      if (cursorEnd > cursorStart) total += cursorEnd - cursorStart;
      cursorStart = span.start;
      cursorEnd = span.end;
    } else {
      cursorEnd = Math.max(cursorEnd, span.end);
    }
  }
  if (cursorEnd > cursorStart) total += cursorEnd - cursorStart;

  return total / 60_000;
}

function summariseSleep(samples: SleepSample[]): SleepSummary | null {
  if (samples.length === 0) return null;

  const timeline = resolveTimeline(samples);
  const minutes = { DEEP: 0, REM: 0, CORE: 0, AWAKE: 0, UNSPECIFIED: 0 };

  for (const interval of timeline) {
    const duration = (interval.end - interval.start) / 60_000;
    switch (interval.stage) {
      case 'DEEP':
        minutes.DEEP += duration;
        break;
      case 'REM':
        minutes.REM += duration;
        break;
      case 'CORE':
        minutes.CORE += duration;
        break;
      case 'AWAKE':
        minutes.AWAKE += duration;
        break;
      default:
        minutes.UNSPECIFIED += duration;
    }
  }

  const asleepMinutes = minutes.DEEP + minutes.REM + minutes.CORE + minutes.UNSPECIFIED;
  if (asleepMinutes <= 0) return null;

  const inBedSamples = samples.filter((s) => s.value === 'INBED');
  const inBedMinutes =
    inBedSamples.length > 0
      ? Math.max(unionMinutes(inBedSamples), asleepMinutes)
      : asleepMinutes + minutes.AWAKE;

  const asleepIntervals = timeline.filter((i) => i.stage !== 'AWAKE');
  const bedtime = asleepIntervals.length > 0 ? new Date(asleepIntervals[0]!.start) : null;
  const wakeTime =
    asleepIntervals.length > 0
      ? new Date(asleepIntervals[asleepIntervals.length - 1]!.end)
      : null;

  return {
    deepMinutes: round(minutes.DEEP),
    remMinutes: round(minutes.REM),
    coreMinutes: round(minutes.CORE),
    awakeMinutes: round(minutes.AWAKE),
    unspecifiedMinutes: round(minutes.UNSPECIFIED),
    asleepMinutes: round(asleepMinutes),
    inBedMinutes: round(inBedMinutes),
    efficiency: inBedMinutes > 0 ? clamp01(asleepMinutes / inBedMinutes) : null,
    bedtime: bedtime ? bedtime.toISOString() : null,
    wakeTime: wakeTime ? wakeTime.toISOString() : null,
  };
}

function round(value: number): number {
  return Math.round(value * 10) / 10;
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

/**
 * Collapses raw HealthKit samples into one snapshot per calendar day across
 * the whole requested window — including days with no samples at all, which
 * are emitted with `null` metrics so gaps stay visible instead of being
 * silently closed by the chart.
 */
export function aggregateDailySnapshots(
  raw: RawTelemetry,
  from: Date,
  to: Date,
): DailySnapshot[] {
  const hrvByDay = bucketByDay(raw.hrv);
  const rhrByDay = bucketByDay(raw.restingHeartRate);
  const energyByDay = bucketByDay(raw.activeEnergy);
  const stepsByDay = bucketByDay(raw.steps);

  const sleepByDay = new Map<IsoDay, SleepSample[]>();
  for (const sample of raw.sleep) {
    const day = sleepDayFor(sample);
    const bucket = sleepByDay.get(day);
    if (bucket) bucket.push(sample);
    else sleepByDay.set(day, [sample]);
  }

  return enumerateDays(from, to).map<DailySnapshot>((day) => {
    const hrvSamples = hrvByDay.get(day) ?? [];
    const rhrSamples = rhrByDay.get(day) ?? [];
    const energySamples = energyByDay.get(day) ?? [];
    const stepSamples = stepsByDay.get(day) ?? [];
    const sleepSamples = sleepByDay.get(day) ?? [];

    const allSources = [...hrvSamples, ...rhrSamples, ...energySamples];

    return {
      day,
      // Apple reports a daily *average* SDNN; taking the max would flatter
      // recovery on nights with one good reading.
      hrv: roundOrNull(mean(hrvSamples.map((s) => s.value)), 1),
      // Resting HR is already a daily derived value; averaging duplicates from
      // multiple sources is the correct reconciliation.
      restingHeartRate: roundOrNull(mean(rhrSamples.map((s) => s.value)), 0),
      sleep: summariseSleep(sleepSamples),
      activeEnergy: roundOrNull(sum(energySamples.map((s) => s.value)), 0),
      steps: roundOrNull(sum(stepSamples.map((s) => s.value)), 0),
      hasWearableSource:
        allSources.some((s) => isWearable(s.sourceName)) ||
        sleepSamples.some((s) => isWearable(s.sourceName)),
    };
  });
}

function roundOrNull(value: number | null, decimals: number): number | null {
  if (value === null || !Number.isFinite(value)) return null;
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}
