/**
 * Small, dependency-free statistics kernel.
 *
 * Everything here is pure and synchronous so the engine can run inside a
 * `useMemo` on the JS thread without jank — the working set is at most a few
 * hundred paired observations.
 */

export function mean(values: number[]): number {
  if (values.length === 0) return Number.NaN;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

export function median(values: number[]): number {
  if (values.length === 0) return Number.NaN;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? ((sorted[mid - 1]! + sorted[mid]!) / 2) : sorted[mid]!;
}

/** Sample standard deviation (n − 1). */
export function stdDev(values: number[]): number {
  if (values.length < 2) return Number.NaN;
  const m = mean(values);
  const variance = values.reduce((sum, v) => sum + (v - m) ** 2, 0) / (values.length - 1);
  return Math.sqrt(variance);
}

export function zScore(value: number, baseline: number[]): number {
  const sd = stdDev(baseline);
  if (!Number.isFinite(sd) || sd === 0) return 0;
  return (value - mean(baseline)) / sd;
}

/** Ordinary-least-squares slope in units per day, x being the index. */
export function linearSlope(values: number[]): number {
  const n = values.length;
  if (n < 3) return 0;
  const xMean = (n - 1) / 2;
  const yMean = mean(values);
  let numerator = 0;
  let denominator = 0;
  for (let i = 0; i < n; i += 1) {
    numerator += (i - xMean) * (values[i]! - yMean);
    denominator += (i - xMean) ** 2;
  }
  return denominator === 0 ? 0 : numerator / denominator;
}

export interface PairedSeries {
  x: number[];
  y: number[];
}

/**
 * Pairs two nullable series positionally, dropping any index where either side
 * is missing. `lag` shifts `x` backwards so `x[t − lag]` is compared with
 * `y[t]`, which is how a physiological input is tested against a delayed
 * response (e.g. training load today → HRV tomorrow).
 */
export function pairSeries(
  xs: Array<number | null>,
  ys: Array<number | null>,
  lag = 0,
): PairedSeries {
  const x: number[] = [];
  const y: number[] = [];

  for (let t = lag; t < ys.length; t += 1) {
    const xv = xs[t - lag];
    const yv = ys[t];
    if (xv == null || yv == null) continue;
    if (!Number.isFinite(xv) || !Number.isFinite(yv)) continue;
    x.push(xv);
    y.push(yv);
  }

  return { x, y };
}

export function pearson(x: number[], y: number[]): number {
  const n = Math.min(x.length, y.length);
  if (n < 3) return Number.NaN;

  const mx = mean(x);
  const my = mean(y);
  let num = 0;
  let dx = 0;
  let dy = 0;

  for (let i = 0; i < n; i += 1) {
    const a = x[i]! - mx;
    const b = y[i]! - my;
    num += a * b;
    dx += a * a;
    dy += b * b;
  }

  const denom = Math.sqrt(dx * dy);
  return denom === 0 ? Number.NaN : num / denom;
}

// ---------------------------------------------------------------------------
// Student's t → p-value, via the regularised incomplete beta function.
// A normal approximation is not good enough here: correlation windows are
// routinely 14–30 days, where the t and z tails diverge materially.
// ---------------------------------------------------------------------------

function logGamma(x: number): number {
  // Lanczos approximation, g = 7, n = 9.
  const coefficients = [
    0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
    -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];

  if (x < 0.5) {
    return Math.log(Math.PI / Math.sin(Math.PI * x)) - logGamma(1 - x);
  }

  const z = x - 1;
  let a = coefficients[0]!;
  const t = z + 7.5;
  for (let i = 1; i < 9; i += 1) {
    a += coefficients[i]! / (z + i);
  }

  return 0.5 * Math.log(2 * Math.PI) + (z + 0.5) * Math.log(t) - t + Math.log(a);
}

/** Continued-fraction expansion for the incomplete beta (Lentz's method). */
function betaContinuedFraction(a: number, b: number, x: number): number {
  const MAX_ITERATIONS = 200;
  const EPSILON = 3e-12;
  const TINY = 1e-30;

  const qab = a + b;
  const qap = a + 1;
  const qam = a - 1;

  let c = 1;
  let d = 1 - (qab * x) / qap;
  if (Math.abs(d) < TINY) d = TINY;
  d = 1 / d;
  let h = d;

  for (let m = 1; m <= MAX_ITERATIONS; m += 1) {
    const m2 = 2 * m;

    let aa = (m * (b - m) * x) / ((qam + m2) * (a + m2));
    d = 1 + aa * d;
    if (Math.abs(d) < TINY) d = TINY;
    c = 1 + aa / c;
    if (Math.abs(c) < TINY) c = TINY;
    d = 1 / d;
    h *= d * c;

    aa = (-(a + m) * (qab + m) * x) / ((a + m2) * (qap + m2));
    d = 1 + aa * d;
    if (Math.abs(d) < TINY) d = TINY;
    c = 1 + aa / c;
    if (Math.abs(c) < TINY) c = TINY;
    d = 1 / d;

    const delta = d * c;
    h *= delta;

    if (Math.abs(delta - 1) < EPSILON) break;
  }

  return h;
}

/** Regularised incomplete beta I_x(a, b). */
function incompleteBeta(a: number, b: number, x: number): number {
  if (x <= 0) return 0;
  if (x >= 1) return 1;

  const front = Math.exp(
    logGamma(a + b) - logGamma(a) - logGamma(b) + a * Math.log(x) + b * Math.log(1 - x),
  );

  return x < (a + 1) / (a + b + 2)
    ? (front * betaContinuedFraction(a, b, x)) / a
    : 1 - (front * betaContinuedFraction(b, a, 1 - x)) / b;
}

/** Two-tailed p-value for a Pearson r over n paired observations. */
export function correlationPValue(r: number, n: number): number {
  if (!Number.isFinite(r) || n < 4) return 1;
  const absR = Math.min(Math.abs(r), 0.999999);
  const df = n - 2;
  const t = absR * Math.sqrt(df / (1 - absR * absR));
  const p = incompleteBeta(df / 2, 0.5, df / (df + t * t));
  return Math.min(1, Math.max(0, p));
}

export type CorrelationStrength = 'none' | 'weak' | 'moderate' | 'strong';

/**
 * Strength is deliberately conservative and gated on significance: an r of
 * 0.6 across five days is noise, and presenting it as a finding is how health
 * apps lose credibility.
 */
export function classifyStrength(r: number, p: number, n: number): CorrelationStrength {
  if (!Number.isFinite(r) || n < 10 || p > 0.05) return 'none';
  const abs = Math.abs(r);
  if (abs >= 0.6) return 'strong';
  if (abs >= 0.4) return 'moderate';
  if (abs >= 0.25) return 'weak';
  return 'none';
}

/** Centred rolling mean; positions without a full window return null. */
export function rollingMean(values: Array<number | null>, window: number): Array<number | null> {
  return values.map((_, index) => {
    const slice: number[] = [];
    const half = Math.floor(window / 2);
    for (let i = index - half; i <= index + half; i += 1) {
      const v = values[i];
      if (v != null && Number.isFinite(v)) slice.push(v);
    }
    return slice.length >= Math.ceil(window / 2) ? mean(slice) : null;
  });
}

/** Percentage change from `previous` to `current`, guarding divide-by-zero. */
export function percentChange(previous: number, current: number): number {
  if (previous === 0) return 0;
  return ((current - previous) / Math.abs(previous)) * 100;
}

export function compact(values: Array<number | null>): number[] {
  return values.filter((v): v is number => v != null && Number.isFinite(v));
}
