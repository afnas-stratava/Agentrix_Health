import type { DailySnapshot } from '@/schemas/health';
import type { ResolvedProfile } from '@/schemas/profile';
import { ACTIVITY_META, HEALTH_GOAL_META } from '@/schemas/profile';
import type { CyclePhase } from '@/features/cycle/phase';
import type { MacroTargets, NutritionTargets } from '@/schemas/nutrition';

/**
 * Daily energy, macro, hydration and movement targets.
 *
 * Every number here is derived from published equations rather than generated,
 * so the same profile always produces the same targets and the brief can be
 * regenerated offline. Where a wearable can measure something we would
 * otherwise estimate — total energy expenditure, in practice — the measurement
 * wins and the activity multiplier is only a fallback.
 */

/** Mifflin–St Jeor, the best-validated BMR estimator for the general adult population. */
export function basalMetabolicRate(profile: ResolvedProfile): number | null {
  const { weightKg, heightCm, ageYears, sex } = profile;
  if (weightKg == null || heightCm == null || ageYears == null) return null;

  const base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;

  switch (sex) {
    case 'male':
      return base + 5;
    case 'female':
      return base - 161;
    // With sex unstated, split the 166 kcal difference rather than silently
    // assuming male — a 5% error in either direction beats a 10% one.
    case 'unspecified':
      return base - 78;
  }
}

/**
 * Median active energy across the trailing week, in kcal. HealthKit reports
 * *active* energy (above resting), which is exactly the term the activity
 * multiplier is standing in for.
 */
function measuredActiveEnergy(series: DailySnapshot[]): number | null {
  const values = series
    .slice(-7)
    .map((day) => day.activeEnergy)
    .filter((value): value is number => value != null && value > 0);

  if (values.length < 4) return null; // too sparse to trust as a habit

  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? ((sorted[mid - 1] ?? 0) + (sorted[mid] ?? 0)) / 2 : (sorted[mid] ?? 0);
}

export interface TargetInput {
  profile: ResolvedProfile;
  /** Trailing telemetry, newest last. Used to measure rather than estimate. */
  series: DailySnapshot[];
  /** Null when the user does not track a cycle. */
  phase: CyclePhase | null;
  /** Cheat days lift the calorie ceiling and relax the sugar cap. */
  isCheatDay?: boolean;
}

/**
 * Protein floor in g/kg of bodyweight.
 *
 * The RDA (0.8 g/kg) is a deficiency-prevention floor, not an optimum. These
 * are the figures used in the resistance-training and sarcopenia literature.
 */
function proteinPerKg(profile: ResolvedProfile): number {
  switch (profile.goal) {
    case 'muscle-gain':
      return 1.8;
    // In a deficit, protein is what protects lean mass, so it goes *up* even
    // as total energy comes down.
    case 'weight-loss':
      return 1.6;
    case 'manage-condition':
      return profile.conditions.includes('type2-diabetes') ||
        profile.conditions.includes('prediabetes')
        ? 1.5
        : 1.2;
    case 'general-wellness':
      return 1.2;
  }
}

function macroSplit(profile: ResolvedProfile, calories: number, weightKg: number): MacroTargets {
  const proteinG = Math.round(proteinPerKg(profile) * weightKg);

  // Carbohydrate share, before the protein and fat floors are honoured.
  let carbShare = 0.45;
  if (profile.restrictions.includes('low-carb')) carbShare = 0.25;
  if (profile.conditions.includes('type2-diabetes') || profile.conditions.includes('prediabetes')) {
    carbShare = Math.min(carbShare, 0.35);
  }
  if (profile.conditions.includes('pcos')) carbShare = Math.min(carbShare, 0.35);

  const carbsG = Math.round((calories * carbShare) / 4);
  // Fat takes the remainder, with a 0.5 g/kg floor for hormone synthesis.
  const remainingKcal = calories - proteinG * 4 - carbsG * 4;
  const fatG = Math.max(Math.round(weightKg * 0.5), Math.round(remainingKcal / 9));

  // Fibre: 14 g per 1000 kcal, the Institute of Medicine's adequate intake.
  const fibreG = Math.round((calories / 1000) * 14);

  return { proteinG, carbsG, fatG, fibreG };
}

