import { computeCyclePhase, withPeriodStart } from '@/features/cycle/phase';
import type { CycleProfile } from '@/schemas/profile';
import { CycleProfileSchema } from '@/schemas/profile';
import { addDays, toIsoDay } from '@/lib/date';

const NOW = new Date('2026-07-29T09:00:00+05:30');

function cycle(overrides: Partial<CycleProfile> = {}): CycleProfile {
  return { ...CycleProfileSchema.parse({}), tracks: true, ...overrides };
}

/** Period start `daysAgo` before NOW, as an ISO day. */
function startedDaysAgo(...daysAgo: number[]): string[] {
  return daysAgo.map((offset) => toIsoDay(addDays(NOW, -offset))).sort();
}

describe('computeCyclePhase', () => {
  it('returns null when tracking is switched off', () => {
    expect(computeCyclePhase(cycle({ tracks: false, periodStarts: startedDaysAgo(3) }), NOW)).toBeNull();
  });

  it('returns null with no logged period', () => {
    expect(computeCyclePhase(cycle(), NOW)).toBeNull();
  });

  it('places day 3 in the menstrual phase', () => {
    const phase = computeCyclePhase(cycle({ periodStarts: startedDaysAgo(2) }), NOW);
    expect(phase?.name).toBe('menstrual');
    expect(phase?.dayOfCycle).toBe(3);
  });

  it('places day 10 of a 28-day cycle in the follicular phase', () => {
    const phase = computeCyclePhase(cycle({ periodStarts: startedDaysAgo(9) }), NOW);
    expect(phase?.name).toBe('follicular');
  });

  it('places ovulation at length minus 14, not at a fixed day 14', () => {
    // A measured 34-day cycle ovulates around day 20.
    const long = cycle({ periodStarts: startedDaysAgo(19, 53, 87) });
    const phase = computeCyclePhase(long, NOW);

    expect(phase?.cycleLengthDays).toBe(34);
    expect(phase?.dayOfCycle).toBe(20);
    expect(phase?.name).toBe('ovulatory');
  });

  it('places the late cycle in the luteal phase', () => {
    const phase = computeCyclePhase(cycle({ periodStarts: startedDaysAgo(21) }), NOW);
    expect(phase?.name).toBe('luteal');
    expect(phase?.daysUntilNextPeriod).toBe(7);
  });

  it('measures cycle length from history and marks it high confidence', () => {
    const phase = computeCyclePhase(cycle({ periodStarts: startedDaysAgo(5, 34, 63) }), NOW);
    expect(phase?.isMeasuredLength).toBe(true);
    expect(phase?.cycleLengthDays).toBe(29);
    expect(phase?.confidence).toBe('high');
  });

  it('falls back to the declared length at moderate confidence', () => {
    const phase = computeCyclePhase(cycle({ periodStarts: startedDaysAgo(5) }), NOW);
    expect(phase?.isMeasuredLength).toBe(false);
    expect(phase?.confidence).toBe('moderate');
  });

  it('takes the median gap so one skipped log cannot distort the model', () => {
    // Gaps of 28, 56 (a missed log) and 28 → median 28, not the 37 mean.
    const phase = computeCyclePhase(cycle({ periodStarts: startedDaysAgo(2, 30, 86, 114) }), NOW);
    expect(phase?.cycleLengthDays).toBe(28);
  });

  it('stops rather than inventing a phase once a log goes stale', () => {
    expect(computeCyclePhase(cycle({ periodStarts: startedDaysAgo(45) }), NOW)).toBeNull();
  });

  it('still reports a late period inside the grace window, at low confidence', () => {
    const phase = computeCyclePhase(cycle({ periodStarts: startedDaysAgo(31) }), NOW);
    expect(phase?.name).toBe('luteal');
    expect(phase?.daysUntilNextPeriod).toBe(-3);
    expect(phase?.confidence).toBe('low');
  });

  it('downgrades confidence on hormonal contraception', () => {
    const phase = computeCyclePhase(
      cycle({ periodStarts: startedDaysAgo(5, 34, 63), hormonalContraception: true }),
      NOW,
    );
    expect(phase?.confidence).toBe('low');
  });

  it('ignores a future-dated log rather than reporting a negative day', () => {
    const future = cycle({ periodStarts: [toIsoDay(addDays(NOW, 3))] });
    expect(computeCyclePhase(future, NOW)).toBeNull();
  });
});

describe('withPeriodStart', () => {
  it('appends and keeps the list sorted', () => {
    const next = withPeriodStart(cycle({ periodStarts: ['2026-05-02'] }), '2026-04-01');
    expect(next.periodStarts).toEqual(['2026-04-01', '2026-05-02']);
  });

  it('is idempotent for the same day', () => {
    const once = withPeriodStart(cycle(), '2026-07-01');
    expect(withPeriodStart(once, '2026-07-01').periodStarts).toEqual(['2026-07-01']);
  });
});
