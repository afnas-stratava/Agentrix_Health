import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../domain/entities/labs/lab_report.dart';

/// No backend in this build: no Google sign-in, no Gmail API call.
/// [findCandidates] returns a fixed set of plausible-looking candidates and
/// [download] never actually fetches anything, so the import screen
/// (search → pick → "import") still reads as real. A real backend restores
/// the OAuth + Gmail API calls this replaced without any caller here
/// changing. The MIME-tree walk below is unrelated to the network and is
/// kept intact — it's exercised directly by tests.
class GmailLabSource {
  GmailLabSource();

  /// Attachment types the lab parser can actually read.
  static const Set<String> _readableExtensions = {
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
  };

  static final List<GmailAttachment> _fixtureCandidates = [
    GmailAttachment(
      messageId: 'fixture-1',
      attachmentId: 'fixture-1-a1',
      filename: 'Quest_Diagnostics_Lab_Report.pdf',
      subject: 'Your lab results are ready',
      from: 'Quest Diagnostics <noreply@questdiagnostics.com>',
      receivedAt: DateTime.now().subtract(const Duration(days: 12)),
      sizeBytes: 214000,
    ),
    GmailAttachment(
      messageId: 'fixture-2',
      attachmentId: 'fixture-2-a1',
      filename: 'LabCorp_CBC_Metabolic_Panel.pdf',
      subject: 'New test results available',
      from: 'LabCorp <results@labcorp.com>',
      receivedAt: DateTime.now().subtract(const Duration(days: 47)),
      sizeBytes: 188500,
    ),
  ];

  Future<bool> get isAuthorized async => true;

  /// Finds messages that look like they carry a lab report.
  Future<List<GmailAttachment>> findCandidates({int limit = 25}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return _fixtureCandidates;
  }

  /// No file is actually downloaded — [LocalLabParser] never reads
  /// [LabUpload.path], only its metadata, so a placeholder path is enough.
  Future<LabUpload> download(GmailAttachment attachment) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return LabUpload(
      path: attachment.filename,
      name: attachment.filename,
      source: LabSource.email,
      sizeBytes: attachment.sizeBytes ?? 200000,
    );
  }

  /// Collects readable attachments from a message payload.
  ///
  /// Public for tests: real lab mail nests attachments inside
  /// `multipart/mixed` → `multipart/related` several levels down, and a walk
  /// that only checks the top level silently finds nothing.
  @visibleForTesting
  static List<GmailAttachment> attachmentsFromPayload(
    Object? payload, {
    String messageId = 'm1',
    String subject = '',
    String from = '',
    DateTime? receivedAt,
  }) {
    final into = <GmailAttachment>[];
    _collectAttachments(
      payload,
      messageId: messageId,
      subject: subject,
      from: from,
      receivedAt: receivedAt ?? DateTime(2026),
      into: into,
    );
    return into;
  }

  /// Walks the MIME tree. Attachments can be nested several levels deep in
  /// multipart messages, so this recurses rather than checking only the top.
  static void _collectAttachments(
    Object? part, {
    required String messageId,
    required String subject,
    required String from,
    required DateTime receivedAt,
    required List<GmailAttachment> into,
  }) {
    if (part is! Map) return;

    final filename = (part['filename'] as String?) ?? '';
    final body = part['body'];
    final attachmentId = body is Map ? body['attachmentId'] as String? : null;

    if (filename.isNotEmpty && attachmentId != null && _isReadable(filename)) {
      final size = body is Map ? (body['size'] as num?)?.toInt() : null;
      if (size == null || size <= LabUpload.maxSizeBytes) {
        into.add(
          GmailAttachment(
            messageId: messageId,
            attachmentId: attachmentId,
            filename: filename,
            sizeBytes: size,
            subject: subject,
            from: from,
            receivedAt: receivedAt,
          ),
        );
      }
    }

    for (final child in (part['parts'] as List?) ?? const []) {
      _collectAttachments(
        child,
        messageId: messageId,
        subject: subject,
        from: from,
        receivedAt: receivedAt,
        into: into,
      );
    }
  }

  static bool _isReadable(String filename) {
    final lower = filename.toLowerCase();
    return _readableExtensions.any(lower.endsWith);
  }

  void dispose() {}
}

/// One attachment that might be a lab report, with enough context for the user
/// to recognise it before anything is downloaded or parsed.
class GmailAttachment {
  const GmailAttachment({
    required this.messageId,
    required this.attachmentId,
    required this.filename,
    required this.subject,
    required this.from,
    required this.receivedAt,
    this.sizeBytes,
  });

  final String messageId;
  final String attachmentId;
  final String filename;
  final String subject;
  final String from;
  final DateTime receivedAt;
  final int? sizeBytes;

  /// Sender display name without the angle-bracket address, for the list row.
  String get senderName {
    final match = RegExp(r'^\s*"?([^"<]+?)"?\s*<').firstMatch(from);
    final name = match?.group(1)?.trim();
    return name != null && name.isNotEmpty ? name : from;
  }
}

/// The user declined Gmail access, or the grant was revoked or expired.
/// Unreachable in this build — kept because [GmailImportNotifier] still
/// catches it — a real backend restores the path that can throw it.
class GmailAccessDenied implements Exception {
  const GmailAccessDenied();

  @override
  String toString() => 'Gmail access was not granted';
}
