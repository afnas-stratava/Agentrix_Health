import type {
  Biomarker,
  BiomarkerCategory,
  BiomarkerCode,
  BiomarkerFlag,
  ReferenceRange,
} from '@/schemas/labs';

/**
 * App-side reference table.
 *
 * `low`/`high` mirror the conventional laboratory interval; `optimalLow`/
 * `optimalHigh` encode the tighter band associated with better outcomes in the
 * literature. The gap between them is where this product does its work — a
 * ferritin of 22 ng/mL is "normal" on every lab report in the world and is
 * still a plausible cause of suppressed HRV in an endurance athlete.
 *
 * These are population defaults for adults. They are NOT a diagnosis, and
 * sex/age-specific intervals are applied in `resolveRange` where they matter.
 */
export interface ReferenceDefinition {
  displayName: string;
  category: BiomarkerCategory;
  canonicalUnit: string;
  low: number | null;
  high: number | null;
  optimalLow: number | null;
  optimalHigh: number | null;
  /** Sex-specific overrides, applied when the profile declares one. */
  bySex?: Partial<
    Record<'male' | 'female', Partial<Pick<ReferenceDefinition, 'low' | 'high' | 'optimalLow' | 'optimalHigh'>>>
  >;
  /** Conversion factors from other common units into `canonicalUnit`. */
  unitConversions?: Record<string, number>;
}

