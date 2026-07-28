import { NativeAppEventEmitter, NativeEventEmitter, NativeModules, Platform } from 'react-native';
import AppleHealthKit, {
  type HealthInputOptions,
  type HealthObserver,
  type HealthValue,
} from 'react-native-health';
import type { HealthPermissionState } from '@/schemas/health';
import { log } from '@/lib/logger';
import { HEALTHKIT_PERMISSIONS } from './permissions';
import type {
  HealthProvider,
  QuantitySample,
  RawTelemetry,
  SleepSample,
  SleepStageValue,
} from './types';

const QUERY_TIMEOUT_MS = 15_000;
/** HealthKit caps a single query; 10k samples is ~90 days of HRV comfortably. */
const SAMPLE_LIMIT = 10_000;

/**
 * `react-native-health` exposes a Node-style callback API. Every read is
 * wrapped here so the rest of the app only ever sees promises, and so a native
 * module that never calls back cannot hang a React Query fetch forever.
 */
function promisify<T>(
  label: string,
  fn: (cb: (error: string | null, result: T) => void) => void,
): Promise<T> {
  return new Promise((resolve, reject) => {
    let settled = false;

    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      reject(new Error(`HealthKit query "${label}" timed out after ${QUERY_TIMEOUT_MS}ms`));
    }, QUERY_TIMEOUT_MS);

    try {
      fn((error, result) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        if (error) {
          reject(new Error(`HealthKit query "${label}" failed: ${error}`));
          return;
        }
        resolve(result);
      });
    } catch (error) {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      reject(error instanceof Error ? error : new Error(String(error)));
    }
  });
}

/**
 * A rejected read must not take the whole sync down — a user may have granted
 * HRV but denied sleep. Each stream degrades to an empty array independently.
 */
async function tolerate<T>(label: string, work: Promise<T[]>): Promise<T[]> {
  try {
    return await work;
  } catch (error) {
    log.warn('health', `Stream "${label}" unavailable, continuing without it`, error);
    return [];
  }
}

function toQuantitySamples(values: HealthValue[]): QuantitySample[] {
  return values.map((v) => ({
    startDate: v.startDate,
    endDate: v.endDate,
    value: v.value,
    sourceName: (v as HealthValue & { sourceName?: string }).sourceName,
    sourceId: (v as HealthValue & { sourceId?: string }).sourceId,
  }));
}

const SLEEP_VALUES: ReadonlySet<string> = new Set<SleepStageValue>([
  'INBED',
  'ASLEEP',
  'AWAKE',
  'CORE',
  'DEEP',
  'REM',
  'UNSPECIFIED',
]);

function normaliseSleepValue(raw: string): SleepStageValue {
  const upper = raw.toUpperCase();
  if (SLEEP_VALUES.has(upper)) return upper as SleepStageValue;
  // Older iOS / third-party writers only emit the coarse categories.
  if (upper.includes('DEEP')) return 'DEEP';
  if (upper.includes('REM')) return 'REM';
  if (upper.includes('CORE') || upper.includes('LIGHT')) return 'CORE';
  if (upper.includes('AWAKE')) return 'AWAKE';
  if (upper.includes('BED')) return 'INBED';
  return 'UNSPECIFIED';
}

/**
 * Observers we register for HealthKit background delivery.
 *
 * `react-native-health` only exposes observers for a fixed set of types —
 * step count, active energy and sleep analysis are NOT among them. Heart-rate
 * observers are the useful proxy: the Watch writes HR, RHR and the day's
 * activity samples in the same sync burst, so an HR notification reliably means
 * "there is fresh data for everything". Anything missed is picked up by the
 * foreground refetch in `useHealthSeries`.
 */
const OBSERVED_TYPES: HealthObserver[] = [
  'HeartRate' as HealthObserver,
  'RestingHeartRate' as HealthObserver,
  'Workout' as HealthObserver,
  'Walking' as HealthObserver,
];

class HealthKitProvider implements HealthProvider {
  readonly id = 'healthkit' as const;

  private initialized = false;

  async isAvailable(): Promise<boolean> {
    if (Platform.OS !== 'ios') return false;
    try {
      return await promisify<boolean>('isAvailable', (cb) =>
        AppleHealthKit.isAvailable((err, available) => cb(err ? String(err) : null, available)),
      );
    } catch {
      return false;
    }
  }

  async requestAuthorization(): Promise<HealthPermissionState> {
    if (!(await this.isAvailable())) return 'unavailable';

    try {
      await promisify<void>('initHealthKit', (cb) =>
        AppleHealthKit.initHealthKit(HEALTHKIT_PERMISSIONS, (err) =>
          cb(err ? String(err) : null, undefined as void),
        ),
      );
      this.initialized = true;
      this.registerObservers();
      return 'granted';
    } catch (error) {
      // The user dismissing the sheet also lands here; treat as denied and let
      // the UI offer a deep link into Settings › Privacy › Health.
      log.warn('health', 'initHealthKit rejected', error);
      return 'denied';
    }
  }

