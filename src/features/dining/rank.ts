import type { DiningMode, DishPick, Restaurant, RestaurantPick } from '@/schemas/dining';
import type { FoodDefinition, FoodTag, Macros, NutritionTargets } from '@/schemas/nutrition';
import { EMPTY_MACROS, sumMacros } from '@/schemas/nutrition';
import type { ResolvedProfile } from '@/schemas/profile';
import { FOOD_DATABASE, dietaryConflict } from '@/features/nutrition/food-database';

/**
 * Dish-level restaurant ranking.
 *
 * The unit of recommendation is a *dish*, not a venue: "there is a healthy
 * place 400 m away" is not actionable, and "order the dal tadka with two rotis
 * — that is 34 g of protein and fits the 780 kcal you have left" is.
 *
 * Dishes come from the same food table the logger uses, filtered by the
 * restaurant's cuisine. That is what makes the macros real: the numbers behind
 * a recommendation are the identical numbers that get written to the food log
 * if the user taps "I ate this". No menu is scraped, and the UI says so.
 */

const DISH_BASIS = 'Typical of this cuisine — we have not read this restaurant’s menu.';

export interface RankInput {
  restaurants: Restaurant[];
  profile: ResolvedProfile;
  targets: NutritionTargets | null;
  /** What the user has already eaten today. */
  consumed: Macros;
  mode: DiningMode;
  /** Food tags today's brief wants floated up (iron-rich, high-protein…). */
  focusTags?: FoodTag[];
  limit?: number;
}

/** Dishes plausible at a restaurant of this cuisine. */
function menuFor(cuisine: Restaurant['cuisine']): FoodDefinition[] {
  if (cuisine == null) {
    // An unknown cuisine gets the pan-cuisine staples rather than nothing —
    // a "restaurant" with no type tags still serves grilled chicken and salad.
    return FOOD_DATABASE.filter((food) => food.cuisine == null);
  }
  return FOOD_DATABASE.filter((food) => food.cuisine === cuisine);
}

interface DishScoreInput {
  food: FoodDefinition;
  profile: ResolvedProfile;
  remaining: { calories: number; proteinG: number; fibreG: number; sugarHeadroomG: number } | null;
  mode: DiningMode;
  focusTags: FoodTag[];
}

/**
 * Scores one dish 0–100 and explains itself. The rationale is built from the
 * terms that actually moved the score, so it can never claim a reason the
 * maths did not use.
 */
function scoreDish({ food, profile, remaining, mode, focusTags }: DishScoreInput): DishPick | null {
  // Hard filter: allergens and diet pattern are safety, not preference, and
  // they apply identically on a cheat day.
  if (dietaryConflict(food, { dietPattern: profile.dietPattern, allergens: profile.allergens }) != null) {
    return null;
  }

  let score = 50;
  const reasons: string[] = [];

  if (mode === 'cheat') {
    /**
     * Cheat mode inverts the objective: the user has decided to enjoy
     * themselves, and a ranker that keeps pushing grilled fish at them is
     * useless. Protein still scores, because a satisfying meal with protein in
     * it beats one without.
     */
    if (food.tags.includes('fried') || food.tags.includes('sugary')) {
      score += 22;
      reasons.push('the indulgent pick you came for');
    }
    if (food.macros.proteinG >= 20) {
      score += 10;
      reasons.push(`still carries ${Math.round(food.macros.proteinG)} g of protein`);
    }
    if (food.tags.includes('ultra-processed')) score += 4;
  } else {
    // --- Protein density -------------------------------------------------
    const proteinPer100Kcal = (food.macros.proteinG / Math.max(1, food.macros.calories)) * 100;
    if (proteinPer100Kcal >= 8) {
      score += 20;
      reasons.push(`${Math.round(food.macros.proteinG)} g of protein for ${food.macros.calories} kcal`);
    } else if (proteinPer100Kcal >= 5) {
      score += 10;
    }

    // --- Fibre ------------------------------------------------------------
    if (food.macros.fibreG >= 6) {
      score += 10;
      reasons.push(`${food.macros.fibreG.toFixed(0)} g of fibre`);
    }

    // --- Penalties --------------------------------------------------------
    if (food.tags.includes('fried')) score -= 16;
    if (food.tags.includes('sugary')) score -= 20;
    if (food.tags.includes('ultra-processed')) score -= 10;

    // --- Declared restrictions -------------------------------------------
    if (profile.restrictions.includes('no-fried') && food.tags.includes('fried')) score -= 30;
    if (profile.restrictions.includes('no-added-sugar') && food.macros.addedSugarG > 5) score -= 30;
    if (profile.restrictions.includes('low-sodium') && food.macros.sodiumMg > 700) {
      score -= 22;
      reasons.push('heavier on salt than you asked for');
    }
    if (profile.restrictions.includes('low-carb') && food.macros.carbsG > 40) score -= 20;
    if (profile.restrictions.includes('no-alcohol') && food.containsAlcohol) score -= 60;
  }

  // --- Today's focus (brief / cycle phase / flagged biomarker) ------------
  const matchedFocus = food.tags.filter((tag) => focusTags.includes(tag));
  if (matchedFocus.length > 0) {
    score += 8 * matchedFocus.length;
    reasons.push(`${matchedFocus[0]?.replace('-', ' ')} — what today's plan calls for`);
  }

  // --- Fit against what is actually left ---------------------------------
  if (remaining != null && mode === 'aligned') {
    if (remaining.calories > 0) {
      const share = food.macros.calories / remaining.calories;
      if (share <= 0.55) {
        score += 12;
        reasons.push(`leaves room in your ${Math.round(remaining.calories)} kcal budget`);
      } else if (share <= 0.85) {
        score += 4;
      } else if (share > 1.15) {
        score -= 24;
        reasons.push('more than you have left today');
      }
    }

    if (remaining.proteinG > 15 && food.macros.proteinG >= remaining.proteinG * 0.4) {
      score += 10;
      reasons.push(`closes most of your ${Math.round(remaining.proteinG)} g protein gap`);
    }

    if (food.macros.addedSugarG > remaining.sugarHeadroomG && food.macros.addedSugarG > 5) {
      score -= 18;
    }
  }

  const bounded = Math.max(0, Math.min(100, Math.round(score)));

  return {
    foodId: food.id,
    name: food.name,
    portionLabel: food.portionLabel,
    macros: food.macros,
    tags: food.tags,
    score: bounded,
    rationale:
      reasons.length > 0
        ? capitalise(reasons.slice(0, 2).join(', and '))
        : `${food.macros.calories} kcal, ${Math.round(food.macros.proteinG)} g protein`,
    basis: DISH_BASIS,
  };
}

