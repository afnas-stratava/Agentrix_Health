import { applyDemoPersona, clearDemoPersona, isDemoPersonaActive } from '@/features/demo/persona';
import { useProfileStore } from '@/store/profile.store';
import { useNutritionStore } from '@/store/nutrition.store';
import { useLabsStore } from '@/store/labs.store';
import { useSettingsStore } from '@/store/settings.store';
import { computeCyclePhase } from '@/features/cycle/phase';
import { computeTargets } from '@/features/nutrition/targets';
import { analyseWeek } from '@/features/nutrition/patterns';
import { dietaryConflict, findFood } from '@/features/nutrition/food-database';
import { HealthProfileSchema } from '@/schemas/profile';
import { needsAttention } from '@/features/labs/reference-ranges';

jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock'),
);

/**
 * The demo persona is what gets shown on stage, so it is worth asserting that
 * the story it is supposed to tell actually falls out of the data — a seeded
 * fixture that quietly stops producing findings is a demo that dies live.
 */
describe('demo persona', () => {
  beforeEach(() => {
    applyDemoPersona(new Date('2026-07-29T09:00:00+05:30'));
  });

  afterEach(() => {
    clearDemoPersona();
  });

  it('is detectable and reversible', () => {
    expect(isDemoPersonaActive()).toBe(true);
    clearDemoPersona();
    expect(isDemoPersonaActive()).toBe(false);
    expect(useNutritionStore.getState().meals).toHaveLength(0);
  });

  it('seeds a profile that unlocks calorie targets', () => {
    const profile = useProfileStore.getState();
    const settings = useSettingsStore.getState();

    expect(profile.heightCm).not.toBeNull();
    expect(profile.weightKg).not.toBeNull();
    expect(settings.birthYear).not.toBeNull();
    expect(profile.cuisines.length).toBeGreaterThan(0);
  });

  it('places the persona in a measured luteal phase, not a guessed one', () => {
    const phase = computeCyclePhase(
      useProfileStore.getState().cycle,
      new Date('2026-07-29T09:00:00+05:30'),
    );

    expect(phase).not.toBeNull();
    expect(phase!.name).toBe('luteal');
    expect(phase!.isMeasuredLength).toBe(true);
    expect(phase!.confidence).toBe('high');
  });

  it('seeds blood work that reads normal on paper but flags against optimal bands', () => {
    const report = useLabsStore.getState().reports.find((r) => r.id === 'demo-report-1');
    expect(report?.status).toBe('ready');

    const ferritin = report!.biomarkers.find((b) => b.code === 'ferritin');
    expect(ferritin?.value).toBe(18);
    // Above the lab's own floor of 15 — the printed report would say nothing.
    expect(ferritin!.value).toBeGreaterThan(ferritin!.range.low!);
    // But below optimal, which is the entire premise of the product.
    expect(needsAttention(ferritin!.flag)).toBe(true);
  });

  it('logs a fortnight of food, with today deliberately part-logged', () => {
    const meals = useNutritionStore.getState().meals;
    const days = new Set(meals.map((meal) => meal.day));

    expect(days.size).toBe(14);
    expect(meals.every((meal) => meal.source === 'seed')).toBe(true);

    const today = meals.filter((meal) => meal.day === '2026-07-29');
    expect(today.length).toBeGreaterThan(0);
    expect(today.every((meal) => meal.slot === 'breakfast')).toBe(true);
  });

  it('only logs food the seeded profile can actually eat', () => {
    const { dietPattern, allergens } = useProfileStore.getState();

    for (const meal of useNutritionStore.getState().meals) {
      for (const food of meal.foods) {
        const definition = findFood(food.foodId!);
        expect(definition).not.toBeNull();
        expect(dietaryConflict(definition!, { dietPattern, allergens })).toBeNull();
      }
    }
  });

  it('produces a week with findings worth showing', () => {
    const profileState = useProfileStore.getState();
    const settings = useSettingsStore.getState();

    const targets = computeTargets({
      profile: {
        ...HealthProfileSchema.parse(profileState),
        sex: settings.sex,
        birthYear: settings.birthYear,
        ageYears:
          settings.birthYear == null ? null : 2026 - settings.birthYear,
      },
      series: [],
      phase: null,
    });

    expect(targets).not.toBeNull();

    const summary = analyseWeek(
      useNutritionStore.getState().meals,
      useNutritionStore.getState().hydration,
      targets,
      { now: new Date('2026-07-29T21:00:00+05:30') },
    );

    expect(summary.isSparse).toBe(false);
    // The point of the seed: the weekly card has something to say.
    expect(summary.patterns.length).toBeGreaterThan(0);
    expect(summary.patterns.some((pattern) => pattern.tone === 'concern')).toBe(true);
  });
});
