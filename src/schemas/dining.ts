import { z } from 'zod';
import { CuisineSchema } from './profile';
import { FoodTagSchema, MacrosSchema } from './nutrition';

/**
 * Restaurant and dish recommendations.
 *
 * IMPORTANT, AND SURFACED IN THE UI: nothing here reads an actual menu.
 * Places APIs return a restaurant's name, location, rating and type — never its
 * dish list, and certainly never nutrition for those dishes. What this feature
 * does is match *the kind of food a place serves* against what the user has
 * left in their macro budget today, and name specific dishes that are typical
 * of that cuisine.
 *
 * So "order the dal tadka and two rotis here" means "at a North Indian place,
 * that combination fits your remaining macros" — not "we read their menu and
 * they have it". `DishPick.basis` carries that distinction into the UI, and
 * every card renders it.
 */

export const RestaurantSourceSchema = z.enum(['places', 'fixture']);
export type RestaurantSource = z.infer<typeof RestaurantSourceSchema>;

export const PriceLevelSchema = z.number().int().min(1).max(4);

export const RestaurantSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  /** Inferred from the provider's type tags; null when nothing matched. */
  cuisine: CuisineSchema.nullable().default(null),
  /** Raw provider type strings, kept for debugging a bad cuisine inference. */
  providerTypes: z.array(z.string()).default([]),
  rating: z.number().min(0).max(5).nullable().default(null),
  ratingCount: z.number().int().nonnegative().default(0),
  priceLevel: PriceLevelSchema.nullable().default(null),
  /** Metres from the user. Null when location was unavailable. */
  distanceMetres: z.number().nonnegative().nullable().default(null),
  address: z.string().nullable().default(null),
  openNow: z.boolean().nullable().default(null),
  source: RestaurantSourceSchema,
  /** Deep link to the provider's listing, for directions. */
  mapsUri: z.string().nullable().default(null),
});
export type Restaurant = z.infer<typeof RestaurantSchema>;

/** A specific dish recommendation, with the macros that justify it. */
export const DishPickSchema = z.object({
  foodId: z.string().min(1),
  name: z.string().min(1),
  portionLabel: z.string().min(1),
  macros: MacrosSchema,
  tags: z.array(FoodTagSchema).default([]),
  /** 0–100. */
  score: z.number().min(0).max(100),
  /** One line: why this dish, for this person, today. */
  rationale: z.string().min(1),
  /** Standing disclosure that this is cuisine-typical, not menu-verified. */
  basis: z.string().min(1),
});
export type DishPick = z.infer<typeof DishPickSchema>;

export const RestaurantPickSchema = z.object({
  restaurant: RestaurantSchema,
  score: z.number().min(0).max(100),
  /** Best two or three dishes, already ranked. */
  dishes: z.array(DishPickSchema),
  /** Combined macros if the user ordered the top pick(s) shown. */
  comboMacros: MacrosSchema,
  /** Why this restaurant floated up: cuisine match, macro fit, distance. */
  reasons: z.array(z.string()).default([]),
});
export type RestaurantPick = z.infer<typeof RestaurantPickSchema>;

/**
 * Cheat day is an explicit user choice, never inferred. In cheat mode the
 * ranker stops penalising indulgence and starts optimising for "the best
 * version of what you actually want" — allergens and diet pattern remain hard
 * filters, because those are safety, not preference.
 */
export const DiningModeSchema = z.enum(['aligned', 'cheat']);
export type DiningMode = z.infer<typeof DiningModeSchema>;
