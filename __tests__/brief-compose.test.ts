import { composeBrief, type ComposeInput } from '@/features/brief/compose';
import { buildEngineContext } from '@/features/correlation/context';
import { enrichBiomarker } from '@/features/labs/reference-ranges';
import { analyseWeek } from '@/features/nutrition/patterns';
import { computeTargets } from '@/features/nutrition/targets';
import type { Biomarker } from '@/schemas/labs';
import type { DailySnapshot } from '@/schemas/health';
import type { ResolvedProfile } from '@/schemas/profile';
import { HealthProfileSchema } from '@/schemas/profile';
import type { Readiness } from '@/schemas/insights';
import { addDays, toIsoDay } from '@/lib/date';

const NOW = new Date('2026-07-29T07:30:00+05:30');

function profile(overrides: Partial<ResolvedProfile> = {}): ResolvedProfile {
  return {
    ...HealthProfileSchema.parse({}),
    sex: 'female',
    birthYear: 1994,
    ageYears: 32,
    heightCm: 165,
    weightKg: 60,
    cuisines: ['south-indian', 'north-indian'],
    dietPattern: 'vegetarian',
    ...overrides,
  };
}

function biomarker(code: Biomarker['code'], value: number, unit: string): Biomarker {
  return enrichBiomarker(
    {
      code,
      rawName: String(code),
      displayName: String(code),
      category: 'other',
      value,
      unit,
      range: { low: null, high: null, optimalLow: null, optimalHigh: null, source: 'app' },
      flag: 'unknown',
      confidence: 1,
      sourcePage: null,
    },
    'female',
  );
}

function series(days: number, sleepMinutes: number): DailySnapshot[] {
  return Array.from({ length: days }, (_, index) => ({
    day: toIsoDay(addDays(NOW, -(days - 1 - index))),
    hrv: 45,
    restingHeartRate: 58,
    sleep: {
      asleepMinutes: sleepMinutes,
      inBedMinutes: sleepMinutes + 30,
      efficiency: 0.92,
      deepMinutes: 65,
      remMinutes: 90,
      coreMinutes: sleepMinutes - 155,
      awakeMinutes: 30,
      unspecifiedMinutes: 0,
      bedtime: null,
      wakeTime: null,
    },
    activeEnergy: 480,
    steps: 8200,
    hasWearableSource: true,
  }));
}

function readiness(score: number, band: Readiness['band']): Readiness {
  return { score, band, drivers: [], baselineDays: 28, computedAt: NOW.toISOString() };
}

function input(overrides: Partial<ComposeInput> = {}): ComposeInput {
  const resolved = overrides.profile ?? profile();
  const telemetry = overrides.context === undefined ? series(35, 450) : [];
  const targets =
    overrides.targets ??
    computeTargets({ profile: resolved, series: telemetry, phase: overrides.phase ?? null })!;

  return {
    day: toIsoDay(NOW),
    now: NOW.toISOString(),
    profile: resolved,
    targets,
    context: buildEngineContext({
      series: telemetry,
      biomarkers: [],
      labReportId: null,
      labCollectedAt: null,
      sex: resolved.sex,
    }),
    readiness: readiness(58, 'moderate'),
    insights: [],
    phase: null,
    nutrition: analyseWeek([], {}, targets, { now: NOW }),
    lastNight: telemetry[telemetry.length - 1] ?? null,
    ...overrides,
  };
}

