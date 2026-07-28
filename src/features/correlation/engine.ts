import type { Insight } from '@/schemas/insights';
import { InsightSchema } from '@/schemas/insights';
import type { Biomarker } from '@/schemas/labs';
import { log } from '@/lib/logger';
import { daysBetween } from '@/lib/date';
import type { EngineContext } from './context';
import { hasSufficientTelemetry } from './context';
import { RULES, type Rule, type RuleOutput } from './rules';

/** Beyond this, a lab result is stale enough to discount heavily. */
const LAB_HALF_LIFE_DAYS = 120;
const MAX_INSIGHTS = 12;

export interface RunEngineOptions {
  /** Rule IDs the user has muted in Settings. */
  mutedRuleIds?: readonly string[];
  maxInsights?: number;
}

/**
 * Adjusts a rule's base score for how much we should actually trust it.
 *
 *   • Lab recency — a ferritin from 14 months ago is a historical footnote.
 *   • Extraction confidence — a value OCR'd at 0.6 confidence is provisional.
 *   • Telemetry coverage — a 40%-covered window supports weaker claims.
 *
 * Medical-referral insights are floored, because "go see a doctor" should not
 * fall off the list just because the underlying data is imperfect.
 */
function scoreInsight(output: RuleOutput, context: EngineContext): number {
  let multiplier = 1;

  if (context.labCollectedAt && output.biomarkerCodes.length > 0) {
    const ageDays = Math.max(0, daysBetween(new Date(context.labCollectedAt), new Date()));
    multiplier *= 0.5 ** (ageDays / LAB_HALF_LIFE_DAYS);
  }

  const confidences = output.biomarkerCodes
    .map((code) => context.biomarkers.get(code)?.confidence)
    .filter((c): c is number => c != null);
  if (confidences.length > 0) {
    multiplier *= Math.min(...confidences);
  }

  const coverages = Object.values(context.metrics).map((m) => m.coverage);
  const meanCoverage = coverages.reduce((sum, c) => sum + c, 0) / (coverages.length || 1);
  multiplier *= 0.6 + 0.4 * Math.min(1, meanCoverage);

  const scored = output.baseScore * multiplier;
  const floor = output.domain === 'medical-referral' ? output.baseScore * 0.75 : 0;

  return Math.round(Math.min(100, Math.max(floor, scored)));
}

function toInsight(rule: Rule, output: RuleOutput, context: EngineContext): Insight | null {
  const evidenceBiomarkers = output.biomarkerCodes
    .map((code) => {
      const biomarker = context.biomarkers.get(code);
      if (!biomarker) return null;
      return {
        code,
        displayName: biomarker.displayName,
        value: biomarker.value,
        unit: biomarker.unit,
        flag: biomarker.flag,
      };
    })
    .filter((b): b is NonNullable<typeof b> => b !== null);

  const candidate = {
    // Deterministic ID: the same finding across recomputations keeps its
    // identity, so a dismissal in the UI persists.
    id: `insight_${rule.id}_${context.labReportId ?? 'telemetry'}`,
    ruleId: rule.id,
    title: output.title,
    summary: output.summary,
    severity: output.severity,
    domain: output.domain,
    score: scoreInsight(output, context),
    evidence: {
      biomarkers: evidenceBiomarkers,
      correlations: output.correlations,
      telemetryNote: output.telemetryNote,
      citations: output.citations,
    },
    suggestions: output.suggestions,
    generatedAt: context.now,
    labReportId: output.biomarkerCodes.length > 0 ? context.labReportId : null,
  };

  const parsed = InsightSchema.safeParse(candidate);
  if (!parsed.success) {
    // A malformed rule must not take down the whole insights tab.
    log.error('engine', `Rule "${rule.id}" produced an invalid insight`, parsed.error.issues);
    return null;
  }

  return parsed.data;
}

const SEVERITY_RANK: Record<Insight['severity'], number> = {
  urgent: 3,
  action: 2,
  watch: 1,
  info: 0,
};

/**
 * Evaluates every rule against the context and returns the ranked findings.
 *
 * Pure and synchronous: no I/O, no clock reads beyond `context.now`, so the
 * same inputs always produce the same output — which is what makes the engine
 * testable and the UI cacheable.
 */
export function runEngine(context: EngineContext, options: RunEngineOptions = {}): Insight[] {
  const muted = new Set(options.mutedRuleIds ?? []);
  const limit = options.maxInsights ?? MAX_INSIGHTS;

  if (!hasSufficientTelemetry(context) && context.biomarkers.size === 0) {
    return [];
  }

  const insights: Insight[] = [];

  for (const rule of RULES) {
    if (muted.has(rule.id)) continue;

    let output: RuleOutput | null;
    try {
      output = rule.evaluate(context);
    } catch (error) {
      log.error('engine', `Rule "${rule.id}" threw during evaluation`, error);
      continue;
    }

    if (!output) continue;

    const insight = toInsight(rule, output, context);
    if (insight) insights.push(insight);
  }

  insights.sort((a, b) => {
    const bySeverity = SEVERITY_RANK[b.severity] - SEVERITY_RANK[a.severity];
    if (bySeverity !== 0) return bySeverity;
    return b.score - a.score;
  });

  log.debug('engine', `Produced ${insights.length} insights`, insights.map((i) => i.ruleId));

  return insights.slice(0, limit);
}

/** Flattens the ranked suggestions across insights, de-duplicated by id. */
export function collectSuggestions(insights: Insight[]) {
  const seen = new Set<string>();
  const out: Array<{ suggestion: Insight['suggestions'][number]; insight: Insight }> = [];

  for (const insight of insights) {
    for (const suggestion of insight.suggestions) {
      if (seen.has(suggestion.id)) continue;
      seen.add(suggestion.id);
      out.push({ suggestion, insight });
    }
  }

  return out;
}

/** Chronologically-latest biomarker per code, for building engine context. */
export function mergeBiomarkers(
  reports: Array<{ collectedAt: string | null; uploadedAt: string; biomarkers: Biomarker[] }>,
): Biomarker[] {
  const sorted = [...reports].sort((a, b) => {
    const aTime = new Date(a.collectedAt ?? a.uploadedAt).getTime();
    const bTime = new Date(b.collectedAt ?? b.uploadedAt).getTime();
    return aTime - bTime;
  });

  const byCode = new Map<string, Biomarker>();
  const unmapped: Biomarker[] = [];

  for (const report of sorted) {
    for (const biomarker of report.biomarkers) {
      if (biomarker.code == null) {
        unmapped.push(biomarker);
        continue;
      }
      byCode.set(biomarker.code, biomarker);
    }
  }

  return [...byCode.values(), ...unmapped];
}