export const REFERENCE_TABLE: Record<BiomarkerCode, ReferenceDefinition> = {
  ferritin: {
    displayName: 'Ferritin',
    category: 'iron',
    canonicalUnit: 'ng/mL',
    low: 15,
    high: 300,
    optimalLow: 50,
    optimalHigh: 150,
    bySex: {
      female: { high: 200, optimalLow: 40, optimalHigh: 120 },
    },
    unitConversions: { 'µg/L': 1, 'ug/L': 1, 'mcg/L': 1 },
  },
  hemoglobin: {
    displayName: 'Haemoglobin',
    category: 'iron',
    canonicalUnit: 'g/dL',
    low: 13.5,
    high: 17.5,
    optimalLow: 14,
    optimalHigh: 16.5,
    bySex: { female: { low: 12, high: 15.5, optimalLow: 12.5, optimalHigh: 15 } },
    unitConversions: { 'g/L': 0.1 },
  },
  transferrinSaturation: {
    displayName: 'Transferrin Saturation',
    category: 'iron',
    canonicalUnit: '%',
    low: 20,
    high: 50,
    optimalLow: 25,
    optimalHigh: 40,
  },
  hsCrp: {
    displayName: 'hs-CRP',
    category: 'inflammation',
    canonicalUnit: 'mg/L',
    low: null,
    high: 3,
    optimalLow: null,
    optimalHigh: 1,
    unitConversions: { 'mg/dL': 10 },
  },
  esr: {
    displayName: 'ESR',
    category: 'inflammation',
    canonicalUnit: 'mm/hr',
    low: null,
    high: 20,
    optimalLow: null,
    optimalHigh: 10,
  },
  hba1c: {
    displayName: 'HbA1c',
    category: 'glycemic',
    canonicalUnit: '%',
    low: 4,
    high: 5.7,
    optimalLow: 4.6,
    optimalHigh: 5.4,
    unitConversions: { 'mmol/mol': 0.0915 },
  },
  fastingGlucose: {
    displayName: 'Fasting Glucose',
    category: 'glycemic',
    canonicalUnit: 'mg/dL',
    low: 70,
    high: 99,
    optimalLow: 75,
    optimalHigh: 89,
    unitConversions: { 'mmol/L': 18.0182 },
  },
  fastingInsulin: {
    displayName: 'Fasting Insulin',
    category: 'glycemic',
    canonicalUnit: 'µIU/mL',
    low: 2,
    high: 19.6,
    optimalLow: 2,
    optimalHigh: 6,
    unitConversions: { 'uIU/mL': 1, 'mIU/L': 1, 'pmol/L': 0.1443 },
  },
  totalCholesterol: {
    displayName: 'Total Cholesterol',
    category: 'lipids',
    canonicalUnit: 'mg/dL',
    low: null,
    high: 200,
    optimalLow: 140,
    optimalHigh: 180,
    unitConversions: { 'mmol/L': 38.67 },
  },
  ldl: {
    displayName: 'LDL Cholesterol',
    category: 'lipids',
    canonicalUnit: 'mg/dL',
    low: null,
    high: 100,
    optimalLow: null,
    optimalHigh: 80,
    unitConversions: { 'mmol/L': 38.67 },
  },
  hdl: {
    displayName: 'HDL Cholesterol',
    category: 'lipids',
    canonicalUnit: 'mg/dL',
    low: 40,
    high: null,
    optimalLow: 55,
    optimalHigh: null,
    bySex: { female: { low: 50, optimalLow: 65 } },
    unitConversions: { 'mmol/L': 38.67 },
  },
  triglycerides: {
    displayName: 'Triglycerides',
    category: 'lipids',
    canonicalUnit: 'mg/dL',
    low: null,
    high: 150,
    optimalLow: null,
    optimalHigh: 90,
    unitConversions: { 'mmol/L': 88.57 },
  },
  apoB: {
    displayName: 'Apolipoprotein B',
    category: 'lipids',
    canonicalUnit: 'mg/dL',
    low: null,
    high: 100,
    optimalLow: null,
    optimalHigh: 80,
  },
  tsh: {
    displayName: 'TSH',
    category: 'thyroid',
    canonicalUnit: 'mIU/L',
    low: 0.45,
    high: 4.5,
    optimalLow: 0.8,
    optimalHigh: 2.5,
    unitConversions: { 'µIU/mL': 1, 'uIU/mL': 1 },
  },
  freeT3: {
    displayName: 'Free T3',
    category: 'thyroid',
    canonicalUnit: 'pg/mL',
    low: 2.3,
    high: 4.2,
    optimalLow: 3,
    optimalHigh: 4,
  },
  freeT4: {
    displayName: 'Free T4',
    category: 'thyroid',
    canonicalUnit: 'ng/dL',
    low: 0.8,
    high: 1.8,
    optimalLow: 1.1,
    optimalHigh: 1.6,
  },
  vitaminD: {
    displayName: 'Vitamin D (25-OH)',
    category: 'micronutrient',
    canonicalUnit: 'ng/mL',
    low: 30,
    high: 100,
    optimalLow: 40,
    optimalHigh: 60,
    unitConversions: { 'nmol/L': 0.4006 },
  },
  vitaminB12: {
    displayName: 'Vitamin B12',
    category: 'micronutrient',
    canonicalUnit: 'pg/mL',
    low: 200,
    high: 900,
    optimalLow: 500,
    optimalHigh: 800,
    unitConversions: { 'pmol/L': 1.355 },
  },
  folate: {
    displayName: 'Folate',
    category: 'micronutrient',
    canonicalUnit: 'ng/mL',
    low: 3,
    high: 20,
    optimalLow: 10,
    optimalHigh: 20,
  },
  magnesium: {
    displayName: 'Magnesium (RBC)',
    category: 'micronutrient',
    canonicalUnit: 'mg/dL',
    low: 4.2,
    high: 6.8,
    optimalLow: 5.4,
    optimalHigh: 6.8,
  },
  alt: {
    displayName: 'ALT',
    category: 'organ',
    canonicalUnit: 'U/L',
    low: null,
    high: 40,
    optimalLow: null,
    optimalHigh: 25,
    bySex: { female: { high: 33, optimalHigh: 20 } },
  },
  ast: {
    displayName: 'AST',
    category: 'organ',
    canonicalUnit: 'U/L',
    low: null,
    high: 40,
    optimalLow: null,
    optimalHigh: 26,
  },
  ggt: {
    displayName: 'GGT',
    category: 'organ',
    canonicalUnit: 'U/L',
    low: null,
    high: 55,
    optimalLow: null,
    optimalHigh: 25,
  },
  creatinine: {
    displayName: 'Creatinine',
    category: 'organ',
    canonicalUnit: 'mg/dL',
    low: 0.7,
    high: 1.3,
    optimalLow: 0.8,
    optimalHigh: 1.1,
    bySex: { female: { low: 0.6, high: 1.1 } },
    unitConversions: { 'µmol/L': 0.0113, 'umol/L': 0.0113 },
  },
  egfr: {
    displayName: 'eGFR',
    category: 'organ',
    canonicalUnit: 'mL/min/1.73m²',
    low: 60,
    high: null,
    optimalLow: 90,
    optimalHigh: null,
  },
  uricAcid: {
    displayName: 'Uric Acid',
    category: 'organ',
    canonicalUnit: 'mg/dL',
    low: 3.5,
    high: 7.2,
    optimalLow: 3.5,
    optimalHigh: 5.5,
    bySex: { female: { high: 6 } },
  },
  testosterone: {
    displayName: 'Total Testosterone',
    category: 'endocrine',
    canonicalUnit: 'ng/dL',
    low: 300,
    high: 1000,
    optimalLow: 500,
    optimalHigh: 900,
    bySex: { female: { low: 15, high: 70, optimalLow: 25, optimalHigh: 60 } },
    unitConversions: { 'nmol/L': 28.84 },
  },
  cortisolAm: {
    displayName: 'Cortisol (AM)',
    category: 'endocrine',
    canonicalUnit: 'µg/dL',
    low: 6,
    high: 18.4,
    optimalLow: 10,
    optimalHigh: 15,
    unitConversions: { 'nmol/L': 0.03625 },
  },
  wbc: {
    displayName: 'White Blood Cells',
    category: 'hematology',
    canonicalUnit: '10³/µL',
    low: 4,
    high: 11,
    optimalLow: 4.5,
    optimalHigh: 8,
  },
  plateletCount: {
    displayName: 'Platelets',
    category: 'hematology',
    canonicalUnit: '10³/µL',
    low: 150,
    high: 400,
    optimalLow: 200,
    optimalHigh: 350,
  },
};

