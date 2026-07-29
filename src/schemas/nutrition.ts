import { z } from 'zod';
import { IsoDaySchema } from './health';
import { AllergenSchema, CuisineSchema } from './profile';

/**
 * Food logging vocabulary.
 *
 * Macros are stored per *logged portion*, not per 100 g — the user logged "two
 * rotis", and converting back and forth through a density figure is where
 * rounding error accumulates. The food database holds per-100 g values; the
 * scaling happens once, at log time, and the result is what persists.
 */

export const MacrosSchema = z.object({
  calories: z.number().min(0).max(10000),
  proteinG: z.number().min(0).max(500),
  carbsG: z.number().min(0).max(1000),
  fatG: z.number().min(0).max(500),
  fibreG: z.number().min(0).max(200).default(0),
  /** Free/added sugars, not total carbohydrate sugars. */
  addedSugarG: z.number().min(0).max(500).default(0),
  sodiumMg: z.number().min(0).max(20000).default(0),
});
export type Macros = z.infer<typeof MacrosSchema>;

export const EMPTY_MACROS: Macros = {
  calories: 0,
  proteinG: 0,
  carbsG: 0,
  fatG: 0,
  fibreG: 0,
  addedSugarG: 0,
  sodiumMg: 0,
};

export const MacroTargetsSchema = z.object({
  proteinG: z.number().min(0),
  carbsG: z.number().min(0),
  fatG: z.number().min(0),
  fibreG: z.number().min(0),
});
export type MacroTargets = z.infer<typeof MacroTargetsSchema>;

export const NutritionTargetsSchema = z.object({
  calories: z.number().min(0),
  /** What the user would eat to hold weight, before the goal offset. */
  maintenanceCalories: z.number().min(0),
  /**
   * Whether total expenditure came from wearable active energy or from the
   * declared activity multiplier. Surfaced in the UI — a user should know when
   * a number is measured and when it is a guess.
   */
  energyBasis: z.enum(['measured', 'estimated']),
  macros: MacroTargetsSchema,
  addedSugarCeilingG: z.number().min(0),
  waterMl: z.number().min(0),
  stepTarget: z.number().min(0),
  sleepTargetMinutes: z.number().min(0),
  isCheatDay: z.boolean().default(false),
});
export type NutritionTargets = z.infer<typeof NutritionTargetsSchema>;

// ---------------------------------------------------------------------------
// Food items
// ---------------------------------------------------------------------------

export const MealSlotSchema = z.enum(['breakfast', 'lunch', 'dinner', 'snack']);
export type MealSlot = z.infer<typeof MealSlotSchema>;

export const MEAL_SLOT_LABEL: Record<MealSlot, string> = {
  breakfast: 'Breakfast',
  lunch: 'Lunch',
  dinner: 'Dinner',
  snack: 'Snack',
};

/** Tags the dish ranker and the pattern analyser both filter on. */
export const FoodTagSchema = z.enum([
  'high-protein',
  'high-fibre',
  'low-carb',
  'wholegrain',
  'fried',
  'sugary',
  'ultra-processed',
  'iron-rich',
  'calcium-rich',
  'omega3-rich',
  'probiotic',
  'leafy-green',
  'vitamin-c-rich',
]);
export type FoodTag = z.infer<typeof FoodTagSchema>;

export const FOOD_TAG_LABEL: Record<FoodTag, string> = {
  'high-protein': 'High protein',
  'high-fibre': 'High fibre',
  'low-carb': 'Low carb',
  wholegrain: 'Wholegrain',
  fried: 'Fried',
  sugary: 'Sugary',
  'ultra-processed': 'Ultra-processed',
  'iron-rich': 'Iron-rich',
  'calcium-rich': 'Calcium-rich',
  'omega3-rich': 'Omega-3',
  probiotic: 'Probiotic',
  'leafy-green': 'Leafy greens',
  'vitamin-c-rich': 'Vitamin C',
};

