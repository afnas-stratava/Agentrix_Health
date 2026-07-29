import { rankRestaurants, headlineDiningPick } from '@/features/dining/rank';
import { dietaryConflict, FOOD_DATABASE, findFood } from '@/features/nutrition/food-database';
import type { Restaurant } from '@/schemas/dining';
import type { ResolvedProfile } from '@/schemas/profile';
import { HealthProfileSchema } from '@/schemas/profile';
import { EMPTY_MACROS, type NutritionTargets } from '@/schemas/nutrition';

function profile(overrides: Partial<ResolvedProfile> = {}): ResolvedProfile {
  return {
    ...HealthProfileSchema.parse({}),
    sex: 'female',
    birthYear: 1994,
    ageYears: 32,
    heightCm: 165,
    weightKg: 60,
    ...overrides,
  };
}

function restaurant(overrides: Partial<Restaurant> = {}): Restaurant {
  return {
    id: 'r1',
    name: 'Test Kitchen',
    cuisine: 'north-indian',
    providerTypes: [],
    rating: 4.4,
    ratingCount: 500,
    priceLevel: 2,
    distanceMetres: 300,
    address: null,
    openNow: null,
    source: 'fixture',
    mapsUri: null,
    ...overrides,
  };
}

const TARGETS: NutritionTargets = {
  calories: 2000,
  maintenanceCalories: 2000,
  energyBasis: 'estimated',
  macros: { proteinG: 90, carbsG: 225, fatG: 65, fibreG: 28 },
  addedSugarCeilingG: 25,
  waterMl: 2100,
  stepTarget: 8000,
  sleepTargetMinutes: 480,
  isCheatDay: false,
};

describe('dietaryConflict', () => {
  it('excludes an allergen match', () => {
    const paneer = findFood('paneer-tikka')!;
    expect(dietaryConflict(paneer, { dietPattern: 'omnivore', allergens: ['dairy'] })).toMatch(/dairy/);
  });

  it('excludes meat for a vegetarian', () => {
    const chicken = findFood('tandoori-chicken')!;
    expect(dietaryConflict(chicken, { dietPattern: 'vegetarian', allergens: [] })).toBe(
      'not vegetarian',
    );
  });

  it('allows fish for a pescatarian but not chicken', () => {
    expect(
      dietaryConflict(findFood('fish-curry')!, { dietPattern: 'pescatarian', allergens: [] }),
    ).toBeNull();
    expect(
      dietaryConflict(findFood('chicken-breast')!, { dietPattern: 'pescatarian', allergens: [] }),
    ).toBe('contains meat');
  });

  it('excludes pork and alcohol on a halal diet', () => {
    expect(dietaryConflict(findFood('bacon')!, { dietPattern: 'halal', allergens: [] })).toBe(
      'contains pork',
    );
    expect(dietaryConflict(findFood('beer')!, { dietPattern: 'halal', allergens: [] })).toBe(
      'contains alcohol',
    );
  });

  it('excludes onion- and garlic-bearing dishes on a Jain diet', () => {
    expect(dietaryConflict(findFood('pakora')!, { dietPattern: 'jain', allergens: [] })).toBe(
      'not Jain-friendly',
    );
    expect(dietaryConflict(findFood('idli')!, { dietPattern: 'jain', allergens: [] })).toBeNull();
  });
});

