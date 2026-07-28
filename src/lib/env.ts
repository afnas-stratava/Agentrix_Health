import Constants from 'expo-constants';
import { z } from 'zod';

const EnvSchema = z.object({
  apiBaseUrl: z.string().url().or(z.literal('')),
  appEnv: z.enum(['development', 'preview', 'production']),
  debugTelemetry: z.boolean(),
});

export type Env = z.infer<typeof EnvSchema>;

const raw = {
  apiBaseUrl:
    process.env.EXPO_PUBLIC_API_BASE_URL ??
    (Constants.expoConfig?.extra?.['apiBaseUrl'] as string | undefined) ??
    '',
  appEnv: process.env.EXPO_PUBLIC_APP_ENV ?? 'development',
  debugTelemetry: process.env.EXPO_PUBLIC_DEBUG_TELEMETRY === 'true',
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
