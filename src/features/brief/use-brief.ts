import { useMemo } from 'react';
import { nowIso, toIsoDay } from '@/lib/date';
import type { DailySnapshot } from '@/schemas/health';
import type { Biomarker } from '@/schemas/labs';
import { useHealthSeries } from '@/features/health/queries';
import { useInsights } from '@/features/insights/use-insights';
import { buildEngineContext } from '@/features/correlation/context';
import { mergeBiomarkers } from '@/features/correlation/engine';
import { enrichBiomarker } from '@/features/labs/reference-ranges';
import { computeCyclePhase } from '@/features/cycle/phase';
import { analyseWeek } from '@/features/nutrition/patterns';
import { computeTargets } from '@/features/nutrition/targets';
import { useProfile } from '@/features/profile/use-profile';
import { useLabsStore } from '@/store/labs.store';
import { useNutritionStore } from '@/store/nutrition.store';
import { composeBrief, type DailyBrief } from './compose';

export interface BriefResult {
  brief: DailyBrief | null;
  isLoading: boolean;
  /** True when the profile is too thin to compute calorie and macro targets. */
  needsProfile: boolean;
}

/**
 * Assembles the morning brief from live state.
 *
 * Composition is pure and cheap — a few passes over at most 90 days — so it
 * runs in a memo rather than through React Query. The only asynchronous input
 * is the telemetry fetch, which `useHealthSeries` already owns.
 */
export function useDailyBrief(): BriefResult {
  const profile = useProfile();
  const { data: series, isLoading } = useHealthSeries();
  const { insights, readiness } = useInsights();

  const reports = useLabsStore((s) => s.reports);
  const meals = useNutritionStore((s) => s.meals);
  const hydration = useNutritionStore((s) => s.hydration);
  const cheatDays = useNutritionStore((s) => s.cheatDays);

  const day = toIsoDay(new Date());
  const isCheatDay = cheatDays.includes(day);

  const phase = useMemo(() => computeCyclePhase(profile.cycle), [profile.cycle]);

  const targets = useMemo(
    () => computeTargets({ profile, series: series ?? [], phase, isCheatDay }),
    [profile, series, phase, isCheatDay],
  );

  const nutrition = useMemo(
    () => analyseWeek(meals, hydration, targets),
    [meals, hydration, targets],
  );

  const context = useMemo(() => {
    if (!series || series.length === 0) return null;

    const ready = reports.filter((r) => r.status === 'ready' || r.status === 'needs-review');
    const biomarkers: Biomarker[] = mergeBiomarkers(ready).map((b) =>
      enrichBiomarker(b, profile.sex),
    );
    const latest = ready[0] ?? null;

    return buildEngineContext({
      series,
      biomarkers,
      labReportId: latest?.id ?? null,
      labCollectedAt: latest?.collectedAt ?? latest?.uploadedAt ?? null,
      sex: profile.sex,
    });
  }, [series, reports, profile.sex]);

  const lastNight: DailySnapshot | null = useMemo(() => {
    if (!series || series.length === 0) return null;
    // Walk back to the most recent day that actually carries a sleep session —
    // today's row exists from midnight but has no sleep until the watch syncs.
    for (let i = series.length - 1; i >= 0 && i >= series.length - 3; i -= 1) {
      const snapshot = series[i];
      if (snapshot?.sleep != null) return snapshot;
    }
    return series[series.length - 1] ?? null;
  }, [series]);

  const brief = useMemo(() => {
    if (targets == null) return null;
    return composeBrief({
      day,
      now: nowIso(),
      profile,
      targets,
      context,
      readiness,
      insights,
      phase,
      nutrition,
      lastNight,
    });
    // `day` and `nowIso()` are derived from the clock, not reactive inputs.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [targets, profile, context, readiness, insights, phase, nutrition, lastNight]);

  return {
    brief,
    isLoading,
    needsProfile: targets == null,
  };
}

/** Today's targets alone, for screens that need the rings but not the prose. */
export function useTodayTargets() {
  const profile = useProfile();
  const { data: series } = useHealthSeries();
  const cheatDays = useNutritionStore((s) => s.cheatDays);
  const day = toIsoDay(new Date());

  const phase = useMemo(() => computeCyclePhase(profile.cycle), [profile.cycle]);

  return useMemo(
    () =>
      computeTargets({
        profile,
        series: series ?? [],
        phase,
        isCheatDay: cheatDays.includes(day),
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [profile, series, phase, cheatDays],
  );
}

/** Consumed vs. target for today, driving the food screen's rings. */
export function useTodayProgress() {
  const targets = useTodayTargets();
  const meals = useNutritionStore((s) => s.meals);
  const hydration = useNutritionStore((s) => s.hydration);
  const day = toIsoDay(new Date());

  return useMemo(() => {
    const todayMeals = meals.filter((meal) => meal.day === day);
    const consumed = todayMeals
      .flatMap((meal) => meal.foods)
      .reduce(
        (total, food) => ({
          calories: total.calories + food.macros.calories,
          proteinG: total.proteinG + food.macros.proteinG,
          carbsG: total.carbsG + food.macros.carbsG,
          fatG: total.fatG + food.macros.fatG,
          fibreG: total.fibreG + food.macros.fibreG,
          addedSugarG: total.addedSugarG + food.macros.addedSugarG,
          sodiumMg: total.sodiumMg + food.macros.sodiumMg,
        }),
        { calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fibreG: 0, addedSugarG: 0, sodiumMg: 0 },
      );

    return {
      targets,
      consumed,
      waterMl: hydration[day] ?? 0,
      mealCount: todayMeals.length,
      /** Remaining calories, floored at zero — a negative budget reads as failure. */
      remainingCalories: targets ? Math.max(0, targets.calories - consumed.calories) : null,
      remainingProteinG: targets ? Math.max(0, targets.macros.proteinG - consumed.proteinG) : null,
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [targets, meals, hydration]);
}
