import type { IsoDay } from '@/schemas/health';
import type { MealEntry, Macros, NutritionTargets } from '@/schemas/nutrition';
import { EMPTY_MACROS, mealMacros, sumMacros } from '@/schemas/nutrition';
import { toIsoDay, addDays } from '@/lib/date';

/**
 * Weekly nutrition pattern analysis.
 *
 * Answers the question a daily calorie total cannot: *what keeps happening*.
 * "You went over your calories today" is noise; "added sugar was over your
 * ceiling on four of the last seven days, and every one of them was a day you
 * slept under six hours" is a finding.
 *
 * Findings are counted over days, never averaged, because averaging is what
 * hides the pattern — three clean days and four heavy ones average out to
 * "fine". Days with no log at all are excluded from denominators rather than
 * treated as zero-intake days.
 */

export interface DayTotals {
  day: IsoDay;
  macros: Macros;
  mealCount: number;
  /** Latest logged meal time, for the late-eating check. */
  lastMealHour: number | null;
  hydrationMl: number;
}

export interface NutritionPattern {
  id: string;
  /** Short headline: "Added sugar over target 4 of 7 days". */
  title: string;
  /** One sentence of specifics. */
  detail: string;
  /** How many logged days exhibited it, and out of how many. */
  daysAffected: number;
  daysConsidered: number;
  /** `concern` is worth acting on; `win` is worth reinforcing. */
  tone: 'concern' | 'win' | 'neutral';
  /** Ranking weight, 0–100. */
  weight: number;
}

export interface WeeklyNutritionSummary {
  days: DayTotals[];
  /** Days in the window that carry at least one meal. */
  loggedDays: number;
  /** Mean over logged days only. */
  averages: Macros;
  patterns: NutritionPattern[];
  /** True when there is too little logging to say anything honest. */
  isSparse: boolean;
}

/** Below this, the analyser reports sparseness instead of inventing findings. */
export const MIN_LOGGED_DAYS = 3;

export function totalsByDay(
  meals: MealEntry[],
  hydration: Record<string, number>,
  windowDays: number,
  now: Date = new Date(),
): DayTotals[] {
  const byDay = new Map<IsoDay, MealEntry[]>();
  for (const meal of meals) {
    const existing = byDay.get(meal.day);
    if (existing) existing.push(meal);
    else byDay.set(meal.day, [meal]);
  }

  const out: DayTotals[] = [];
  for (let offset = windowDays - 1; offset >= 0; offset -= 1) {
    const day = toIsoDay(addDays(now, -offset));
    const dayMeals = byDay.get(day) ?? [];

    const hours = dayMeals.map((meal) => new Date(meal.loggedAt).getHours());

    out.push({
      day,
      macros: dayMeals.length > 0 ? sumMacros(dayMeals.map(mealMacros)) : { ...EMPTY_MACROS },
      mealCount: dayMeals.length,
      lastMealHour: hours.length > 0 ? Math.max(...hours) : null,
      hydrationMl: hydration[day] ?? 0,
    });
  }

  return out;
}

