import type { MatchReason } from '@/schemas/connections';

/**
 * Registry of diagnostics providers that email results to patients.
 *
 * This list is the difference between a scan that finds the user's bloods and
 * one that returns their gym newsletter. It is weighted toward India (where
 * emailed, password-protected PDF reports are the norm), then the US, UK and
 * the direct-to-consumer testing market.
 *
 * Domains are matched on the *registrable* portion, so `reports.lalpathlabs.com`
 * and `noreply@lalpathlabs.com` both hit.
 */
export const LAB_SENDER_DOMAINS: readonly string[] = [
  // India
  'lalpathlabs.com',
  'labs.lalpathlabs.com',
  'metropolisindia.com',
  'thyrocare.com',
  'srlworld.com',
  'srldiagnostics.com',
  'agilus.in',
  'agilusdiagnostics.com',
  'apollodiagnostics.in',
  'apollo247.com',
  'redcliffelabs.com',
  'healthians.com',
  'orangehealth.in',
  'tata1mg.com',
  'pharmeasy.in',
  'maxlab.co.in',
  'neubergdiagnostics.com',
  'vijayadiagnostic.com',
  'suburbandiagnostics.com',
  // United States
  'labcorp.com',
  'questdiagnostics.com',
  'myquest.questdiagnostics.com',
  'sonoraquest.com',
  'bioreference.com',
  'everlywell.com',
  'functionhealth.com',
  'insidetracker.com',
  'letsgetchecked.com',
  'ownyourlabs.com',
  'ultalabtests.com',
  // United Kingdom / Europe
  'medichecks.com',
  'thriva.co',
  'randoxhealth.com',
  'bluecrest.co.uk',
  'nuffieldhealth.com',
  'synlab.co.uk',
  // Hospital / EHR portals that forward results
  'mychart.com',
  'followmyhealth.com',
  'healow.com',
  'practo.com',
];

/** Subject-line terms that suggest a diagnostic result. */
const SUBJECT_TERMS: readonly string[] = [
  'lab report',
  'lab result',
  'test report',
  'test result',
  'blood test',
  'blood report',
  'pathology',
  'diagnostic report',
  'health checkup',
  'health check-up',
  'master health',
  'investigation report',
  'biochemistry',
  'haematology',
  'hematology',
  'lipid profile',
  'thyroid profile',
  'cbc report',
  'your results',
  'your report',
  'medical report',
  'radiology',
];

/** Filename fragments typical of an emailed report. */
const FILENAME_TERMS: readonly string[] = [
  'report',
  'result',
  'lab',
  'path',
  'diagnos',
  'bloodtest',
  'blood_test',
  'health',
  'checkup',
  'profile',
  'panel',
];

/** Clinical terms whose presence in the snippet raises confidence. */
const BODY_TERMS: readonly string[] = [
  'haemoglobin',
  'hemoglobin',
  'ferritin',
  'creatinine',
  'cholesterol',
  'triglyceride',
  'hba1c',
  'tsh',
  'vitamin d',
  'vitamin b12',
  'reference range',
  'biological reference',
  'specimen',
  'phlebotomy',
  'collected on',
  'reported on',
];

const PDF_MIME = 'application/pdf';
const IMAGE_MIMES = new Set(['image/jpeg', 'image/png', 'image/heic', 'image/heif']);

/**
 * Terms that strongly indicate the message is *marketing about* testing rather
 * than an actual result. Without this, "Book your full body checkup — 50% off"
 * scores as high as a real report from the same sender.
 */
const PROMOTIONAL_TERMS: readonly string[] = [
  'book now',
  'offer',
  'discount',
  '% off',
  'sale',
  'coupon',
  'newsletter',
  'unsubscribe from',
  'limited period',
  'cashback',
  'refer a friend',
];

