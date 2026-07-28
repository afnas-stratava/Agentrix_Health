import { aggregateDailySnapshots } from '@/features/health/aggregate';
import type { RawTelemetry, SleepSample } from '@/features/health/types';
import { toIsoDay } from '@/lib/date';

const EMPTY: RawTelemetry = {
  hrv: [],
  restingHeartRate: [],
  sleep: [],
  activeEnergy: [],
  steps: [],
};

/** Local-time ISO string, so tests are timezone-independent. */
function at(day: string, hour: number, minute = 0): string {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number];
  return new Date(y, m - 1, d, hour, minute, 0, 0).toISOString();
}

function sleep(
  startDay: string,
  startHour: number,
  endDay: string,
  endHour: number,
  value: SleepSample['value'],
  sourceName = 'Apple Watch',
): SleepSample {
  return {
    startDate: at(startDay, startHour),
    endDate: at(endDay, endHour),
    value,
    sourceName,
  };
}

describe('aggregateDailySnapshots', () => {
  const from = new Date(2026, 2, 10);
  const to = new Date(2026, 2, 12);

  it('emits one snapshot per day in the window, including empty days', () => {
    const result = aggregateDailySnapshots(EMPTY, from, to);

    expect(result).toHaveLength(3);
    expect(result.map((r) => r.day)).toEqual(['2026-03-10', '2026-03-11', '2026-03-12']);
  });

  it('reports missing telemetry as null, never zero', () => {
    // A day with no steps recorded is unknown, not a day of zero walking —
    // the correlation engine must be able to tell those apart.
    const [day] = aggregateDailySnapshots(EMPTY, from, from);

    expect(day?.steps).toBeNull();
    expect(day?.hrv).toBeNull();
    expect(day?.sleep).toBeNull();
    expect(day?.restingHeartRate).toBeNull();
  });

  it('averages HRV samples across the day and sums cumulative metrics', () => {
    const raw: RawTelemetry = {
      ...EMPTY,
      hrv: [
        { startDate: at('2026-03-10', 2), endDate: at('2026-03-10', 2), value: 40 },
        { startDate: at('2026-03-10', 4), endDate: at('2026-03-10', 4), value: 60 },
      ],
      steps: [
        { startDate: at('2026-03-10', 9), endDate: at('2026-03-10', 9), value: 4000 },
        { startDate: at('2026-03-10', 18), endDate: at('2026-03-10', 18), value: 3000 },
      ],
      activeEnergy: [
        { startDate: at('2026-03-10', 9), endDate: at('2026-03-10', 9), value: 210.4 },
      ],
    };

    const [day] = aggregateDailySnapshots(raw, from, from);

    expect(day?.hrv).toBe(50);
    expect(day?.steps).toBe(7000);
    expect(day?.activeEnergy).toBe(210);
  });

  it('does not double-count overlapping sleep samples from two sources', () => {
    // The Watch writes staged sleep while the phone writes INBED over the same
    // window. Naively summing durations would report ~16 hours of sleep.
    const raw: RawTelemetry = {
      ...EMPTY,
      sleep: [
        sleep('2026-03-09', 23, '2026-03-10', 7, 'INBED', 'iPhone'),
        sleep('2026-03-09', 23, '2026-03-10', 2, 'CORE'),
        sleep('2026-03-10', 2, '2026-03-10', 4, 'DEEP'),
        sleep('2026-03-10', 4, '2026-03-10', 7, 'REM'),
        // A competing source claiming the same block is light sleep.
        sleep('2026-03-10', 2, '2026-03-10', 4, 'CORE', 'Oura'),
      ],
    };

    const [day] = aggregateDailySnapshots(raw, from, from);

    // 3h core + 2h deep + 3h rem = 8h, not 8h + the duplicated 2h.
    expect(day?.sleep?.asleepMinutes).toBe(480);
    expect(day?.sleep?.deepMinutes).toBe(120);
    expect(day?.sleep?.remMinutes).toBe(180);
    expect(day?.sleep?.coreMinutes).toBe(180);
  });

  it('resolves an overlap to the highest-priority stage', () => {
    const raw: RawTelemetry = {
      ...EMPTY,
      sleep: [
        sleep('2026-03-10', 1, '2026-03-10', 3, 'CORE'),
        sleep('2026-03-10', 1, '2026-03-10', 3, 'DEEP', 'Oura'),
      ],
    };

    const [day] = aggregateDailySnapshots(raw, from, from);

    // DEEP outranks CORE; the two hours are credited once, to deep.
    expect(day?.sleep?.deepMinutes).toBe(120);
    expect(day?.sleep?.coreMinutes).toBe(0);
    expect(day?.sleep?.asleepMinutes).toBe(120);
  });

  it('attributes sleep crossing midnight to the wake day', () => {
    const raw: RawTelemetry = {
      ...EMPTY,
      sleep: [sleep('2026-03-10', 23, '2026-03-11', 7, 'CORE')],
    };

    const result = aggregateDailySnapshots(raw, from, to);
    const tenth = result.find((r) => r.day === '2026-03-10');
    const eleventh = result.find((r) => r.day === '2026-03-11');

    expect(tenth?.sleep).toBeNull();
    expect(eleventh?.sleep?.asleepMinutes).toBe(480);
  });

  it('excludes awake time from asleep minutes but counts it toward efficiency', () => {
    const raw: RawTelemetry = {
      ...EMPTY,
      sleep: [
        sleep('2026-03-09', 23, '2026-03-10', 3, 'CORE'),
        sleep('2026-03-10', 3, '2026-03-10', 4, 'AWAKE'),
        sleep('2026-03-10', 4, '2026-03-10', 7, 'CORE'),
      ],
    };

    const [day] = aggregateDailySnapshots(raw, from, from);

    expect(day?.sleep?.asleepMinutes).toBe(420); // 4h + 3h
    expect(day?.sleep?.awakeMinutes).toBe(60);
    expect(day?.sleep?.inBedMinutes).toBe(480);
    expect(day?.sleep?.efficiency).toBeCloseTo(420 / 480, 5);
  });

  it('flags whether a wearable contributed to the day', () => {
    const withWatch = aggregateDailySnapshots(
      { ...EMPTY, sleep: [sleep('2026-03-10', 1, '2026-03-10', 6, 'CORE', 'Apple Watch')] },
      from,
      from,
    );
    const withPhoneOnly = aggregateDailySnapshots(
      { ...EMPTY, sleep: [sleep('2026-03-10', 1, '2026-03-10', 6, 'CORE', 'Sleep Cycle')] },
      from,
      from,
    );

    expect(withWatch[0]?.hasWearableSource).toBe(true);
    expect(withPhoneOnly[0]?.hasWearableSource).toBe(false);
  });

  it('buckets by local calendar day', () => {
    const raw: RawTelemetry = {
      ...EMPTY,
      steps: [{ startDate: at('2026-03-11', 23, 30), endDate: at('2026-03-11', 23, 59), value: 500 }],
    };

    const result = aggregateDailySnapshots(raw, from, to);
    expect(result.find((r) => r.day === toIsoDay(new Date(2026, 2, 11)))?.steps).toBe(500);
    expect(result.find((r) => r.day === '2026-03-12')?.steps).toBeNull();
  });
});
