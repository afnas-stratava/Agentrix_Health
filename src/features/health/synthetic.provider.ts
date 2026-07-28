import type { HealthPermissionState } from '@/schemas/health';
import { addDays, startOfLocalDay } from '@/lib/date';
import type { HealthProvider, QuantitySample, RawTelemetry, SleepSample } from './types';

/**
 * Deterministic synthetic telemetry for the simulator, Android and CI.
 *
 * The series is *not* random noise: it encodes a plausible physiology so the
 * correlation engine has something real to find — a sub-clinical iron/
 * inflammation drift over the last three weeks that suppresses HRV, lifts
 * resting heart rate and fragments sleep. Screenshots and tests are therefore
 * reproducible frame-for-frame.
 */

/** Mulberry32 — small, fast, and seeded so every run is identical. */
function seededRandom(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function dayIndexSeed(date: Date): number {
  return Math.floor(startOfLocalDay(date).getTime() / 86_400_000);
}

interface DayProfile {
  hrv: number;
  rhr: number;
  asleepMinutes: number;
  awakeMinutes: number;
  activeEnergy: number;
  steps: number;
}

function profileForDay(date: Date, daysAgo: number): DayProfile {
  const rand = seededRandom(dayIndexSeed(date) * 2654435761);
  const weekday = date.getDay();
  const isWeekend = weekday === 0 || weekday === 6;

  // Slow decline over the trailing 21 days, then a stable healthy plateau.
  const declinePhase = Math.max(0, 1 - daysAgo / 21);
  const hrvDrift = -14 * declinePhase;
  const rhrDrift = 6 * declinePhase;

  // Weekly rhythm: worse recovery early in the week, best on Saturday.
  const circadian = Math.sin(((weekday - 2) / 7) * Math.PI * 2);

  return {
    hrv: clamp(52 + hrvDrift + circadian * 4 + (rand() - 0.5) * 9, 14, 120),
    rhr: clamp(56 + rhrDrift - circadian * 1.5 + (rand() - 0.5) * 4, 40, 95),
    asleepMinutes: clamp(
      414 - 26 * declinePhase + (isWeekend ? 38 : 0) + (rand() - 0.5) * 55,
      210,
      620,
    ),
    awakeMinutes: clamp(24 + 18 * declinePhase + (rand() - 0.5) * 14, 4, 90),
    activeEnergy: clamp(
      (isWeekend ? 690 : 470) - 90 * declinePhase + (rand() - 0.5) * 260,
      60,
      1600,
    ),
    steps: Math.round(
      clamp((isWeekend ? 11200 : 8300) - 1400 * declinePhase + (rand() - 0.5) * 5200, 500, 26000),
    ),
  };
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function quantity(day: Date, value: number, offsetMinutes: number): QuantitySample {
  const start = new Date(day);
  start.setHours(0, offsetMinutes, 0, 0);
  const end = new Date(start.getTime() + 60_000);
  return { startDate: start.toISOString(), endDate: end.toISOString(), value, sourceName: 'Apple Watch' };
}

function buildSleepSamples(day: Date, profile: DayProfile): SleepSample[] {
  // Sleep is attributed to the *wake* day, matching Apple Health's convention.
  const bedtime = new Date(day);
  bedtime.setDate(bedtime.getDate() - 1);
  bedtime.setHours(23, 12, 0, 0);

  const deep = profile.asleepMinutes * 0.18;
  const rem = profile.asleepMinutes * 0.22;
  const core = profile.asleepMinutes - deep - rem;

  const segments: Array<{ value: SleepSample['value']; minutes: number }> = [
    { value: 'CORE', minutes: core * 0.45 },
    { value: 'DEEP', minutes: deep },
    { value: 'AWAKE', minutes: profile.awakeMinutes },
    { value: 'CORE', minutes: core * 0.55 },
    { value: 'REM', minutes: rem },
  ];

  const out: SleepSample[] = [];
  let cursor = bedtime.getTime();
  for (const segment of segments) {
    const end = cursor + segment.minutes * 60_000;
    out.push({
      startDate: new Date(cursor).toISOString(),
      endDate: new Date(end).toISOString(),
      value: segment.value,
      sourceName: 'Apple Watch',
    });
    cursor = end;
  }

  out.push({
    startDate: bedtime.toISOString(),
    endDate: new Date(cursor).toISOString(),
    value: 'INBED',
    sourceName: 'Apple Watch',
  });

  return out;
}

class SyntheticProvider implements HealthProvider {
  readonly id = 'synthetic' as const;

  async isAvailable(): Promise<boolean> {
    return true;
  }

  async requestAuthorization(): Promise<HealthPermissionState> {
    return 'granted';
  }

  async getPermissionState(): Promise<HealthPermissionState> {
    return 'granted';
  }

  async fetchRange(from: Date, to: Date): Promise<RawTelemetry> {
    const out: RawTelemetry = {
      hrv: [],
      restingHeartRate: [],
      sleep: [],
      activeEnergy: [],
      steps: [],
    };

    const today = startOfLocalDay(new Date());
    let cursor = startOfLocalDay(from);
    const last = startOfLocalDay(to);

    while (cursor.getTime() <= last.getTime()) {
      const daysAgo = Math.round((today.getTime() - cursor.getTime()) / 86_400_000);
      const profile = profileForDay(cursor, daysAgo);

      // HRV is sampled several times a night, not once.
      for (let i = 0; i < 4; i += 1) {
        const jitter = seededRandom(dayIndexSeed(cursor) + i)();
        out.hrv.push(quantity(cursor, profile.hrv * (0.9 + jitter * 0.2), 120 + i * 55));
      }
      out.restingHeartRate.push(quantity(cursor, profile.rhr, 420));
      out.activeEnergy.push(quantity(cursor, profile.activeEnergy, 720));
      out.steps.push(quantity(cursor, profile.steps, 720));
      out.sleep.push(...buildSleepSamples(cursor, profile));

      cursor = addDays(cursor, 1);
    }

    // Simulate native bridge latency so loading states are exercised in dev.
    await new Promise((resolve) => setTimeout(resolve, 220));
    return out;
  }

  subscribe(): () => void {
    return () => undefined;
  }
}

export const syntheticProvider = new SyntheticProvider();
