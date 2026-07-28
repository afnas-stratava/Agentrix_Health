import type { Biomarker } from '@/schemas/labs';
import {
  classifyValue,
  enrichBiomarker,
  isOutOfRange,
  needsAttention,
  resolveRange,
  toCanonicalUnit,
} from '@/features/labs/reference-ranges';

function biomarker(overrides: Partial<Biomarker> = {}): Biomarker {
  return {
    code: 'ferritin',
    rawName: 'FERRITIN, SERUM',
    displayName: 'Ferritin',
    category: 'iron',
    value: 21,
    unit: 'ng/mL',
    range: { low: null, high: null, optimalLow: null, optimalHigh: null, source: 'lab' },
    flag: 'unknown',
    confidence: 1,
    sourcePage: 1,
    ...overrides,
  };
}

describe('toCanonicalUnit', () => {
  it('passes through a value already in the canonical unit', () => {
    expect(toCanonicalUnit('ferritin', 50, 'ng/mL')).toEqual({ value: 50, unit: 'ng/mL' });
  });

  it('converts mmol/L glucose into mg/dL', () => {
    const result = toCanonicalUnit('fastingGlucose', 5.4, 'mmol/L');
    expect(result?.value).toBeCloseTo(97.3, 1);
    expect(result?.unit).toBe('mg/dL');
  });

  it('converts nmol/L vitamin D into ng/mL', () => {
    const result = toCanonicalUnit('vitaminD', 75, 'nmol/L');
    expect(result?.value).toBeCloseTo(30.045, 3);
  });

  it('is case-insensitive about the printed unit', () => {
    expect(toCanonicalUnit('fastingGlucose', 5.4, 'MMOL/L')?.unit).toBe('mg/dL');
  });

  it('returns null rather than guessing at an unknown unit', () => {
    // Silently assuming units match is how a normal glucose becomes an alert.
    expect(toCanonicalUnit('fastingGlucose', 5.4, 'furlongs')).toBeNull();
  });
});

describe('classifyValue', () => {
  const range = { low: 15, high: 300, optimalLow: 50, optimalHigh: 150, source: 'app' as const };

  it('separates the optimal band from merely-normal', () => {
    expect(classifyValue(100, range)).toBe('optimal');
    expect(classifyValue(21, range)).toBe('borderline-low');
    expect(classifyValue(200, range)).toBe('borderline-high');
  });

  it('flags values outside the lab interval', () => {
    expect(classifyValue(14, range)).toBe('low');
    expect(classifyValue(320, range)).toBe('high');
  });

  it('escalates far-out values to critical', () => {
    expect(classifyValue(9, range)).toBe('critical-low');
    expect(classifyValue(460, range)).toBe('critical-high');
  });

  it('reports plain normal when no optimal band is defined', () => {
    expect(
      classifyValue(50, { low: 10, high: 100, optimalLow: null, optimalHigh: null, source: 'lab' }),
    ).toBe('normal');
  });
});

describe('resolveRange', () => {
  it('applies sex-specific intervals', () => {
    expect(resolveRange('hdl', 'male').low).toBe(40);
    expect(resolveRange('hdl', 'female').low).toBe(50);
    expect(resolveRange('ferritin', 'female').high).toBe(200);
    expect(resolveRange('ferritin', 'male').high).toBe(300);
  });

  it('falls back to the combined interval when sex is unspecified', () => {
    expect(resolveRange('hdl', 'unspecified').low).toBe(40);
  });
});

describe('enrichBiomarker', () => {
  it('flags a "normal" ferritin as below optimal', () => {
    // The core product claim: 21 ng/mL is inside every lab range and still
    // low enough to matter.
    const result = enrichBiomarker(
      biomarker({ range: { low: 15, high: 300, optimalLow: null, optimalHigh: null, source: 'lab' } }),
      'male',
    );

    expect(result.flag).toBe('borderline-low');
    expect(needsAttention(result.flag)).toBe(true);
    expect(isOutOfRange(result.flag)).toBe(false);
  });

  it("keeps the lab's printed interval but layers on the app's optimal band", () => {
    const result = enrichBiomarker(
      biomarker({ range: { low: 30, high: 400, optimalLow: null, optimalHigh: null, source: 'lab' } }),
      'male',
    );

    expect(result.range.low).toBe(30); // lab's, not the app's 15
    expect(result.range.optimalLow).toBe(50); // app's opinion
    expect(result.range.source).toBe('lab');
    expect(result.flag).toBe('low'); // 21 < the lab's own floor of 30
  });

  it('normalises the value and unit', () => {
    const result = enrichBiomarker(
      biomarker({ code: 'fastingGlucose', value: 5.4, unit: 'mmol/L', category: 'other' }),
      'male',
    );

    expect(result.unit).toBe('mg/dL');
    expect(result.value).toBeCloseTo(97.298, 3);
    expect(result.category).toBe('glycemic');
    expect(result.flag).toBe('borderline-high'); // in range, above the 89 optimum
  });

  it('downgrades confidence when the unit cannot be resolved', () => {
    const result = enrichBiomarker(
      biomarker({ unit: 'unknown-unit', confidence: 0.95, range: { low: 15, high: 300, optimalLow: null, optimalHigh: null, source: 'lab' } }),
      'male',
    );

    expect(result.confidence).toBeLessThanOrEqual(0.6);
    expect(result.value).toBe(21); // left verbatim, not silently converted
  });

  it('leaves an unmapped analyte unclassified', () => {
    const result = enrichBiomarker(biomarker({ code: null, rawName: 'MYSTERY ANALYTE' }), 'male');
    expect(result.flag).toBe('unknown');
  });

  it('is idempotent', () => {
    const once = enrichBiomarker(biomarker({ code: 'fastingGlucose', value: 5.4, unit: 'mmol/L' }), 'male');
    const twice = enrichBiomarker(once, 'male');
    expect(twice).toEqual(once);
  });
});
