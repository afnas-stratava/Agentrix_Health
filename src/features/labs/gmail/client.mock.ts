import {
  GmailConnectionSchema,
  GmailImportResponseSchema,
  GmailScanResultSchema,
  LabCandidateSchema,
  type GmailConnection,
  type GmailImportResponse,
  type GmailScanResult,
  type LabCandidate,
} from '@/schemas/connections';
import { createId } from '@/lib/id';
import { addDays, nowIso } from '@/lib/date';
import { parseLocally } from '../parser.mock';
import { scoreCandidate, DISCOVERY_THRESHOLD } from './providers';
import { ImportFailed } from './errors';

/**
 * Offline fixtures for the Gmail import flow.
 *
 * The candidate set is chosen to exercise every branch of the review UI:
 * a high-confidence report from a known lab, a password-protected one (the
 * norm for Indian labs), a lower-confidence attachment from an unknown sender,
 * one already imported, and a promotional email from a real lab that the
 * scorer must push below the discovery threshold.
 */

let connection: GmailConnection | null = null;

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function connectGmail(): Promise<GmailConnection> {
  await delay(900);

  connection = GmailConnectionSchema.parse({
    connectionId: createId('conn'),
    emailAddress: 'you@example.com',
    status: 'connected',
    connectedAt: nowIso(),
    lastScanAt: null,
    grantedScopes: [
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/userinfo.email',
    ],
  });

  return connection;
}

export async function getGmailConnection(): Promise<GmailConnection | null> {
  await delay(120);
  return connection;
}

export async function disconnectGmail(): Promise<void> {
  await delay(250);
  connection = null;
}

interface Seed {
  subject: string;
  fromName: string;
  fromAddress: string;
  filename: string;
  mimeType: string;
  sizeBytes: number;
  daysAgo: number;
  snippet: string;
  isPasswordProtected?: boolean;
  alreadyImported?: boolean;
}

const SEEDS: Seed[] = [
  {
    subject: 'Your Lab Report is ready — Comprehensive Health Checkup',
    fromName: 'Dr Lal PathLabs',
    fromAddress: 'reports@lalpathlabs.com',
    filename: 'LPL_Report_8842193.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 412_884,
    daysAgo: 9,
    snippet:
      'Dear Patient, please find attached your test report. Collected on 19 Jul. Haemoglobin, Ferritin, Lipid Profile, Vitamin D. Biological reference intervals are provided.',
    isPasswordProtected: true,
  },
  {
    subject: 'Thyrocare — Test Report (Aarogyam 1.3)',
    fromName: 'Thyrocare Technologies',
    fromAddress: 'noreply@thyrocare.com',
    filename: 'Aarogyam_Report.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 288_140,
    daysAgo: 96,
    snippet: 'Your test report is attached. TSH, Vitamin B12, HbA1c, Creatinine. Reported on 03 May.',
  },
  {
    subject: 'Blood test results',
    fromName: 'City Clinic',
    fromAddress: 'frontdesk@cityclinic-example.com',
    filename: 'results_scan.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 1_204_553,
    daysAgo: 210,
    snippet: 'Attaching the results from your visit. Please book a follow-up if you have questions.',
  },
  {
    subject: 'Metropolis — Your Health Checkup Report',
    fromName: 'Metropolis Healthcare',
    fromAddress: 'care@metropolisindia.com',
    filename: 'Metropolis_HealthReport_Mar.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 356_902,
    daysAgo: 285,
    snippet: 'Report attached. Complete Blood Count, Lipid Profile, Liver Function Test.',
    alreadyImported: true,
  },
  {
    subject: 'Flat 50% OFF on Full Body Checkup — Book Now!',
    fromName: 'Redcliffe Labs',
    fromAddress: 'offers@redcliffelabs.com',
    filename: 'offer_flyer.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 890_233,
    daysAgo: 4,
    snippet:
      'Limited period offer! Book now and get 50% off on our full body checkup package. Unsubscribe from these emails.',
  },
];

function toCandidate(seed: Seed): LabCandidate {
  const { confidence, reasons } = scoreCandidate({
    fromAddress: seed.fromAddress,
    subject: seed.subject,
    filename: seed.filename,
    mimeType: seed.mimeType,
    snippet: seed.snippet,
  });

  return LabCandidateSchema.parse({
    messageId: `msg_${seed.filename.replace(/\W+/g, '_').toLowerCase()}`,
    attachmentId: `att_${seed.filename.replace(/\W+/g, '_').toLowerCase()}`,
    subject: seed.subject,
    fromName: seed.fromName,
    fromAddress: seed.fromAddress,
    receivedAt: addDays(new Date(), -seed.daysAgo).toISOString(),
    filename: seed.filename,
    mimeType: seed.mimeType,
    sizeBytes: seed.sizeBytes,
    confidence,
    matchReasons: reasons,
    isPasswordProtected: seed.isPasswordProtected ?? false,
    alreadyImported: seed.alreadyImported ?? false,
  });
}

export async function scanGmail(sinceDays: number): Promise<GmailScanResult> {
  // Mailbox scans genuinely take a while; exercise the progress UI.
  await delay(2200);

  const candidates = SEEDS.filter((seed) => seed.daysAgo <= sinceDays)
    .map(toCandidate)
    // The promotional email is scored down by the same logic the real scan
    // uses, so the fixture proves the filter works rather than hiding it.
    .filter((candidate) => candidate.confidence >= DISCOVERY_THRESHOLD)
    .sort((a, b) => b.confidence - a.confidence);

  if (connection) connection = { ...connection, lastScanAt: nowIso() };

  return GmailScanResultSchema.parse({
    scanId: createId('scan'),
    scannedAt: nowIso(),
    messagesExamined: 1_284,
    candidates,
    truncated: false,
  });
}

export async function importFromGmail(
  messageId: string,
  attachmentId: string,
  password?: string,
): Promise<GmailImportResponse> {
  const candidate = SEEDS.map(toCandidate).find((c) => c.attachmentId === attachmentId);

  if (candidate?.isPasswordProtected && !password) {
    throw new ImportFailed('wrong-password', 'This report needs a password');
  }

  const parsed = await parseLocally({
    uri: `gmail://${messageId}/${attachmentId}`,
    name: candidate?.filename ?? 'report.pdf',
    mimeType: 'application/pdf',
    sizeBytes: candidate?.sizeBytes ?? 200_000,
    source: 'pdf',
  });

  return GmailImportResponseSchema.parse({ ...parsed, messageId, attachmentId });
}