function meanOf(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

/**
 * A day counts toward the analysis only if it looks genuinely logged. One
 * banana is not a food diary, and letting it into the denominator makes every
 * "under target" finding meaningless.
 */
function isLogged(day: DayTotals): boolean {
  return day.mealCount >= 2 || day.macros.calories >= 800;
}

export function analyseWeek(
  meals: MealEntry[],
  hydration: Record<string, number>,
  targets: NutritionTargets | null,
  options: { windowDays?: number; now?: Date } = {},
): WeeklyNutritionSummary {
  const windowDays = options.windowDays ?? 7;
  const now = options.now ?? new Date();

  const days = totalsByDay(meals, hydration, windowDays, now);
  const logged = days.filter(isLogged);

  const averages: Macros = {
    calories: Math.round(meanOf(logged.map((d) => d.macros.calories))),
    proteinG: Math.round(meanOf(logged.map((d) => d.macros.proteinG))),
    carbsG: Math.round(meanOf(logged.map((d) => d.macros.carbsG))),
    fatG: Math.round(meanOf(logged.map((d) => d.macros.fatG))),
    fibreG: Math.round(meanOf(logged.map((d) => d.macros.fibreG))),
    addedSugarG: Math.round(meanOf(logged.map((d) => d.macros.addedSugarG))),
    sodiumMg: Math.round(meanOf(logged.map((d) => d.macros.sodiumMg))),
  };

  const summary: WeeklyNutritionSummary = {
    days,
    loggedDays: logged.length,
    averages,
    patterns: [],
    isSparse: logged.length < MIN_LOGGED_DAYS,
  };

  if (summary.isSparse || targets == null) return summary;

  const patterns: NutritionPattern[] = [];
  const n = logged.length;
  const plural = (count: number) => (count === 1 ? 'day' : 'days');

  // --- Added sugar ---------------------------------------------------------
  const sugarDays = logged.filter((d) => d.macros.addedSugarG > targets.addedSugarCeilingG);
  if (sugarDays.length >= 2) {
    const worst = Math.max(...sugarDays.map((d) => d.macros.addedSugarG));
    patterns.push({
      id: 'sugar-over',
      title: `Added sugar over target ${sugarDays.length} of ${n} ${plural(n)}`,
      detail: `Your ceiling is ${targets.addedSugarCeilingG} g. The heaviest day hit ${Math.round(worst)} g — roughly ${Math.round(worst / 4)} teaspoons.`,
      daysAffected: sugarDays.length,
      daysConsidered: n,
      tone: 'concern',
      weight: 60 + sugarDays.length * 6,
    });
  }

  // --- Protein -------------------------------------------------------------
  const proteinFloor = targets.macros.proteinG * 0.85;
  const lowProteinDays = logged.filter((d) => d.macros.proteinG < proteinFloor);
  if (lowProteinDays.length >= 3) {
    patterns.push({
      id: 'protein-short',
      title: `Protein short on ${lowProteinDays.length} of ${n} ${plural(n)}`,
      detail: `You averaged ${averages.proteinG} g against a ${targets.macros.proteinG} g target. The gap is about ${Math.round(targets.macros.proteinG - averages.proteinG)} g a day — one more protein-led meal or a shake closes it.`,
      daysAffected: lowProteinDays.length,
      daysConsidered: n,
      tone: 'concern',
      weight: 58 + lowProteinDays.length * 4,
    });
  } else if (lowProteinDays.length === 0) {
    patterns.push({
      id: 'protein-consistent',
      title: 'Protein target hit every logged day',
      detail: `You averaged ${averages.proteinG} g against a ${targets.macros.proteinG} g target. This is the habit that protects lean mass — keep it.`,
      daysAffected: n,
      daysConsidered: n,
      tone: 'win',
      weight: 40,
    });
  }

  // --- Fibre ---------------------------------------------------------------
  const lowFibreDays = logged.filter((d) => d.macros.fibreG < targets.macros.fibreG * 0.7);
  if (lowFibreDays.length >= 3) {
    patterns.push({
      id: 'fibre-short',
      title: `Fibre low on ${lowFibreDays.length} of ${n} ${plural(n)}`,
      detail: `${averages.fibreG} g a day against a ${targets.macros.fibreG} g target. Dal, chana, or swapping white rice for brown moves this fastest.`,
      daysAffected: lowFibreDays.length,
      daysConsidered: n,
      tone: 'concern',
      weight: 50 + lowFibreDays.length * 3,
    });
  }

  // --- Energy balance ------------------------------------------------------
  const overDays = logged.filter((d) => d.macros.calories > targets.calories * 1.12);
  const underDays = logged.filter((d) => d.macros.calories < targets.calories * 0.75);
  if (overDays.length >= 3) {
    patterns.push({
      id: 'calories-over',
      title: `Over your calorie target ${overDays.length} of ${n} ${plural(n)}`,
      detail: `Averaging ${averages.calories} kcal against ${targets.calories}. At this margin the weight trend will flatten rather than move.`,
      daysAffected: overDays.length,
      daysConsidered: n,
      tone: 'concern',
      weight: 62,
    });
  } else if (underDays.length >= 3) {
    patterns.push({
      id: 'calories-under',
      title: `Well under target ${underDays.length} of ${n} ${plural(n)}`,
      detail: `Averaging ${averages.calories} kcal against ${targets.calories}. Under-eating this consistently is the most common reason HRV and sleep quality stall.`,
      daysAffected: underDays.length,
      daysConsidered: n,
      tone: 'concern',
      weight: 64,
    });
  }

  // --- Ultra-processed and fried ------------------------------------------
  const friedDays = logged.filter((day) =>
    meals.some(
      (meal) =>
        meal.day === day.day &&
        meal.foods.some((f) => f.tags.includes('fried') || f.tags.includes('ultra-processed')),
    ),
  );
  if (friedDays.length >= 3) {
    patterns.push({
      id: 'processed-frequency',
      title: `Fried or ultra-processed food on ${friedDays.length} of ${n} ${plural(n)}`,
      detail:
        'Not a reason to panic on any single day, but at this frequency it is the main driver of your sodium and your saturated fat.',
      daysAffected: friedDays.length,
      daysConsidered: n,
      tone: 'concern',
      weight: 48,
    });
  }

  // --- Sodium --------------------------------------------------------------
  // WHO recommends under 2000 mg of sodium a day.
  const highSodiumDays = logged.filter((d) => d.macros.sodiumMg > 2300);
  if (highSodiumDays.length >= 3) {
    patterns.push({
      id: 'sodium-high',
      title: `Sodium above 2.3 g on ${highSodiumDays.length} of ${n} ${plural(n)}`,
      detail: `Averaging ${(averages.sodiumMg / 1000).toFixed(1)} g. Restaurant and packaged food, not your salt shaker, is almost always where this comes from.`,
      daysAffected: highSodiumDays.length,
      daysConsidered: n,
      tone: 'concern',
      weight: 46,
    });
  }

  // --- Hydration -----------------------------------------------------------
  const dryDays = logged.filter((d) => d.hydrationMl > 0 && d.hydrationMl < targets.waterMl * 0.7);
  if (dryDays.length >= 3) {
    patterns.push({
      id: 'hydration-short',
      title: `Under your water target ${dryDays.length} of ${n} ${plural(n)}`,
      detail: `Target is ${(targets.waterMl / 1000).toFixed(1)} L. Mild dehydration alone lifts resting heart rate a few beats, which then reads as poor recovery.`,
      daysAffected: dryDays.length,
      daysConsidered: n,
      tone: 'concern',
      weight: 42,
    });
  }

  // --- Late eating ---------------------------------------------------------
  const lateDays = logged.filter((d) => d.lastMealHour != null && d.lastMealHour >= 22);
  if (lateDays.length >= 3) {
    patterns.push({
      id: 'late-eating',
      title: `Last meal after 10pm on ${lateDays.length} of ${n} ${plural(n)}`,
      detail:
        'Eating close to bedtime raises overnight heart rate and cuts deep sleep, which shows up as a low readiness score the next morning.',
      daysAffected: lateDays.length,
      daysConsidered: n,
      tone: 'concern',
      weight: 54,
    });
  }

  summary.patterns = patterns.sort((a, b) => b.weight - a.weight);
  return summary;
}

/** The single pattern most worth putting in the morning brief. */
export function headlinePattern(summary: WeeklyNutritionSummary): NutritionPattern | null {
  return summary.patterns.find((p) => p.tone === 'concern') ?? summary.patterns[0] ?? null;
}
