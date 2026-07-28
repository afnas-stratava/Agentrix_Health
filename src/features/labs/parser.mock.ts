import type { Biomarker, LabParseResponse, LabUploadRequest } from '@/schemas/labs';
import { LabParseResponseSchema } from '@/schemas/labs';
import { createId } from '@/lib/id';
import { addDays } from '@/lib/date';

/**
 * Offline parser used when no API base URL is configured.
 *
 * It returns a fixed, clinically coherent panel rather than random numbers:
 * mildly depleted iron stores, low-grade inflammation and insufficient vitamin
 * D. Paired with the synthetic telemetry in `synthetic.provider.ts` — which
 * encodes a matching three-week HRV decline — this reliably lights up the
 * iron, inflammation and vitamin-D rules, so the insights surface is
 * developable and screenshot-stable without a backend.
 */

interface Seed {
  code: Biomarker['code'];
  rawName: string;
  displayName: string;
  category: Biomarker['category'];
  value: number;
  unit: string;
  low: number | null;
  high: number | null;
  page: number;
}

const PANEL: Seed[] = [
  { code: 'ferritin', rawName: 'FERRITIN, SERUM', displayName: 'Ferritin', category: 'iron', value: 21, unit: 'ng/mL', low: 15, high: 300, page: 1 },
  { code: 'hemoglobin', rawName: 'HAEMOGLOBIN', displayName: 'Haemoglobin', category: 'iron', value: 13.9, unit: 'g/dL', low: 13.5, high: 17.5, page: 1 },
  { code: 'transferrinSaturation', rawName: 'TRANSFERRIN SAT.', displayName: 'Transferrin Saturation', category: 'iron', value: 18, unit: '%', low: 20, high: 50, page: 1 },
  { code: 'hsCrp', rawName: 'C-REACTIVE PROTEIN (HS)', displayName: 'hs-CRP', category: 'inflammation', value: 3.4, unit: 'mg/L', low: null, high: 3, page: 1 },
  { code: 'hba1c', rawName: 'GLYCOSYLATED HB (HbA1c)', displayName: 'HbA1c', category: 'glycemic', value: 5.6, unit: '%', low: 4, high: 5.7, page: 2 },
  { code: 'fastingGlucose', rawName: 'GLUCOSE, FASTING', displayName: 'Fasting Glucose', category: 'glycemic', value: 96, unit: 'mg/dL', low: 70, high: 99, page: 2 },
  { code: 'triglycerides', rawName: 'TRIGLYCERIDES', displayName: 'Triglycerides', category: 'lipids', value: 168, unit: 'mg/dL', low: null, high: 150, page: 2 },
  { code: 'hdl', rawName: 'HDL CHOLESTEROL', displayName: 'HDL Cholesterol', category: 'lipids', value: 46, unit: 'mg/dL', low: 40, high: null, page: 2 },
  { code: 'ldl', rawName: 'LDL CHOLESTEROL', displayName: 'LDL Cholesterol', category: 'lipids', value: 112, unit: 'mg/dL', low: null, high: 100, page: 2 },
  { code: 'totalCholesterol', rawName: 'CHOLESTEROL, TOTAL', displayName: 'Total Cholesterol', category: 'lipids', value: 191, unit: 'mg/dL', low: null, high: 200, page: 2 },
  { code: 'vitaminD', rawName: '25-OH VITAMIN D (TOTAL)', displayName: 'Vitamin D (25-OH)', category: 'micronutrient', value: 22, unit: 'ng/mL', low: 30, high: 100, page: 3 },
  { code: 'vitaminB12', rawName: 'VITAMIN B-12', displayName: 'Vitamin B12', category: 'micronutrient', value: 412, unit: 'pg/mL', low: 200, high: 900, page: 3 },
  { code: 'magnesium', rawName: 'MAGNESIUM, RBC', displayName: 'Magnesium (RBC)', category: 'micronutrient', value: 5.1, unit: 'mg/dL', low: 4.2, high: 6.8, page: 3 },
  { code: 'tsh', rawName: 'TSH, ULTRASENSITIVE', displayName: 'TSH', category: 'thyroid', value: 2.1, unit: 'mIU/L', low: 0.45, high: 4.5, page: 3 },
  { code: 'alt', rawName: 'SGPT / ALT', displayName: 'ALT', category: 'organ', value: 29, unit: 'U/L', low: null, high: 40, page: 4 },
  { code: 'ast', rawName: 'SGOT / AST', displayName: 'AST', category: 'organ', value: 24, unit: 'U/L', low: null, high: 40, page: 4 },
  { code: 'creatinine', rawName: 'CREATININE, SERUM', displayName: 'Creatinine', category: 'organ', value: 0.94, unit: 'mg/dL', low: 0.7, high: 1.3, page: 4 },
  { code: 'wbc', rawName: 'TOTAL LEUCOCYTE COUNT', displayName: 'White Blood Cells', category: 'hematology', value: 6.8, unit: '10³/µL', low: 4, high: 11, page: 1 },
];

function toBiomarker(seed: Seed): Biomarker {
  return {
    code: seed.code,
    rawName: seed.rawName,
    displayName: seed.displayName,
    category: seed.category,
    value: seed.value,
    unit: seed.unit,
    range: {
      low: seed.low,
      high: seed.high,
      optimalLow: null,
      optimalHigh: null,
      source: 'lab',
    },
    // Flagging is deliberately left to `enrichBiomarker`, so the offline path
    // exercises exactly the same classification code as the network path.
    flag: 'unknown',
    confidence: 0.94,
    sourcePage: seed.page,
  };
}

export async function parseLocally(upload: LabUploadRequest): Promise<LabParseResponse> {
  // Mimic OCR latency so skeleton states are exercised during development.
  await new Promise((resolve) => setTimeout(resolve, 1400));

  const collectedAt = addDays(new Date(), -9);
  collectedAt.setHours(8, 15, 0, 0);

  return LabParseResponseSchema.parse({
    reportId: createId('lab'),
    status: 'ready',
    collectedAt: collectedAt.toISOString(),
    labName: 'Meridian Diagnostics',
    panelName: 'Comprehensive Metabolic & Micronutrient Panel',
    biomarkers: PANEL.map(toBiomarker),
    overallConfidence: 0.94,
    warnings:
      upload.source === 'image'
        ? ['Parsed from a photograph — confirm any value that looks wrong before acting on it.']
        : [],
  });
}
