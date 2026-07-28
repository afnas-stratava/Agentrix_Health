import { z } from 'zod';

/**
 * Biomarkers the correlation engine knows how to reason about. Anything the
 * parser returns outside this set is preserved verbatim as an `unknown`
 * biomarker so nothing is silently dropped from the user's report.
 */
export const BiomarkerCodeSchema = z.enum([
  // Iron / oxygen transport
  'ferritin',
  'hemoglobin',
  'transferrinSaturation',
  // Inflammation
  'hsCrp',
  'esr',
  // Glycemic
  'hba1c',
  'fastingGlucose',
  'fastingInsulin',
  // Lipids
  'totalCholesterol',
  'ldl',
  'hdl',
  'triglycerides',
  'apoB',
  // Thyroid
  'tsh',
  'freeT3',
  'freeT4',
  // Micronutrients
  'vitaminD',
  'vitaminB12',
  'folate',
  'magnesium',
  // Hepatic / renal
  'alt',
  'ast',
  'ggt',
  'creatinine',
  'egfr',
  'uricAcid',
  // Endocrine
  'testosterone',
  'cortisolAm',
  // Haematology
  'wbc',
  'plateletCount',
]);
export type BiomarkerCode = z.infer<typeof BiomarkerCodeSchema>;

export const BiomarkerCategorySchema = z.enum([
  'iron',
  'inflammation',
  'glycemic',
  'lipids',
  'thyroid',
  'micronutrient',
  'organ',
  'endocrine',
  'hematology',
  'other',
]);
export type BiomarkerCategory = z.infer<typeof BiomarkerCategorySchema>;

/**
 * Where a value sits relative to its reference interval. `optimal` is a
 * narrower, evidence-based band inside the lab's own `normal` range — the
 * distinction is the whole point of the product.
 */
export const BiomarkerFlagSchema = z.enum([
  'critical-low',
  'low',
  'borderline-low',
  'optimal',
  'normal',
  'borderline-high',
  'high',
  'critical-high',
  'unknown',
]);
export type BiomarkerFlag = z.infer<typeof BiomarkerFlagSchema>;

export const ReferenceRangeSchema = z.object({
  low: z.number().nullable(),
  high: z.number().nullable(),
  /** Tighter evidence-based band, when the app has an opinion. */
  optimalLow: z.number().nullable().default(null),
  optimalHigh: z.number().nullable().default(null),
  /** `lab` = printed on the report, `app` = our own reference table. */
  source: z.enum(['lab', 'app']).default('lab'),
});
export type ReferenceRange = z.infer<typeof ReferenceRangeSchema>;

export const BiomarkerSchema = z.object({
  /** Known code, or `null` when the parser could not map the printed name. */
  code: BiomarkerCodeSchema.nullable(),
  /** Verbatim analyte name as printed on the report. */
  rawName: z.string().min(1),
  displayName: z.string().min(1),
  category: BiomarkerCategorySchema.default('other'),
  value: z.number(),
  unit: z.string().min(1),
  range: ReferenceRangeSchema,
  flag: BiomarkerFlagSchema.default('unknown'),
  /** Extraction confidence 0–1. Below 0.7 the UI asks the user to confirm. */
  confidence: z.number().min(0).max(1).default(1),
  /** 1-based page in the source PDF, for the "show me where" affordance. */
  sourcePage: z.number().int().positive().nullable().default(null),
});
export type Biomarker = z.infer<typeof BiomarkerSchema>;

export const LabSourceSchema = z.enum(['pdf', 'image', 'manual']);
export type LabSource = z.infer<typeof LabSourceSchema>;

export const ParseStatusSchema = z.enum([
  'pending',
  'uploading',
  'parsing',
  'needs-review',
  'ready',
  'failed',
]);
export type ParseStatus = z.infer<typeof ParseStatusSchema>;

export const LabReportSchema = z.object({
  id: z.string().min(1),
  source: LabSourceSchema,
  status: ParseStatusSchema,
  /** When blood was drawn — the date the correlation engine anchors to. */
  collectedAt: z.string().datetime({ offset: true }).nullable(),
  uploadedAt: z.string().datetime({ offset: true }),
  labName: z.string().nullable().default(null),
  panelName: z.string().nullable().default(null),
  biomarkers: z.array(BiomarkerSchema),
  /** Local `file://` URI of the original document, kept for re-parsing. */
  fileUri: z.string().nullable().default(null),
  fileName: z.string().nullable().default(null),
  fileSizeBytes: z.number().int().nonnegative().nullable().default(null),
  /** Human-readable failure cause when `status === 'failed'`. */
  error: z.string().nullable().default(null),
});
export type LabReport = z.infer<typeof LabReportSchema>;

/** Multipart upload envelope validated before it is sent to the parser. */
export const LabUploadRequestSchema = z.object({
  uri: z.string().min(1),
  name: z.string().min(1),
  mimeType: z.enum([
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
  ]),
  sizeBytes: z
    .number()
    .int()
    .positive()
    .max(25 * 1024 * 1024, 'Reports must be under 25 MB'),
  source: LabSourceSchema,
});
export type LabUploadRequest = z.infer<typeof LabUploadRequestSchema>;

/** Exactly what the `/v1/labs/parse` endpoint is contracted to return. */
export const LabParseResponseSchema = z.object({
  reportId: z.string().min(1),
  status: ParseStatusSchema,
  collectedAt: z.string().datetime({ offset: true }).nullable(),
  labName: z.string().nullable(),
  panelName: z.string().nullable(),
  biomarkers: z.array(BiomarkerSchema),
  /** Mean extraction confidence across all analytes. */
  overallConfidence: z.number().min(0).max(1),
  warnings: z.array(z.string()).default([]),
});
export type LabParseResponse = z.infer<typeof LabParseResponseSchema>;
