import type { DailySnapshot, HealthPermissionState, IsoDay } from '@/schemas/health';

/** Normalised sample shape shared by every provider implementation. */
export interface QuantitySample {
  startDate: string;
  endDate: string;
  value: number;
  sourceName?: string | undefined;
  sourceId?: string | undefined;
}

export type SleepStageValue =
  | 'INBED'
  | 'ASLEEP'
  | 'AWAKE'
  | 'CORE'
  | 'DEEP'
  | 'REM'
  | 'UNSPECIFIED';

export interface SleepSample {
  startDate: string;
  endDate: string;
  value: SleepStageValue;
  sourceName?: string | undefined;
  sourceId?: string | undefined;
}

export interface RawTelemetry {
  hrv: QuantitySample[];
  restingHeartRate: QuantitySample[];
  sleep: SleepSample[];
  activeEnergy: QuantitySample[];
  steps: QuantitySample[];
}

/**
 * Platform-agnostic contract. iOS binds this to HealthKit; the simulator and
 * Android bind it to the deterministic synthetic provider so every screen is
 * developable without a paired Apple Watch.
 */
export interface HealthProvider {
  readonly id: 'healthkit' | 'synthetic';
  isAvailable(): Promise<boolean>;
  requestAuthorization(): Promise<HealthPermissionState>;
  getPermissionState(): Promise<HealthPermissionState>;
  fetchRange(from: Date, to: Date): Promise<RawTelemetry>;
  /** Returns an unsubscribe function; no-op on providers without observers. */
  subscribe(onChange: () => void): () => void;
}

export interface DailySnapshotMap {
  [day: IsoDay]: DailySnapshot;
}
