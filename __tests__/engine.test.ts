import type { DailySnapshot } from '@/schemas/health';
import type { Biomarker } from '@/schemas/labs';
import { buildEngineContext } from '@/features/correlation/context';
import { runEngine } from '@/features/correlation/engine';
import { computeReadiness } from '@/features/correlation/readiness';
import { enrichBiomarker } from '@/features/labs/reference-ranges';
import { addDays, toIsoDay } from '@/lib/date';

const NOW = new Date(2026, 5, 30);

/**
 * Builds a 60-day series. The final `declineDays` carry a linear degradation
 * so the recent 7-day window sits below the 28-day baseline — the shape every
 * telemetry-side rule predicate looks for.
 */
function buildSeries(options: {
  days?: number;
  hrvBase?: number;
  hrvDrop?: number;
  rhrBase?: number;
  rhrRise?: number;
  sleepHours?: number;
  steps?: number;
  activeEnergy?: number;
  declineDays?: number;
}): DailySnapshot[] {
  const {
    days = 60,
    hrvBase = 55,
    hrvDrop = 0,
    rhrBase = 55,
    rhrRise = 0,
    sleepHours = 7.8,
    steps = 9000,
    activeEnergy = 500,
    declineDays = 21,
  } = options;

  return Array.from({ length: days }, (_, index) => {
    const daysFromEnd = days - 1 - index;
    const progress = daysFromEnd < declineDays ? 1 - daysFromEnd / declineDays : 0;
    const asleepMinutes = sleepHours * 60;

    return {
      day: toIsoDay(addDays(NOW, -daysFromEnd)),
      hrv: hrvBase - hrvDrop * progress,
      restingHeartRate: rhrBase + rhrRise * progress,
      sleep: {
        deepMinutes: asleepMinutes * 0.18,
        remMinutes: asleepMinutes * 0.22,
        coreMinutes: asleepMinutes * 0.6,
        awakeMinutes: 25,
        unspecifiedMinutes: 0,
        asleepMinutes,
        inBedMinutes: asleepMinutes + 25,
        efficiency: asleepMinutes / (asleepMinutes + 25),
        bedtime: addDays(NOW, -daysFromEnd - 1).toISOString(),
        wakeTime: addDays(NOW, -daysFromEnd).toISOString(),
      },
      activeEnergy,
      steps,
      hasWearableSource: true,
    } satisfies DailySnapshot;
  });
}

function lab(code: Biomarker['code'], value: number, unit: string): Biomarker {
  return enrichBiomarker(
    {
      code,
      rawName: String(code),
      displayName: String(code),
      category: 'other',
      value,
      unit,
      range: { low: null, high: null, optimalLow: null, optimalHigh: null, source: 'lab' },
      flag: 'unknown',
      confidence: 1,
      sourcePage: 1,
    },
    'male',
  );
}

function context(series: DailySnapshot[], biomarkers: Biomarker[]) {
  return buildEngineContext({
    series,
    biomarkers,
    labReportId: 'lab_test',
    labCollectedAt: addDays(NOW, -5).toISOString(),
    sex: 'male',
    now: NOW.toISOString(),
  });
}

