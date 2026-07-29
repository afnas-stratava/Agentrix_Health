import { z } from 'zod';
import { LabParseResponseSchema } from './labs';

/**
 * Gmail connection state.
 *
 * NOTE ON TOKENS: the device never holds a Gmail access or refresh token. The
 * client runs an authorization-code + PKCE flow and forwards only the
 * short-lived `code` to our backend, which performs the exchange and stores
 * the refresh token server-side. A refresh token granting read access to
 * someone's entire inbox is the single most sensitive credential this product
 * touches; it does not belong in AsyncStorage, the keychain, or a redux
 * devtools dump.
 */
export const ConnectionStatusSchema = z.enum([
  'disconnected',
  'connecting',
  'connected',
  'expired',
  'revoked',
  'error',
]);
export type ConnectionStatus = z.infer<typeof ConnectionStatusSchema>;

export const GmailConnectionSchema = z.object({
  connectionId: z.string().min(1),
  /** The connected mailbox, shown so the user can confirm which account. */
  emailAddress: z.string().email(),
  status: ConnectionStatusSchema,
  connectedAt: z.string().datetime({ offset: true }),
  lastScanAt: z.string().datetime({ offset: true }).nullable().default(null),
  /** Scopes actually granted — Google may grant a subset of what we asked. */
  grantedScopes: z.array(z.string()).default([]),
});
export type GmailConnection = z.infer<typeof GmailConnectionSchema>;

/** Why the scanner believes a message contains a lab report. */
export const MatchReasonSchema = z.enum([
  'known-lab-sender',
  'medical-subject',
  'report-filename',
  'medical-body-terms',
  'pdf-attachment',
]);
export type MatchReason = z.infer<typeof MatchReasonSchema>;

export const MATCH_REASON_LABEL: Record<MatchReason, string> = {
  'known-lab-sender': 'Known diagnostics lab',
  'medical-subject': 'Medical subject line',
  'report-filename': 'Report-style filename',
  'medical-body-terms': 'Clinical terms in body',
  'pdf-attachment': 'PDF attachment',
};

/**
 * A candidate attachment discovered in the mailbox. Deliberately carries only
 * metadata — the attachment bytes are never sent to the device unless the user
 * explicitly imports it.
 */
export const LabCandidateSchema = z.object({
  messageId: z.string().min(1),
  attachmentId: z.string().min(1),
  subject: z.string(),
  fromName: z.string(),
  fromAddress: z.string(),
  receivedAt: z.string().datetime({ offset: true }),
  filename: z.string(),
  mimeType: z.string(),
  sizeBytes: z.number().int().nonnegative(),
  /** 0–1 heuristic score; the UI pre-selects anything above 0.6. */
  confidence: z.number().min(0).max(1),
  matchReasons: z.array(MatchReasonSchema).default([]),
  /**
   * Indian and UK labs very commonly email password-protected PDFs keyed on
   * date of birth or phone number. The scanner detects encryption up front so
   * the UI can ask once, rather than failing mid-import.
   */
  isPasswordProtected: z.boolean().default(false),
  /** True when this exact attachment has already been imported. */
  alreadyImported: z.boolean().default(false),
});
export type LabCandidate = z.infer<typeof LabCandidateSchema>;

export const GmailScanResultSchema = z.object({
  scanId: z.string().min(1),
  scannedAt: z.string().datetime({ offset: true }),
  /** How many messages were examined, for an honest "we looked at N" line. */
  messagesExamined: z.number().int().nonnegative(),
  candidates: z.array(LabCandidateSchema),
  /** Set when Gmail paginated out; the UI offers to widen the window. */
  truncated: z.boolean().default(false),
});
export type GmailScanResult = z.infer<typeof GmailScanResultSchema>;

/** Import of one candidate returns the same payload as a manual upload. */
export const GmailImportResponseSchema = LabParseResponseSchema.extend({
  messageId: z.string().min(1),
  attachmentId: z.string().min(1),
});
export type GmailImportResponse = z.infer<typeof GmailImportResponseSchema>;

export const ImportErrorReasonSchema = z.enum([
  'wrong-password',
  'encrypted-unsupported',
  'unreadable',
  'no-biomarkers',
  'network',
  'unknown',
]);
export type ImportErrorReason = z.infer<typeof ImportErrorReasonSchema>;

export const IMPORT_ERROR_COPY: Record<ImportErrorReason, string> = {
  'wrong-password': 'That password did not unlock the PDF. Labs often use your date of birth (DDMMYYYY) or the last digits of your phone number.',
  'encrypted-unsupported': 'This PDF uses an encryption scheme we cannot open. Download it, remove the password, and upload it manually.',
  unreadable: 'We could not read any text from this document.',
  'no-biomarkers': 'No recognisable biomarkers were found — this may not be a lab report.',
  network: 'Could not reach the parsing service. Check your connection and retry.',
  unknown: 'Something went wrong importing this report.',
};