describe('composeBrief', () => {
  it('prescribes a normal session at baseline readiness', () => {
    expect(composeBrief(input()).workout.intensity).toBe('moderate');
  });

  it('prescribes rest when recovery is compromised', () => {
    const brief = composeBrief(input({ readiness: readiness(22, 'compromised') }));
    expect(brief.workout.intensity).toBe('rest');
    expect(brief.headline).toMatch(/rest/i);
  });

  it('lets a primed morning license a hard session', () => {
    expect(composeBrief(input({ readiness: readiness(78, 'primed') })).workout.intensity).toBe('hard');
  });

  it('caps intensity after a short night, even when readiness is high', () => {
    const short = series(35, 300);
    const brief = composeBrief(
      input({
        readiness: readiness(78, 'primed'),
        lastNight: short[short.length - 1]!,
      }),
    );

    expect(brief.workout.intensity).toBe('easy');
    expect(brief.drivers.map((driver) => driver.id)).toContain('sleep-short');
  });

  it('leads on iron when ferritin is low, and names the vitamin C pairing', () => {
    const context = buildEngineContext({
      series: series(35, 450),
      biomarkers: [biomarker('ferritin', 18, 'ng/mL')],
      labReportId: 'r1',
      labCollectedAt: NOW.toISOString(),
      sex: 'female',
    });

    const brief = composeBrief(input({ context }));

    expect(brief.foodFocus.title).toMatch(/iron/i);
    expect(brief.foodFocus.detail).toMatch(/vitamin C/i);
    expect(brief.foodFocus.tags).toContain('iron-rich');
    expect(brief.drivers.map((driver) => driver.id)).toContain('labs-iron');
  });

  it('only recommends foods compatible with the declared diet', () => {
    const context = buildEngineContext({
      series: series(35, 450),
      biomarkers: [biomarker('ferritin', 18, 'ng/mL')],
      labReportId: 'r1',
      labCollectedAt: NOW.toISOString(),
      sex: 'female',
    });

    const brief = composeBrief(
      input({ context, profile: profile({ dietPattern: 'vegan', allergens: ['dairy'] }) }),
    );

    // The iron-rich shortlist is otherwise led by palak paneer.
    for (const example of brief.foodFocus.examples) {
      expect(example.name.toLowerCase()).not.toContain('paneer');
    }
  });

  it('leads on glucose handling when HbA1c is raised', () => {
    const context = buildEngineContext({
      series: series(35, 450),
      biomarkers: [biomarker('hba1c', 6.1, '%')],
      labReportId: 'r1',
      labCollectedAt: NOW.toISOString(),
      sex: 'female',
    });

    const brief = composeBrief(input({ context }));
    expect(brief.foodFocus.title).toMatch(/protein and fibre/i);
    expect(brief.foodFocus.tags).toContain('high-fibre');
  });

  it('folds cycle phase into training and names it as a driver', () => {
    const brief = composeBrief(
      input({
        readiness: readiness(78, 'primed'),
        phase: {
          name: 'menstrual',
          label: 'Menstrual phase',
          dayOfCycle: 2,
          cycleLengthDays: 29,
          isMeasuredLength: true,
          daysUntilNextPeriod: 27,
          confidence: 'high',
          summary: 'Day 2 — iron demand is at its highest point of the month.',
        },
      }),
    );

    // The menstrual phase caps a "primed" hard session down to easy.
    expect(brief.workout.intensity).toBe('easy');
    expect(brief.drivers.map((driver) => driver.id)).toContain('cycle');
    expect(brief.narrative.join(' ')).toMatch(/iron demand/i);
  });

  it('declares what it could not see rather than staying silent', () => {
    const brief = composeBrief(input());
    expect(brief.caveats.join(' ')).toMatch(/no blood work/i);
    expect(brief.caveats.join(' ')).toMatch(/logged/i);
  });

  it('flags cheat day in the caveats so a raised target is never a surprise', () => {
    const resolved = profile();
    const targets = computeTargets({
      profile: resolved,
      series: series(35, 450),
      phase: null,
      isCheatDay: true,
    })!;

    expect(composeBrief(input({ profile: resolved, targets })).caveats.join(' ')).toMatch(
      /cheat day/i,
    );
  });

  it('always emits the five daily targets', () => {
    expect(composeBrief(input()).targets.map((target) => target.id)).toEqual([
      'calories',
      'protein',
      'water',
      'steps',
      'sleep',
    ]);
  });

  it('is deterministic — the same inputs compose the same brief', () => {
    const args = input();
    expect(composeBrief(args)).toEqual(composeBrief(args));
  });
});
