import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { GmailConnection } from '@/schemas/connections';
import { GmailConnectionSchema } from '@/schemas/connections';
import { createJsonStorage, StorageKeys } from '@/lib/storage';
import { log } from '@/lib/logger';

const STORAGE_KEY = StorageKeys.connections;

interface ConnectionsState {
  /**
   * Connection *metadata* only. No access token, no refresh token — those live
   * server-side, keyed by `connectionId`. See src/schemas/connections.ts.
   */
  gmail: GmailConnection | null;
  /** Attachment IDs already turned into lab reports, to avoid duplicates. */
  importedAttachmentIds: string[];

  setGmail: (connection: GmailConnection | null) => void;
  markImported: (attachmentIds: string[]) => void;
  reset: () => void;
}

type PersistedConnections = Pick<ConnectionsState, 'gmail' | 'importedAttachmentIds'>;

export const useConnectionsStore = create<ConnectionsState>()(
  persist(
    (set) => ({
      gmail: null,
      importedAttachmentIds: [],

      setGmail: (gmail) => set({ gmail }),

      markImported: (attachmentIds) =>
        set((state) => ({
          importedAttachmentIds: [
            ...new Set([...state.importedAttachmentIds, ...attachmentIds]),
          ],
        })),

      reset: () => set({ gmail: null, importedAttachmentIds: [] }),
    }),
    {
      name: STORAGE_KEY,
      storage: createJsonStorage<PersistedConnections>('connections'),
      version: 1,
      partialize: (state): PersistedConnections => ({
        gmail: state.gmail,
        importedAttachmentIds: state.importedAttachmentIds,
      }),
      merge: (persisted, current) => {
        const raw = persisted as Partial<PersistedConnections> | undefined;
        const parsed = raw?.gmail ? GmailConnectionSchema.safeParse(raw.gmail) : null;

        if (raw?.gmail && parsed && !parsed.success) {
          log.warn('store', 'Discarded an unreadable Gmail connection record');
        }

        return {
          ...current,
          gmail: parsed?.success ? parsed.data : null,
          importedAttachmentIds: raw?.importedAttachmentIds ?? [],
        };
      },
    },
  ),
);

export const selectGmail = (state: ConnectionsState) => state.gmail;
export const selectIsGmailConnected = (state: ConnectionsState) =>
  state.gmail?.status === 'connected';