describe('rankRestaurants', () => {
  it('never suggests a dish containing a declared allergen', () => {
    const picks = rankRestaurants({
      restaurants: FOOD_DATABASE.map((_, index) =>
        restaurant({ id: `r${index}`, cuisine: 'north-indian' }),
      ).slice(0, 3),
      profile: profile({ allergens: ['dairy', 'gluten'] }),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
      mode: 'aligned',
    });

    for (const pick of picks) {
      for (const dish of pick.dishes) {
        const definition = findFood(dish.foodId)!;
        expect(definition.allergens).not.toContain('dairy');
        expect(definition.allergens).not.toContain('gluten');
      }
    }
  });

  it('keeps allergens excluded on a cheat day — indulgence is not a safety exemption', () => {
    const picks = rankRestaurants({
      restaurants: [restaurant({ cuisine: 'american' }), restaurant({ id: 'r2', cuisine: null })],
      profile: profile({ allergens: ['gluten'] }),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
      mode: 'cheat',
    });

    for (const pick of picks) {
      for (const dish of pick.dishes) {
        expect(findFood(dish.foodId)!.allergens).not.toContain('gluten');
      }
    }
  });

  it('drops a venue where nothing is edible rather than recommending it anyway', () => {
    const picks = rankRestaurants({
      // Every American-cuisine row in the table contains gluten, dairy or meat.
      restaurants: [restaurant({ cuisine: 'american' })],
      profile: profile({ dietPattern: 'vegan', allergens: ['gluten'] }),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
      mode: 'aligned',
    });

    expect(picks).toHaveLength(0);
  });

  it('favours the user’s top cuisine over an equally good alternative', () => {
    const picks = rankRestaurants({
      restaurants: [
        restaurant({ id: 'south', cuisine: 'south-indian' }),
        restaurant({ id: 'med', cuisine: 'mediterranean' }),
      ],
      profile: profile({ cuisines: ['south-indian', 'mediterranean'] }),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
      mode: 'aligned',
    });

    expect(picks[0]?.restaurant.id).toBe('south');
    expect(picks[0]?.reasons).toContain('your favourite cuisine');
  });

  it('inverts its preference for indulgent dishes in cheat mode', () => {
    const args = {
      restaurants: [restaurant({ cuisine: 'north-indian' })],
      profile: profile(),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
    };

    const aligned = rankRestaurants({ ...args, mode: 'aligned' });
    const cheat = rankRestaurants({ ...args, mode: 'cheat' });

    const alignedTop = aligned[0]!.dishes[0]!;
    const cheatTop = cheat[0]!.dishes[0]!;

    expect(alignedTop.foodId).not.toBe(cheatTop.foodId);
    const cheatDefinition = findFood(cheatTop.foodId)!;
    expect(
      cheatDefinition.tags.includes('fried') || cheatDefinition.tags.includes('sugary'),
    ).toBe(true);
  });

  it('penalises a dish that overshoots what is left in the budget', () => {
    const roomy = rankRestaurants({
      restaurants: [restaurant({ cuisine: 'north-indian' })],
      profile: profile(),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
      mode: 'aligned',
    });

    const nearlyFull = rankRestaurants({
      restaurants: [restaurant({ cuisine: 'north-indian' })],
      profile: profile(),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS, calories: 1850 },
      mode: 'aligned',
    });

    expect(nearlyFull[0]!.dishes[0]!.score).toBeLessThan(roomy[0]!.dishes[0]!.score);
  });

  it('respects a low-sodium preference by down-ranking salty dishes', () => {
    const [plain] = rankRestaurants({
      restaurants: [restaurant({ cuisine: 'east-asian' })],
      profile: profile(),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
      mode: 'aligned',
    });

    const [restricted] = rankRestaurants({
      restaurants: [restaurant({ cuisine: 'east-asian' })],
      profile: profile({ restrictions: ['low-sodium'] }),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
      mode: 'aligned',
    });

    const salty = restricted!.dishes.find((dish) => dish.macros.sodiumMg > 700);
    // Either the salty dish fell out of the top three, or it scored lower.
    if (salty != null) {
      const before = plain!.dishes.find((dish) => dish.foodId === salty.foodId);
      if (before != null) expect(salty.score).toBeLessThan(before.score);
    }
  });

  it('always attaches the not-a-menu disclosure to every dish', () => {
    const picks = rankRestaurants({
      restaurants: [restaurant()],
      profile: profile(),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
      mode: 'aligned',
    });

    for (const dish of picks[0]!.dishes) {
      expect(dish.basis).toMatch(/have not read this restaurant/i);
    }
  });

  it('works without targets, ranking on dish quality alone', () => {
    const picks = rankRestaurants({
      restaurants: [restaurant()],
      profile: profile(),
      targets: null,
      consumed: { ...EMPTY_MACROS },
      mode: 'aligned',
    });

    expect(picks.length).toBeGreaterThan(0);
    expect(picks[0]!.dishes.length).toBeGreaterThan(0);
  });
});

describe('headlineDiningPick', () => {
  it('is null with nothing to recommend', () => {
    expect(headlineDiningPick([])).toBeNull();
  });

  it('names the dishes and the venue', () => {
    const picks = rankRestaurants({
      restaurants: [restaurant({ name: 'Copper Pot' })],
      profile: profile(),
      targets: TARGETS,
      consumed: { ...EMPTY_MACROS },
      mode: 'aligned',
    });

    const headline = headlineDiningPick(picks);
    expect(headline).toContain('Copper Pot');
    expect(headline).toMatch(/kcal/);
  });
});