describe('runEngine', () => {
  it('produces nothing when there is neither telemetry nor lab data', () => {
    expect(runEngine(context([], []))).toEqual([]);
  });

  it('stays silent on healthy telemetry with in-range labs', () => {
    const insights = runEngine(context(buildSeries({ declineDays: 0 }), [lab('ferritin', 110, 'ng/mL')]));
    expect(insights).toEqual([]);
  });

  it('does NOT fire the iron rule on low ferritin alone', () => {
    // A lab value without a matching telemetry pattern is just a number.
    const insights = runEngine(
      context(buildSeries({ declineDays: 0 }), [lab('ferritin', 21, 'ng/mL')]),
    );
    expect(insights.find((i) => i.ruleId === 'iron-deficiency-recovery-drag')).toBeUndefined();
  });

  it('does NOT fire the iron rule on falling HRV alone', () => {
    const insights = runEngine(context(buildSeries({ hrvDrop: 14, rhrRise: 6 }), []));
    expect(insights.find((i) => i.ruleId === 'iron-deficiency-recovery-drag')).toBeUndefined();
  });

  it('fires the iron rule when low ferritin coincides with suppressed recovery', () => {
    const insights = runEngine(
      context(buildSeries({ hrvDrop: 14, rhrRise: 6 }), [lab('ferritin', 21, 'ng/mL')]),
    );

    const iron = insights.find((i) => i.ruleId === 'iron-deficiency-recovery-drag');
    expect(iron).toBeDefined();
    expect(iron?.suggestions.length).toBeGreaterThan(0);
    expect(iron?.evidence.biomarkers[0]?.code).toBe('ferritin');
    expect(iron?.evidence.telemetryNote).toContain('HRV');
    expect(iron?.evidence.citations[0]?.url).toMatch(/^https:\/\//);
  });

  it('escalates severity as the biomarker worsens', () => {
    const series = buildSeries({ hrvDrop: 14, rhrRise: 6 });

    const borderline = runEngine(context(series, [lab('ferritin', 21, 'ng/mL')])).find(
      (i) => i.ruleId === 'iron-deficiency-recovery-drag',
    );
    const frank = runEngine(context(series, [lab('ferritin', 8, 'ng/mL')])).find(
      (i) => i.ruleId === 'iron-deficiency-recovery-drag',
    );

    expect(borderline?.severity).toBe('watch');
    expect(frank?.severity).toBe('urgent');
    expect(frank!.score).toBeGreaterThan(borderline!.score);
  });

  it('fires the sleep-debt rule from telemetry alone', () => {
    const insights = runEngine(context(buildSeries({ sleepHours: 5.9, declineDays: 0 }), []));
    const debt = insights.find((i) => i.ruleId === 'chronic-sleep-debt');

    expect(debt).toBeDefined();
    expect(debt?.severity).toBe('action');
  });

  it('respects muted rules', () => {
    const ctx = context(buildSeries({ sleepHours: 5.9, declineDays: 0 }), []);
    const insights = runEngine(ctx, { mutedRuleIds: ['chronic-sleep-debt'] });

    expect(insights.find((i) => i.ruleId === 'chronic-sleep-debt')).toBeUndefined();
  });

  it('ranks urgent findings above lower-severity ones', () => {
    const insights = runEngine(
      context(buildSeries({ hrvDrop: 14, rhrRise: 6, sleepHours: 5.9 }), [
        lab('ferritin', 8, 'ng/mL'),
      ]),
    );

    expect(insights.length).toBeGreaterThan(1);
    expect(insights[0]?.severity).toBe('urgent');
  });

  it('discounts an insight anchored to a stale lab report', () => {
    const series = buildSeries({ hrvDrop: 14, rhrRise: 6 });
    const biomarkers = [lab('ferritin', 21, 'ng/mL')];

    const fresh = runEngine(context(series, biomarkers)).find(
      (i) => i.ruleId === 'iron-deficiency-recovery-drag',
    );

    const staleContext = buildEngineContext({
      series,
      biomarkers,
      labReportId: 'lab_old',
      // Two half-lives back (240 days) — should cut the score to roughly a quarter.
      labCollectedAt: addDays(NOW, -240).toISOString(),
      sex: 'male',
      now: NOW.toISOString(),
    });
    const stale = runEngine(staleContext).find((i) => i.ruleId === 'iron-deficiency-recovery-drag');

    expect(stale!.score).toBeLessThan(fresh!.score / 2);
  });

  it('gives an insight a stable id across recomputations, so dismissals stick', () => {
    const args = { series: buildSeries({ sleepHours: 5.9, declineDays: 0 }), biomarkers: [] };

    const first = runEngine(context(args.series, args.biomarkers));
    const second = runEngine(context(args.series, args.biomarkers));

    expect(first.map((i) => i.id)).toEqual(second.map((i) => i.id));
  });
});

describe('computeReadiness', () => {
  it('withholds a score until the baseline is long enough', () => {
    expect(computeReadiness(context(buildSeries({ days: 5 }), []))).toBeNull();
  });

  it('sits near 50 when today matches the baseline', () => {
    const readiness = computeReadiness(context(buildSeries({ declineDays: 0 }), []));

    expect(readiness).not.toBeNull();
    expect(readiness!.score).toBeGreaterThanOrEqual(45);
    expect(readiness!.score).toBeLessThanOrEqual(55);
    expect(readiness!.band).toBe('moderate');
  });

  it('drops when HRV falls and resting heart rate climbs', () => {
    const readiness = computeReadiness(context(buildSeries({ hrvDrop: 18, rhrRise: 8 }), []));

    expect(readiness!.score).toBeLessThan(40);
    expect(['compromised', 'low']).toContain(readiness!.band);
  });

  it('orients drivers so a positive contribution always means "helping"', () => {
    const readiness = computeReadiness(context(buildSeries({ hrvDrop: 18, rhrRise: 8 }), []));
    const rhr = readiness!.drivers.find((d) => d.metric === 'restingHeartRate');

    // RHR rose (z > 0) but that is bad, so its contribution must be negative.
    expect(rhr!.z).toBeGreaterThan(0);
    expect(rhr!.contribution).toBeLessThan(0);
  });
});
