import {
  classifyStrength,
  correlationPValue,
  linearSlope,
  pairSeries,
  pearson,
  percentChange,
  rollingMean,
  stdDev,
  zScore,
} from '@/features/correlation/stats';

describe('pearson', () => {
  it('returns 1 for a perfect positive relationship', () => {
    expect(pearson([1, 2, 3, 4, 5], [2, 4, 6, 8, 10])).toBeCloseTo(1, 10);
  });

  it('returns -1 for a perfect inverse relationship', () => {
    expect(pearson([1, 2, 3, 4, 5], [10, 8, 6, 4, 2])).toBeCloseTo(-1, 10);
  });

  it('matches a hand-computed value on non-trivial data', () => {
    // Σdxdy = 478, Σdx² = 1240.83, Σdy² = 656 → r = 478/√(1240.83·656) = 0.5298
    const r = pearson([43, 21, 25, 42, 57, 59], [99, 65, 79, 75, 87, 81]);
    expect(r).toBeCloseTo(0.5298, 4);
  });

  it('is NaN when a series has no variance', () => {
    expect(Number.isNaN(pearson([5, 5, 5, 5], [1, 2, 3, 4]))).toBe(true);
  });

  it('refuses to compute on fewer than 3 points', () => {
    expect(Number.isNaN(pearson([1, 2], [3, 4]))).toBe(true);
  });
});

describe('correlationPValue', () => {
  it('is near zero for a strong correlation over many samples', () => {
    expect(correlationPValue(0.9, 50)).toBeLessThan(0.0001);
  });

  it('is near one for no correlation', () => {
    expect(correlationPValue(0, 30)).toBeCloseTo(1, 6);
  });

  it('matches the t-distribution at a known point', () => {
    // r = 0.5, n = 20 → t = 2.4495, df = 18 → two-tailed p = 0.02502
    expect(correlationPValue(0.5, 20)).toBeCloseTo(0.025, 3);
  });

  it('treats an under-powered sample as non-significant', () => {
    expect(correlationPValue(0.99, 3)).toBe(1);
  });

  it('is symmetric in the sign of r', () => {
    expect(correlationPValue(0.62, 25)).toBeCloseTo(correlationPValue(-0.62, 25), 12);
  });
});

describe('classifyStrength', () => {
  it('rejects a high r on a small sample', () => {
    // The whole point: 0.8 across 6 days is noise, not a finding.
    expect(classifyStrength(0.8, correlationPValue(0.8, 6), 6)).toBe('none');
  });

  it('rejects anything that fails the significance gate', () => {
    expect(classifyStrength(0.7, 0.06, 20)).toBe('none');
  });

  it('grades a significant, well-powered correlation', () => {
    expect(classifyStrength(0.65, 0.001, 40)).toBe('strong');
    expect(classifyStrength(0.45, 0.004, 40)).toBe('moderate');
    expect(classifyStrength(0.3, 0.04, 40)).toBe('weak');
  });
});

describe('pairSeries', () => {
  it('drops indices where either side is missing', () => {
    const { x, y } = pairSeries([1, null, 3, 4], [5, 6, null, 8]);
    expect(x).toEqual([1, 4]);
    expect(y).toEqual([5, 8]);
  });

  it('shifts x backwards by the lag so x[t-1] pairs with y[t]', () => {
    const { x, y } = pairSeries([10, 20, 30, 40], [1, 2, 3, 4], 1);
    expect(x).toEqual([10, 20, 30]);
    expect(y).toEqual([2, 3, 4]);
  });

  it('excludes non-finite values', () => {
    const { x } = pairSeries([Number.NaN, 2], [1, 2]);
    expect(x).toEqual([2]);
  });
});

describe('descriptive helpers', () => {
  it('computes the sample standard deviation with n-1', () => {
    // Σ(x−x̄)² = 8 over 5 points → 8/(n−1) = 2 → sample SD = √2 = 1.41421…
    // (the population SD, dividing by n, would be 1.26491 — the distinction
    // matters because baselines here are samples, not populations)
    expect(stdDev([2, 4, 4, 4, 6])).toBeCloseTo(1.4142135, 6);
  });

  it('returns a zero z-score when the baseline has no spread', () => {
    expect(zScore(10, [5, 5, 5])).toBe(0);
  });

  it('signs the slope by direction', () => {
    expect(linearSlope([1, 2, 3, 4, 5])).toBeCloseTo(1, 10);
    expect(linearSlope([5, 4, 3, 2, 1])).toBeCloseTo(-1, 10);
  });

  it('guards percentChange against a zero baseline', () => {
    expect(percentChange(0, 50)).toBe(0);
    expect(percentChange(50, 60)).toBeCloseTo(20, 10);
  });

  it('smooths a dense series and blanks positions with too few neighbours', () => {
    // Window 3 needs at least 2 of the 3 surrounding values to be present.
    const result = rollingMean([2, 4, 6, null, null, null, 8], 3);

    expect(result[1]).toBeCloseTo(4, 10); // (2+4+6)/3
    expect(result[4]).toBeNull(); // isolated inside the gap
    expect(result[6]).toBeNull(); // only itself at the edge of the gap
  });
});
