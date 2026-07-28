import { z } from 'zod';
import { BiomarkerCodeSchema } from './labs';
import { MetricKeySchema } from './health';

export const InsightSeveritySchema = z.enum(['info', 'watch', 'action', 'urgent']);
export type InsightSeverity = z.infer<typeof InsightSeveritySchema>;

export const InsightDomainSchema = z.enum([
  'nutrition',
  'training',
  'sleep',
  'recovery',
  'stress',
  'medical-referral',
]);
export type InsightDomain = z.infer<typeof InsightDomainSchema>;

/** Strength of a statistical link, exposed to the UI as plain language. */
export const CorrelationSchema = z.object({
  metric: MetricKeySchema,
  /** Pearson r over the analysis window, −1…1. */
  r: z.number().min(-1).max(1),
  /** Two-tailed p-value from the t-approximation. */
  p: z.number().min(0).max(1),
  /** Sample size (paired days) behind r. */
  n: z.number().int().nonnegative(),
  /** Lag in days applied to the metric before correlating. */
  lagDays: z.number().int().min(0).max(14).default(0),
  strength: z.enum(['none', 'weak', 'moderate', 'strong']),
  direction: z.enum(['positive', 'negative', 'none']),
});
export type Correlation = z.infer<typeof CorrelationSchema>;

export const SuggestionSchema = z.object({
  id: z.string().min(1),
  title: z.string().min(1),
  /** One-sentence, imperative, specific. "Add 2 Brazil nuts daily", not "eat better". */
  detail: z.string().min(1),
  domain: InsightDomainSchema,
  /** Rough effort for the user, drives ordering within an insight. */
  effort: z.enum(['low', 'medium', 'high']),
  /** Expected time-to-signal before the linked metric should move. */
  horizonDays: z.number().int().positive().max(180),
});
export type Suggestion = z.infer<typeof SuggestionSchema>;

export const EvidenceSchema = z.object({
  biomarkers: z.array(
    z.object({
      code: BiomarkerCodeSchema,
      displayName: z.string(),
      value: z.number(),
      unit: z.string(),
      flag: z.string(),
    }),
  ),
  correlations: z.array(CorrelationSchema).default([]),
  /** Short plain-language statement of the telemetry pattern that fired. */
  telemetryNote: z.string().nullable().default(null),
  /** PubMed IDs / DOIs backing the mechanism. Never fabricated at runtime. */
  citations: z
    .array(z.object({ label: z.string(), url: z.string().url() }))
    .default([]),
});
export type Evidence = z.infer<typeof EvidenceSchema>;

export const InsightSchema = z.object({
  id: z.string().min(1),
  /** Stable rule identifier, so dismissals survive re-computation. */
  ruleId: z.string().min(1),
  title: z.string().min(1),
  summary: z.string().min(1),
  severity: InsightSeveritySchema,
  domain: InsightDomainSchema,
  /** 0–100 ranking score; the dashboard shows the top N by this. */
  score: z.number().min(0).max(100),
  evidence: EvidenceSchema,
  suggestions: z.array(SuggestionSchema).min(1),
  generatedAt: z.string().datetime({ offset: true }),
  /** Which lab report anchored this insight, when applicable. */
  labReportId: z.string().nullable().default(null),
});
export type Insight = z.infer<typeof InsightSchema>;

export const ReadinessSchema = z.object({
  /** 0–100 composite of HRV, RHR, sleep and load, vs. the 28-day baseline. */
  score: z.number().min(0).max(100),
  band: z.enum(['compromised', 'low', 'moderate', 'primed']),
  drivers: z.array(
    z.object({
      metric: MetricKeySchema,
      /** Signed contribution to the score, in points. */
      contribution: z.number(),
      /** z-score of today vs. baseline. */
      z: z.number(),
    }),
  ),
  /** Days of data behind the baseline; below 7 the score is suppressed. */
  baselineDays: z.number().int().nonnegative(),
  computedAt: z.string().datetime({ offset: true }),
});
export type Readiness = z.infer<typeof ReadinessSchema>;
