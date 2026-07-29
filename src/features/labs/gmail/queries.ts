import { useCallback } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { GmailConnection, GmailScanResult, LabCandidate } from '@/schemas/connections';
import type { LabReport } from '@/schemas/labs';
import { queryKeys } from '@/lib/query-client';
import { nowIso } from '@/lib/date';
import { log } from '@/lib/logger';
import { useConnectionsStore } from '@/store/connections.store';
import { useLabsStore } from '@/store/labs.store';
import { useSettingsStore, selectSex } from '@/store/settings.store';
import { enrichBiomarker } from '../reference-ranges';
import { authorizeGmail, hasRequiredScopes } from './auth';
import {
  connectGmail,
  disconnectGmail,
  getGmailConnection,
  importFromGmail,
  scanGmail,
} from './client';
import { ImportFailed } from './errors';

/** Default lookback for a scan — two years catches most annual checkups. */
export const DEFAULT_SCAN_DAYS = 730;

export const gmailKeys = {
  all: ['gmail'] as const,
  connection: () => [...gmailKeys.all, 'connection'] as const,
  scan: (sinceDays: number) => [...gmailKeys.all, 'scan', sinceDays] as const,
};

/** Reconciles the locally cached connection with the server's view. */
export function useGmailConnection() {
  const setGmail = useConnectionsStore((s) => s.setGmail);
  const cached = useConnectionsStore((s) => s.gmail);

  const query = useQuery({
    queryKey: gmailKeys.connection(),
    queryFn: async () => {
      const connection = await getGmailConnection();
      setGmail(connection);
      return connection;
    },
    // The server is authoritative — a user can revoke access from their Google
    // account page at any time, and we would otherwise show "Connected"
    // indefinitely.
    staleTime: 5 * 60_000,
    initialData: cached,
  });

  return query;
}

/**
 * Runs the full connect handshake: browser authorization on device, then a
 * server-side code exchange. Returns the stored connection.
 */
export function useConnectGmail() {
  const queryClient = useQueryClient();
  const setGmail = useConnectionsStore((s) => s.setGmail);

  return useMutation<GmailConnection>({
    mutationFn: async () => {
      const grant = await authorizeGmail();
      const connection = await connectGmail(grant);

      // Google can grant a subset of the requested scopes if the user unticks
      // one on the consent screen. Without gmail.readonly there is no feature.
      if (
        connection.grantedScopes.length > 0 &&
        !hasRequiredScopes(connection.grantedScopes)
      ) {
        throw new Error(
          'Gmail read access was not granted. Reconnect and leave the Gmail permission ticked.',
        );
      }

      return connection;
    },
    onSuccess: (connection) => {
      setGmail(connection);
      void queryClient.invalidateQueries({ queryKey: gmailKeys.all });
    },
  });
}

export function useDisconnectGmail() {
  const queryClient = useQueryClient();
  const gmail = useConnectionsStore((s) => s.gmail);
  const reset = useConnectionsStore((s) => s.reset);

  return useMutation<void>({
    mutationFn: async () => {
      if (gmail) await disconnectGmail(gmail.connectionId);
    },
    onSuccess: () => {
      reset();
      queryClient.removeQueries({ queryKey: gmailKeys.all });
    },
  });
}

/**
 * Scans the mailbox. Not auto-run: a mailbox scan is a privacy-visible action
 * and should follow an explicit tap, never a screen mount.
 */
export function useGmailScan(sinceDays: number = DEFAULT_SCAN_DAYS) {
  const importedIds = useConnectionsStore((s) => s.importedAttachmentIds);

  return useMutation<GmailScanResult, Error, void>({
    mutationFn: async () => {
      const result = await scanGmail({ sinceDays });
      log.info('labs', `Gmail scan surfaced ${result.candidates.length} candidates`);

      // Reconcile the server's view with what this device already imported —
      // the backend does not track per-device library state.
      return { ...result, candidates: markKnownImports(result.candidates, importedIds) };
    },
  });
}

/** Applies local import history to a freshly-scanned candidate list. */
export function markKnownImports(
  candidates: LabCandidate[],
  importedIds: readonly string[],
): LabCandidate[] {
  const known = new Set(importedIds);
  return candidates.map((candidate) =>
    known.has(candidate.attachmentId)
      ? { ...candidate, alreadyImported: true }
      : candidate,
  );
}

export interface ImportVariables {
  candidate: LabCandidate;
  password?: string;
}

/**
 * Imports one candidate into the local lab library.
 *
 * Single-candidate rather than batch on purpose: each PDF can fail for its own
 * reason (wrong password, unreadable scan), and a batch endpoint would force
 * an all-or-nothing result on a screen where partial success is the norm.
 */
export function useImportCandidate() {
  const queryClient = useQueryClient();
  const sex = useSettingsStore(selectSex);
  const upsertReport = useLabsStore((s) => s.upsertReport);
  const markImported = useConnectionsStore((s) => s.markImported);

  return useMutation<LabReport, ImportFailed, ImportVariables>({
    mutationFn: async ({ candidate, password }) => {
      const response = await importFromGmail({
        messageId: candidate.messageId,
        attachmentId: candidate.attachmentId,
        ...(password ? { password } : {}),
      });

      const biomarkers = response.biomarkers.map((b) => enrichBiomarker(b, sex));
      if (biomarkers.length === 0) {
        throw new ImportFailed('no-biomarkers', 'No biomarkers found in this document');
      }

      return {
        id: response.reportId,
        source: 'pdf',
        status: response.overallConfidence < 0.7 ? 'needs-review' : response.status,
        collectedAt: response.collectedAt,
        uploadedAt: nowIso(),
        labName: response.labName ?? candidate.fromName,
        panelName: response.panelName ?? candidate.subject,
        biomarkers,
        // The document stays in the mailbox; we keep a pointer, not a copy.
        fileUri: null,
        fileName: candidate.filename,
        fileSizeBytes: candidate.sizeBytes,
        error: null,
      } satisfies LabReport;
    },

    onSuccess: (report, { candidate }) => {
      upsertReport(report);
      markImported([candidate.attachmentId]);
      void queryClient.invalidateQueries({ queryKey: queryKeys.insights.all });
    },
  });
}

/** Convenience wrapper for importing several candidates sequentially. */
export function useImportQueue() {
  const importOne = useImportCandidate();

  const run = useCallback(
    async (candidates: LabCandidate[], passwords: Record<string, string>) => {
      const results: Array<{ candidate: LabCandidate; error: ImportFailed | null }> = [];

      // Sequential, not parallel: the parsing service is the bottleneck and
      // firing ten OCR jobs at once just times them all out together.
      for (const candidate of candidates) {
        try {
          const password = passwords[candidate.attachmentId];
          await importOne.mutateAsync({ candidate, ...(password ? { password } : {}) });
          results.push({ candidate, error: null });
        } catch (error) {
          results.push({
            candidate,
            error:
              error instanceof ImportFailed
                ? error
                : new ImportFailed('unknown', 'Import failed'),
          });
        }
      }

      return results;
    },
    [importOne],
  );

  return { run, isImporting: importOne.isPending };
}
