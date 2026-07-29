import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { createJsonStorage, StorageKeys } from '@/lib/storage';
import { createId } from '@/lib/id';
import { toIsoDay } from '@/lib/date';
import type { IsoDay } from '@/schemas/health';
import type { LoggedFood, MealEntry, MealSlot, MealSource } from '@/schemas/nutrition';
import { MealEntrySchema } from '@/schemas/nutrition';

/**
 * The food log.
 *
 * Retention is capped at `RETENTION_DAYS` — the weekly pattern analyser never
 * looks further back than a fortnight, and an unbounded meal log with photo URIs
 * grows without limit on a device the user cannot easily prune. Trimming happens
 * on write rather than on a timer, so it cannot be skipped.
 */

const RETENTION_DAYS = 120;

interface AddMealInput {
  slot: MealSlot;
  foods: LoggedFood[];
  source: MealSource;
  photoUri?: string | null;
  confidence?: number;
  note?: string | null;
  /** Overridable so the demo seeder can write historical days. */
  loggedAt?: string;
  day?: IsoDay;
}

interface NutritionState {
  meals: MealEntry[];
  /** Millilitres per ISO day. Water is a running total, not a list of entries. */
  hydration: Record<string, number>;
  /**
   * Days the user has declared a cheat day. Explicit rather than inferred —
   * deciding for someone that they are having a cheat day because they ate a
   * dessert is exactly the kind of judgement this app should not make.
   */
  cheatDays: IsoDay[];

  addMeal: (input: AddMealInput) => MealEntry;
  updateMeal: (id: string, patch: Partial<Pick<MealEntry, 'foods' | 'slot' | 'note' | 'confidence'>>) => void;
  removeMeal: (id: string) => void;
  addWater: (ml: number, day?: IsoDay) => void;
  setWater: (ml: number, day?: IsoDay) => void;
  toggleCheatDay: (day?: IsoDay) => void;
  isCheatDay: (day?: IsoDay) => boolean;
  mealsForDay: (day: IsoDay) => MealEntry[];
  /** Food IDs by recency, feeding the plate-suggestion ranker. */
  recentFoodIds: (limit?: number) => string[];
  hydrate: (input: { meals: MealEntry[]; hydration: Record<string, number>; cheatDays?: IsoDay[] }) => void;
  clear: () => void;
}

type PersistedNutrition = Pick<NutritionState, 'meals' | 'hydration' | 'cheatDays'>;

function trim(meals: MealEntry[]): MealEntry[] {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - RETENTION_DAYS);
  const cutoffDay = toIsoDay(cutoff);
  // ISO days sort lexicographically, so a string compare is a date compare.
  return meals.filter((meal) => meal.day >= cutoffDay);
}

export const useNutritionStore = create<NutritionState>()(
  persist(
    (set, get) => ({
      meals: [],
      hydration: {},
      cheatDays: [],

      addMeal: (input) => {
        const loggedAt = input.loggedAt ?? new Date().toISOString();
        const entry = MealEntrySchema.parse({
          id: createId('meal'),
          day: input.day ?? toIsoDay(new Date(loggedAt)),
          loggedAt,
          slot: input.slot,
          source: input.source,
          photoUri: input.photoUri ?? null,
          foods: input.foods,
          confidence: input.confidence ?? 1,
          note: input.note ?? null,
        });

        set((state) => ({ meals: trim([...state.meals, entry]) }));
        return entry;
      },

      updateMeal: (id, patch) =>
        set((state) => ({
          meals: state.meals.map((meal) => (meal.id === id ? { ...meal, ...patch } : meal)),
        })),

      removeMeal: (id) => set((state) => ({ meals: state.meals.filter((meal) => meal.id !== id) })),

      addWater: (ml, day) =>
        set((state) => {
          const key = day ?? toIsoDay(new Date());
          const next = Math.max(0, (state.hydration[key] ?? 0) + ml);
          return { hydration: { ...state.hydration, [key]: next } };
        }),

      setWater: (ml, day) =>
        set((state) => {
          const key = day ?? toIsoDay(new Date());
          return { hydration: { ...state.hydration, [key]: Math.max(0, ml) } };
        }),

      toggleCheatDay: (day) =>
        set((state) => {
          const key = day ?? toIsoDay(new Date());
          return {
            cheatDays: state.cheatDays.includes(key)
              ? state.cheatDays.filter((d) => d !== key)
              : [...state.cheatDays, key],
          };
        }),

      isCheatDay: (day) => get().cheatDays.includes(day ?? toIsoDay(new Date())),

      mealsForDay: (day) =>
        get()
          .meals.filter((meal) => meal.day === day)
          .sort((a, b) => a.loggedAt.localeCompare(b.loggedAt)),

      recentFoodIds: (limit = 30) => {
        const seen = new Set<string>();
        const sorted = [...get().meals].sort((a, b) => b.loggedAt.localeCompare(a.loggedAt));
        for (const meal of sorted) {
          for (const food of meal.foods) {
            if (food.foodId != null) seen.add(food.foodId);
          }
          if (seen.size >= limit) break;
        }
        return [...seen].slice(0, limit);
      },

      hydrate: ({ meals, hydration, cheatDays }) =>
        set({ meals: trim(meals), hydration, cheatDays: cheatDays ?? [] }),

      clear: () => set({ meals: [], hydration: {}, cheatDays: [] }),
    }),
    {
      name: StorageKeys.nutrition,
      storage: createJsonStorage<PersistedNutrition>('nutrition'),
      version: 1,
      partialize: (state) => ({
        meals: state.meals,
        hydration: state.hydration,
        cheatDays: state.cheatDays,
      }),
    },
  ),
);

export const selectMeals = (state: NutritionState) => state.meals;
export const selectHydration = (state: NutritionState) => state.hydration;
export const selectCheatDays = (state: NutritionState) => state.cheatDays;
