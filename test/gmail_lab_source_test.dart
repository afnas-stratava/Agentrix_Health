import 'package:flutter_test/flutter_test.dart';

import 'package:agentrix_health/data/labs/gmail_lab_source.dart';
import 'package:agentrix_health/domain/entities/labs/lab_report.dart';

/// Covers payload walking and filtering. Real lab mail buries the PDF several
/// levels inside nested multipart containers, alongside inline logos that must
/// not be mistaken for reports.
void main() {
  Map<String, dynamic> part({
    String filename = '',
    String? attachmentId,
    int size = 1024,
    List<Map<String, dynamic>>? parts,
  }) => {
    'filename': filename,
    'body': {'attachmentId': ?attachmentId, 'size': size},
    'parts': ?parts,
  };

  test('finds an attachment nested inside multipart containers', () {
    final found = GmailLabSource.attachmentsFromPayload(
      part(
        parts: [
          part(parts: [part(filename: 'results.pdf', attachmentId: 'a1')]),
        ],
      ),
    );

    expect(found, hasLength(1));
    expect(found.single.filename, 'results.pdf');
    expect(found.single.attachmentId, 'a1');
  });

  test('ignores file types the parser cannot read', () {
    final found = GmailLabSource.attachmentsFromPayload(
      part(
        parts: [
          part(filename: 'report.pdf', attachmentId: 'a1'),
          part(filename: 'calendar.ics', attachmentId: 'a2'),
          part(filename: 'archive.zip', attachmentId: 'a3'),
        ],
      ),
    );

    expect(found.map((a) => a.filename), ['report.pdf']);
  });

  test('ignores inline body parts that carry no attachmentId', () {
    final found = GmailLabSource.attachmentsFromPayload(
      part(parts: [part(filename: 'logo.png')]),
    );

    expect(found, isEmpty);
  });

  test('skips attachments above the upload size limit', () {
    final found = GmailLabSource.attachmentsFromPayload(
      part(
        parts: [
          part(
            filename: 'huge.pdf',
            attachmentId: 'a1',
            size: LabUpload.maxSizeBytes + 1,
          ),
          part(filename: 'fine.pdf', attachmentId: 'a2', size: 2048),
        ],
      ),
    );

    expect(found.map((a) => a.filename), ['fine.pdf']);
  });

  test('matches extensions case-insensitively', () {
    final found = GmailLabSource.attachmentsFromPayload(
      part(parts: [part(filename: 'RESULTS.PDF', attachmentId: 'a1')]),
    );

    expect(found, hasLength(1));
  });

  test('survives a malformed payload rather than throwing', () {
    expect(GmailLabSource.attachmentsFromPayload(null), isEmpty);
    expect(GmailLabSource.attachmentsFromPayload('not a map'), isEmpty);
  });

  group('senderName', () {
    GmailAttachment withFrom(String from) => GmailAttachment(
      messageId: 'm',
      attachmentId: 'a',
      filename: 'f.pdf',
      subject: 's',
      from: from,
      receivedAt: DateTime(2026),
    );

    test('strips the angle-bracket address', () {
      expect(withFrom('Quest Diagnostics <no-reply@quest.com>').senderName,
          'Quest Diagnostics');
    });

    test('strips surrounding quotes', () {
      expect(withFrom('"Labcorp Results" <r@labcorp.com>').senderName,
          'Labcorp Results');
    });

    test('falls back to the bare address when there is no display name', () {
      expect(withFrom('results@labcorp.com').senderName, 'results@labcorp.com');
    });
  });
}
