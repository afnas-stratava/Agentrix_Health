import {
  AUTO_SELECT_THRESHOLD,
  DISCOVERY_THRESHOLD,
  buildGmailQuery,
  isKnownLabSender,
  scoreCandidate,
} from '@/features/labs/gmail/providers';

const PDF = 'application/pdf';

describe('isKnownLabSender', () => {
  it('matches a known lab domain', () => {
    expect(isKnownLabSender('reports@lalpathlabs.com')).toBe(true);
    expect(isKnownLabSender('noreply@questdiagnostics.com')).toBe(true);
  });

  it('matches subdomains of a known lab', () => {
    expect(isKnownLabSender('auto@reports.lalpathlabs.com')).toBe(true);
  });

  it('normalises common mail-host prefixes', () => {
    expect(isKnownLabSender('x@mail.thyrocare.com')).toBe(true);
  });

  it('does not match an unrelated domain', () => {
    expect(isKnownLabSender('hr@tarento.com')).toBe(false);
  });

  it('is not fooled by a lab name inside another domain', () => {
    // The registrable-domain check must not turn into a substring match.
    expect(isKnownLabSender('phish@labcorp.com.evil.ru')).toBe(false);
  });
});

describe('scoreCandidate', () => {
  it('scores a real report from a known lab above the auto-select bar', () => {
    const { confidence, reasons } = scoreCandidate({
      fromAddress: 'reports@lalpathlabs.com',
      subject: 'Your Lab Report is ready',
      filename: 'LPL_Report_8842193.pdf',
      mimeType: PDF,
      snippet: 'Ferritin, Haemoglobin. Biological reference intervals enclosed.',
    });

    expect(confidence).toBeGreaterThanOrEqual(AUTO_SELECT_THRESHOLD);
    expect(reasons).toContain('known-lab-sender');
    expect(reasons).toContain('medical-subject');
  });

  it('pushes promotional mail from a real lab below discovery', () => {
    // The most common false positive: labs market to the same address they
    // send results to, from the same domain.
    const { confidence } = scoreCandidate({
      fromAddress: 'offers@redcliffelabs.com',
      subject: 'Flat 50% OFF on Full Body Checkup — Book Now!',
      filename: 'offer_flyer.pdf',
      mimeType: PDF,
      snippet: 'Limited period offer. Unsubscribe from these emails.',
    });

    expect(confidence).toBeLessThan(DISCOVERY_THRESHOLD);
  });

  it('scores an unknown sender with report-like content as merely possible', () => {
    const { confidence } = scoreCandidate({
      fromAddress: 'frontdesk@some-clinic.example.com',
      subject: 'Blood test results',
      filename: 'results_scan.pdf',
      mimeType: PDF,
      snippet: 'Attaching the results from your visit.',
    });

    expect(confidence).toBeGreaterThanOrEqual(DISCOVERY_THRESHOLD);
    expect(confidence).toBeLessThan(AUTO_SELECT_THRESHOLD);
  });

  it('ignores attachments that cannot be documents', () => {
    const { confidence, reasons } = scoreCandidate({
      fromAddress: 'reports@lalpathlabs.com',
      subject: 'Your Lab Report is ready',
      filename: 'report.zip',
      mimeType: 'application/zip',
      snippet: 'ferritin',
    });

    expect(confidence).toBe(0);
    expect(reasons).toHaveLength(0);
  });

  it('penalises a bare image with no corroborating signal', () => {
    const bareImage = scoreCandidate({
      fromAddress: 'friend@example.com',
      subject: 'holiday pics',
      filename: 'IMG_2841.jpg',
      mimeType: 'image/jpeg',
    });

    expect(bareImage.confidence).toBeLessThan(DISCOVERY_THRESHOLD);
  });

  it('accepts a photographed report when other signals agree', () => {
    const scanned = scoreCandidate({
      fromAddress: 'care@metropolisindia.com',
      subject: 'Your Health Checkup Report',
      filename: 'report_page1.jpg',
      mimeType: 'image/jpeg',
      snippet: 'Complete blood count, reference range',
    });

    expect(scanned.confidence).toBeGreaterThanOrEqual(DISCOVERY_THRESHOLD);
  });

  it('never returns a score outside 0..1', () => {
    const maxed = scoreCandidate({
      fromAddress: 'reports@lalpathlabs.com',
      subject: 'lab report test result blood report pathology',
      filename: 'lab_report_result_health_profile.pdf',
      mimeType: PDF,
      snippet: 'ferritin hemoglobin creatinine hba1c reference range specimen',
    });
    const floored = scoreCandidate({
      fromAddress: 'spam@example.com',
      subject: 'unsubscribe from newsletter offer discount sale',
      filename: 'a.jpg',
      mimeType: 'image/jpeg',
    });

    expect(maxed.confidence).toBeLessThanOrEqual(1);
    expect(floored.confidence).toBeGreaterThanOrEqual(0);
  });
});

describe('buildGmailQuery', () => {
  const query = buildGmailQuery(730);

  it('restricts to messages with attachments inside the window', () => {
    expect(query).toContain('has:attachment');
    expect(query).toContain('newer_than:730d');
  });

  it('excludes spam and trash', () => {
    expect(query).toContain('-in:spam');
    expect(query).toContain('-in:trash');
  });

  it('ORs lab senders with medical subjects rather than requiring both', () => {
    // Requiring both would miss reports from labs whose subject line is just
    // an invoice number.
    expect(query).toMatch(/\(\(from:.+\) OR \(subject:.+\)\)/);
  });

  it('scopes the search rather than fetching the whole mailbox', () => {
    expect(query).toContain('from:lalpathlabs.com');
    expect(query).not.toBe('has:attachment');
  });
});
