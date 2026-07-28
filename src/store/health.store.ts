import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { HealthPermissionState } from '@/schemas/health';
import { createJsonStorage, StorageKeys } from '@/lib/storage';

type PersistedHealth = Pick<
  HealthState,
  'permission' | 'lastSyncedAt' | 'hasSeenPrimer' | 'syncedButEmpty'
>;

interface HealthState {
  permission: HealthPermissionState;
  /** ISO timestamp of the last successful HealthKit read. */
  lastSyncedAt: string | null;
  /** Set once the user has seen the pre-permission priming screen. */
  hasSeenPrimer: boolean;
  /** True when a sync completed but every stream came back empty. */
  syncedButEmpty: boolean;

  setPermission: (permission: HealthPermissionState) => void;
  markSynced: (isoTimestamp: string, hadData: boolean) => void;
  markPrimerSeen: () => void;
  reset: () => void;
}

export const useHealthStore = create<HealthState>()(
  persist(
    (set) => ({
      permission: 'undetermined',
      lastSyncedAt: null,
      hasSeenPrimer: false,
      syncedButEmpty: false,

      setPermission: (permission) => set({ permission }),
      markSynced: (isoTimestamp, hadData) =>
        set({ lastSyncedAt: isoTimestamp, syncedButEmpty: !hadData }),
      markPrimerSeen: () => set({ hasSeenPrimer: true }),
      reset: () =>
        set({
          permission: 'undetermined',
          lastSyncedAt: null,
          hasSeenPrimer: false,
          syncedButEmpty: false,
        }),
    }),
    {
      name: StorageKeys.health,
      storage: createJsonStorage<PersistedHealth>('health'),
      version: 1,
      partialize: (state): PersistedHealth => ({
        permission: state.permission,
        lastSyncedAt: state.lastSyncedAt,
        hasSeenPrimer: state.hasSeenPrimer,
        syncedButEmpty: state.syncedButEmpty,
      }),
    },
  ),
);

export const selectPermission = (state: HealthState) => state.permission;
export const selectLastSyncedAt = (state: HealthState) => state.lastSyncedAt;
