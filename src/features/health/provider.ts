import { Platform } from 'react-native';
import Constants from 'expo-constants';
import { log } from '@/lib/logger';
import type { HealthProvider } from './types';
import { healthKitProvider } from './healthkit.provider';
import { syntheticProvider } from './synthetic.provider';

/**
 * HealthKit exists on the iOS simulator but is permanently empty, which makes
 * every screen look broken during development. Resolve to the synthetic
 * provider whenever real telemetry cannot exist, and only there.
 */
function resolveProvider(): HealthProvider {
  if (Platform.OS !== 'ios') {
    log.info('health', 'Non-iOS platform — using synthetic telemetry');
    return syntheticProvider;
  }

  const isSimulator = Constants.executionEnvironment !== 'standalone' && !Constants.isDevice;
  if (isSimulator) {
    log.info('health', 'iOS Simulator — using synthetic telemetry');
    return syntheticProvider;
  }

  return healthKitProvider;
}

export const healthProvider: HealthProvider = resolveProvider();

export const isSyntheticTelemetry = healthProvider.id === 'synthetic';