export type BiologicalSex = 'male' | 'female' | 'unspecified';

export function resolveRange(code: BiomarkerCode, sex: BiologicalSex): ReferenceRange {
  const base = REFERENCE_TABLE[code];
  const override = sex === 'unspecified' ? undefined : base.bySex?.[sex];

  return {
    low: override?.low ?? base.low,
    high: override?.high ?? base.high,
    optimalLow: override?.optimalLow ?? base.optimalLow,
    optimalHigh: override?.optimalHigh ?? base.optimalHigh,
    source: 'app',
  };
}

/**
 * Converts a printed value into the app's canonical unit for a biomarker.
 * Returns null when the unit is unrecognised — silently assuming the units
 * match would turn a 5.4 mmol/L glucose into a hypoglycaemia alert.
 */
export function toCanonicalUnit(
  code: BiomarkerCode,
  value: number,
  unit: string,
): { value: number; unit: string } | null {
  const definition = REFERENCE_TABLE[code];
  const normalised = unit.trim();

  if (normalised.toLowerCase() === definition.canonicalUnit.toLowerCase()) {
    return { value, unit: definition.canonicalUnit };
  }

  const factor = definition.unitConversions?.[normalised];
  if (factor != null) {
    return { value: value * factor, unit: definition.canonicalUnit };
  }

  const caseInsensitive = Object.entries(definition.unitConversions ?? {}).find(
    ([key]) => key.toLowerCase() === normalised.toLowerCase(),
  );
  if (caseInsensitive) {
    return { value: value * caseInsensitive[1], unit: definition.canonicalUnit };
  }

  return null;
}

/** How far outside the conventional interval counts as `critical`. */
const CRITICAL_MULTIPLIER = 1.5;

export function classifyValue(value: number, range: ReferenceRange): BiomarkerFlag {
  const { low, high, optimalLow, optimalHigh } = range;

  if (low != null && value < low) {
    return value < low / CRITICAL_MULTIPLIER ? 'critical-low' : 'low';
  }
  if (high != null && value > high) {
    return value > high * CRITICAL_MULTIPLIER ? 'critical-high' : 'high';
  }

  // Inside the lab range — is it inside the tighter optimal band?
  if (optimalLow != null && value < optimalLow) return 'borderline-low';
  if (optimalHigh != null && value > optimalHigh) return 'borderline-high';
  if (optimalLow != null || optimalHigh != null) return 'optimal';

  return 'normal';
}

/**
 * Re-flags a parsed biomarker against the app's reference table, preferring the
 * lab's own printed interval when it exists (labs calibrate per-assay) but
 * always layering our optimal band on top of it.
 */
export function enrichBiomarker(biomarker: Biomarker, sex: BiologicalSex): Biomarker {
  if (biomarker.code == null) {
    return { ...biomarker, flag: 'unknown' };
  }

  const appRange = resolveRange(biomarker.code, sex);
  const converted = toCanonicalUnit(biomarker.code, biomarker.value, biomarker.unit);

  if (converted === null) {
    // Unknown unit: keep the value verbatim, trust only the lab's own range.
    const labRange = biomarker.range;
    const usable = labRange.low != null || labRange.high != null;
    return {
      ...biomarker,
      flag: usable ? classifyValue(biomarker.value, labRange) : 'unknown',
      confidence: Math.min(biomarker.confidence, 0.6),
    };
  }

  const hasLabInterval = biomarker.range.low != null || biomarker.range.high != null;

  const range: ReferenceRange = {
    low: biomarker.range.low ?? appRange.low,
    high: biomarker.range.high ?? appRange.high,
    optimalLow: appRange.optimalLow,
    optimalHigh: appRange.optimalHigh,
    // Provenance must survive re-enrichment. Deriving it purely from "does the
    // range have numbers in it" would relabel an app-supplied interval as the
    // lab's own on the second pass — and this function runs again on every
    // render of the insights feed.
    source: biomarker.range.source === 'app' ? 'app' : hasLabInterval ? 'lab' : 'app',
  };

  return {
    ...biomarker,
    value: Math.round(converted.value * 1000) / 1000,
    unit: converted.unit,
    category: REFERENCE_TABLE[biomarker.code].category,
    displayName: REFERENCE_TABLE[biomarker.code].displayName,
    range,
    flag: classifyValue(converted.value, range),
  };
}

export const FLAG_SEVERITY: Record<BiomarkerFlag, number> = {
  'critical-low': 4,
  'critical-high': 4,
  low: 3,
  high: 3,
  'borderline-low': 2,
  'borderline-high': 2,
  optimal: 0,
  normal: 1,
  unknown: 0,
};

export function isOutOfRange(flag: BiomarkerFlag): boolean {
  return FLAG_SEVERITY[flag] >= 3;
}

export function needsAttention(flag: BiomarkerFlag): boolean {
  return FLAG_SEVERITY[flag] >= 2;
}
