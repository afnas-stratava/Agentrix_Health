import { useCallback } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import type { LabReport, LabUploadRequest } from '@/schemas/labs';
import { queryKeys } from '@/lib/query-client';
import { createId } from '@/lib/id';
import { nowIso } from '@/lib/date';
import { log } from '@/lib/logger';
import { useLabsStore } from '@/store/labs.store';
import { useSettingsStore, selectSex } from '@/store/settings.store';
import { parseLabReport } from './parser';

/**
 * Uploads and parses a report.
 *
 * A placeholder row is written to the store immediately so the Labs tab shows
 * the pending report the instant the picker closes — the parse can take 30+
 * seconds and an empty list in the meantime reads as a failure.
 */
export function useUploadLabReport() {
  const queryClient = useQueryClient();
  const sex = useSettingsStore(selectSex);
  const upsertReport = useLabsStore((s) => s.upsertReport);
  const removeReport = useLabsStore((s) => s.removeReport);

  return useMutation<LabReport, Error, LabUploadRequest, { placeholderId: string }>({
    mutationFn: async (upload) => parseLabReport(upload, { sex }),

    onMutate: (upload) => {
      const placeholderId = createId('pending');
      upsertReport({
        id: placeholderId,
        source: upload.source,
        status: 'parsing',
        collectedAt: null,
        uploadedAt: nowIso(),
        labName: null,
        panelName: null,
        biomarkers: [],
        fileUri: upload.uri,
        fileName: upload.name,
        fileSizeBytes: upload.sizeBytes,
        error: null,
      });
      return { placeholderId };
    },

    onSuccess: (report, _upload, context) => {
      // Swap the placeholder for the parsed report rather than leaving both.
      if (context?.placeholderId) removeReport(context.placeholderId);
      upsertReport(report);
      void queryClient.invalidateQueries({ queryKey: queryKeys.insights.all });
    },

    onError: (error, upload, context) => {
      log.error('labs', 'Lab parse failed', error);
      if (!context?.placeholderId) return;

      // Keep the row, flipped to `failed`, so the user can retry or delete it.
      upsertReport({
        id: context.placeholderId,
        source: upload.source,
        status: 'failed',
        collectedAt: null,
        uploadedAt: nowIso(),
        labName: null,
        panelName: null,
        biomarkers: [],
        fileUri: upload.uri,
        fileName: upload.name,
        fileSizeBytes: upload.sizeBytes,
        error: error.message,
      });
    },
  });
}

export function useDeleteLabReport() {
  const queryClient = useQueryClient();
  const removeReport = useLabsStore((s) => s.removeReport);

  return useCallback(
    (id: string) => {
      removeReport(id);
      void queryClient.invalidateQueries({ queryKey: queryKeys.insights.all });
    },
    [removeReport, queryClient],
  );
}

/** Lets the user correct a mis-OCR'd value without re-uploading. */
export function useCorrectBiomarker() {
  const queryClient = useQueryClient();
  const reports = useLabsStore((s) => s.reports);
  const upsertReport = useLabsStore((s) => s.upsertReport);

  return useCallback(
    (reportId: string, rawName: string, value: number) => {
      const report = reports.find((r) => r.id === reportId);
      if (!report) return;

      upsertReport({
        ...report,
        status: 'ready',
        biomarkers: report.biomarkers.map((biomarker) =>
          biomarker.rawName === rawName ? { ...biomarker, value, confidence: 1 } : biomarker,
        ),
      });

      void queryClient.invalidateQueries({ queryKey: queryKeys.insights.all });
    },
    [reports, upsertReport, queryClient],
  );
}
