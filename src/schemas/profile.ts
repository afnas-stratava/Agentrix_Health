import { z } from 'zod';
import { IsoDaySchema } from './health';

/**
 * The user-declared half of the health picture.
 *
 * Everything here is *stated*, never inferred: telemetry tells us how someone
 * slept, and blood work tells us what is circulating, but only the user can
 * tell us they are vegetarian, allergic to peanuts, or training for a race.
 * The nutrition targets, the morning brief and the restaurant ranker all read
 * from this file, so a field added here shows up in three features at once.
 *
 * Biological sex and birth year deliberately live in `settings.store` — they
 * were already wired into the lab reference-range resolver before this profile
 * existed, and `useProfile()` recombines them into one object for consumers.
 */

// ---------------------------------------------------------------------------
// Goals
// ---------------------------------------------------------------------------

export const HealthGoalSchema = z.enum([
  'weight-loss',
  'muscle-gain',
  'general-wellness',
  'manage-condition',
]);
export type HealthGoal = z.infer<typeof HealthGoalSchema>;

export const HEALTH_GOAL_META: Record<
  HealthGoal,
  { label: string; hint: string; /** kcal offset applied to maintenance. */ calorieOffset: number }
> = {
  'weight-loss': {
    label: 'Lose weight',
    hint: 'A moderate deficit — about 0.5 kg a week',
    // ~500 kcal/day is the largest deficit that reliably preserves lean mass
    // without wrecking recovery, which is the metric this app watches.
    calorieOffset: -500,
  },
  'muscle-gain': {
    label: 'Build muscle',
    hint: 'A small surplus with a high protein floor',
    calorieOffset: 250,
  },
  'general-wellness': {
    label: 'Feel better day to day',
    hint: 'Maintain weight, optimise sleep and energy',
    calorieOffset: 0,
  },
  'manage-condition': {
    label: 'Manage a condition',
    hint: 'Targets shaped around what you tell us below',
    calorieOffset: 0,
  },
};

// ---------------------------------------------------------------------------
// Conditions
// ---------------------------------------------------------------------------

export const ConditionSchema = z.enum([
  'prediabetes',
  'type2-diabetes',
  'hypertension',
  'high-cholesterol',
  'pcos',
  'hypothyroidism',
  'anaemia',
  'fatty-liver',
]);
export type Condition = z.infer<typeof ConditionSchema>;

export const CONDITION_LABEL: Record<Condition, string> = {
  prediabetes: 'Prediabetes',
  'type2-diabetes': 'Type 2 diabetes',
  hypertension: 'High blood pressure',
  'high-cholesterol': 'High cholesterol',
  pcos: 'PCOS',
  hypothyroidism: 'Hypothyroidism',
  anaemia: 'Anaemia',
  'fatty-liver': 'Fatty liver',
};

// ---------------------------------------------------------------------------
// Diet
// ---------------------------------------------------------------------------

/**
 * A hard constraint on what can be recommended. Unlike a preference, violating
 * one of these is a bug — the dish ranker filters on it rather than scoring it.
 */
export const DietPatternSchema = z.enum([
  'omnivore',
  'vegetarian',
  'eggetarian',
  'vegan',
  'pescatarian',
  'halal',
  'jain',
]);
export type DietPattern = z.infer<typeof DietPatternSchema>;

export const DIET_PATTERN_META: Record<DietPattern, { label: string; hint: string }> = {
  omnivore: { label: 'No restrictions', hint: 'Everything is on the table' },
  vegetarian: { label: 'Vegetarian', hint: 'No meat or fish; dairy is fine' },
  eggetarian: { label: 'Eggetarian', hint: 'Vegetarian plus eggs' },
  vegan: { label: 'Vegan', hint: 'No animal products at all' },
  pescatarian: { label: 'Pescatarian', hint: 'Fish and seafood, no other meat' },
  halal: { label: 'Halal', hint: 'Halal meat only, no pork or alcohol' },
  jain: { label: 'Jain', hint: 'No meat, eggs, root vegetables, onion or garlic' },
};

export const AllergenSchema = z.enum([
  'peanut',
  'tree-nut',
  'dairy',
  'gluten',
  'egg',
  'soy',
  'shellfish',
  'fish',
  'sesame',
]);
export type Allergen = z.infer<typeof AllergenSchema>;

export const ALLERGEN_LABEL: Record<Allergen, string> = {
  peanut: 'Peanuts',
  'tree-nut': 'Tree nuts',
  dairy: 'Dairy',
  gluten: 'Gluten',
  egg: 'Eggs',
  soy: 'Soy',
  shellfish: 'Shellfish',
  fish: 'Fish',
  sesame: 'Sesame',
};

/** Softer than an allergy — down-ranks a dish rather than excluding it. */
export const RestrictionSchema = z.enum([
  'low-sodium',
  'low-carb',
  'no-added-sugar',
  'low-fodmap',
  'no-alcohol',
  'no-fried',
]);
export type Restriction = z.infer<typeof RestrictionSchema>;

export const RESTRICTION_LABEL: Record<Restriction, string> = {
  'low-sodium': 'Low sodium',
  'low-carb': 'Low carb',
  'no-added-sugar': 'No added sugar',
  'low-fodmap': 'Low FODMAP',
  'no-alcohol': 'No alcohol',
  'no-fried': 'Nothing deep-fried',
};