function capitalise(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

/**
 * Distance decay. Sharp inside a kilometre, flat beyond — the difference
 * between 200 m and 600 m matters to someone deciding where to eat; the
 * difference between 3 km and 3.4 km does not.
 */
function distanceScore(metres: number | null): number {
  if (metres == null) return 0;
  if (metres <= 400) return 12;
  if (metres <= 800) return 8;
  if (metres <= 1500) return 4;
  if (metres <= 3000) return 0;
  return -8;
}

function ratingScore(rating: number | null, count: number): number {
  if (rating == null || count < 20) return 0; // too few reviews to mean anything
  return Math.round((rating - 3.8) * 10);
}

export function rankRestaurants({
  restaurants,
  profile,
  targets,
  consumed,
  mode,
  focusTags = [],
  limit = 12,
}: RankInput): RestaurantPick[] {
  const remaining =
    targets == null
      ? null
      : {
          calories: Math.max(0, targets.calories - consumed.calories),
          proteinG: Math.max(0, targets.macros.proteinG - consumed.proteinG),
          fibreG: Math.max(0, targets.macros.fibreG - consumed.fibreG),
          sugarHeadroomG: Math.max(0, targets.addedSugarCeilingG - consumed.addedSugarG),
        };

  const picks: RestaurantPick[] = [];

  for (const restaurant of restaurants) {
    const dishes = menuFor(restaurant.cuisine)
      .map((food) => scoreDish({ food, profile, remaining, mode, focusTags }))
      .filter((dish): dish is DishPick => dish != null)
      .sort((a, b) => b.score - a.score)
      .slice(0, 3);

    // A venue with nothing this user can eat is not a recommendation.
    if (dishes.length === 0) continue;

    const reasons: string[] = [];
    let score = dishes[0]?.score ?? 0;

    const cuisineRank = restaurant.cuisine ? profile.cuisines.indexOf(restaurant.cuisine) : -1;
    if (cuisineRank === 0) {
      score += 14;
      reasons.push('your favourite cuisine');
    } else if (cuisineRank > 0) {
      score += Math.max(4, 10 - cuisineRank * 2);
      reasons.push('a cuisine you eat often');
    }

    const distance = distanceScore(restaurant.distanceMetres);
    score += distance;
    if (distance >= 8 && restaurant.distanceMetres != null) {
      reasons.push(`${restaurant.distanceMetres} m away`);
    }

    score += ratingScore(restaurant.rating, restaurant.ratingCount);
    if (restaurant.rating != null && restaurant.rating >= 4.4 && restaurant.ratingCount >= 100) {
      reasons.push(`rated ${restaurant.rating.toFixed(1)}`);
    }

    if (dishes[0] != null) reasons.push(dishes[0].rationale.toLowerCase());

    /**
     * The combo is the top dish plus, in aligned mode, the best complementary
     * one that still fits the remaining budget — the "dal tadka + roti" shape
     * of recommendation rather than a single item.
     */
    const combo: DishPick[] = [dishes[0]].filter((d): d is DishPick => d != null);
    if (mode === 'aligned' && remaining != null && dishes[1] != null) {
      const together = combo[0]!.macros.calories + dishes[1].macros.calories;
      if (remaining.calories === 0 || together <= remaining.calories * 1.05) {
        combo.push(dishes[1]);
      }
    }

    picks.push({
      restaurant,
      score: Math.max(0, Math.min(100, Math.round(score))),
      dishes,
      comboMacros: combo.length > 0 ? sumMacros(combo.map((d) => d.macros)) : { ...EMPTY_MACROS },
      reasons: reasons.slice(0, 3),
    });
  }

  return picks.sort((a, b) => b.score - a.score).slice(0, limit);
}

/**
 * The single sentence the Today screen shows: what to order, where, and why.
 * Returns null when there is nothing worth interrupting the user with.
 */
export function headlineDiningPick(picks: RestaurantPick[]): string | null {
  const top = picks[0];
  if (top == null) return null;

  const dishNames = top.dishes.slice(0, 2).map((d) => d.name.toLowerCase());
  const dishPhrase = dishNames.length > 1 ? `${dishNames[0]} with ${dishNames[1]}` : dishNames[0];

  return `Order the ${dishPhrase} at ${top.restaurant.name} — ${top.comboMacros.calories} kcal, ${Math.round(top.comboMacros.proteinG)} g protein.`;
}