  async getPermissionState(): Promise<HealthPermissionState> {
    if (!(await this.isAvailable())) return 'unavailable';
    if (this.initialized) return 'granted';
    return 'undetermined';
  }

  async fetchRange(from: Date, to: Date): Promise<RawTelemetry> {
    if (!this.initialized) {
      const state = await this.requestAuthorization();
      if (state !== 'granted') {
        return { hrv: [], restingHeartRate: [], sleep: [], activeEnergy: [], steps: [] };
      }
    }

    const options: HealthInputOptions = {
      startDate: from.toISOString(),
      endDate: to.toISOString(),
      ascending: true,
      limit: SAMPLE_LIMIT,
    };

    // Five independent native queries; running them concurrently keeps a
    // 90-day sync under ~2s on an A15 instead of ~8s serially.
    const [hrv, restingHeartRate, sleep, activeEnergy, steps] = await Promise.all([
      tolerate(
        'hrv',
        promisify<HealthValue[]>('getHeartRateVariabilitySamples', (cb) =>
          AppleHealthKit.getHeartRateVariabilitySamples(options, (err, results) =>
            cb(err ? String(err) : null, results ?? []),
          ),
        ).then(toQuantitySamples),
      ),
      tolerate(
        'restingHeartRate',
        promisify<HealthValue[]>('getRestingHeartRateSamples', (cb) =>
          AppleHealthKit.getRestingHeartRateSamples(options, (err, results) =>
            cb(err ? String(err) : null, results ?? []),
          ),
        ).then(toQuantitySamples),
      ),
      tolerate(
        'sleep',
        promisify<Array<{ startDate: string; endDate: string; value: string; sourceName?: string; sourceId?: string }>>(
          'getSleepSamples',
          (cb) =>
            AppleHealthKit.getSleepSamples(options, (err, results) =>
              cb(err ? String(err) : null, (results ?? []) as never),
            ),
        ).then<SleepSample[]>((rows) =>
          rows.map((row) => ({
            startDate: row.startDate,
            endDate: row.endDate,
            value: normaliseSleepValue(row.value),
            sourceName: row.sourceName,
            sourceId: row.sourceId,
          })),
        ),
      ),
      tolerate(
        'activeEnergy',
        promisify<HealthValue[]>('getActiveEnergyBurned', (cb) =>
          AppleHealthKit.getActiveEnergyBurned(options, (err, results) =>
            cb(err ? String(err) : null, results ?? []),
          ),
        ).then(toQuantitySamples),
      ),
      tolerate(
        'steps',
        // `getDailyStepCountSamples` already buckets by local day and, unlike
        // `getStepCount`, de-duplicates iPhone vs. Watch double-counting.
        promisify<HealthValue[]>('getDailyStepCountSamples', (cb) =>
          AppleHealthKit.getDailyStepCountSamples(options, (err, results) =>
            cb(err ? String(err) : null, results ?? []),
          ),
        ).then(toQuantitySamples),
      ),
    ]);

    log.debug('health', 'Fetched raw telemetry', {
      hrv: hrv.length,
      rhr: restingHeartRate.length,
      sleep: sleep.length,
      energy: activeEnergy.length,
      steps: steps.length,
    });

    return { hrv, restingHeartRate, sleep, activeEnergy, steps };
  }

  subscribe(onChange: () => void): () => void {
    if (Platform.OS !== 'ios') return () => undefined;

    // react-native-health emits through NativeAppEventEmitter on older RN and
    // through the module's own emitter under the New Architecture bridgeless
    // mode. Listening to both is harmless and avoids a silent dead observer.
    const listeners: Array<{ remove: () => void }> = [];

    const moduleEmitter = NativeModules['AppleHealthKit']
      ? new NativeEventEmitter(NativeModules['AppleHealthKit'] as never)
      : null;

    for (const type of OBSERVED_TYPES) {
      const event = `healthKit:${type}:new`;
      listeners.push(NativeAppEventEmitter.addListener(event, onChange));
      if (moduleEmitter) {
        try {
          listeners.push(moduleEmitter.addListener(event, onChange));
        } catch {
          // Emitter without a matching native event registry — ignore.
        }
      }
    }

    return () => {
      for (const listener of listeners) listener.remove();
    };
  }

  private registerObservers(): void {
    for (const type of OBSERVED_TYPES) {
      try {
        AppleHealthKit.setObserver({ type });
      } catch (error) {
        log.warn('health', `Could not register observer for ${type}`, error);
      }
    }
  }
}

export const healthKitProvider = new HealthKitProvider();
