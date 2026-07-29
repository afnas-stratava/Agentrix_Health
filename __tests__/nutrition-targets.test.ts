import { basalMetabolicRate, computeTargets } from '@/features/nutrition/targets';
import type { ResolvedProfile } from '@/schemas/profile';
import { HealthProfileSchema } from '@/schemas/profile';
import type { DailySnapshot } from '@/schemas/health';
import type { CyclePhase } from '@/features/cycle/phase';

function profile(overrides: Partial<ResolvedProfile> = {}): ResolvedProfile {
  return {
    ...HealthProfileSchema.parse({}),
    sex: 'female',
    birthYear: 1994,
    ageYears: 32,
    heightCm: 165,
    weightKg: 60,
    ...overrides,
  };
}

function day(overrides: Partial<DailySnapshot> = {}): DailySnapshot {
  return {
    day: '2026-07-01',
    hrv: 45,
    restingHeartRate: 58,
    sleep: null,
    activeEnergy: null,
    steps: null,
    hasWearableSource: true,
    ...overrides,
  };
}

const LUTEAL: CyclePhase = {
  name: 'luteal',
  label: 'Luteal phase',
  dayOfCycle: 22,
  cycleLengthDays: 28,
  isMeasuredLength: true,
  daysUntilNextPeriod: 6,
  confidence: 'high',
  summary: '',
};

describe('basalMetabolicRate', () => {
  it('applies the Mifflin–St Jeor female constant', () => {
    // 10(60) + 6.25(165) − 5(32) − 161 = 600 + 1031.25 − 160 − 161
    expect(basalMetabolicRate(profile())).toBeCloseTo(1310.25, 2);
  });

  it('applies the male constant', () => {
    expect(basalMetabolicRate(profile({ sex: 'male' }))).toBeCloseTo(1476.25, 2);
  });

  it('splits the difference when sex is unstated rather than assuming male', () => {
    const value = basalMetabolicRate(profile({ sex: 'unspecified' }));
    expect(value).toBeGreaterThan(basalMetabolicRate(profile({ sex: 'female' }))!);
    expect(value).toBeLessThan(basalMetabolicRate(profile({ sex: 'male' }))!);
  });

  it('is null without the measurements it needs', () => {
    expect(basalMetabolicRate(profile({ weightKg: null }))).toBeNull();
  });
});

describe('computeTargets', () => {
  it('returns null rather than guessing when the profile is incomplete', () => {
    expect(
      computeTargets({ profile: profile({ heightCm: null }), series: [], phase: null }),
    ).toBeNull();
  });

  it('prefers measured active energy over the declared activity multiplier', () => {
    const series = Array.from({ length: 7 }, () => day({ activeEnergy: 600 }));
    const measured = computeTargets({ profile: profile(), series, phase: null });
    const estimated = computeTargets({ profile: profile(), series: [], phase: null });

    expect(measured?.energyBasis).toBe('measured');
    expect(estimated?.energyBasis).toBe('estimated');
    // 1310 × 1.1 + 600 ≈ 2041, well above the 'light' multiplier's 1801.
    expect(measured!.maintenanceCalories).toBeGreaterThan(estimated!.maintenanceCalories);
  });

  it('ignores a sparse week of active energy as a habit', () => {
    const series = [day({ activeEnergy: 600 }), day({ activeEnergy: 600 }), day()];
    expect(computeTargets({ profile: profile(), series, phase: null })?.energyBasis).toBe(
      'estimated',
    );
  });

  it('raises protein per kilo in a deficit to protect lean mass', () => {
    const loss = computeTargets({ profile: profile({ goal: 'weight-loss' }), series: [], phase: null });
    const wellness = computeTargets({ profile: profile(), series: [], phase: null });

    expect(loss!.calories).toBeLessThan(wellness!.calories);
    expect(loss!.macros.proteinG).toBeGreaterThan(wellness!.macros.proteinG);
    expect(loss!.macros.proteinG).toBe(Math.round(1.6 * 60));
  });

  it('adds the luteal-phase expenditure premium', () => {
    const base = computeTargets({ profile: profile(), series: [], phase: null });
    const luteal = computeTargets({ profile: profile(), series: [], phase: LUTEAL });

    expect(luteal!.calories).toBeGreaterThan(base!.calories);
    expect(luteal!.calories).toBe(Math.round(base!.calories * 1.05));
  });

  it('never prescribes below the micronutrient-adequacy floor', () => {
    // A small, sedentary person on a deficit would otherwise land near 1000.
    const tiny = profile({ heightCm: 150, weightKg: 42, ageYears: 60, goal: 'weight-loss' });
    expect(computeTargets({ profile: tiny, series: [], phase: null })!.calories).toBe(1200);
  });

  it('tightens the carbohydrate share and sugar ceiling for dysglycaemia', () => {
    const plain = computeTargets({ profile: profile(), series: [], phase: null });
    const diabetic = computeTargets({
      profile: profile({ goal: 'manage-condition', conditions: ['type2-diabetes'] }),
      series: [],
      phase: null,
    });

    expect(diabetic!.macros.carbsG).toBeLessThan(plain!.macros.carbsG);
    expect(diabetic!.addedSugarCeilingG).toBeLessThan(plain!.addedSugarCeilingG);
  });

  it('lifts calories on an explicit cheat day', () => {
    const normal = computeTargets({ profile: profile(), series: [], phase: null });
    const cheat = computeTargets({ profile: profile(), series: [], phase: null, isCheatDay: true });

    expect(cheat!.calories).toBe(Math.round(normal!.calories * 1.15));
    expect(cheat!.isCheatDay).toBe(true);
  });

  it('sets a step target from the user’s own baseline, not a round 10,000', () => {
    const series = Array.from({ length: 14 }, () => day({ steps: 4000 }));
    const targets = computeTargets({ profile: profile(), series, phase: null });

    expect(targets!.stepTarget).toBeGreaterThan(4000);
    expect(targets!.stepTarget).toBeLessThan(5000);
  });

  it('extends the sleep target when the week ran a debt', () => {
    const short = Array.from({ length: 7 }, () =>
      day({
        sleep: {
          asleepMinutes: 360,
          inBedMinutes: 400,
          efficiency: 0.9,
          deepMinutes: 60,
          remMinutes: 80,
          coreMinutes: 220,
          awakeMinutes: 40,
          unspecifiedMinutes: 0,
          bedtime: null,
          wakeTime: null,
        },
      }),
    );

    const targets = computeTargets({ profile: profile(), series: short, phase: null });
    expect(targets!.sleepTargetMinutes).toBeGreaterThan(480);
  });
});
