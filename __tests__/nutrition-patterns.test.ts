import { analyseWeek, headlinePattern, MIN_LOGGED_DAYS } from '@/features/nutrition/patterns';
import type { MealEntry, MealSlot, NutritionTargets } from '@/schemas/nutrition';
import { MealEntrySchema, scaleMacros } from '@/schemas/nutrition';
import { findFood } from '@/features/nutrition/food-database';
import { addDays, toIsoDay } from '@/lib/date';

const NOW = new Date('2026-07-29T20:00:00+05:30');

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

/** Builds one meal `daysAgo` before NOW. */
function meal(daysAgo: number, slot: MealSlot, foodId: string, portions = 1, hour = 13): MealEntry {
  const date = addDays(NOW, -daysAgo);
  const loggedAt = new Date(date);
  loggedAt.setHours(hour, 0, 0, 0);

  const definition = findFood(foodId);
  if (definition == null) throw new Error(`Unknown fixture food: ${foodId}`);

  return MealEntrySchema.parse({
    id: `${daysAgo}-${slot}-${foodId}`,
    day: toIsoDay(date),
    loggedAt: loggedAt.toISOString(),
    slot,
    source: 'database',
    foods: [
      {
        foodId,
        name: definition.name,
        portions,
        macros: scaleMacros(definition.macros, portions),
        tags: definition.tags,
      },
    ],
  });
}

/** A plausible, adequate day so the denominator counts it as logged. */
function solidDay(daysAgo: number): MealEntry[] {
  return [
    meal(daysAgo, 'breakfast', 'oats-porridge', 1, 8),
    meal(daysAgo, 'lunch', 'grilled-chicken-salad', 1, 13),
    meal(daysAgo, 'dinner', 'dal-tadka', 2, 20),
    meal(daysAgo, 'dinner', 'roti', 3, 20),
  ];
}

describe('analyseWeek', () => {
  it('reports sparseness instead of inventing findings', () => {
    const summary = analyseWeek(solidDay(1), {}, TARGETS, { now: NOW });
    expect(summary.isSparse).toBe(true);
    expect(summary.patterns).toHaveLength(0);
  });

  it('starts analysing once enough days are logged', () => {
    const meals = [0, 1, 2, 3].flatMap(solidDay);
    const summary = analyseWeek(meals, {}, TARGETS, { now: NOW });

    expect(summary.isSparse).toBe(false);
    expect(summary.loggedDays).toBeGreaterThanOrEqual(MIN_LOGGED_DAYS);
  });

  it('does not count a single banana as a logged day', () => {
    const meals = [...solidDay(0), ...solidDay(1), ...solidDay(2), meal(3, 'snack', 'banana')];
    expect(analyseWeek(meals, {}, TARGETS, { now: NOW }).loggedDays).toBe(3);
  });

  it('counts sugar-over days rather than averaging them away', () => {
    const meals = [
      ...solidDay(0),
      ...solidDay(1),
      ...solidDay(2),
      ...solidDay(3),
      // Four heavy dessert days: ~28 g added sugar each, over the 25 g ceiling.
      ...[0, 1, 2, 3].map((offset) => meal(offset, 'snack', 'ice-cream', 1, 21)),
    ];

    const summary = analyseWeek(meals, {}, TARGETS, { now: NOW });
    const sugar = summary.patterns.find((pattern) => pattern.id === 'sugar-over');

    expect(sugar).toBeDefined();
    expect(sugar!.daysAffected).toBe(4);
    expect(sugar!.title).toMatch(/4 of 4 days/);
    expect(sugar!.tone).toBe('concern');
  });

  it('flags a protein shortfall against the target', () => {
    const meals = [0, 1, 2, 3, 4].flatMap((offset) => [
      meal(offset, 'breakfast', 'idli', 2, 8),
      meal(offset, 'lunch', 'plain-rice', 2, 13),
      meal(offset, 'dinner', 'roti', 3, 20),
    ]);

    const protein = analyseWeek(meals, {}, TARGETS, { now: NOW }).patterns.find(
      (pattern) => pattern.id === 'protein-short',
    );

    expect(protein).toBeDefined();
    expect(protein!.daysAffected).toBe(5);
  });

  it('reinforces a win when protein is hit every day', () => {
    const meals = [0, 1, 2, 3].flatMap((offset) => [
      ...solidDay(offset),
      meal(offset, 'snack', 'whey-shake', 2, 16),
      meal(offset, 'breakfast', 'greek-yoghurt', 1, 9),
    ]);

    const win = analyseWeek(meals, {}, TARGETS, { now: NOW }).patterns.find(
      (pattern) => pattern.id === 'protein-consistent',
    );

    expect(win?.tone).toBe('win');
  });

  it('flags late-night eating', () => {
    const meals = [0, 1, 2, 3].flatMap((offset) => [
      ...solidDay(offset),
      meal(offset, 'snack', 'almonds', 1, 23),
    ]);

    const late = analyseWeek(meals, {}, TARGETS, { now: NOW }).patterns.find(
      (pattern) => pattern.id === 'late-eating',
    );

    expect(late?.daysAffected).toBe(4);
  });

  it('flags under-hydration only on days water was actually logged', () => {
    const meals = [0, 1, 2, 3].flatMap(solidDay);
    const hydration = Object.fromEntries(
      [0, 1, 2, 3].map((offset) => [toIsoDay(addDays(NOW, -offset)), 900]),
    );

    const dry = analyseWeek(meals, hydration, TARGETS, { now: NOW }).patterns.find(
      (pattern) => pattern.id === 'hydration-short',
    );

    expect(dry?.daysAffected).toBe(4);

    // With no water logged at all we say nothing, rather than accusing the
    // user of dehydration for not using the tracker.
    const silent = analyseWeek(meals, {}, TARGETS, { now: NOW }).patterns.find(
      (pattern) => pattern.id === 'hydration-short',
    );
    expect(silent).toBeUndefined();
  });

  it('says nothing at all without targets to compare against', () => {
    const meals = [0, 1, 2, 3].flatMap(solidDay);
    expect(analyseWeek(meals, {}, null, { now: NOW }).patterns).toHaveLength(0);
  });
});

describe('headlinePattern', () => {
  it('prefers a concern over a win', () => {
    const meals = [
      ...[0, 1, 2, 3].flatMap(solidDay),
      ...[0, 1, 2, 3].map((offset) => meal(offset, 'snack', 'ice-cream', 1, 21)),
    ];

    const headline = headlinePattern(analyseWeek(meals, {}, TARGETS, { now: NOW }));
    expect(headline?.tone).toBe('concern');
  });

  it('is null when there is nothing to report', () => {
    expect(headlinePattern(analyseWeek([], {}, TARGETS, { now: NOW }))).toBeNull();
  });
});
