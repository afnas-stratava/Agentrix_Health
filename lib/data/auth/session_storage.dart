import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A signed-in session's display fields — not a Google ID token. Those expire
/// within the hour and are useless to replay after that, so there is nothing
/// worth persisting from them. What survives a restart is "who is signed
/// in", restored straight into account state without repeating the provider
/// handshake.
class StoredSession {
  const StoredSession({
    this.email,
    this.displayName,
    this.photoUrl,
    this.providerIds = const [],
  });

  final String? email;
  final String? displayName;
  final String? photoUrl;
  final List<String> providerIds;
}

/// Persists [StoredSession] across restarts, Keystore/Keychain-backed rather
/// than plaintext SharedPreferences since it carries the user's email.
class SessionStorage {
  const SessionStorage();

  static const _key = 'auth_session.v1';
  static const _storage = FlutterSecureStorage();

  Future<StoredSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      return StoredSession(
        email: map['email'] as String?,
        displayName: map['displayName'] as String?,
        photoUrl: map['photoUrl'] as String?,
        providerIds: (map['providerIds'] as List?)?.cast<String>() ?? const [],
      );
    } catch (error) {
      debugPrint('SessionStorage.read failed: $error');
      return null;
    }
  }

  Future<void> write(StoredSession session) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'email': session.email,
          'displayName': session.displayName,
          'photoUrl': session.photoUrl,
          'providerIds': session.providerIds,
        }),
      );
    } catch (error) {
      debugPrint('SessionStorage.write failed: $error');
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (error) {
      debugPrint('SessionStorage.clear failed: $error');
    }
  }
}
