import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/labs/lab_report.dart';
import '../auth/social_sign_in.dart' show AuthConfig;

/// Read-only Gmail access, scoped to finding lab reports the user already has.
///
/// The token is obtained on-device: an iOS OAuth client is issued no client
/// secret, so the PKCE flow `google_sign_in` runs needs no backend to exchange
/// the authorization code. Only [gmailReadonlyScope] is ever requested, and it
/// is requested *separately* from sign-in — a user can use the app without ever
/// granting it, and granting it is an explicit, revocable act.
///
/// Nothing here imports automatically. [findCandidates] returns what it found
/// and the user chooses; silently reaching into someone's mail and acting on
/// what it finds is not a thing a health app should do.
class GmailLabSource {
  GmailLabSource({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Restricted scope. Google requires OAuth verification plus an annual CASA
  /// assessment before this can be granted outside the project's test users.
  static const String gmailReadonlyScope =
      'https://www.googleapis.com/auth/gmail.readonly';

  static const String _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

  /// Attachment types the lab parser can actually read.
  static const Set<String> _readableExtensions = {
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
  };

  /// Narrow enough that the results are plausibly lab reports, broad enough to
  /// catch the major US labs and the generic wording hospital portals use.
  static const String searchQuery =
      'has:attachment '
      '(filename:pdf OR filename:jpg OR filename:jpeg OR filename:png) '
      '(lab OR laboratory OR labcorp OR quest OR "test result" OR "test results" '
      'OR pathology OR bloodwork OR "blood test" OR "blood work" OR diagnostics '
      'OR "lipid panel" OR cbc OR "metabolic panel" OR hba1c)';

  /// Asks for Gmail access, prompting if it has not been granted yet.
  ///
  /// Returns null when the user declines — a refusal, not an error, so callers
  /// show the manual upload path rather than a failure state.
  Future<Map<String, String>?> _authHeaders({bool prompt = true}) async {
    await _ensureInitialized();

    // Reuses the session the user already has if there is one, so granting
    // Gmail access does not make them sign in a second time.
    final existing = await GoogleSignIn.instance
        .attemptLightweightAuthentication();
    final account =
        existing ?? (prompt ? await GoogleSignIn.instance.authenticate() : null);
    if (account == null) return null;

    return account.authorizationClient.authorizationHeaders(
      const [gmailReadonlyScope],
      promptIfNecessary: prompt,
    );
  }

  /// [SocialSignIn] may have initialized the SDK already. A second call throws
  /// on some platforms, and there is no "is initialized" query, so the result
  /// is memoised and a repeat failure swallowed rather than surfaced.
  static Future<void>? _init;

  Future<void> _ensureInitialized() async {
    _init ??= GoogleSignIn.instance.initialize(
      clientId: AuthConfig.clientId,
      serverClientId: AuthConfig.serverClientId,
    );
    try {
      await _init;
    } catch (_) {
      // Already initialized by another caller.
    }
  }

  /// True when Gmail access has already been granted, without prompting.
  Future<bool> get isAuthorized async {
    try {
      return await _authHeaders(prompt: false) != null;
    } catch (_) {
      return false;
    }
  }

  /// Finds messages that look like they carry a lab report.
  ///
  /// [limit] caps how many messages are opened — each one costs a round trip,
  /// and a user with years of mail should not wait on all of them.
  Future<List<GmailAttachment>> findCandidates({int limit = 25}) async {
    final headers = await _authHeaders();
    if (headers == null) throw const GmailAccessDenied();

    final listed = await _getJson(
      Uri.parse(
        '$_base/messages'
        '?q=${Uri.encodeQueryComponent(searchQuery)}'
        '&maxResults=$limit',
      ),
      headers,
    );

    final messages = (listed['messages'] as List?) ?? const [];
    final found = <GmailAttachment>[];

    for (final entry in messages) {
      if (entry is! Map) continue;
      final id = entry['id'] as String?;
      if (id == null) continue;

      final message = await _getJson(
        Uri.parse('$_base/messages/$id?format=full'),
        headers,
      );

      final headerMap = _headerMap(message);
      final receivedMs = int.tryParse((message['internalDate'] as String?) ?? '');

      _collectAttachments(
        message['payload'],
        messageId: id,
        subject: headerMap['subject'] ?? '(no subject)',
        from: headerMap['from'] ?? '',
        receivedAt: receivedMs == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(receivedMs),
        into: found,
      );
    }

    found.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return found;
  }

  /// Downloads one attachment to a temp file and wraps it as a [LabUpload]
  /// ready for the parser. The file is written under [Directory.systemTemp] so
  /// it is not backed up and does not linger in the app's documents.
  Future<LabUpload> download(GmailAttachment attachment) async {
    final headers = await _authHeaders();
    if (headers == null) throw const GmailAccessDenied();

    final body = await _getJson(
      Uri.parse(
        '$_base/messages/${attachment.messageId}'
        '/attachments/${attachment.attachmentId}',
      ),
      headers,
    );

    final data = body['data'] as String?;
    if (data == null) {
      throw StateError('Gmail returned no data for ${attachment.filename}');
    }

    final bytes = base64Url.decode(base64.normalize(data));
    final dir = await Directory.systemTemp.createTemp('agentrix_lab_');
    final file = File('${dir.path}/${attachment.filename}');
    await file.writeAsBytes(bytes, flush: true);

    return LabUpload(
      path: file.path,
      name: attachment.filename,
      source: LabSource.email,
      sizeBytes: bytes.lengthInBytes,
    );
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final response = await _http.get(uri, headers: headers);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const GmailAccessDenied();
    }
    if (response.statusCode != 200) {
      throw StateError('Gmail ${response.statusCode} for ${uri.path}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Gmail returned ${decoded.runtimeType} for ${uri.path}');
    }
    return decoded;
  }

  static Map<String, String> _headerMap(Map<String, dynamic> message) {
    final payload = message['payload'];
    if (payload is! Map) return const {};
    final headers = (payload['headers'] as List?) ?? const [];
    return {
      for (final header in headers)
        if (header is Map && header['name'] is String)
          (header['name'] as String).toLowerCase():
              (header['value'] as String?) ?? '',
    };
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

  void dispose() => _http.close();
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
/// Distinct from a transport failure so the UI can offer the manual path
/// instead of presenting a refusal as an error.
class GmailAccessDenied implements Exception {
  const GmailAccessDenied();

  @override
  String toString() => 'Gmail access was not granted';
}
