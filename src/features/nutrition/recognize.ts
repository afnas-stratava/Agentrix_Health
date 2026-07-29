import type { Cuisine } from '@/schemas/profile';
import type { FoodDefinition, MealSlot } from '@/schemas/nutrition';
import { FOOD_DATABASE, dietaryConflict } from './food-database';

/**
 * Plate suggestion for photo logging.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * THIS DOES NOT LOOK AT THE PHOTO. There is no vision model in this build.
 *
 * What it does is narrow ~90 foods down to the handful a given user plausibly
 * ate at a given meal — using their cuisine preferences, dietary constraints,
 * the time of day and their own logging history — and let them confirm in two
 * taps. The photo is still captured and attached to the entry, so the log is
 * visual; the macros come from the user's confirmation, not from a guess we
 * dressed up as recognition.
 *
 * The UI must therefore never say "we identified your food". It says "what's on
 * the plate?" and pre-selects likely answers. `SUGGESTION_BASIS` below is
 * rendered verbatim in the sheet so the mechanism is never misrepresented.
 *
 * To make this real, implement `recognizePlate` against a vision endpoint and
 * return the same `PlateSuggestion[]` shape; every call site downstream already
 * treats confidence below 1 as "needs confirming", so nothing else changes.
 * ─────────────────────────────────────────────────────────────────────────────
 */

export const SUGGESTION_BASIS =
  'Ranked from your cuisines, diet and the time of day — not from the photo. Tap to confirm what you actually ate.';

export interface PlateSuggestion {
  food: FoodDefinition;
  /**
   * 0–1, and never 1: these are candidates, not identifications. The log entry
   * only reaches full confidence once the user confirms it.
   */
  confidence: number;
  /** Why this surfaced, shown as a caption. */
  reason: string;
}

export interface SuggestInput {
  slot: MealSlot;
  cuisines: Cuisine[];
  dietPattern: string;
  allergens: Parameters<typeof dietaryConflict>[1]['allergens'];
  /** Food IDs the user has logged before, most recent first. */
  recentFoodIds?: string[];
  /** Stable seed so the same photo always yields the same ordering. */
  seed?: string;
  limit?: number;
}

/**
 * Which foods make sense in which slot. A dosa at 9pm is not impossible, it is
 * just less likely than at 9am, and the ordering should reflect that.
 */
const SLOT_AFFINITY: Record<MealSlot, readonly string[]> = {
  breakfast: [
    'idli',
    'plain-dosa',
    'masala-dosa',
    'upma',
    'ven-pongal',
    'uttapam',
    'oats-porridge',
    'greek-yoghurt',
    'boiled-eggs',
    'veg-omelette',
    'avocado-toast',
    'aloo-paratha',
    'shakshuka',
    'banana',
    'filter-coffee',
    'masala-chai',
    'black-coffee',
  ],
  lunch: [
    'dal-tadka',
    'rajma',
    'chole',
    'roti',
    'plain-rice',
    'brown-rice',
    'curd-rice',
    'sambar',
    'mixed-sabzi',
    'bhindi-masala',
    'grilled-chicken-salad',
    'chickpea-salad',
    'greek-salad',
    'chicken-biryani',
    'falafel-wrap',
    'chicken-shawarma-plate',
    'tabbouleh',
    'pizza-slice',
    'cheeseburger',
  ],
  dinner: [
    'roti',
    'dal-tadka',
    'dal-makhani',
    'palak-paneer',
    'paneer-tikka',
    'tandoori-chicken',
    'chicken-tikka',
    'butter-chicken',
    'fish-curry',
    'grilled-salmon',
    'chicken-breast',
    'tofu-stirfry',
    'jeera-rice',
    'mixed-sabzi',
    'lentil-soup',
    'salmon-sushi',
    'pho',
    'pad-thai',
    'chicken-teriyaki',
  ],
  snack: [
    'almonds',
    'walnuts',
    'banana',
    'orange',
    'guava',
    'greek-yoghurt',
    'whey-shake',
    'samosa',
    'pakora',
    'medu-vada',
    'chocolate-bar',
    'ice-cream',
    'gulab-jamun',
    'sweet-lassi',
    'cola',
    'fries',
    'edamame',
    'coconut-chutney',
  ],
};

/** FNV-1a — small, dependency-free, and stable across runs. */
function hash(input: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < input.length; i += 1) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

export function suggestPlateContents({
  slot,
  cuisines,
  dietPattern,
  allergens,
  recentFoodIds = [],
  seed = '',
  limit = 6,
}: SuggestInput): PlateSuggestion[] {
  const affinity = SLOT_AFFINITY[slot];
  const seedValue = hash(`${seed}|${slot}`);

  const scored: PlateSuggestion[] = [];

  for (const food of FOOD_DATABASE) {
    // Never suggest something the user cannot eat. This is the one hard filter.
    if (dietaryConflict(food, { dietPattern, allergens }) != null) continue;

    const slotIndex = affinity.indexOf(food.id);
    if (slotIndex === -1) continue;

    // Base score decays down the slot list.
    let score = 1 - slotIndex / affinity.length;
    const reasons: string[] = [];

    const cuisineRank = food.cuisine ? cuisines.indexOf(food.cuisine) : -1;
    if (cuisineRank === 0) {
      score += 0.45;
      reasons.push('your top cuisine');
    } else if (cuisineRank > 0) {
      score += 0.3 - cuisineRank * 0.05;
      reasons.push('a cuisine you picked');
    }

    const recentIndex = recentFoodIds.indexOf(food.id);
    if (recentIndex !== -1) {
      // Logged recently — people eat the same twenty things.
      score += Math.max(0.1, 0.4 - recentIndex * 0.03);
      reasons.push('you logged this recently');
    }

    /**
     * A small deterministic jitter keyed on the photo, so two different photos
     * of two different lunches do not present an identical list. Bounded well
     * below the signal terms above so it reorders ties, never rankings.
     */
    score += (hash(`${food.id}|${seedValue}`) % 100) / 1000;

    scored.push({
      food,
      // Held below 0.8 on purpose: these are candidates awaiting confirmation.
      confidence: Math.min(0.78, Math.round(score * 100) / 100),
      reason: reasons[0] ?? `common at ${slot}`,
    });
  }

  return scored.sort((a, b) => b.confidence - a.confidence).slice(0, limit);
}

/** Slot inferred from the clock, used to pre-select the picker. */
export function slotForTime(now: Date = new Date()): MealSlot {
  const hour = now.getHours();
  if (hour < 11) return 'breakfast';
  if (hour < 16) return 'lunch';
  if (hour < 22) return 'dinner';
  return 'snack';
}
