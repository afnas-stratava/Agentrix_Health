import { useMemo } from 'react';
import type { Insight, Readiness } from '@/schemas/insights';
import type { Biomarker } from '@/schemas/labs';
import { nowIso } from '@/lib/date';
import { useLabsStore } from '@/store/labs.store';
import {
  selectAnalysisWindow,
  selectDismissedIds,
  selectMutedRuleIds,
  selectSex,
  useSettingsStore,
} from '@/store/settings.store';
import { useHealthSeries } from '@/features/health/queries';
import { enrichBiomarker } from '@/features/labs/reference-ranges';
import { buildEngineContext, type EngineContext } from '@/features/correlation/context';
import { mergeBiomarkers, runEngine } from '@/features/correlation/engine';
import { computeReadiness } from '@/features/correlation/readiness';

/**
 * The engine is pure and fast (tens of milliseconds on a 90-day window), so it
 * runs synchronously in a memo keyed on its real inputs rather than through
 * React Query. Nothing here touches the network; React Query owns the
 * telemetry fetch, and this layer owns the derivation.
 */
function useEngineContext(): { context: EngineContext | null; isLoading: boolean } {
  const sex = useSettingsStore(selectSex);
  const windowDays = useSettingsStore(selectAnalysisWindow);
  const reports = useLabsStore((s) => s.reports);
  const { data: series, isLoading } = useHealthSeries(windowDays);

  // Re-flagging here (rather than trusting what was stored at parse time)
  // means changing your sex in Settings instantly re-evaluates every historical
  // report against the correct reference intervals.
  const biomarkers = useMemo<Biomarker[]>(() => {
    const ready = reports.filter((r) => r.status === 'ready' || r.status === 'needs-review');
    return mergeBiomarkers(ready).map((biomarker) => enrichBiomarker(biomarker, sex));
  }, [reports, sex]);

  const latestReport = useMemo(
    () => reports.find((r) => r.status === 'ready' || r.status === 'needs-review') ?? null,
    [reports],
  );

  const context = useMemo(() => {
    if (!series || series.length === 0) return null;
    return buildEngineContext({
      series,
      biomarkers,
      labReportId: latestReport?.id ?? null,
      labCollectedAt: latestReport?.collectedAt ?? latestReport?.uploadedAt ?? null,
      sex,
      // Stable within a render pass; the memo deps decide when it advances.
      now: nowIso(),
    });
    // `nowIso()` deliberately excluded — it is derived, not an input.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [series, biomarkers, latestReport?.id, latestReport?.collectedAt, sex]);

  return { context, isLoading };
}

export interface InsightsResult {
  insights: Insight[];
  dismissed: Insight[];
  readiness: Readiness | null;
  isLoading: boolean;
  hasLabData: boolean;
  hasTelemetry: boolean;
}

export function useInsights(): InsightsResult {
  const { context, isLoading } = useEngineContext();
  const mutedRuleIds = useSettingsStore(selectMutedRuleIds);
  const dismissedIds = useSettingsStore(selectDismissedIds);

  const all = useMemo(() => {
    if (!context) return [] as Insight[];
    return runEngine(context, { mutedRuleIds });
  }, [context, mutedRuleIds]);

  const { insights, dismissed } = useMemo(() => {
    const dismissedSet = new Set(dismissedIds);
    return {
      insights: all.filter((i) => !dismissedSet.has(i.id)),
      dismissed: all.filter((i) => dismissedSet.has(i.id)),
    };
  }, [all, dismissedIds]);

  const readiness = useMemo(() => (context ? computeReadiness(context) : null), [context]);

  return {
    insights,
    dismissed,
    readiness,
    isLoading,
    hasLabData: (context?.biomarkers.size ?? 0) > 0,
    hasTelemetry: (context?.series.length ?? 0) > 0,
  };
}

/** Top-priority insight for the dashboard hero slot. */
export function usePrimaryInsight(): Insight | null {
  const { insights } = useInsights();
  return insights[0] ?? null;
}

/** Every suggestion across every active insight, ranked and de-duplicated. */
export function useSuggestionFeed() {
  const { insights, isLoading } = useInsights();

  const feed = useMemo(() => {
    const seen = new Set<string>();
    const out: Array<{ suggestion: Insight['suggestions'][number]; source: Insight }> = [];

    for (const insight of insights) {
      for (const suggestion of insight.suggestions) {
        if (seen.has(suggestion.id)) continue;
        seen.add(suggestion.id);
        out.push({ suggestion, source: insight });
      }
    }

    // Within the already severity-ranked stream, surface the cheap wins first.
    const effortRank = { low: 0, medium: 1, high: 2 } as const;
    return out.sort((a, b) => effortRank[a.suggestion.effort] - effortRank[b.suggestion.effort]);
  }, [insights]);

  return { feed, isLoading };
}
