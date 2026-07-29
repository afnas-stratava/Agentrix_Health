import { z } from 'zod';
import {
  GmailConnectionSchema,
  GmailImportResponseSchema,
  GmailScanResultSchema,
  type GmailConnection,
  type GmailImportResponse,
  type GmailScanResult,
} from '@/schemas/connections';
import { ApiError, request } from '@/lib/api';
import { isOfflineMode } from '@/lib/env';
import type { AuthorizationGrant } from './auth';
import { buildGmailQuery } from './providers';
import { ImportFailed } from './errors';
import * as fixtures from './client.mock';

export { ImportFailed } from './errors';

/**
 * Exchanges the authorization code for a stored server-side connection.
 *
 * The backend owns the token exchange, encrypts the refresh token at rest, and
 * hands back only an opaque `connectionId`. Nothing sensitive returns to the
 * device.
 */
export async function connectGmail(grant: AuthorizationGrant): Promise<GmailConnection> {
  if (isOfflineMode) return fixtures.connectGmail();

  return request({
    path: '/v1/connections/gmail',
    method: 'POST',
    body: {
      code: grant.code,
      codeVerifier: grant.codeVerifier,
      redirectUri: grant.redirectUri,
    },
    schema: GmailConnectionSchema,
  });
}

export async function getGmailConnection(): Promise<GmailConnection | null> {
  if (isOfflineMode) return fixtures.getGmailConnection();

  try {
    return await request({
      path: '/v1/connections/gmail',
      method: 'GET',
      schema: GmailConnectionSchema,
    });
  } catch (error) {
    // No connection is a normal state, not an error worth surfacing.
    if (error instanceof ApiError && error.status === 404) return null;
    throw error;
  }
}

export async function disconnectGmail(connectionId: string): Promise<void> {
  if (isOfflineMode) return fixtures.disconnectGmail();

  await request({
    path: `/v1/connections/gmail/${encodeURIComponent(connectionId)}`,
    method: 'DELETE',
    schema: z.object({ revoked: z.boolean() }),
  });
}

export interface ScanOptions {
  /** How far back to search. */
  sinceDays: number;
  signal?: AbortSignal;
}

/**
 * Asks the backend to search the mailbox and return attachment *metadata*.
 *
 * The search query is built client-side and sent along, so the matching logic
 * is versioned with the app and unit-testable rather than buried in a server
 * deploy. The backend is still free to reject or narrow it.
 */
export async function scanGmail({ sinceDays, signal }: ScanOptions): Promise<GmailScanResult> {
  if (isOfflineMode) return fixtures.scanGmail(sinceDays);

  return request({
    path: '/v1/connections/gmail/scan',
    method: 'POST',
    body: { query: buildGmailQuery(sinceDays), sinceDays },
    schema: GmailScanResultSchema,
    // Scanning a large mailbox and probing attachments for encryption is slow.
    timeoutMs: 120_000,
    ...(signal ? { signal } : {}),
  });
}

export interface ImportOptions {
  messageId: string;
  attachmentId: string;
  /** Supplied only for password-protected PDFs. Never persisted. */
  password?: string;
  signal?: AbortSignal;
}

export async function importFromGmail({
  messageId,
  attachmentId,
  password,
  signal,
}: ImportOptions): Promise<GmailImportResponse> {
  if (isOfflineMode) return fixtures.importFromGmail(messageId, attachmentId, password);

  try {
    return await request({
      path: '/v1/labs/import-from-gmail',
      method: 'POST',
      body: { messageId, attachmentId, ...(password ? { password } : {}) },
      schema: GmailImportResponseSchema,
      timeoutMs: 90_000,
      ...(signal ? { signal } : {}),
    });
  } catch (error) {
    throw toImportFailure(error);
  }
}

/** Maps transport errors onto reasons the UI can act on. */
function toImportFailure(error: unknown): ImportFailed {
  if (error instanceof ImportFailed) return error;

  if (error instanceof ApiError) {
    const code =
      error.body && typeof error.body === 'object' && 'reason' in error.body
        ? String((error.body as { reason: unknown }).reason)
        : null;

    switch (code) {
      case 'wrong-password':
        return new ImportFailed('wrong-password', error.message);
      case 'encrypted-unsupported':
        return new ImportFailed('encrypted-unsupported', error.message);
      case 'unreadable':
        return new ImportFailed('unreadable', error.message);
      case 'no-biomarkers':
        return new ImportFailed('no-biomarkers', error.message);
      default:
        break;
    }

    if (error.status === 0 || error.status === 408) {
      return new ImportFailed('network', error.message);
    }
  }

  return new ImportFailed('unknown', error instanceof Error ? error.message : 'Import failed');
}
