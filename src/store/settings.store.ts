import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { createJsonStorage, StorageKeys } from '@/lib/storage';
import type { BiologicalSex } from '@/features/labs/reference-ranges';

export type AnalysisWindow = 30 | 60 | 90;

/**
 * Only the data half of the store is written to disk — actions are recreated
 * on every boot. Naming the persisted shape explicitly keeps `partialize` and
 * the storage adapter in agreement; inferring it lets them drift apart.
 */
type PersistedSettings = Pick<
  SettingsState,
  | 'hasOnboarded'
  | 'sex'
  | 'birthYear'
  | 'analysisWindowDays'
  | 'mutedRuleIds'
  | 'dismissedInsightIds'
  | 'units'
>;

interface SettingsState {
  hasOnboarded: boolean;
  /** Drives sex-specific reference intervals; never inferred silently. */
  sex: BiologicalSex;
  birthYear: number | null;
  analysisWindowDays: AnalysisWindow;
  /** Rule IDs the user has switched off in Settings. */
  mutedRuleIds: string[];
  /** Insight IDs the user has dismissed from the dashboard. */
  dismissedInsightIds: string[];
  units: 'metric' | 'imperial';

  completeOnboarding: () => void;
  setSex: (sex: BiologicalSex) => void;
  setBirthYear: (year: number | null) => void;
  setAnalysisWindow: (days: AnalysisWindow) => void;
  toggleRule: (ruleId: string) => void;
  dismissInsight: (insightId: string) => void;
  restoreInsight: (insightId: string) => void;
  clearDismissed: () => void;
  setUnits: (units: 'metric' | 'imperial') => void;
  reset: () => void;
}

const INITIAL = {
  hasOnboarded: false,
  sex: 'unspecified' as BiologicalSex,
  birthYear: null,
  analysisWindowDays: 90 as AnalysisWindow,
  mutedRuleIds: [] as string[],
  dismissedInsightIds: [] as string[],
  units: 'metric' as const,
};

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      ...INITIAL,

      completeOnboarding: () => set({ hasOnboarded: true }),
      setSex: (sex) => set({ sex }),
      setBirthYear: (birthYear) => set({ birthYear }),
      setAnalysisWindow: (analysisWindowDays) => set({ analysisWindowDays }),

      toggleRule: (ruleId) =>
        set((state) => ({
          mutedRuleIds: state.mutedRuleIds.includes(ruleId)
            ? state.mutedRuleIds.filter((id) => id !== ruleId)
            : [...state.mutedRuleIds, ruleId],
        })),

      dismissInsight: (insightId) =>
        set((state) =>
          state.dismissedInsightIds.includes(insightId)
            ? state
            : { dismissedInsightIds: [...state.dismissedInsightIds, insightId] },
        ),

      restoreInsight: (insightId) =>
        set((state) => ({
          dismissedInsightIds: state.dismissedInsightIds.filter((id) => id !== insightId),
        })),

      clearDismissed: () => set({ dismissedInsightIds: [] }),
      setUnits: (units) => set({ units }),
      reset: () => set(INITIAL),
    }),
    {
      name: StorageKeys.settings,
      storage: createJsonStorage<PersistedSettings>('settings'),
      version: 1,
      partialize: (state) => ({
        hasOnboarded: state.hasOnboarded,
        sex: state.sex,
        birthYear: state.birthYear,
        analysisWindowDays: state.analysisWindowDays,
        mutedRuleIds: state.mutedRuleIds,
        dismissedInsightIds: state.dismissedInsightIds,
        units: state.units,
      }),
    },
  ),
);

/**
 * Selectors are exported individually so components subscribe to the narrowest
 * possible slice — a component reading `sex` must not re-render when an
 * insight is dismissed.
 */
export const selectSex = (state: SettingsState) => state.sex;
export const selectAnalysisWindow = (state: SettingsState) => state.analysisWindowDays;
export const selectMutedRuleIds = (state: SettingsState) => state.mutedRuleIds;
export const selectDismissedIds = (state: SettingsState) => state.dismissedInsightIds;
export const selectHasOnboarded = (state: SettingsState) => state.hasOnboarded;
