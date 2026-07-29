import type { ExpoConfig, ConfigContext } from 'expo/config';

const HEALTH_SHARE_REASON =
  'We read your heart-rate variability, resting heart rate, sleep, steps and active energy to correlate them with your lab results and generate lifestyle suggestions. Your health data never leaves your device unless you explicitly share a report.';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: 'Vitals',
  slug: 'vitals-health-correlation',
  scheme: 'vitals',
  version: '1.0.0',
  orientation: 'portrait',
  userInterfaceStyle: 'automatic',
  // The New Architecture is the default and only mode in SDK 55 — the
  // `newArchEnabled` flag was removed from the config schema entirely.
  jsEngine: 'hermes',
  icon: './assets/icon.png',
  splash: {
    image: './assets/splash.png',
    resizeMode: 'contain',
    backgroundColor: '#080a0e',
  },
  assetBundlePatterns: ['**/*'],
  ios: {
    supportsTablet: false,
    bundleIdentifier: 'com.vitals.health',
    buildNumber: '1',
    // HealthKit is only granted to apps that declare the entitlement AND the
    // usage strings below. Background delivery requires the second entitlement.
    entitlements: {
      'com.apple.developer.healthkit': true,
      'com.apple.developer.healthkit.access': [],
      'com.apple.developer.healthkit.background-delivery': true,
    },
    infoPlist: {
      NSHealthShareUsageDescription: HEALTH_SHARE_REASON,
      NSHealthUpdateUsageDescription:
        'We write mindful-minutes and workout annotations back to Health only when you ask us to.',
      NSCameraUsageDescription:
        'Take a photo of a printed lab report so we can extract your biomarkers.',
      NSPhotoLibraryUsageDescription:
        'Attach a saved photo or scan of your lab report.',
      NSLocationWhenInUseUsageDescription:
        'We use your location only while the app is open, to find restaurants near you that fit your health profile. It is never stored or sent anywhere.',
      ITSAppUsesNonExemptEncryption: false,
      UIBackgroundModes: ['fetch', 'processing'],
    },
  },
  android: {
    package: 'com.vitals.health',
    // HealthKit is iOS-only; the Android target ships without telemetry sync
    // until a Health Connect adapter lands. See src/features/health/provider.ts
    adaptiveIcon: {
      foregroundImage: './assets/adaptive-icon.png',
      backgroundColor: '#080a0e',
    },
  },
  plugins: [
    [
      'expo-router',
      {
        origin: false,
      },
    ],
    [
      'expo-build-properties',
      {
        ios: {
          deploymentTarget: '16.0',
          useFrameworks: 'static',
        },
        android: {
          compileSdkVersion: 36,
          targetSdkVersion: 36,
          minSdkVersion: 26,
        },
      },
    ],
    [
      'react-native-health',
      {
        isClinicalDataEnabled: false,
        healthSharePermission: HEALTH_SHARE_REASON,
      },
    ],
    [
      'expo-image-picker',
      {
        photosPermission: 'Attach a saved photo or scan of your lab report.',
        cameraPermission:
          'Take a photo of a printed lab report so we can extract your biomarkers.',
      },
    ],
    'expo-document-picker',
  ],
  experiments: {
    typedRoutes: true,
    reactCompiler: true,
  },
  extra: {
    apiBaseUrl: process.env.EXPO_PUBLIC_API_BASE_URL ?? '',
    // OAuth *client* ID — public by design. The client secret is held only by
    // the backend, which performs the authorization-code exchange.
    googleClientId: process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID ?? '',
    // Restricted in the Cloud console to this bundle ID + the Places API.
    placesApiKey: process.env.EXPO_PUBLIC_GOOGLE_PLACES_API_KEY ?? '',
    eas: {
      projectId: process.env.EAS_PROJECT_ID ?? '00000000-0000-0000-0000-000000000000',
    },
  },
});
