import { z } from 'zod';
import { env } from './env';
import { log } from './logger';

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly body?: unknown,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  /** 4xx (except 408/429) will never succeed on retry. */
  get isRetryable(): boolean {
    if (this.status === 0) return true; // network failure
    if (this.status === 408 || this.status === 429) return true;
    return this.status >= 500;
  }
}

export class ValidationError extends Error {
  constructor(
    readonly path: string,
    readonly issues: z.ZodIssue[],
  ) {
    super(`Response from ${path} did not match its contract`);
    this.name = 'ValidationError';
  }
}

const DEFAULT_TIMEOUT_MS = 30_000;

interface RequestOptions<TResponse> {
  path: string;
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  body?: unknown;
  formData?: FormData;
  /**
   * The third type argument widens the schema's *input* to `unknown`. Without
   * it, any schema using `.default()` has an input type that differs from its
   * output and fails to match `z.ZodType<TResponse>` — which is exactly the
   * shape every response schema here has.
   */
  schema: z.ZodType<TResponse, z.ZodTypeDef, unknown>;
  timeoutMs?: number;
  signal?: AbortSignal;
}

/**
 * Single choke-point for network I/O. Every response is parsed through a Zod
 * schema before it reaches application code, so an upstream contract change
 * surfaces as a typed ValidationError instead of an undefined-property crash
 * three screens later.
 */
export async function request<TResponse>({
  path,
  method = 'GET',
  body,
  formData,
  schema,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  signal,
}: RequestOptions<TResponse>): Promise<TResponse> {
  if (!env.apiBaseUrl) {
    throw new ApiError('No API base URL configured (offline mode)', 0);
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const onAbort = () => controller.abort();
  signal?.addEventListener('abort', onAbort);

  const url = `${env.apiBaseUrl.replace(/\/$/, '')}${path}`;

  try {
    const response = await fetch(url, {
      method,
      signal: controller.signal,
      headers: formData
        ? { Accept: 'application/json' }
        : { Accept: 'application/json', 'Content-Type': 'application/json' },
      body: formData ?? (body != null ? JSON.stringify(body) : undefined),
    });

    const text = await response.text();
    const payload: unknown = text ? safeJsonParse(text) : null;

    if (!response.ok) {
      throw new ApiError(
        extractErrorMessage(payload) ?? `Request failed with ${response.status}`,
        response.status,
        payload,
      );
    }

    const parsed = schema.safeParse(payload);
    if (!parsed.success) {
      log.error('api', `Contract violation on ${path}`, parsed.error.issues);
      throw new ValidationError(path, parsed.error.issues);
    }

    return parsed.data;
  } catch (error) {
    if (error instanceof ApiError || error instanceof ValidationError) throw error;
    if (error instanceof Error && error.name === 'AbortError') {
      throw new ApiError('The request timed out', 408);
    }
    throw new ApiError(
      error instanceof Error ? error.message : 'Network request failed',
      0,
      error,
    );
  } finally {
    clearTimeout(timeout);
    signal?.removeEventListener('abort', onAbort);
  }
}

function safeJsonParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function extractErrorMessage(payload: unknown): string | null {
  if (payload && typeof payload === 'object' && 'message' in payload) {
    const message = (payload as { message: unknown }).message;
    if (typeof message === 'string') return message;
  }
  return null;
}
