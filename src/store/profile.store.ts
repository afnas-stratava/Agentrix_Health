import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { createJsonStorage, StorageKeys } from '@/lib/storage';
import {
  HealthProfileSchema,
  type Allergen,
  type Condition,
  type Cuisine,
  type CycleProfile,
  type HealthGoal,
  type HealthProfile,
  type Restriction,
} from '@/schemas/profile';

/**
 * The declared profile. Persisted in full — unlike telemetry, none of this can
 * be re-derived on next launch, and re-asking a user their allergies because a
 * cache was dropped is the kind of thing that gets an app deleted.
 */

interface ProfileState extends HealthProfile {
  setGoal: (goal: HealthGoal) => void;
  toggleCondition: (condition: Condition) => void;
  setBody: (input: {
    heightCm?: number | null;
    weightKg?: number | null;
    targetWeightKg?: number | null;
  }) => void;
  setActivityLevel: (level: HealthProfile['activityLevel']) => void;
  setDietPattern: (pattern: HealthProfile['dietPattern']) => void;
  toggleAllergen: (allergen: Allergen) => void;
  toggleRestriction: (restriction: Restriction) => void;
  /** Toggling an unselected cuisine appends it, preserving preference order. */
  toggleCuisine: (cuisine: Cuisine) => void;
  setSpiceTolerance: (tolerance: HealthProfile['spiceTolerance']) => void;
  setDisplayName: (name: string | null) => void;
  updateCycle: (patch: Partial<CycleProfile>) => void;
  /** Bulk-apply, used by the demo persona seeder. */
  hydrate: (profile: Partial<HealthProfile>) => void;
  reset: () => void;
}

/**
 * Parsing an empty object through the schema materialises every `.default()`
 * exactly once, so the initial state can never drift from the contract.
 */
const INITIAL: HealthProfile = HealthProfileSchema.parse({});

function toggle<T>(list: T[], value: T): T[] {
  return list.includes(value) ? list.filter((item) => item !== value) : [...list, value];
}

export const useProfileStore = create<ProfileState>()(
  persist(
    (set) => ({
      ...INITIAL,

      setGoal: (goal) => set({ goal }),
      toggleCondition: (condition) =>
        set((state) => ({ conditions: toggle(state.conditions, condition) })),

      setBody: (input) =>
        set((state) => ({
          heightCm: input.heightCm !== undefined ? input.heightCm : state.heightCm,
          weightKg: input.weightKg !== undefined ? input.weightKg : state.weightKg,
          targetWeightKg:
            input.targetWeightKg !== undefined ? input.targetWeightKg : state.targetWeightKg,
        })),

      setActivityLevel: (activityLevel) => set({ activityLevel }),
      setDietPattern: (dietPattern) => set({ dietPattern }),

      toggleAllergen: (allergen) =>
        set((state) => ({ allergens: toggle(state.allergens, allergen) })),
      toggleRestriction: (restriction) =>
        set((state) => ({ restrictions: toggle(state.restrictions, restriction) })),
      toggleCuisine: (cuisine) => set((state) => ({ cuisines: toggle(state.cuisines, cuisine) })),

      setSpiceTolerance: (spiceTolerance) => set({ spiceTolerance }),
      setDisplayName: (displayName) => set({ displayName }),

      updateCycle: (patch) => set((state) => ({ cycle: { ...state.cycle, ...patch } })),

      hydrate: (profile) => set((state) => ({ ...state, ...profile })),
      reset: () => set(INITIAL),
    }),
    {
      name: StorageKeys.profile,
      storage: createJsonStorage<HealthProfile>('profile'),
      version: 1,
      // Actions are recreated on boot; only the data half is written.
      partialize: (state) => HealthProfileSchema.parse(state),
    },
  ),
);

export const selectGoal = (state: ProfileState) => state.goal;
export const selectDietPattern = (state: ProfileState) => state.dietPattern;
export const selectCycle = (state: ProfileState) => state.cycle;
export const selectCuisines = (state: ProfileState) => state.cuisines;