/**
 * Added-sugar ceiling in grams. WHO conditional recommendation is under 5% of
 * energy; the AHA caps are 25 g (women) and 36 g (men). We take the stricter of
 * the two so the number is defensible either way.
 */
function addedSugarCeiling(profile: ResolvedProfile, calories: number): number {
  const fivePercent = Math.round((calories * 0.05) / 4);
  const ahaCap = profile.sex === 'male' ? 36 : 25;
  const base = Math.min(fivePercent, ahaCap);

  if (
    profile.conditions.includes('type2-diabetes') ||
    profile.conditions.includes('prediabetes') ||
    profile.conditions.includes('fatty-liver')
  ) {
    return Math.round(base * 0.6);
  }
  return base;
}

export function computeTargets({
  profile,
  series,
  phase,
  isCheatDay = false,
}: TargetInput): NutritionTargets | null {
  const bmr = basalMetabolicRate(profile);
  const weightKg = profile.weightKg;
  if (bmr == null || weightKg == null) return null;

  const measured = measuredActiveEnergy(series);
  const maintenance =
    measured != null
      ? // Resting expenditure (BMR plus the thermic effect of food, ~10%) plus
        // what the watch actually saw the user burn.
        Math.round(bmr * 1.1 + measured)
      : Math.round(bmr * ACTIVITY_META[profile.activityLevel].multiplier);

  let calories = maintenance + HEALTH_GOAL_META[profile.goal].calorieOffset;

  /**
   * Luteal-phase resting expenditure runs measurably higher — the reported
   * range is 2–12%; 5% is the conservative middle. Not applying it is why
   * generic trackers tell people they overate in the week before their period.
   */
  if (phase?.name === 'luteal') calories = Math.round(calories * 1.05);

  // Never prescribe below the floor at which micronutrient adequacy becomes
  // hard, regardless of what the deficit maths says.
  const floor = profile.sex === 'male' ? 1500 : 1200;
  calories = Math.max(floor, calories);

  if (isCheatDay) calories = Math.round(calories * 1.15);

  const macros = macroSplit(profile, calories, weightKg);

  /**
   * Hydration: 35 mL/kg baseline, plus replacement for measured sweat loss
   * approximated at 500 mL per 500 kcal of active energy.
   */
  const activeToday = series[series.length - 1]?.activeEnergy ?? measured ?? 0;
  const waterMl = Math.round((weightKg * 35 + (activeToday / 500) * 500) / 50) * 50;

  /**
   * Step target: nudge from the trailing baseline rather than prescribing a
   * round 10,000 to someone who averages 4,000. Capped so a rest day after a
   * heavy week is not framed as a failure.
   */
  const recentSteps = series
    .slice(-14)
    .map((d) => d.steps)
    .filter((v): v is number => v != null);
  const stepBaseline =
    recentSteps.length > 0
      ? recentSteps.reduce((sum, v) => sum + v, 0) / recentSteps.length
      : 6000;
  const stepTarget = Math.min(14000, Math.round((stepBaseline * 1.08) / 250) * 250);

  /**
   * Sleep target: 8 h for adults, extended when the trailing week ran a debt.
   * Anything above 9 h stops being a target and becomes a symptom.
   */
  const recentSleep = series
    .slice(-7)
    .map((d) => (d.sleep ? d.sleep.asleepMinutes : null))
    .filter((v): v is number => v != null);
  const sleepMean =
    recentSleep.length > 0 ? recentSleep.reduce((s, v) => s + v, 0) / recentSleep.length : 450;
  const sleepTargetMinutes = Math.min(540, Math.max(450, Math.round((480 + (480 - sleepMean) * 0.5) / 15) * 15));

  return {
    calories,
    maintenanceCalories: maintenance,
    energyBasis: measured != null ? 'measured' : 'estimated',
    macros,
    addedSugarCeilingG: addedSugarCeiling(profile, calories),
    waterMl,
    stepTarget,
    sleepTargetMinutes,
    isCheatDay,
  };
}