function registrableDomain(address: string): string {
  const at = address.lastIndexOf('@');
  const host = (at >= 0 ? address.slice(at + 1) : address).toLowerCase().trim();
  return host.replace(/^mail\./, '').replace(/^email\./, '').replace(/^noreply\./, '');
}

export function isKnownLabSender(fromAddress: string): boolean {
  const host = registrableDomain(fromAddress);
  return LAB_SENDER_DOMAINS.some((domain) => host === domain || host.endsWith(`.${domain}`));
}

function containsAny(haystack: string, needles: readonly string[]): boolean {
  const lower = haystack.toLowerCase();
  return needles.some((needle) => lower.includes(needle));
}

export interface ScoreInput {
  fromAddress: string;
  subject: string;
  filename: string;
  mimeType: string;
  /** Gmail's message snippet, when available. */
  snippet?: string;
}

export interface ScoreResult {
  confidence: number;
  reasons: MatchReason[];
}

/**
 * Heuristic confidence that an attachment is a lab report.
 *
 * Weighted rather than boolean because no single signal is sufficient: a PDF
 * from LabCorp is almost certainly a result, a PDF called `report.pdf` from a
 * colleague almost certainly is not, and the interesting cases sit between.
 *
 * The score is capped below 1.0 for anything that is not a PDF from a known
 * sender, so the UI never pre-selects something on weak evidence alone.
 */
export function scoreCandidate({
  fromAddress,
  subject,
  filename,
  mimeType,
  snippet = '',
}: ScoreInput): ScoreResult {
  const reasons: MatchReason[] = [];
  let score = 0;

  const isPdf = mimeType.toLowerCase() === PDF_MIME;
  const isImage = IMAGE_MIMES.has(mimeType.toLowerCase());

  // A non-document attachment is not a report, whatever else matches.
  if (!isPdf && !isImage) {
    return { confidence: 0, reasons: [] };
  }

  if (isKnownLabSender(fromAddress)) {
    score += 0.55;
    reasons.push('known-lab-sender');
  }

  if (containsAny(subject, SUBJECT_TERMS)) {
    score += 0.25;
    reasons.push('medical-subject');
  }

  if (containsAny(filename, FILENAME_TERMS)) {
    score += 0.15;
    reasons.push('report-filename');
  }

  if (containsAny(snippet, BODY_TERMS)) {
    score += 0.2;
    reasons.push('medical-body-terms');
  }

  if (isPdf) {
    score += 0.1;
    reasons.push('pdf-attachment');
  }

  // Promotional mail from a real lab is the most common false positive.
  if (containsAny(`${subject} ${snippet}`, PROMOTIONAL_TERMS)) {
    score -= 0.45;
  }

  // Photos need corroborating signal; a bare JPEG is almost never a report.
  if (isImage && reasons.length <= 1) {
    score -= 0.2;
  }

  return {
    confidence: Math.max(0, Math.min(1, Number(score.toFixed(2)))),
    reasons,
  };
}

/** Candidates at or above this are pre-ticked in the import review list. */
export const AUTO_SELECT_THRESHOLD = 0.6;

/** Below this we do not show the candidate at all. */
export const DISCOVERY_THRESHOLD = 0.3;

/**
 * Builds the Gmail search query the backend runs.
 *
 * Kept client-side and sent with the scan request so the filtering logic is
 * versioned with the app rather than hidden in a server deploy — and so this
 * function can be unit-tested. Gmail caps query length, so sender domains are
 * OR-ed in a single clause rather than one term each.
 */
export function buildGmailQuery(sinceDays: number): string {
  const senders = LAB_SENDER_DOMAINS.map((d) => `from:${d}`).join(' OR ');
  const subjects = SUBJECT_TERMS.map((t) => `subject:"${t}"`).join(' OR ');

  return [
    'has:attachment',
    `newer_than:${sinceDays}d`,
    '-in:spam',
    '-in:trash',
    `((${senders}) OR (${subjects}))`,
  ].join(' ');
}
