// The env module validates configuration at import time and throws on a bad
// shape. Tests run without a .env file, so supply the offline-mode defaults.
process.env.EXPO_PUBLIC_API_BASE_URL = '';
process.env.EXPO_PUBLIC_APP_ENV = 'development';
process.env.EXPO_PUBLIC_DEBUG_TELEMETRY = 'false';
