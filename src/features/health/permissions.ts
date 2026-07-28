import AppleHealthKit, { type HealthKitPermissions } from 'react-native-health';

/**
 * Read-only scope. We deliberately request **no write permissions**: the app
 * is an observer, and an empty write set means iOS never shows the "allow
 * writing" toggles that erode user trust on first run.
 */
export const HEALTHKIT_PERMISSIONS: HealthKitPermissions = {
  permissions: {
    read: [
      AppleHealthKit.Constants.Permissions.HeartRateVariability,
      AppleHealthKit.Constants.Permissions.RestingHeartRate,
      AppleHealthKit.Constants.Permissions.SleepAnalysis,
      AppleHealthKit.Constants.Permissions.ActiveEnergyBurned,
      AppleHealthKit.Constants.Permissions.StepCount,
      AppleHealthKit.Constants.Permissions.HeartRate,
      AppleHealthKit.Constants.Permissions.RespiratoryRate,
      AppleHealthKit.Constants.Permissions.DateOfBirth,
      AppleHealthKit.Constants.Permissions.BiologicalSex,
    ],
    write: [],
  },
};

/**
 * HealthKit never tells you whether *read* access was granted — `getAuthStatus`
 * reports `sharingDenied`/`sharingAuthorized` for writes only, and read status
 * is intentionally opaque so apps cannot infer that a user has a condition by
 * detecting an empty result set.
 *
 * The only honest signal is therefore: did `initHealthKit` succeed, and did we
 * subsequently receive any samples? `granted` below means "the sheet was
 * completed"; the UI must still handle a permanently empty series.
 */
export const READ_STATUS_IS_OPAQUE = true;