export const CuisineSchema = z.enum([
  'north-indian',
  'south-indian',
  'mediterranean',
  'middle-eastern',
  'east-asian',
  'japanese',
  'thai',
  'mexican',
  'american',
  'continental',
]);
export type Cuisine = z.infer<typeof CuisineSchema>;

export const CUISINE_LABEL: Record<Cuisine, string> = {
  'north-indian': 'North Indian',
  'south-indian': 'South Indian',
  mediterranean: 'Mediterranean',
  'middle-eastern': 'Middle Eastern',
  'east-asian': 'East Asian',
  japanese: 'Japanese',
  thai: 'Thai',
  mexican: 'Mexican',
  american: 'American',
  continental: 'Continental',
};

// ---------------------------------------------------------------------------
// Activity
// ---------------------------------------------------------------------------

export const ActivityLevelSchema = z.enum([
  'sedentary',
  'light',
  'moderate',
  'active',
  'very-active',
]);
export type ActivityLevel = z.infer<typeof ActivityLevelSchema>;

/**
 * Physical-activity multipliers applied to basal metabolic rate. These are the
 * conventional Harris–Benedict/Mifflin factors; the brief prefers measured
 * active energy from HealthKit when a wearable is attached and only falls back
 * to these when it is not.
 */
export const ACTIVITY_META: Record<
  ActivityLevel,
  { label: string; hint: string; multiplier: number }
> = {
  sedentary: { label: 'Sedentary', hint: 'Desk job, little deliberate exercise', multiplier: 1.2 },
  light: { label: 'Lightly active', hint: 'Walks most days, 1–2 workouts a week', multiplier: 1.375 },
  moderate: { label: 'Moderately active', hint: '3–4 workouts a week', multiplier: 1.55 },
  active: { label: 'Active', hint: '5–6 workouts a week', multiplier: 1.725 },
  'very-active': {
    label: 'Very active',
    hint: 'Daily training or physical job',
    multiplier: 1.9,
  },
};

// ---------------------------------------------------------------------------
// Menstrual cycle
// ---------------------------------------------------------------------------

export const CycleProfileSchema = z.object({
  /** Off by default; nothing about cycles renders until this is switched on. */
  tracks: z.boolean().default(false),
  /**
   * First days of logged periods, oldest first. Kept as a list rather than a
   * single date so cycle length can be *measured* from the user's own history
   * instead of taken from the textbook 28 days — which very few people have.
   *
   * Logged in-app: `react-native-health` exposes no menstrual-flow category,
   * so HealthKit cannot supply this even though iOS itself records it.
   */
  periodStarts: z.array(IsoDaySchema).default([]),
  /** Fallback used until two periods have been logged. */
  averageCycleDays: z.number().int().min(18).max(60).default(28),
  averagePeriodDays: z.number().int().min(1).max(14).default(5),
  /** Set when a coil, implant or continuous pill makes phase maths meaningless. */
  hormonalContraception: z.boolean().default(false),
});
export type CycleProfile = z.infer<typeof CycleProfileSchema>;

// ---------------------------------------------------------------------------
// The profile
// ---------------------------------------------------------------------------

export const HealthProfileSchema = z.object({
  displayName: z.string().max(60).nullable().default(null),
  goal: HealthGoalSchema.default('general-wellness'),
  conditions: z.array(ConditionSchema).default([]),

  heightCm: z.number().min(90).max(250).nullable().default(null),
  weightKg: z.number().min(25).max(350).nullable().default(null),
  /** Only meaningful for weight-loss and muscle-gain goals. */
  targetWeightKg: z.number().min(25).max(350).nullable().default(null),
  /** Self-declared; used only when no wearable energy data exists. */
  activityLevel: ActivityLevelSchema.default('light'),

  dietPattern: DietPatternSchema.default('omnivore'),
  allergens: z.array(AllergenSchema).default([]),
  restrictions: z.array(RestrictionSchema).default([]),
  /**
   * Ordered most-preferred first. The restaurant ranker treats position as a
   * weight, so "prefers Indian" genuinely floats Indian-healthy options up
   * rather than merely tagging them.
   */
  cuisines: z.array(CuisineSchema).default([]),
  /** Spice tolerance shifts dish picks inside a cuisine, not across cuisines. */
  spiceTolerance: z.enum(['mild', 'medium', 'hot']).default('medium'),

  cycle: CycleProfileSchema.default({
    tracks: false,
    periodStarts: [],
    averageCycleDays: 28,
    averagePeriodDays: 5,
    hormonalContraception: false,
  }),
});
export type HealthProfile = z.infer<typeof HealthProfileSchema>;

/**
 * Composite passed to the targets calculator, the brief composer and the dish
 * ranker: the declared profile plus the two demographic fields that live in
 * settings. Assembled by `useProfile()`.
 */
export interface ResolvedProfile extends HealthProfile {
  sex: 'male' | 'female' | 'unspecified';
  birthYear: number | null;
  /** Derived from `birthYear`; null when it was never provided. */
  ageYears: number | null;
}

/** True once we know enough to compute calorie and macro targets. */
export function canComputeTargets(profile: ResolvedProfile): boolean {
  return profile.heightCm != null && profile.weightKg != null && profile.ageYears != null;
}

export function bodyMassIndex(profile: Pick<HealthProfile, 'heightCm' | 'weightKg'>): number | null {
  if (profile.heightCm == null || profile.weightKg == null) return null;
  const metres = profile.heightCm / 100;
  return Math.round((profile.weightKg / (metres * metres)) * 10) / 10;
}
