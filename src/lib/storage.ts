import AsyncStorage from '@react-native-async-storage/async-storage';
import type { PersistStorage, StorageValue } from 'zustand/middleware';
import { log } from './logger';

/**
 * Typed JSON adapter for Zustand's `persist`. A corrupt or schema-drifted
 * payload is discarded rather than crashing the app on boot — losing cached
 * state is always preferable to a launch loop.
 */
export function createJsonStorage<T>(scope: string): PersistStorage<T> {
  return {
    getItem: async (name) => {
      try {
        const raw = await AsyncStorage.getItem(name);
        if (raw == null) return null;
        return JSON.parse(raw) as StorageValue<T>;
      } catch (error) {
        log.warn('store', `Dropping unreadable persisted state for ${scope}`, error);
        await AsyncStorage.removeItem(name).catch(() => undefined);
        return null;
      }
    },
    setItem: async (name, value) => {
      try {
        await AsyncStorage.setItem(name, JSON.stringify(value));
      } catch (error) {
        log.error('store', `Failed to persist ${scope}`, error);
      }
    },
    removeItem: async (name) => {
      await AsyncStorage.removeItem(name).catch(() => undefined);
    },
  };
}

export const StorageKeys = {
  settings: 'vitals.settings.v1',
  labs: 'vitals.labs.v1',
  health: 'vitals.health.v1',
  insights: 'vitals.insights.v1',
  profile: 'vitals.profile.v1',
  nutrition: 'vitals.nutrition.v1',
  connections: 'vitals.connections.v1',
} as const;
