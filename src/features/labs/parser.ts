import type { LabParseResponse, LabReport, LabUploadRequest } from '@/schemas/labs';
import { LabParseResponseSchema } from '@/schemas/labs';
import { request } from '@/lib/api';
import { isOfflineMode } from '@/lib/env';
import { log } from '@/lib/logger';
import { nowIso } from '@/lib/date';
import { enrichBiomarker, type BiologicalSex } from './reference-ranges';
import { parseLocally } from './parser.mock';

/** Below this mean confidence the report is routed to manual review. */
const REVIEW_THRESHOLD = 0.7;

/**
 * Sends the document to the parsing service. React Native's `fetch` streams
 * the file from disk when given a `{ uri, name, type }` part, so a 20 MB PDF
 * never has to be base64'd through the bridge.
 */
async function parseRemotely(
  upload: LabUploadRequest,
  signal?: AbortSignal,
): Promise<LabParseResponse> {
  const form = new FormData();
  form.append('document', {
    uri: upload.uri,
    name: upload.name,
    type: upload.mimeType,
  } as unknown as Blob);
  form.append('source', upload.source);

  return request({
    path: '/v1/labs/parse',
    method: 'POST',
    formData: form,
    schema: LabParseResponseSchema,
    // OCR + extraction on a multi-page panel is genuinely slow.
    timeoutMs: 90_000,
    ...(signal ? { signal } : {}),
  });
}

export interface ParseOptions {
  sex: BiologicalSex;
  signal?: AbortSignal;
}

/**
 * Parses an uploaded document into a fully-flagged `LabReport`.
 *
 * Flagging happens client-side against the app's reference table even when the
 * backend already supplied ranges — the "optimal band" opinion belongs to the
 * app, and keeping it here means it can be revised without a server deploy.
 */
export async function parseLabReport(
  upload: LabUploadRequest,
  { sex, signal }: ParseOptions,
): Promise<LabReport> {
  const response = isOfflineMode
    ? await parseLocally(upload)
    : await parseRemotely(upload, signal);

  const biomarkers = response.biomarkers.map((biomarker) => enrichBiomarker(biomarker, sex));

  const mappedCount = biomarkers.filter((b) => b.code != null).length;
  if (mappedCount === 0) {
    log.warn('labs', 'Parser returned no recognisable biomarkers', {
      reportId: response.reportId,
    });
  }

  const status: LabReport['status'] =
    response.overallConfidence < REVIEW_THRESHOLD || mappedCount === 0
      ? 'needs-review'
      : response.status;

  return {
    id: response.reportId,
    source: upload.source,
    status,
    collectedAt: response.collectedAt,
    uploadedAt: nowIso(),
    labName: response.labName,
    panelName: response.panelName,
    biomarkers,
    fileUri: upload.uri,
    fileName: upload.name,
    fileSizeBytes: upload.sizeBytes,
    error: null,
  };
}

/** Re-flags an existing report, e.g. after the user corrects their sex. */
export function reflagReport(report: LabReport, sex: BiologicalSex): LabReport {
  return {
    ...report,
    biomarkers: report.biomarkers.map((biomarker) => enrichBiomarker(biomarker, sex)),
  };
}
