import Constants from 'expo-constants';
import { z } from 'zod';

const EnvSchema = z.object({
  apiBaseUrl: z.string().url().or(z.literal('')),
  appEnv: z.enum(['development', 'preview', 'production']),
  debugTelemetry: z.boolean(),
  /** Google OAuth *client* ID. Public by design — the secret lives server-side. */
  googleClientId: z.string(),
  /**
   * Google Places API key. Unlike the OAuth client ID this is a real credential
   * and is only safe in the bundle because it must be restricted, in the Cloud
   * console, to this bundle identifier and the Places API alone.
   */
  placesApiKey: z.string(),
});

export type Env = z.infer<typeof EnvSchema>;

const raw = {
  apiBaseUrl:
    process.env.EXPO_PUBLIC_API_BASE_URL ??
    (Constants.expoConfig?.extra?.['apiBaseUrl'] as string | undefined) ??
    '',
  appEnv: process.env.EXPO_PUBLIC_APP_ENV ?? 'development',
  debugTelemetry: process.env.EXPO_PUBLIC_DEBUG_TELEMETRY === 'true',
  googleClientId:
    process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID ??
    (Constants.expoConfig?.extra?.['googleClientId'] as string | undefined) ??
    '',
  placesApiKey:
    process.env.EXPO_PUBLIC_GOOGLE_PLACES_API_KEY ??
    (Constants.expoConfig?.extra?.['placesApiKey'] as string | undefined) ??
    '',
};

const parsed = EnvSchema.safeParse(raw);

if (!parsed.success) {
  // Fail loud at startup rather than at the first network call.
  throw new Error(
    `Invalid environment configuration:\n${parsed.error.issues
      .map((i) => `  • ${i.path.join('.')}: ${i.message}`)
      .join('\n')}`,
  );
}

export const env: Env = parsed.data;

/**
 * With no API base URL the app runs entirely on-device against the local
 * fixture parser. Everything except LLM-grade OCR still works.
 */
export const isOfflineMode = env.apiBaseUrl === '';

/**
 * Gmail import needs both halves: a client ID to authorize with, and a backend
 * to exchange the code and do the actual mailbox scanning. In offline mode the
 * feature runs against fixtures instead.
 */
export const isGmailConfigured = env.googleClientId !== '' && !isOfflineMode;