/**
 * One row of the food database. `per` describes what the macros refer to, so a
 * portion multiplier is always unambiguous: `{ amount: 1, unit: 'roti' }` means
 * the macros below are for exactly one roti.
 */
export const FoodDefinitionSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  /** Shown under the name — "1 medium, ~45 g". */
  portionLabel: z.string().min(1),
  cuisine: CuisineSchema.nullable().default(null),
  macros: MacrosSchema,
  tags: z.array(FoodTagSchema).default([]),
  allergens: z.array(AllergenSchema).default([]),
  /** Diet patterns this food is compatible with. Used as a hard filter. */
  vegetarian: z.boolean().default(false),
  vegan: z.boolean().default(false),
  /** Contains onion/garlic/root vegetables — excluded for Jain diets. */
  jainSafe: z.boolean().default(false),
  containsPork: z.boolean().default(false),
  containsAlcohol: z.boolean().default(false),
});
export type FoodDefinition = z.infer<typeof FoodDefinitionSchema>;

// ---------------------------------------------------------------------------
// Log entries
// ---------------------------------------------------------------------------

/** How this entry's macros were arrived at — surfaced honestly in the UI. */
export const MealSourceSchema = z.enum(['photo', 'database', 'manual', 'restaurant', 'seed']);
export type MealSource = z.infer<typeof MealSourceSchema>;

export const LoggedFoodSchema = z.object({
  /** Null for a free-text entry with no database match. */
  foodId: z.string().nullable().default(null),
  name: z.string().min(1),
  /** Multiplier against the definition's portion. 2 = "two rotis". */
  portions: z.number().positive().max(50).default(1),
  macros: MacrosSchema,
  tags: z.array(FoodTagSchema).default([]),
});
export type LoggedFood = z.infer<typeof LoggedFoodSchema>;

export const MealEntrySchema = z.object({
  id: z.string().min(1),
  day: IsoDaySchema,
  loggedAt: z.string().datetime({ offset: true }),
  slot: MealSlotSchema,
  source: MealSourceSchema,
  /** Local URI of the photo, when one was taken. Never uploaded. */
  photoUri: z.string().nullable().default(null),
  foods: z.array(LoggedFoodSchema).min(1),
  /**
   * 0–1 confidence in the macro estimate. Photo entries start below 1 and the
   * UI keeps them editable; a user-confirmed entry is 1.
   */
  confidence: z.number().min(0).max(1).default(1),
  note: z.string().max(280).nullable().default(null),
});
export type MealEntry = z.infer<typeof MealEntrySchema>;

/** Water is logged as a running millilitre total per day, not as entries. */
export const HydrationEntrySchema = z.object({
  day: IsoDaySchema,
  ml: z.number().min(0).max(20000),
});
export type HydrationEntry = z.infer<typeof HydrationEntrySchema>;

export function sumMacros(items: Macros[]): Macros {
  return items.reduce<Macros>(
    (total, item) => ({
      calories: total.calories + item.calories,
      proteinG: total.proteinG + item.proteinG,
      carbsG: total.carbsG + item.carbsG,
      fatG: total.fatG + item.fatG,
      fibreG: total.fibreG + item.fibreG,
      addedSugarG: total.addedSugarG + item.addedSugarG,
      sodiumMg: total.sodiumMg + item.sodiumMg,
    }),
    { ...EMPTY_MACROS },
  );
}

export function scaleMacros(macros: Macros, factor: number): Macros {
  const round = (value: number) => Math.round(value * 10) / 10;
  return {
    calories: Math.round(macros.calories * factor),
    proteinG: round(macros.proteinG * factor),
    carbsG: round(macros.carbsG * factor),
    fatG: round(macros.fatG * factor),
    fibreG: round(macros.fibreG * factor),
    addedSugarG: round(macros.addedSugarG * factor),
    sodiumMg: Math.round(macros.sodiumMg * factor),
  };
}

export function mealMacros(meal: MealEntry): Macros {
  return sumMacros(meal.foods.map((food) => food.macros));
}
