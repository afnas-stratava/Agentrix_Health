import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { LabReport } from '@/schemas/labs';
import { LabReportSchema } from '@/schemas/labs';
import { createJsonStorage, StorageKeys } from '@/lib/storage';
import { deleteStoredFile } from '@/features/labs/picker';
import { log } from '@/lib/logger';

type PersistedLabs = Pick<LabsState, 'reports'>;

interface LabsState {
  reports: LabReport[];
  /** Transient per-report progress for the upload sheet, not persisted. */
  progress: Record<string, number>;

  upsertReport: (report: LabReport) => void;
  removeReport: (id: string) => void;
  replaceAll: (reports: LabReport[]) => void;
  setProgress: (id: string, value: number) => void;
  clearProgress: (id: string) => void;
  reset: () => void;
}

function sortByRecency(reports: LabReport[]): LabReport[] {
  return [...reports].sort((a, b) => {
    const aTime = new Date(a.collectedAt ?? a.uploadedAt).getTime();
    const bTime = new Date(b.collectedAt ?? b.uploadedAt).getTime();
    return bTime - aTime;
  });
}

export const useLabsStore = create<LabsState>()(
  persist(
    (set, get) => ({
      reports: [],
      progress: {},

      upsertReport: (report) =>
        set((state) => {
          const existing = state.reports.findIndex((r) => r.id === report.id);
          const next =
            existing >= 0
              ? state.reports.map((r, i) => (i === existing ? report : r))
              : [...state.reports, report];
          return { reports: sortByRecency(next) };
        }),

      removeReport: (id) => {
        const report = get().reports.find((r) => r.id === id);
        // Drop the copied PDF/image too, or storage grows without bound.
        if (report) deleteStoredFile(report.fileUri);
        set((state) => ({ reports: state.reports.filter((r) => r.id !== id) }));
      },

      replaceAll: (reports) => set({ reports: sortByRecency(reports) }),

      setProgress: (id, value) =>
        set((state) => ({ progress: { ...state.progress, [id]: value } })),

      clearProgress: (id) =>
        set((state) => {
          const { [id]: _removed, ...rest } = state.progress;
          return { progress: rest };
        }),

      reset: () => set({ reports: [], progress: {} }),
    }),
    {
      name: StorageKeys.labs,
      storage: createJsonStorage<PersistedLabs>('labs'),
      version: 1,
      // Upload progress is deliberately not persisted — a parse interrupted by
      // app termination is dead, and restoring its progress bar would strand
      // the row at 40% forever.
      partialize: (state): PersistedLabs => ({ reports: state.reports }),
      /**
       * Persisted reports are re-validated on hydration. A shape change from a
       * previous app version drops the offending report rather than crashing
       * every screen that reads `biomarkers`.
       */
      merge: (persisted, current) => {
        const raw = (persisted as PersistedLabs | undefined)?.reports ?? [];
        const valid: LabReport[] = [];

        for (const candidate of raw) {
          const parsed = LabReportSchema.safeParse(candidate);
          if (parsed.success) valid.push(parsed.data);
          else log.warn('store', 'Discarded a lab report that failed validation');
        }

        return { ...current, reports: sortByRecency(valid) };
      },
    },
  ),
);

export const selectReports = (state: LabsState) => state.reports;
export const selectLatestReport = (state: LabsState) => state.reports[0] ?? null;
export const selectReportById = (id: string) => (state: LabsState) =>
  state.reports.find((r) => r.id === id) ?? null;
