import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/labs/lab_report.dart';

/// Collects lab documents handed to the app through the iOS share sheet.
///
/// This is the provider-agnostic import path, and the only one with no ceiling
/// on it. Mail.app already holds the user's iCloud, Gmail, Outlook, Yahoo and
/// IMAP accounts, and the Gmail and Outlook apps expose the same sheet — so
/// "Copy to Agentrix Health" reaches every mail provider without an OAuth
/// scope, Google verification, a CASA assessment or a 100-user cap.
///
/// The native side queues paths because a cold launch delivers the URL before
/// Dart is listening. [takePending] drains that queue; calling it twice does
/// not import the same file twice.
class SharedDocumentReceiver {
  const SharedDocumentReceiver({
    MethodChannel channel = const MethodChannel('agentrix/shared_documents'),
  }) : _channel = channel;

  final MethodChannel _channel;

  /// Documents shared since the last call, ready for the parser.
  ///
  /// Returns empty rather than throwing when the platform side is absent —
  /// Android and the test environment have no such channel, and a missing
  /// share path is not an error worth surfacing to the user.
  Future<List<LabUpload>> takePending() async {
    final List<String>? paths;
    try {
      paths = await _channel.invokeListMethod<String>('takePending');
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }

    if (paths == null || paths.isEmpty) return const [];

    final uploads = <LabUpload>[];
    for (final path in paths) {
      final upload = await _toUpload(path);
      if (upload != null) uploads.add(upload);
    }
    return uploads;
  }

  static Future<LabUpload?> _toUpload(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final name = path.split('/').last;
    if (!_isReadable(name)) return null;

    return LabUpload(
      path: path,
      name: name,
      // The document came out of a mail client, so this is the same provenance
      // the Gmail path records — the user should not see two different labels
      // for what is, to them, the same action.
      source: LabSource.email,
      sizeBytes: await file.length(),
    );
  }

  static const Set<String> _readableExtensions = {
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
  };

  static bool _isReadable(String name) {
    final lower = name.toLowerCase();
    return _readableExtensions.any(lower.endsWith);
  }
}
